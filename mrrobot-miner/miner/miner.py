"""
Mining loop.  Runs one thread per GPU, polls Oracle for jobs,
submits shares when found.
"""
from __future__ import annotations

import asyncio
import collections
import logging
import threading
import time
import struct

from .gpu import MiningContext, detect_amd_gpus, GPUDevice, BATCH_SIZE
from .client import OracleClient

log = logging.getLogger("mrrobot.miner")


class GPUMiner:
    """Controls one GPU mining loop."""

    def __init__(self, ctx: MiningContext, oracle: OracleClient, share_log=None, share_lock=None):
        self.ctx         = ctx
        self.oracle      = oracle
        self._stop       = threading.Event()
        self._thread: threading.Thread | None = None
        self.status      = "IDLE"
        self._share_log  = share_log   # deque shared with MrRobotMiner
        self._share_lock = share_lock

    def start(self):
        self._thread = threading.Thread(
            target=self._run, daemon=True, name=f"GPU-{self.ctx.gpu.index}"
        )
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=5)

    # ------------------------------------------------------------------
    def _run(self):
        self.status = "INITIALIZING"
        gpu_idx     = self.ctx.gpu.index

        # Stagger start to spread Oracle polling load
        time.sleep(gpu_idx * 0.25)

        nonce_offset    = gpu_idx * (1 << 48)  # each GPU owns a 48-bit nonce space
        nonce           = nonce_offset
        job             = None
        job_id          = None
        last_job_check  = 0.0
        JOB_CHECK_SEC   = 5  # re-poll Oracle every 5 seconds, not every batch

        while not self._stop.is_set():
            now = time.monotonic()

            # Only hit Oracle when we have no job or it's time to refresh
            if job is None or (now - last_job_check) >= JOB_CHECK_SEC:
                try:
                    new_job = asyncio.run(self.oracle.get_job())
                    if new_job:
                        job = new_job
                    last_job_check = time.monotonic()
                except Exception as e:
                    log.warning(f"GPU {gpu_idx}: Oracle unreachable – {e}")
                    if job is None:
                        self.status = "WAITING FOR ORACLE"
                        time.sleep(3)
                        continue

            if not job:
                time.sleep(1)
                continue

            # Re-init scratchpad if epoch changed
            epoch = job.get("epoch", 0)
            self.ctx.init_scratchpad(epoch)

            header_bytes    = bytes.fromhex(job["block_header_hex"])
            difficulty_bits = job["difficulty_bits"]
            current_job_id  = job["job_id"]

            # If job changed, reset nonce within our space
            if current_job_id != job_id:
                job_id = current_job_id
                nonce  = nonce_offset
                self.status = "MINING"

            # Run one GPU batch — stays hot between Oracle polls
            result = self.ctx.mine_batch(header_bytes, nonce, difficulty_bits)
            nonce += BATCH_SIZE

            if result:
                winning_nonce, winning_hash = result
                self.status = "SHARE FOUND!"
                log.info(
                    f"GPU {gpu_idx}: SHARE! nonce={hex(winning_nonce)} "
                    f"hash={winning_hash[:16]}..."
                )
                try:
                    resp = asyncio.run(
                        self.oracle.submit_share(
                            job_id=job_id,
                            nonce=winning_nonce,
                            result_hash=winning_hash,
                        )
                    )
                    log.info(f"GPU {gpu_idx}: Oracle response – {resp}")

                    # Record share + tx proof for dashboard display
                    if self._share_log is not None and resp:
                        tx_sig  = resp.get("tx_signature", "")
                        reward  = resp.get("reward_mrrbt", 0) / 1_000_000
                        entry = {
                            "time":    time.strftime("%H:%M:%S"),
                            "gpu":     gpu_idx,
                            "nonce":   hex(winning_nonce),
                            "hash":    winning_hash[:16],
                            "reward":  reward,
                            "tx_sig":  tx_sig,
                            "status":  resp.get("status", "?"),
                        }
                        with self._share_lock:
                            self._share_log.appendleft(entry)

                except Exception as e:
                    log.error(f"GPU {gpu_idx}: Share submission failed – {e}")

                # Force job refresh immediately after share (new prev_hash)
                job            = None
                last_job_check = 0.0
                self.status    = "MINING"

            # Wrap nonce within our 48-bit block
            if nonce >= nonce_offset + (1 << 48):
                nonce = nonce_offset


class MrRobotMiner:
    """
    Top-level miner.  Detects AMD GPUs, spins up one GPUMiner per device.
    """

    def __init__(self, oracle_url: str, wallet_address: str):
        self.oracle        = OracleClient(oracle_url, wallet_address)
        self.gpus: list[GPUMiner] = []
        self.recent_shares: collections.deque = collections.deque(maxlen=12)
        self._shares_lock  = threading.Lock()

    def start(self, progress_cb=None) -> list[GPUDevice]:
        devices = detect_amd_gpus()
        workers = []

        # Phase 1: initialize all OpenCL contexts before any thread starts
        for dev in devices:
            if progress_cb:
                progress_cb(dev, "init")
            ctx    = MiningContext(dev)
            worker = GPUMiner(ctx, self.oracle,
                              share_log=self.recent_shares,
                              share_lock=self._shares_lock)
            workers.append(worker)
            if progress_cb:
                progress_cb(dev, "online")
            log.info(f"Initialized {dev}")

        # Phase 2: start all mining threads once every context is ready
        for worker in workers:
            worker.start()
            self.gpus.append(worker)

        return [w.ctx.gpu for w in self.gpus]

    def stop(self):
        for w in self.gpus:
            w.stop()

    # ------------------------------------------------------------------
    @property
    def total_mhs(self) -> float:
        return sum(w.ctx.mhash_rate for w in self.gpus)

    @property
    def total_shares(self) -> int:
        return sum(w.ctx.shares_found for w in self.gpus)

    def gpu_stats(self) -> list[dict]:
        return [
            {
                "index":   w.ctx.gpu.index,
                "name":    w.ctx.gpu.name,
                "mhs":     round(w.ctx.mhash_rate, 2),
                "shares":  w.ctx.shares_found,
                "status":  w.status,
                "vram":    w.ctx.gpu.vram_mb,
                "cu":      w.ctx.gpu.cu_count,
                "temp_c":  w.ctx.gpu.read_temp_c(),
                "power_w": w.ctx.gpu.read_power_w(),
                "fan_pct": w.ctx.gpu.read_fan_pct(),
            }
            for w in self.gpus
        ]
