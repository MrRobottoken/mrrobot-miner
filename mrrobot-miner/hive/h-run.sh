#!/usr/bin/env bash
# ============================================================
#   MR. ROBOT — HiveOS run script
#   Called by HiveOS to start the miner.
#   Set in flight sheet Extra config:
#     WALLET=<your_solana_address>
#     WORKER=myrig            (optional, default: mrrobot)
#     DIFF=4300               (optional, default: 4300)
#     POOL=ethash.unmineable.com:3333   (optional)
# ============================================================

MINER_DIR="/hive/miners/mrrobot"
LOG_DIR="${MINER_LOG_BASEDIR:-/var/log/miner}"
LOG_FILE="${LOG_DIR}/mrrobot.log"

# Parse from flight sheet Extra config
if [[ -n "$CUSTOM_USER_CONFIG" ]]; then
    while IFS='=' read -r key val; do
        key="${key// /}"
        val="${val// /}"
        case "$key" in
            WALLET) WALLET="$val" ;;
            WORKER) WORKER="$val" ;;
            DIFF)   DIFF="$val" ;;
            POOL)   POOL="$val" ;;
        esac
    done <<< "$CUSTOM_USER_CONFIG"
fi

WORKER="${WORKER:-mrrobot}"
DIFF="${DIFF:-4300}"
POOL="${POOL:-ethash.unmineable.com:3333}"
LOLMINER="$MINER_DIR/lolMiner"

if [[ -z "$WALLET" ]]; then
    echo "[mrrobot] ERROR: No WALLET set. Add  WALLET=<solana_address>  to flight sheet Extra config."
    exit 1
fi

if [[ ! -x "$LOLMINER" ]]; then
    echo "[mrrobot] ERROR: lolMiner not found at $LOLMINER. Re-run the installer."
    exit 1
fi

echo "[mrrobot] Wallet  : $WALLET"
echo "[mrrobot] Worker  : $WORKER"
echo "[mrrobot] Pool    : $POOL"
echo "[mrrobot] Diff    : $DIFF"
echo ""

mkdir -p "$LOG_DIR"

exec "$LOLMINER" \
    --algo ETHASH \
    --pool "$POOL" \
    --user "MRRBT:${WALLET}.${WORKER}+${DIFF}" \
    --pass x \
    --apiport 10080 \
    2>&1 | tee "$LOG_FILE"
