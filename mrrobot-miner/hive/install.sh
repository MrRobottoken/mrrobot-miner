#!/usr/bin/env bash
# ============================================================
#   MR. ROBOT — HiveOS Installer
#   Installs the miner to /hive/miners/mrrobot/
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
BRANCH="main"

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

# ── Check we are on HiveOS ──────────────────────────────────
if [[ ! -d /hive ]]; then
    echo -e "${YL}[WARN] /hive not found. This installer is designed for HiveOS."
    echo -e "       For Ubuntu/Debian, use  bash install.sh  from the repo root.${NC}"
fi

# ── Check Python 3.8+ ───────────────────────────────────────
echo -e "${GREEN}[1/5] Checking Python...${NC}"
PYTHON=""
for py in python3.10 python3.9 python3.8 python3; do
    if command -v "$py" &>/dev/null; then
        ver=$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        major=$(echo "$ver" | cut -d. -f1)
        minor=$(echo "$ver" | cut -d. -f2)
        if [[ $major -ge 3 && $minor -ge 8 ]]; then
            PYTHON="$py"
            echo "    OK — Python $ver ($py)"
            break
        fi
    fi
done

if [[ -z "$PYTHON" ]]; then
    echo -e "${YL}    Python 3.8+ not found. Installing from deadsnakes PPA...${NC}"
    add-apt-repository ppa:deadsnakes/ppa -y 2>&1 | tail -1
    apt-get update -qq
    apt-get install -y python3.8 python3.8-dev python3-pip 2>&1 | tail -3
    PYTHON="python3.8"
    echo "    OK — Python 3.8 installed"
fi

# ── Check AMD GPU ──────────────────────────────────────────
echo -e "${GREEN}[2/5] Scanning for AMD GPU...${NC}"
"$PYTHON" - <<'PYCHECK'
import sys
try:
    import pyopencl as cl
    gpus = [d for p in cl.get_platforms()
              for d in p.get_devices(cl.device_type.GPU)
              if "AMD" in d.vendor.upper() or "Advanced Micro Devices" in d.vendor]
    if gpus:
        print(f"    Found {len(gpus)} AMD GPU(s):")
        for g in gpus: print(f"      • {g.name.strip()}")
        sys.exit(0)
except ImportError:
    pass  # pyopencl not installed yet — will check after deps

import glob, pathlib
amd = [h for h in glob.glob("/sys/class/hwmon/hwmon*")
       if (pathlib.Path(h)/"name").exists()
       and (pathlib.Path(h)/"name").read_text().strip() == "amdgpu"]
if amd:
    print(f"    Found {len(amd)} AMD GPU(s) via sysfs")
    sys.exit(0)

print("    WARNING: No AMD GPU detected via sysfs.")
print("    Make sure amdgpu drivers are loaded (HiveOS does this automatically).")
PYCHECK

# ── Install Python dependencies ────────────────────────────
echo -e "${GREEN}[3/5] Installing Python dependencies...${NC}"
"$PYTHON" -m pip install -q --upgrade pip
"$PYTHON" -m pip install -q pyopencl numpy rich httpx
echo "    OK"

# ── Download / copy miner files ───────────────────────────
echo -e "${GREEN}[4/5] Installing to ${INSTALL_DIR}...${NC}"
mkdir -p "$INSTALL_DIR"

# If running from inside a cloned repo, copy directly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "$REPO_ROOT/miner/main.py" ]]; then
    echo "    Copying from local repo..."
    cp -r "$REPO_ROOT/miner"        "$INSTALL_DIR/"
    cp -r "$REPO_ROOT/hive"         "$INSTALL_DIR/"
    cp    "$REPO_ROOT/mine.sh"      "$INSTALL_DIR/"
    cp    "$REPO_ROOT/install.sh"   "$INSTALL_DIR/"
    [[ -f "$REPO_ROOT/miner/kernel.cl" ]] && cp "$REPO_ROOT/miner/kernel.cl" "$INSTALL_DIR/miner/"
else
    echo "    Downloading from GitHub..."
    command -v git &>/dev/null || apt-get install -y git -qq
    git clone --depth=1 "$REPO_URL" /tmp/mrrobot-clone 2>&1 | tail -2
    cp -r /tmp/mrrobot-clone/miner  "$INSTALL_DIR/"
    cp -r /tmp/mrrobot-clone/hive   "$INSTALL_DIR/"
    cp    /tmp/mrrobot-clone/mine.sh      "$INSTALL_DIR/" 2>/dev/null || true
    rm -rf /tmp/mrrobot-clone
fi

# Copy HiveOS hook scripts to the expected location
cp "$INSTALL_DIR/hive/h-manifest.conf" "$INSTALL_DIR/"
cp "$INSTALL_DIR/hive/h-run.sh"        "$INSTALL_DIR/"
cp "$INSTALL_DIR/hive/h-stats.sh"      "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/h-run.sh" "$INSTALL_DIR/h-stats.sh"
[[ -f "$INSTALL_DIR/mine.sh" ]] && chmod +x "$INSTALL_DIR/mine.sh"

echo "    OK"

# ── Done ──────────────────────────────────────────────────
echo -e "${GREEN}[5/5] Done.${NC}"
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
echo -e "${GREEN}║    python3 -m miner.main --wallet <address>                     ║${NC}"
echo -e "${GREEN}║                                                                  ║${NC}"
echo -e "${GREEN}║  The revolution is being hashed.                                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
