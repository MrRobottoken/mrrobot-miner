#!/bin/bash
# ============================================================
#   MR. ROBOT — $MRRBT AMD-Only GPU Miner
#   Usage:  ./mine.sh <YOUR_SOLANA_WALLET_ADDRESS>
# ============================================================

if [ -z "$1" ]; then
    echo ""
    echo "  Usage:  ./mine.sh <your_solana_wallet_address>"
    echo ""
    echo "  Example:"
    echo "    ./mine.sh AbCdEf1234...YourWalletHere"
    echo ""
    exit 1
fi

WALLET="$1"
WORKER="${WORKER:-mrrobot}"
DIFF="${DIFF:-4300}"
POOL="${POOL:-ethash.unmineable.com:3333}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOLMINER="${LOLMINER:-$SCRIPT_DIR/lolMiner}"

if [[ ! -x "$LOLMINER" ]]; then
    LOLMINER="$(command -v lolMiner 2>/dev/null)"
fi
if [[ -z "$LOLMINER" || ! -x "$LOLMINER" ]]; then
    echo "  ERROR: lolMiner not found. Run ./install.sh first."
    exit 1
fi

exec "$LOLMINER" \
    --algo ETHASH \
    --pool "$POOL" \
    --user "MRRBT:${WALLET}.${WORKER}+${DIFF}" \
    --pass x \
    --apiport 10080
