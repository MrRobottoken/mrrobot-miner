#!/bin/bash
# ============================================================
#   MR. ROBOT — $MRRBT Public Miner Launch
#   AMD GPU only. Enter your Solana wallet to start.
# ============================================================
cd "$(dirname "$0")"

G='\033[0;32m'
BG='\033[1;32m'
CY='\033[0;36m'
YL='\033[0;33m'
NC='\033[0m'

clear
echo -e "${BG}"
cat << 'LOGO'
 ███╗   ███╗██████╗       ██████╗  ██████╗ ██████╗  ██████╗ ████████╗
 ████╗ ████║██╔══██╗      ██╔══██╗██╔═══██╗██╔══██╗██╔═══██╗╚══██╔══╝
 ██╔████╔██║██████╔╝      ██████╔╝██║   ██║██████╔╝██║   ██║   ██║
 ██║╚██╔╝██║██╔══██╗      ██╔══██╗██║   ██║██╔══██╗██║   ██║   ██║
 ██║ ╚═╝ ██║██║  ██║      ██║  ██║╚██████╔╝██████╔╝╚██████╔╝   ██║
 ╚═╝     ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ╚═════╝    ╚═╝
LOGO
echo -e "${NC}"
echo -e "  ${G}\$MRRBT AMD-ONLY GPU MINER${NC}"
echo -e "  ${G}Mine Ethereum to earn \$MRRBT on Solana — via unMineable${NC}"
echo -e "  ${G}AMD GPU required (RX 470 / 480 / 570 / 580 / Vega / RDNA)${NC}"
echo ""
echo -e "  ──────────────────────────────────────────────────"
echo ""
echo -e "  ${CY}Enter your Solana wallet address to receive \$MRRBT rewards.${NC}"
echo ""
read -p "  Wallet address: " WALLET
echo ""

if [ -z "$WALLET" ]; then
    echo -e "  ${YL}No wallet entered. Exiting.${NC}"
    exec bash
fi

WORKER="${WORKER:-mrrobot}"
DIFF="${DIFF:-4300}"
POOL="${POOL:-ethash.unmineable.com:3333}"

echo -e "  ${G}Wallet  : ${BG}${WALLET}${NC}"
echo -e "  ${G}Pool    : ${POOL}${NC}"
echo -e "  ${G}Reward  : \$MRRBT (Solana) via unMineable${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOLMINER="${LOLMINER:-$SCRIPT_DIR/lolMiner}"

if [[ ! -x "$LOLMINER" ]]; then
    LOLMINER="$(command -v lolMiner 2>/dev/null)"
fi
if [[ -z "$LOLMINER" || ! -x "$LOLMINER" ]]; then
    echo -e "  ${YL}ERROR: lolMiner not found. Run ./install.sh first.${NC}"
    exec bash
fi

exec "$LOLMINER" \
    --algo ETHASH \
    --pool "$POOL" \
    --user "MRRBT:${WALLET}.${WORKER}+${DIFF}" \
    --pass x \
    --apiport 10080
