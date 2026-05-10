"""
HTTP client for communication with the Mr. Robot Oracle server.
"""
import asyncio
import logging
import httpx

log = logging.getLogger("mrrobot.client")

DEFAULT_ORACLE = "http://oracle.mrrobottoken.com:8181"


class OracleClient:
    def __init__(self, oracle_url: str, miner_wallet: str):
        self.oracle_url   = oracle_url.rstrip("/")
        self.miner_wallet = miner_wallet
        self._job_cache   = None

    async def get_job(self) -> dict:
        async with httpx.AsyncClient(timeout=10.0) as c:
            r = await c.get(f"{self.oracle_url}/job")
            r.raise_for_status()
            self._job_cache = r.json()
            return self._job_cache

    async def submit_share(
        self, job_id: str, nonce: int, result_hash: str
    ) -> dict:
        payload = {
            "job_id":        job_id,
            "miner_address": self.miner_wallet,
            "nonce":         hex(nonce),
            "result_hash":   result_hash,
        }
        async with httpx.AsyncClient(timeout=30.0) as c:
            r = await c.post(f"{self.oracle_url}/submit", json=payload)
            r.raise_for_status()
            return r.json()

    async def get_stats(self) -> dict:
        async with httpx.AsyncClient(timeout=10.0) as c:
            r = await c.get(f"{self.oracle_url}/stats")
            r.raise_for_status()
            return r.json()

    async def get_treasury(self) -> dict:
        async with httpx.AsyncClient(timeout=10.0) as c:
            r = await c.get(f"{self.oracle_url}/treasury")
            r.raise_for_status()
            return r.json()

    async def get_buyback(self) -> dict:
        async with httpx.AsyncClient(timeout=10.0) as c:
            r = await c.get(f"{self.oracle_url}/buyback")
            r.raise_for_status()
            return r.json()
