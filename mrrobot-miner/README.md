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
Mine Ethereum and earn $MRRBT tokens directly to your Solana wallet — powered by lolMiner and the unMineable pool. No registration. No BS.

> **HiveOS is the recommended platform.** Older AMD GPUs (Polaris / Vega) are fully
> supported on HiveOS out of the box — no driver wrestling required.

---

## How It Works

1. Your AMD GPU mines Ethereum (Ethash algorithm) via the unMineable pool
2. unMineable pays you in **$MRRBT** — the rewards go straight to your Solana wallet
3. Every valid share is verified on-chain; payouts are traceable on Solana Explorer
4. The miner runs 24/7 with zero dependency on any private server

---

## Token

| | |
|---|---|
| **Token** | $MRRBT |
| **Network** | Solana Mainnet |
| **Mint** | `BEKad5PmS5nN9mvnDrPmuctPoaU8V1vVFUp5BQt4pump` |
| **Platform** | Pump.fun |
| **Mining engine** | lolMiner (Ethash via unMineable) |
| **Pool** | `ethash.unmineable.com:3333` |

---

## HiveOS Installation (Recommended)

### Step 1 — Install the miner on your rig

SSH into your HiveOS rig (or use the Hive shell) and run:

```bash
curl -fsSL https://raw.githubusercontent.com/MrRobottoken/mrrobot-miner/main/hive/install.sh | bash
```

This will:
- Auto-detect your AMD GPUs
- Download and install lolMiner 1.98a
- Copy all run/stats scripts to `/hive/miners/mrrobot/`

### Step 2 — Add a Flight Sheet in Hive

1. Go to **Flight Sheets** → **Add Flight Sheet**
2. Set **Miner** to `Custom`
3. Fill in:

| Field | Value |
|---|---|
| **Miner name** | `mrrobot` |
| **Installation URL** | *(leave blank — already installed)* |
| **Hash algorithm** | `ethash` |
| **Wallet** | *(your Solana wallet address)* |
| **Extra config** | `WALLET=<your_solana_wallet_address>` |

4. Apply the flight sheet to your rig — that's it.

The miner will appear in your Hive dashboard with live hashrate, temperature, and fan speed per GPU.

### Optional Extra config parameters

```
WALLET=YourSolanaWalletHere
WORKER=myrig
DIFF=4300
POOL=ethash.unmineable.com:3333
```

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
- AMD GPU (Polaris, Vega, or RDNA)
- Internet connection (pool mining — no local server needed)

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
| **Mining algorithm** | Ethash (Ethereum) |
| **Reward token** | $MRRBT (Solana) |
| **Payout** | Automatic via unMineable, on-chain |
| **Minimum payout** | Set on your unMineable dashboard |
| **Difficulty** | Fixed at 4300 MH (consistent share rate) |

---

## Custom Difficulty

The `DIFF` parameter controls share frequency. Default is `4300` (roughly one share every ~150 seconds on an RX 470).

Lower values = more shares, smaller rewards each. Higher = fewer shares, larger each.

```bash
DIFF=2000 ./mine.sh YourWalletHere   # more frequent shares
DIFF=8000 ./mine.sh YourWalletHere   # less frequent shares
```

---

## License

MIT — the revolution is open source.
