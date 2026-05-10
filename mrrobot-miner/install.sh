#!/bin/bash
# ============================================================
#   MR. ROBOT — $MRRBT AMD-Only GPU Miner
#   Public Install Script
# ============================================================
set -e

GREEN='\033[0;32m'
RED='\033[1;31m'
NC='\033[0m'

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

# ── Check Python ─────────────────────────────────────────────
echo -e "${GREEN}[1/4] Checking Python 3.10+...${NC}"
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}Python 3 not found. Install it first.${NC}"; exit 1
fi
python3 -c "import sys; assert sys.version_info >= (3,10), 'Need Python 3.10+'" || {
    echo -e "${RED}Python 3.10+ required.${NC}"; exit 1
}
echo "    OK — $(python3 --version)"

# ── Check AMD GPU ─────────────────────────────────────────────
echo -e "${GREEN}[2/4] Scanning for AMD GPU...${NC}"
python3 - <<'PYCHECK'
import pyopencl as cl, sys
gpus = []
for p in cl.get_platforms():
    for d in p.get_devices(cl.device_type.GPU):
        if "Advanced Micro Devices" in d.vendor or "AMD" in d.vendor.upper():
            gpus.append(d.name.strip())
if not gpus:
    print("  NO AMD GPU DETECTED")
    print("  This miner requires an AMD Radeon GPU (RX 470/480/570/580/590 or RDNA).")
    print("  NVIDIA is not supported — by design.")
    sys.exit(1)
print(f"  Found {len(gpus)} AMD GPU(s):")
for n in gpus:
    print(f"    • {n}")
PYCHECK

# ── Install dependencies ──────────────────────────────────────
echo -e "${GREEN}[3/4] Installing dependencies...${NC}"
pip3 install -q pyopencl numpy rich httpx
echo "    OK"

# ── Make mine.sh executable ───────────────────────────────────
echo -e "${GREEN}[4/4] Finalising...${NC}"
chmod +x "$(dirname "$0")/mine.sh"
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
