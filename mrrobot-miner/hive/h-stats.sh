#!/usr/bin/env bash
# ============================================================
#   MR. ROBOT — HiveOS stats script
#   Reads live stats from lolMiner API (port 10080).
#   Falls back to AMD hwmon sensors if miner is not yet running.
# ============================================================

python3 - <<'PYEOF'
import json, urllib.request, glob, pathlib

def hwmon_fallback():
    gpus = sorted(
        h for h in glob.glob("/sys/class/hwmon/hwmon*")
        if (pathlib.Path(h)/"name").exists()
        and (pathlib.Path(h)/"name").read_text().strip() == "amdgpu"
    )
    temps, fans = [], []
    for h in gpus:
        try: temps.append(int((pathlib.Path(h)/"temp1_input").read_text()) // 1000)
        except: temps.append(0)
        try: fans.append(round(int((pathlib.Path(h)/"pwm1").read_text()) * 100 / 255))
        except: fans.append(0)
    n = max(len(gpus), 1)
    print(json.dumps({
        "hs": [0.0]*n, "hs_units": "mhs",
        "temp": temps or [0]*n, "fan": fans or [0]*n,
        "uptime": 0, "ar": [0,0], "algo": "ethash",
    }))

try:
    with urllib.request.urlopen("http://localhost:10080/summary", timeout=3) as r:
        data = json.loads(r.read())
    gpus = data.get("GPUs", [])
    if not gpus:
        hwmon_fallback()
    else:
        print(json.dumps({
            "hs":       [g.get("Speed_MHs", 0) for g in gpus],
            "hs_units": "mhs",
            "temp":     [g.get("T", 0) for g in gpus],
            "fan":      [g.get("Fan", 0) for g in gpus],
            "uptime":   data.get("Session", {}).get("Uptime", 0),
            "ar":       [
                sum(g.get("Shares", {}).get("Accepted", 0) for g in gpus),
                sum(g.get("Shares", {}).get("Rejected", 0) for g in gpus),
            ],
            "algo":     "ethash",
        }))
except Exception:
    hwmon_fallback()
PYEOF
