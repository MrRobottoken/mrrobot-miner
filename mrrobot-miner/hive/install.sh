#!/usr/bin/env bash
# ============================================================
#   MR. ROBOT — HiveOS Installer
#   Installs lolMiner + run scripts to /hive/miners/mrrobot/
#
#   One-command install on your HiveOS rig:
#     curl -fsSL https://raw.githubusercontent.com/MrRobottoken/mrrobot-miner/main/hive/install.sh | bash
#
#   Or if you cloned the repo:
#     bash hive/install.sh
# ============================================================
set -e

GREEN='\033[0;32m'
RED='\033[1;31m'
YL='\033[0;33m'
NC='\033[0m'

INSTALL_DIR="/hive/miners/mrrobot"
REPO_URL="https://github.com/MrRobottoken/mrrobot-miner"
LOLMINER_VER="1.98a"
LOLMINER_URL="https://github.com/Lolliedieb/lolMiner-releases/releases/download/${LOLMINER_VER}/lolMiner_v${LOLMINER_VER}_Lin64.tar.gz"

echo -e "${GREEN}"
cat << 'BANNER'
 ███╗   ███╗██████╗       ██████╗  ██████╗ ██████╗  ██████╗ ████████╗
 ████╗ ████║██╔══██╗      ██╔══██╗██╔═══██╗██╔══██╗██╔═══██╗╚══██╔══╝
 ██╔████╔██║██████╔╝      ██████╔╝██║   ██║██████╔╝██║   ██║   ██║
 ██║╚██╔╝██║██╔══██╗      ██╔══██╗██║   ██║██╔══██╗██║   ██║   ██║
 ██║ ╚═╝ ██║██║  ██║      ██║  ██║╚██████╔╝██████╔╝╚██████╔╝   ██║
 ╚═╝     ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ╚═════╝    ╚═╝
BANNER
echo -e "  ${GREEN}\$MRRBT AMD-Only HiveOS Miner — Installer${NC}"
echo ""

# ── Check we are on HiveOS ────────────────────────────────────
if [[ ! -d /hive ]]; then
    echo -e "${YL}[WARN] /hive not found. This installer is designed for HiveOS."
    echo -e "       For Ubuntu/Debian, use  bash install.sh  from the repo root.${NC}"
fi

# ── Check AMD GPU ─────────────────────────────────────────────
echo -e "${GREEN}[1/4] Scanning for AMD GPU...${NC}"
AMD_COUNT=$(ls /sys/class/hwmon/ 2>/dev/null | while read h; do
    name="/sys/class/hwmon/$h/name"
    [[ -f "$name" ]] && grep -q "amdgpu" "$name" && echo "1"
done | wc -l)

if [[ "$AMD_COUNT" -gt 0 ]]; then
    echo "    Found ${AMD_COUNT} AMD GPU(s)"
else
    echo -e "${YL}    WARNING: No AMD GPU detected — make sure amdgpu drivers are loaded.${NC}"
fi

# ── Install lolMiner ──────────────────────────────────────────
echo -e "${GREEN}[2/4] Installing lolMiner ${LOLMINER_VER}...${NC}"
mkdir -p "$INSTALL_DIR"

if [[ -x "$INSTALL_DIR/lolMiner" ]]; then
    echo "    Already installed, skipping download."
else
    echo "    Downloading lolMiner ${LOLMINER_VER}..."
    command -v wget &>/dev/null || apt-get install -y wget -qq
    wget -q "$LOLMINER_URL" -O /tmp/lolminer.tar.gz
    tar -xzf /tmp/lolminer.tar.gz -C /tmp/
    LOLMINER_BIN=$(find /tmp -name "lolMiner" -type f 2>/dev/null | head -1)
    if [[ -z "$LOLMINER_BIN" ]]; then
        echo -e "${RED}    ERROR: Could not find lolMiner binary after extraction.${NC}"
        exit 1
    fi
    cp "$LOLMINER_BIN" "$INSTALL_DIR/lolMiner"
    chmod +x "$INSTALL_DIR/lolMiner"
    rm -f /tmp/lolminer.tar.gz
    echo "    OK — lolMiner ${LOLMINER_VER}"
fi

# ── Download / copy miner scripts ─────────────────────────────
echo -e "${GREEN}[3/4] Installing to ${INSTALL_DIR}...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "$REPO_ROOT/mine.sh" ]]; then
    echo "    Copying from local repo..."
    cp    "$REPO_ROOT/mine.sh"           "$INSTALL_DIR/"
    cp -r "$REPO_ROOT/hive"              "$INSTALL_DIR/"
else
    echo "    Downloading from GitHub..."
    command -v git &>/dev/null || apt-get install -y git -qq
    rm -rf /tmp/mrrobot-clone
    git clone --depth=1 "$REPO_URL" /tmp/mrrobot-clone 2>&1 | tail -2
    cp    /tmp/mrrobot-clone/mine.sh      "$INSTALL_DIR/"
    cp -r /tmp/mrrobot-clone/hive         "$INSTALL_DIR/"
    rm -rf /tmp/mrrobot-clone
fi

# Copy HiveOS hook scripts to top-level install dir
cp "$INSTALL_DIR/hive/h-manifest.conf"  "$INSTALL_DIR/"
cp "$INSTALL_DIR/hive/h-run.sh"         "$INSTALL_DIR/"
cp "$INSTALL_DIR/hive/h-stats.sh"       "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/h-run.sh" "$INSTALL_DIR/h-stats.sh" "$INSTALL_DIR/mine.sh"
echo "    OK"

# ── Done ─────────────────────────────────────────────────────
echo -e "${GREEN}[4/4] Done.${NC}"
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  MR. ROBOT MINER INSTALLED                                      ║${NC}"
echo -e "${GREEN}║                                                                  ║${NC}"
echo -e "${GREEN}║  HiveOS Flight Sheet:                                            ║${NC}"
echo -e "${GREEN}║    Miner    → Custom                                             ║${NC}"
echo -e "${GREEN}║    Name     → mrrobot                                            ║${NC}"
echo -e "${GREEN}║    Run path → /hive/miners/mrrobot/h-run.sh                     ║${NC}"
echo -e "${GREEN}║    Extra config:                                                 ║${NC}"
echo -e "${GREEN}║      WALLET=<your_solana_address>                                ║${NC}"
echo -e "${GREEN}║                                                                  ║${NC}"
echo -e "${GREEN}║  Or mine directly:                                               ║${NC}"
echo -e "${GREEN}║    ./mine.sh <your_solana_wallet_address>                        ║${NC}"
echo -e "${GREEN}║                                                                  ║${NC}"
echo -e "${GREEN}║  The revolution is being hashed.                                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
