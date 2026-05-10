"""
GPU management for Mr. Robot Miner.
AMD-only enforcement via OpenCL vendor string check.
"""
from __future__ import annotations

import struct
import time
import glob
import numpy as np
import pyopencl as cl
from pathlib import Path

AMD_VENDOR_STRINGS = ("Advanced Micro Devices", "AMD")
KERNEL_FILE = Path(__file__).parent / "kernel.cl"

SCRATCHPAD_ENTRIES = 262144   # 256 K × 8 uint32 = 8 MB
SCRATCHPAD_WORDS   = 2097152  # 2 M uint32
BATCH_SIZE         = 65536    # nonces per kernel launch


class AMDGPUError(RuntimeError):
    pass


class GPUDevice:
    def __init__(self, cl_platform, cl_device, index: int):
        self.platform  = cl_platform
        self.device    = cl_device
        self.index     = index
        self.name      = cl_device.name.strip()
        self.vendor    = cl_device.vendor.strip()
        self.vram_mb   = cl_device.global_mem_size // (1024 * 1024)
        self.cu_count  = cl_device.max_compute_units
        self.clock_mhz = cl_device.max_clock_frequency
        self._hwmon    = self._find_hwmon(cl_device)

    def _find_hwmon(self, cl_device) -> str | None:
        """Match this OpenCL device to its /sys/class/hwmon path via PCI address."""
        try:
            topo = cl_device.get_info(0x4037)  # CL_DEVICE_TOPOLOGY_AMD
            # sysfs path ends with "domain:bus:device.function", e.g. "0000:01:00.0"
            pci_suffix = f"{topo.bus:02x}:{topo.device:02x}.{topo.function}"
            for hwmon in glob.glob("/sys/class/hwmon/hwmon*"):
                dev_link = Path(hwmon) / "device"
                if dev_link.exists():
                    pci_addr = Path(dev_link).resolve().name
                    if pci_addr.endswith(pci_suffix):
                        name = (Path(hwmon) / "name").read_text().strip()
                        if name == "amdgpu":
                            return hwmon
        except Exception:
            pass
        return None

    def read_temp_c(self) -> int | None:
        """GPU junction temperature in °C, or None if unavailable."""
        if not self._hwmon:
            return None
        try:
            raw = int(Path(self._hwmon, "temp1_input").read_text())
            return raw // 1000
        except Exception:
            return None

    def read_power_w(self) -> int | None:
        """GPU power draw in Watts, or None if unavailable."""
        if not self._hwmon:
            return None
        for fname in ("power1_average", "power1_input"):
            try:
                raw = int(Path(self._hwmon, fname).read_text())
                return raw // 1_000_000
            except Exception:
                continue
        return None

    def read_fan_pct(self) -> int | None:
        """Fan speed as 0-100%, or None if unavailable."""
        if not self._hwmon:
            return None
        try:
            rpm = int(Path(self._hwmon, "fan1_input").read_text())
            max_rpm_path = Path(self._hwmon, "fan1_max")
            if max_rpm_path.exists():
                max_rpm = int(max_rpm_path.read_text())
                return min(100, round(rpm * 100 / max_rpm)) if max_rpm else None
            pwm_path = Path(self._hwmon, "pwm1")
            if pwm_path.exists():
                pwm = int(pwm_path.read_text())
                return round(pwm * 100 / 255)
        except Exception:
            pass
        return None

    def __str__(self):
        return (
            f"GPU {self.index} │ {self.name:<32s} │ "
            f"{self.vram_mb:>5d} MB │ {self.cu_count:>3d} CUs │ {self.clock_mhz} MHz"
        )


def detect_amd_gpus() -> list[GPUDevice]:
    """
    Enumerate OpenCL GPUs and keep only AMD devices.
    Raises AMDGPUError if no AMD hardware is found.
    """
    found = []
    non_amd = []

    for platform in cl.get_platforms():
        try:
            devices = platform.get_devices(cl.device_type.GPU)
        except cl.Error:
            continue

        for dev in devices:
            vendor = dev.vendor.strip()
            is_amd = any(s.upper() in vendor.upper() for s in AMD_VENDOR_STRINGS)
            if is_amd:
                found.append(GPUDevice(platform, dev, len(found)))
            else:
                non_amd.append(dev.name.strip())

    if non_amd:
        names = ", ".join(non_amd)
        print(f"\n[NO-NAVIDAD] Rejected non-AMD hardware: {names}")

    if not found:
        raise AMDGPUError(
            "ACCESS DENIED: NO AMD HARDWARE DETECTED\n"
            "This miner is AMD-only. The revolution requires Polaris silicon."
        )

    return found


