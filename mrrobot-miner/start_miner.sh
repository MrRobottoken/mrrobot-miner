#!/bin/bash
# Start the Mr. Robot AMD miner
# Usage: ./start_miner.sh <YOUR_SOLANA_WALLET_ADDRESS>

if [ -z "$1" ]; then
    echo "Usage: $0 <solana_wallet_address>"
    echo "Example: $0 YourSolanaWalletAddressHere"
    exit 1
fi

WALLET="$1"
ORACLE="${ORACLE_URL:-http://oracle.mrrobottoken.com:8181}"

cd "$(dirname "$0")"
echo "[MR. ROBOT] Starting AMD miner..."
echo "[MR. ROBOT] Wallet  : $WALLET"
echo "[MR. ROBOT] Oracle  : $ORACLE"
echo

python3 -m miner.main --wallet "$WALLET" --oracle "$ORACLE"
