#!/bin/bash
# ============================================================
#   MR. ROBOT — $MRRBT AMD-Only GPU Miner
#   Usage:  ./mine.sh <YOUR_SOLANA_WALLET_ADDRESS>
# ============================================================

ORACLE_URL="${ORACLE_URL:-http://oracle.mrrobottoken.com:8181}"

if [ -z "$1" ]; then
    echo ""
    echo "  Usage:  ./mine.sh <your_solana_wallet_address>"
    echo ""
    echo "  Example:"
    echo "    ./mine.sh AbCdEf1234...YourWalletHere"
    echo ""
    echo "  Set a custom Oracle URL:"
    echo "    ORACLE_URL=http://your.oracle.ip:8181 ./mine.sh <wallet>"
    echo ""
    exit 1
fi

WALLET="$1"
cd "$(dirname "$0")"

python3 -m miner.main --wallet "$WALLET" --oracle "$ORACLE_URL"
