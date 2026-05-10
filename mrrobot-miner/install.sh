#!/bin/bash
# ============================================================
#   MR. ROBOT — $MRRBT AMD-Only GPU Miner
#   Linux/Ubuntu Installer (non-HiveOS)
#   For HiveOS use: bash hive/install.sh
# ============================================================
set -e

GREEN='\033[0;32m'
RED='\033[1;31m'
YL='\033[0;33m'
NC='\033[0m'

LOLMINER_VER="1.98a"
LOLMINER_URL="https://github.com/Lolliedieb/lolMiner-releases/releases/download/${LOLMINER_VER}/lolMiner_v${LOLMINER_VER}_Lin64.tar.gz"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${GREEN}"
cat << 'BANNER'
 ███╗   ███╗██████╗       ██████╗  ██████╗ ██████╗  ██████╗ ████████╗
 ████╗ ████║██╔══██╗      ██╔══██╗██╔═══██╗██╔══██╗██╔═══██╗╚══██╔══╝
 ██╔████╔██║██████╔╝      ██████╔╝██║   ██║██████╔╝██║   ██║   ██║
 ██║╚██╔╝██║██╔══██╗      ██╔══██╗██║   ██║██╔══██╗██║   ██║   ██║
 ██║ ╚═╝ ██║██║  ██║      ██║  ██║╚██████╔╝██████╔╝╚██████╔╝   ██║
 ╚═╝     ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ╚═════╝    ╚═╝
BANNER
echo -e "  \$MRRBT AMD-Only GPU Miner — Installer${NC}"
echo ""

# ── Check AMD GPU ─────────────────────────────────────────────
echo -e "${GREEN}[1/3] Scanning for AMD GPU...${NC}"
AMD_COUNT=$(ls /sys/class/hwmon/ 2>/dev/null | while read h; do
    name="/sys/class/hwmon/$h/name"
    [[ -f "$name" ]] && grep -q "amdgpu" "$name" && echo "1"
done | wc -l)

if [[ "$AMD_COUNT" -gt 0 ]]; then
    echo "    Found ${AMD_COUNT} AMD GPU(s)"
else
    echo -e "${YL}    WARNING: No AMD GPU detected — install amdgpu-pro or ROCm drivers first.${NC}"
fi

# ── Install lolMiner ──────────────────────────────────────────
echo -e "${GREEN}[2/3] Installing lolMiner ${LOLMINER_VER}...${NC}"

if [[ -x "$SCRIPT_DIR/lolMiner" ]]; then
    echo "    Already installed at $SCRIPT_DIR/lolMiner"
else
    echo "    Downloading lolMiner ${LOLMINER_VER}..."
    command -v wget &>/dev/null || { apt-get update -qq && apt-get install -y wget -qq; }
    wget -q "$LOLMINER_URL" -O /tmp/lolminer.tar.gz
    tar -xzf /tmp/lolminer.tar.gz -C /tmp/
    LOLMINER_BIN=$(find /tmp -name "lolMiner" -type f 2>/dev/null | head -1)
    if [[ -z "$LOLMINER_BIN" ]]; then
        echo -e "${RED}    ERROR: lolMiner binary not found after extraction.${NC}"
        exit 1
    fi
    cp "$LOLMINER_BIN" "$SCRIPT_DIR/lolMiner"
    chmod +x "$SCRIPT_DIR/lolMiner"
    rm -f /tmp/lolminer.tar.gz
    echo "    OK — lolMiner ${LOLMINER_VER}"
fi

# ── Make scripts executable ───────────────────────────────────
echo -e "${GREEN}[3/3] Finalising...${NC}"
chmod +x "$SCRIPT_DIR/mine.sh" "$SCRIPT_DIR/public-miner-start.sh"
echo "    OK"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  INSTALL COMPLETE                                 ║${NC}"
echo -e "${GREEN}║                                                   ║${NC}"
echo -e "${GREEN}║  Start mining:                                    ║${NC}"
echo -e "${GREEN}║  ./mine.sh <your_solana_wallet_address>           ║${NC}"
echo -e "${GREEN}║                                                   ║${NC}"
echo -e "${GREEN}║  The revolution is being hashed.                  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
