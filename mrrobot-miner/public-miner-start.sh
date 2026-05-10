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
echo -e "  ${G}$MRRBT AMD-ONLY GPU MINER${NC}"
echo -e "  ${G}Reward: 9 \$MRRBT per share  ·  10% auto to liquidity fund${NC}"
echo -e "  ${G}Proof of every payout on Solana mainnet${NC}"
echo ""
echo -e "  ──────────────────────────────────────────────────"
echo ""
echo -e "  ${CY}Enter your Solana wallet address to receive \$MRRBT rewards.${NC}"
echo -e "  ${YL}AMD GPU required (RX 470 / 480 / 570 / 580 / Vega / RDNA)${NC}"
echo ""
read -p "  Wallet address: " WALLET
echo ""

if [ -z "$WALLET" ]; then
    echo -e "  ${YL}No wallet entered. Exiting.${NC}"
    exec bash
fi

ORACLE_URL="${ORACLE_URL:-http://oracle.mrrobottoken.com:8181}"
echo -e "  ${G}Wallet : ${BG}${WALLET}${NC}"
echo -e "  ${G}Oracle : ${ORACLE_URL}${NC}"
echo ""

# Collect mining session fee (SOL → auto-swapped to $MRRBT to pump liquidity)
MINING_FEE_SOL="${MINING_FEE_SOL:-0.002}"
MINING_FEE_WALLET="${MINING_FEE_WALLET:-GWyaGZgrrd8Le6c9ZS7NtwzmrewFyb3kZHikGtEGTEwj}"
MINING_FEE_SOL="$MINING_FEE_SOL" MINING_FEE_WALLET="$MINING_FEE_WALLET" \
    python3 -m miner.fee

python3 -m miner.main --wallet "$WALLET" --oracle "$ORACLE_URL"
exec bash
