#!/usr/bin/env bash
# ============================================================
#   MR. ROBOT — HiveOS run script
#   Called by HiveOS to start the miner.
#   Set in flight sheet Extra config:
#     WALLET=<your_solana_address>
#     ORACLE_URL=http://oracle.mrrobottoken.com:8181   (optional)
# ============================================================

MINER_DIR="/hive/miners/mrrobot"
LOG_DIR="${MINER_LOG_BASEDIR:-/var/log/miner}"
LOG_FILE="${LOG_DIR}/mrrobot.log"

# Parse WALLET and ORACLE_URL from CUSTOM_USER_CONFIG (flight sheet Extra config)
if [[ -n "$CUSTOM_USER_CONFIG" ]]; then
    while IFS='=' read -r key val; do
        key="${key// /}"
        val="${val// /}"
        case "$key" in
            WALLET)     WALLET="$val" ;;
            ORACLE_URL) ORACLE_URL="$val" ;;
        esac
    done <<< "$CUSTOM_USER_CONFIG"
fi

ORACLE_URL="${ORACLE_URL:-http://oracle.mrrobottoken.com:8181}"

if [[ -z "$WALLET" ]]; then
    echo "[mrrobot] ERROR: No WALLET set. Add  WALLET=<solana_address>  to flight sheet Extra config."
    exit 1
fi

echo "[mrrobot] Wallet : $WALLET"
echo "[mrrobot] Oracle : $ORACLE_URL"
echo "[mrrobot] Log    : $LOG_FILE"
echo ""

mkdir -p "$LOG_DIR"

cd "$MINER_DIR"
exec python3 -m miner.main \
    --wallet "$WALLET" \
    --oracle "$ORACLE_URL" \
    2>&1 | tee "$LOG_FILE"
