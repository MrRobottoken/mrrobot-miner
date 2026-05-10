"""
Mining session fee collector.
Sends a small SOL fee from the miner's wallet to the project fee wallet
before mining begins.  Uses solana CLI if available, falls back to
solders direct transaction if a keypair path is provided.
"""
import os
import subprocess
import sys
import time

FEE_SOL    = float(os.getenv("MINING_FEE_SOL",    "0.002"))
FEE_WALLET = os.getenv("MINING_FEE_WALLET", "GWyaGZgrrd8Le6c9ZS7NtwzmrewFyb3kZHikGtEGTEwj")

G  = "\033[0;32m"
BG = "\033[1;32m"
CY = "\033[0;36m"
YL = "\033[0;33m"
RD = "\033[0;31m"
NC = "\033[0m"


def _try_solana_cli() -> bool:
    """Attempt fee payment via solana CLI.  Returns True on success."""
    try:
        result = subprocess.run(
            ["solana", "transfer", FEE_WALLET, str(FEE_SOL),
             "--allow-unfunded-recipient", "--commitment", "confirmed"],
            capture_output=True, text=True, timeout=60,
        )
        if result.returncode == 0:
            sig = result.stdout.strip().split()[-1]
            print(f"  {BG}Fee sent!{NC} tx: {sig[:20]}…")
            return True
        else:
            print(f"  {YL}solana CLI error: {result.stderr.strip()[:120]}{NC}")
    except FileNotFoundError:
        pass  # solana CLI not installed
    except Exception as e:
        print(f"  {YL}solana CLI: {e}{NC}")
    return False


def _try_keypair_file(keypair_path: str) -> bool:
    """Attempt fee payment using a keypair JSON file via solders."""
    try:
        import json
        import asyncio
        from solders.keypair import Keypair
        from solders.pubkey import Pubkey
        from solders.system_program import transfer, TransferParams
        from solders.transaction import Transaction
        from solana.rpc.async_api import AsyncClient
        from solana.rpc.commitment import Confirmed

        with open(keypair_path) as f:
            key_bytes = bytes(json.load(f))
        kp = Keypair.from_bytes(key_bytes)

        async def _send():
            async with AsyncClient(
                os.getenv("SOLANA_RPC_URL", "https://api.mainnet-beta.solana.com"),
                commitment=Confirmed,
            ) as client:
                dest     = Pubkey.from_string(FEE_WALLET)
                lamports = int(FEE_SOL * 1_000_000_000)

                blockhash = (await client.get_latest_blockhash()).value.blockhash
                ix  = transfer(TransferParams(
                    from_pubkey=kp.pubkey(),
                    to_pubkey=dest,
                    lamports=lamports,
                ))
                tx  = Transaction.new_signed_with_payer(
                    instructions=[ix],
                    payer=kp.pubkey(),
                    signing_keypairs=[kp],
                    recent_blockhash=blockhash,
                )
                result = await client.send_transaction(tx)
                return str(result.value)

        sig = asyncio.run(_send())
        print(f"  {BG}Fee sent!{NC} tx: {sig[:20]}…")
        return True

    except Exception as e:
        print(f"  {YL}Keypair send failed: {e}{NC}")
        return False


def collect_fee() -> bool:
    """
    Show the fee info and try to collect it automatically.
    Returns True if fee was sent, False if manual/skipped.
    """
    print(f"\n  {CY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{NC}")
    print(f"  {BG}MINING SESSION FEE: {FEE_SOL} SOL{NC}")
    print(f"  {G}This SOL is auto-swapped → $MRRBT via Jupiter to pump{NC}")
    print(f"  {G}the liquidity pool and refill the mining payout treasury.{NC}")
    print(f"  {CY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{NC}")
    print(f"\n  {G}Fee destination:{NC} {FEE_WALLET}")
    print()

    # Try solana CLI first (most common setup)
    if _try_solana_cli():
        return True

    # Try default keypair locations
    default_paths = [
        os.path.expanduser("~/.config/solana/id.json"),
        os.path.expanduser("~/.config/solana/id.json"),
    ]
    for path in default_paths:
        if os.path.exists(path):
            print(f"  {G}Found keypair at {path}, using it...{NC}")
            if _try_keypair_file(path):
                return True

    # Manual fallback
    print(f"  {YL}Could not auto-send fee. To pay manually:{NC}")
    print(f"  {YL}  solana transfer {FEE_WALLET} {FEE_SOL} --allow-unfunded-recipient{NC}")
    print(f"  {YL}  or send {FEE_SOL} SOL from Phantom to:{NC}")
    print(f"  {YL}  {FEE_WALLET}{NC}")
    print()
    ans = input(f"  Press Enter to mine anyway, or Ctrl+C to exit: ")
    return False


if __name__ == "__main__":
    collect_fee()