class MiningContext:
    """
    OpenCL context bound to a single AMD GPU.
    Owns the scratchpad buffer, compiled kernels, and per-GPU stats.
    """

    def __init__(self, gpu: GPUDevice):
        self.gpu      = gpu
        self.ctx      = cl.Context([gpu.device])
        self.queue    = cl.CommandQueue(
            self.ctx,
            properties=cl.command_queue_properties.PROFILING_ENABLE,
        )

        src = KERNEL_FILE.read_text()
        self.prog = cl.Program(self.ctx, src).build(
            options="-cl-fast-relaxed-math -cl-mad-enable -cl-unsafe-math-optimizations"
        )

        # 8 MB scratchpad in VRAM (READ_WRITE so mrh_init can fill it)
        self.scratchpad = cl.Buffer(
            self.ctx,
            cl.mem_flags.READ_WRITE,
            size=SCRATCHPAD_WORDS * 4,
        )

        # Cached kernel handles (avoids repeated retrieval overhead)
        self._k_init = cl.Kernel(self.prog, "mrh_init")
        self._k_mine = cl.Kernel(self.prog, "mrh_mine")

        # Persistent header buffer (76 bytes = 19 uint32) — updated via copy
        self.buf_header = cl.Buffer(self.ctx, cl.mem_flags.READ_ONLY, 76)

        # Result buffers
        self.buf_found = cl.Buffer(self.ctx, cl.mem_flags.READ_WRITE, 4)
        self.buf_nonce = cl.Buffer(self.ctx, cl.mem_flags.READ_WRITE, 8)
        self.buf_hash  = cl.Buffer(self.ctx, cl.mem_flags.READ_WRITE, 32)

        self._epoch          = -1
        self.hashrate        = 0.0
        self.total_hashes    = 0
        self.shares_found    = 0
        self._t0             = time.monotonic()

    # ------------------------------------------------------------------
    def init_scratchpad(self, epoch: int):
        """Fill the 8 MB scratchpad for the given epoch (only if changed)."""
        if epoch == self._epoch:
            return

        k = self._k_init
        k.set_arg(0, self.scratchpad)
        k.set_arg(1, np.uint32(epoch))
        cl.enqueue_nd_range_kernel(self.queue, k, (SCRATCHPAD_ENTRIES,), None)
        self.queue.finish()
        self._epoch = epoch

    # ------------------------------------------------------------------
    def mine_batch(
        self,
        block_header: bytes,
        start_nonce: int,
        difficulty_bits: int,
    ):
        """
        Run one batch of BATCH_SIZE nonces.

        Args:
            block_header:    exactly 76 bytes (big-endian)
            start_nonce:     first nonce to try (uint64)
            difficulty_bits: number of leading zero bits required

        Returns:
            (nonce: int, hash_hex: str)  if a share was found, else None
        """
        assert len(block_header) == 76, f"header must be 76 bytes, got {len(block_header)}"

        # Upload header into persistent buffer (no allocation each call)
        header_arr = np.frombuffer(block_header, dtype=">u4").astype(np.uint32)
        cl.enqueue_copy(self.queue, self.buf_header, header_arr)

        # Reset the found flag
        zero = np.array([0], dtype=np.uint32)
        cl.enqueue_copy(self.queue, self.buf_found, zero)
        self.queue.finish()

        k = self._k_mine
        k.set_arg(0, self.scratchpad)
        k.set_arg(1, self.buf_header)
        k.set_arg(2, np.uint64(start_nonce))
        k.set_arg(3, np.uint32(difficulty_bits))
        k.set_arg(4, self.buf_found)
        k.set_arg(5, self.buf_nonce)
        k.set_arg(6, self.buf_hash)

        t0 = time.perf_counter()
        cl.enqueue_nd_range_kernel(self.queue, k, (BATCH_SIZE,), None)
        self.queue.finish()
        elapsed = time.perf_counter() - t0

        self.total_hashes += BATCH_SIZE
        if elapsed > 0:
            self.hashrate = BATCH_SIZE / elapsed  # H/s

        # Read result flag
        found = np.zeros(1, dtype=np.uint32)
        cl.enqueue_copy(self.queue, found, self.buf_found)
        self.queue.finish()

        if found[0] == 1:
            nonce_arr = np.zeros(1, dtype=np.uint64)
            hash_arr  = np.zeros(8, dtype=np.uint32)
            cl.enqueue_copy(self.queue, nonce_arr, self.buf_nonce)
            cl.enqueue_copy(self.queue, hash_arr,  self.buf_hash)
            self.queue.finish()

            nonce     = int(nonce_arr[0])
            hash_hex  = b"".join(struct.pack(">I", h) for h in hash_arr).hex()
            self.shares_found += 1
            return nonce, hash_hex

        return None

    # ------------------------------------------------------------------
    @property
    def mhash_rate(self) -> float:
        return self.hashrate / 1_000_000
