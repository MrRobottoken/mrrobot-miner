#!/usr/bin/env bash
# ============================================================
#   MR. ROBOT — HiveOS stats script
#   Reads /tmp/mrrobot-stats.json written by the miner every 5s.
#   Falls back to live GPU sensor read if the file is stale/missing.
# ============================================================

STATS_FILE="/tmp/mrrobot-stats.json"
MINER_DIR="/hive/miners/mrrobot"
STALE_SECS=30

is_stale() {
    [[ ! -f "$STATS_FILE" ]] && return 0
    local age=$(( $(date +%s) - $(stat -c %Y "$STATS_FILE" 2>/dev/null || echo 0) ))
    [[ $age -gt $STALE_SECS ]] && return 0
    return 1
}

if ! is_stale; then
    cat "$STATS_FILE"
    exit 0
fi

# Miner not running yet or file stale — emit live GPU sensor data with zero hashrate
python3 - <<'PYEOF'
import json, glob, pathlib, sys

def read_hwmon_value(path):
    try:
        return int(pathlib.Path(path).read_text())
    except Exception:
        return None

gpus = []
for hwmon in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
    name_file = pathlib.Path(hwmon) / "name"
    try:
        if name_file.read_text().strip() == "amdgpu":
            gpus.append(hwmon)
    except Exception:
        pass

temps = []
fans  = []
for hwmon in gpus:
    t = read_hwmon_value(f"{hwmon}/temp1_input")
    temps.append((t // 1000) if t else 0)

    pwm = read_hwmon_value(f"{hwmon}/pwm1")
    fans.append(round(pwm * 100 / 255) if pwm else 0)

n = max(len(gpus), 1)
print(json.dumps({
    "hs":       [0.0] * n,
    "hs_units": "mhs",
    "temp":     temps or [0] * n,
    "fan":      fans  or [0] * n,
    "uptime":   0,
    "ar":       [0, 0],
    "algo":     "mrh256",
}))
PYEOF
