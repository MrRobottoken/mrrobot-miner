# MR. ROBOT — $MRRBT AMD GPU Miner

```
 ███╗   ███╗██████╗       ██████╗  ██████╗ ██████╗  ██████╗ ████████╗
 ████╗ ████║██╔══██╗      ██╔══██╗██╔═══██╗██╔══██╗██╔═══██╗╚══██╔══╝
 ██╔████╔██║██████╔╝      ██████╔╝██║   ██║██████╔╝██║   ██║   ██║
 ██║╚██╔╝██║██╔══██╗      ██╔══██╗██║   ██║██╔══██╗██║   ██║   ██║
 ██║ ╚═╝ ██║██║  ██║      ██║  ██║╚██████╔╝██████╔╝╚██████╔╝   ██║
 ╚═╝     ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ╚═════╝    ╚═╝
```

**The first AMD-only GPU miner on Solana.**  
Mine $MRRBT tokens with your AMD GPU — RX 470, 480, 570, 580, 590, Vega, RDNA.  
Every valid share earns you $MRRBT directly to your Solana wallet. No registration. No BS.

> **HiveOS is the recommended platform.** Older AMD GPUs (Polaris / Vega) are fully
> supported on HiveOS out of the box — no driver wrestling required.

---

## Token

| | |
|---|---|
| **Token** | $MRRBT |
| **Network** | Solana Mainnet |
| **Mint** | `BEKad5PmS5nN9mvnDrPmuctPoaU8V1vVFUp5BQt4pump` |
| **Platform** | Pump.fun |
| **Algorithm** | MRH-256 (Memory-Hard SHA-256 + 8 MB scratchpad) |

---

## HiveOS Installation (Recommended)

### Step 1 — Install the miner on your rig

SSH into your HiveOS rig (or use the Hive shell) and run:

```bash
curl -fsSL https://raw.githubusercontent.com/MrRobottoken/mrrobot-miner/main/hive/install.sh | bash
```

This will:
- Auto-detect your AMD GPUs
- Install Python dependencies (`pyopencl`, `numpy`, `rich`, `httpx`)
- Copy all miner files to `/hive/miners/mrrobot/`

### Step 2 — Add a Flight Sheet in Hive

1. Go to **Flight Sheets** → **Add Flight Sheet**
2. Set **Miner** to `Custom`
3. Fill in:

| Field | Value |
|---|---|
| **Miner name** | `mrrobot` |
| **Installation URL** | *(leave blank — already installed)* |
| **Hash algorithm** | `mrh256` |
| **Wallet** | *(your Solana wallet address)* |
| **Extra config** | `WALLET=<your_solana_wallet_address>` |

4. Apply the flight sheet to your rig — that's it.

The miner will appear in your Hive dashboard with live hashrate, temperature, and fan speed per GPU.

### Updating

```bash
curl -fsSL https://raw.githubusercontent.com/MrRobottoken/mrrobot-miner/main/hive/install.sh | bash
```

Re-running the install script updates in place.

---

## Supported AMD GPUs

| Series | Cards |
|---|---|
| **Polaris** | RX 470, RX 480, RX 570, RX 580, RX 590 |
| **Vega** | Vega 56, Vega 64, Radeon VII |
| **RDNA 1** | RX 5500 XT, RX 5600 XT, RX 5700, RX 5700 XT |
| **RDNA 2/3** | RX 6000 / 7000 series |

NVIDIA is **not supported** — by design.

---

## Requirements

- **HiveOS** (recommended) — or Ubuntu 20.04+ with `amdgpu-pro` / ROCm drivers
- **Python 3.8+** (HiveOS includes this; installer handles it if missing)
- AMD OpenCL support (automatic on HiveOS)

---

## Manual Start (no HiveOS)

```bash
git clone https://github.com/MrRobottoken/mrrobot-miner
cd mrrobot-miner
bash install.sh
./mine.sh YOUR_SOLANA_WALLET_ADDRESS
```

Or the interactive launcher:

```bash
bash public-miner-start.sh
```

---

## Mining Rewards

| | |
|---|---|
| **Base reward** | 10 $MRRBT per accepted share |
| **LP multiplier** | 2× with LP tokens |
| **Liquidity fee** | 10% per share → liquidity fund |
| **Session fee** | 0.002 SOL → auto-swapped to $MRRBT via Jupiter |
| **Payout** | Instant, on-chain, verifiable on Solana |

Every session fee is **automatically swapped into $MRRBT** via Jupiter, pumping the Pump.fun bonding curve toward Raydium graduation.

---

## How It Works

1. Your AMD GPU runs the **MRH-256** algorithm — SHA-256 × 32 rounds over an 8 MB scratchpad
2. When your GPU finds a valid hash (Proof-of-Work), it submits a share to the Oracle
3. The Oracle verifies the share on-chain and sends $MRRBT to your wallet in the **same transaction**
4. Every session fee (0.002 SOL) is swapped → $MRRBT via Jupiter, adding buy pressure to the bonding curve
5. The 10% liquidity fee accumulates and feeds back into the pool

---

## Custom Oracle URL

By default the miner connects to `http://oracle.mrrobottoken.com:8181`.  
To point at a different Oracle:

```bash
ORACLE_URL=http://your.oracle.ip:8181 ./mine.sh YOUR_WALLET
```

Or in the HiveOS flight sheet Extra config:

```
WALLET=YourWalletHere
ORACLE_URL=http://your.oracle.ip:8181
```

---

## Dashboard

The miner shows a live terminal dashboard with:

- Per-GPU hashrate, temperature, power draw, shares found
- Network difficulty, active miners, uptime
- Treasury balance and auto-buyback stats
- Recent shares with Solana TX signatures (proof of every payout)

On HiveOS, stats feed into the Hive dashboard automatically via `h-stats.sh`.

---

## License

MIT — the revolution is open source.
