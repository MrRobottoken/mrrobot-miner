"""
Mr. Robot Miner — fsociety Terminal Dashboard
AMD-Only $MRRBT GPU Mining Client v1.0
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
import time
import threading

from rich.console import Console
from rich.layout import Layout
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich import box

from .miner import MrRobotMiner
from .client import DEFAULT_ORACLE

console = Console()

# ── ASCII Art ─────────────────────────────────────────────────────────────────
LOGO = r"""
 ███╗   ███╗██████╗       ██████╗  ██████╗ ██████╗  ██████╗ ████████╗
 ████╗ ████║██╔══██╗      ██╔══██╗██╔═══██╗██╔══██╗██╔═══██╗╚══██╔══╝
 ██╔████╔██║██████╔╝      ██████╔╝██║   ██║██████╔╝██║   ██║   ██║
 ██║╚██╔╝██║██╔══██╗      ██╔══██╗██║   ██║██╔══██╗██║   ██║   ██║
 ██║ ╚═╝ ██║██║  ██║      ██║  ██║╚██████╔╝██████╔╝╚██████╔╝   ██║
 ╚═╝     ╚═╝╚═╝  ╚═╝      ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ╚═════╝    ╚═╝
"""

TAGLINE = "[ $MRRBT · AMD-ONLY MINING PROTOCOL v1.0 · THE REVOLUTION IS BEING HASHED ]"


# ── Dashboard builder ─────────────────────────────────────────────────────────
def make_dashboard(miner: MrRobotMiner, oracle_url: str, oracle_stats: dict, treasury: dict, buyback: dict = None) -> Layout:
    layout = Layout()
    layout.split_column(
        Layout(name="header", size=11),
        Layout(name="body"),
        Layout(name="footer", size=3),
    )
    layout["body"].split_row(
        Layout(name="gpu_panel", ratio=3),
        Layout(name="side_panel", ratio=2),
    )
    layout["side_panel"].split_column(
        Layout(name="stats"),
        Layout(name="treasury"),
        Layout(name="shares_log"),
    )

    # ── Header ────────────────────────────────────────────────────────────────
    header_text = Text(LOGO, style="bold green")
    header_text.append(f"\n{TAGLINE:^73}", style="bright_green")
    layout["header"].update(
        Panel(header_text, border_style="green", box=box.HEAVY)
    )

    # ── GPU Table ─────────────────────────────────────────────────────────────
    gpu_table = Table(
        title="[bold green]NODE STATUS[/bold green]",
        box=box.SIMPLE_HEAVY,
        style="green",
        header_style="bold green",
        border_style="green",
        expand=True,
    )
    gpu_table.add_column("GPU",   justify="center", width=5)
    gpu_table.add_column("NAME",  width=22)
    gpu_table.add_column("MH/s",  justify="right", width=7)
    gpu_table.add_column("SHARES",justify="right", width=7)
    gpu_table.add_column("TEMP",  justify="right", width=7)
    gpu_table.add_column("WATTS", justify="right", width=7)
    gpu_table.add_column("STATUS",justify="center", width=14)

    for g in miner.gpu_stats():
        status_style = "bold bright_green" if "MINING" in g["status"] else \
                       "bold yellow" if "SHARE" in g["status"] else "dim"

        temp  = g.get("temp_c")
        power = g.get("power_w")

        temp_style  = "bold red" if temp and temp >= 90 else \
                      "yellow"   if temp and temp >= 80 else "green"
        temp_str  = f"{temp}°C"   if temp  is not None else "—"
        power_str = f"{power}W"   if power is not None else "—"

        gpu_table.add_row(
            str(g["index"]),
            g["name"][:22],
            f"{g['mhs']:.2f}",
            str(g["shares"]),
            Text(temp_str,  style=temp_style),
            power_str,
            Text(g["status"], style=status_style),
        )

    layout["gpu_panel"].update(
        Panel(gpu_table, border_style="green", box=box.HEAVY)
    )

    # ── Mining Stats ──────────────────────────────────────────────────────────
    stats_table = Table(box=None, show_header=False, expand=True, style="green")
    stats_table.add_column("KEY",   style="bold green", width=20)
    stats_table.add_column("VALUE", style="bright_white")

    diff  = oracle_stats.get("difficulty_bits", "—")
    total_shares = oracle_stats.get("total_shares", 0)
    miners = oracle_stats.get("unique_miners", 0)
    uptime = oracle_stats.get("uptime_seconds", 0)
    h = uptime // 3600; m = (uptime % 3600) // 60; s = uptime % 60

    fee_pct  = oracle_stats.get("liq_fee_percent", 10)
    liq_ui   = oracle_stats.get("liq_fund_total_ui", 0.0)

    gpu_data     = miner.gpu_stats()
    total_power  = sum(g["power_w"] for g in gpu_data if g.get("power_w") is not None)
    temps        = [g["temp_c"] for g in gpu_data if g.get("temp_c") is not None]
    max_temp     = max(temps) if temps else None
    power_str    = f"{total_power}W" if total_power else "—"
    temp_str     = f"{max_temp}°C max" if max_temp is not None else "—"

    stats_table.add_row("TOTAL HASHRATE",   f"{miner.total_mhs:.2f} MH/s")
    stats_table.add_row("TOTAL POWER",      f"[cyan]{power_str}[/cyan]")
    stats_table.add_row("GPU TEMP (MAX)",   f"[{'red' if max_temp and max_temp>=90 else 'yellow' if max_temp and max_temp>=80 else 'green'}]{temp_str}[/]")
    stats_table.add_row("DIFFICULTY",       f"{diff} bits")
    stats_table.add_row("SHARES ACCEPTED",  str(total_shares))
    stats_table.add_row("ACTIVE MINERS",    str(miners))
    stats_table.add_row("ORACLE",           oracle_url)
    stats_table.add_row("UPTIME",           f"{h:02d}:{m:02d}:{s:02d}")
    stats_table.add_row("─" * 18, "─" * 20)
    stats_table.add_row("LIQ FEE",          f"[yellow]{fee_pct}% per share → fund[/yellow]")
    stats_table.add_row("LIQ FUND TOTAL",   f"[cyan]{liq_ui:,.2f} $MRRBT[/cyan]")

    layout["stats"].update(
        Panel(stats_table, title="[bold green]MINING STATS[/bold green]",
              border_style="green", box=box.HEAVY)
    )

    # ── Treasury ──────────────────────────────────────────────────────────────
    bal = treasury.get("balance_mrrbt", "—")
    wallet = treasury.get("wallet", "—")
    if isinstance(bal, int):
        bal_str = f"{bal:,} $MRRBT"
    else:
        bal_str = str(bal)

    treas_table = Table(box=None, show_header=False, expand=True, style="green")
    treas_table.add_column("KEY",   style="bold green", width=20)
    treas_table.add_column("VALUE", style="bright_white")
    fee_pct = oracle_stats.get("liq_fee_percent", 10)
    miner_pct = 100 - fee_pct

    treas_table.add_row("PAYOUT BALANCE",   bal_str)
    treas_table.add_row("PAYOUT WALLET",    "H5CDHT97KUC6EXYc…")
    treas_table.add_row("MAIN VAULT",       "GWyaGZgrrd8Le6c9…")
    treas_table.add_row("TOKEN MINT",       "BEKad5PmS5nN9mv…")
    treas_table.add_row("BASE REWARD",      "10 $MRRBT/share")
    treas_table.add_row("LP MULTIPLIER",    "2× with LP tokens")
    treas_table.add_row("─" * 18, "─" * 20)
    treas_table.add_row(
        "REWARD SPLIT",
        f"[green]{miner_pct}%[/green] miner  [yellow]{fee_pct}%[/yellow] liq fund"
    )

    # Buyback stats
    bb = buyback or {}
    bb_count   = bb.get("total_buybacks", 0)
    bb_sol     = bb.get("total_sol_spent", 0.0)
    bb_mrrbt   = bb.get("total_mrrbt_bought_ui", 0.0)
    bb_enabled = bb.get("enabled", False)
    bb_status  = "[bold green]ACTIVE[/bold green]" if bb_enabled else "[dim]SIMULATED[/dim]"
    treas_table.add_row("─" * 18, "─" * 20)
    treas_table.add_row("AUTO-BUYBACK",    bb_status)
    treas_table.add_row("BUYBACKS RUN",    f"[cyan]{bb_count}[/cyan]")
    treas_table.add_row("SOL SPENT",       f"[cyan]{bb_sol:.4f} SOL[/cyan]")
    treas_table.add_row("MRRBT BOUGHT",    f"[bold green]{bb_mrrbt:,.1f} $MRRBT[/bold green]")

    layout["treasury"].update(
        Panel(treas_table, title="[bold green]TREASURY & BUYBACK[/bold green]",
              border_style="green", box=box.HEAVY)
    )

    # ── Recent Shares / TX Proof ──────────────────────────────────────────────
    shares_table = Table(box=None, show_header=True, expand=True, style="green")
    shares_table.add_column("TIME",   style="dim green",    width=10)
    shares_table.add_column("GPU",    style="bold green",   width=4,  justify="center")
    shares_table.add_column("REWARD", style="bright_white", width=9,  justify="right")
    shares_table.add_column("TX SIGNATURE (SOLANA PROOF)",  style="dim cyan", min_width=20)

    with miner._shares_lock:
        entries = list(miner.recent_shares)

    if entries:
        for e in entries[:6]:
            sig  = e.get("tx_sig", "")
            # Show first 12 + "…" + last 6 chars so it's recognisable but fits
            if len(sig) > 20:
                sig_display = sig[:16] + "…" + sig[-6:]
            else:
                sig_display = sig or "pending"
            reward_str = f"{e['reward']:.1f} $M"
            shares_table.add_row(
                e["time"],
                str(e["gpu"]),
                reward_str,
                sig_display,
            )
    else:
        shares_table.add_row("—", "—", "—", "waiting for first share…")

    layout["shares_log"].update(
        Panel(shares_table,
              title="[bold green]RECENT SHARES — TX PROOF[/bold green]",
              border_style="green", box=box.HEAVY)
    )

    # ── Footer ────────────────────────────────────────────────────────────────
    layout["footer"].update(
        Panel(
            Text(
                "  fsociety  │  $MRRBT AMD Miner  │  mrrobottoken.com  │  "
                f"[{time.strftime('%H:%M:%S')}]  │  Press Ctrl+C to exit",
                style="green",
            ),
            border_style="green",
            box=box.HEAVY,
        )
    )

    return layout


# ── Access Denied screen ──────────────────────────────────────────────────────
def access_denied(msg: str):
    console.print(Panel(
        Text(f"\n  ACCESS DENIED\n\n  {msg}\n", style="bold red"),
        title="[bold red]MR. ROBOT MINER[/bold red]",
        border_style="red",
        box=box.HEAVY,
    ))
    sys.exit(1)


# ── Startup banner (before Live) ─────────────────────────────────────────────
def print_banner():
    console.print(Text(LOGO, style="bold green"))
    console.print(Text(f"{TAGLINE:^73}\n", style="bright_green"))


# ── Main ─────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Mr. Robot $MRRBT Miner")
    parser.add_argument(
        "--oracle",
        default=os.getenv("ORACLE_URL", DEFAULT_ORACLE),
        help=f"Oracle server URL  (default: {DEFAULT_ORACLE})",
    )
    parser.add_argument(
        "--wallet",
        required=True,
        help="Your Solana wallet address for payouts",
    )
    args = parser.parse_args()

    print_banner()
    console.print("[bold green]Scanning for AMD hardware...[/bold green]\n")

    def gpu_progress(dev, state):
        if state == "init":
            console.print(f"  [dim green]GPU {dev.index}  {dev.name.strip()[:28]}  — initializing...[/dim green]")
        else:
            console.print(f"  [bold green]GPU {dev.index}  {dev.name.strip()[:28]}  — ONLINE[/bold green]")

    try:
        miner    = MrRobotMiner(oracle_url=args.oracle, wallet_address=args.wallet)
        gpu_list = miner.start(progress_cb=gpu_progress)
    except Exception as e:
        access_denied(str(e))

    console.print(f"\n[bold green]MINER ONLINE — {len(gpu_list)} AMD GPU(s) active[/bold green]\n")

    oracle_stats = {}
    treasury     = {}
    buyback_data = {}

    _start_time = time.monotonic()

    def _write_hiveos_stats():
        gpu_data = miner.gpu_stats()
        stats = {
            "hs":       [g["mhs"] for g in gpu_data],
            "hs_units": "mhs",
            "temp":     [g["temp_c"]  or 0 for g in gpu_data],
            "fan":      [g["fan_pct"] or 0 for g in gpu_data],
            "uptime":   int(time.monotonic() - _start_time),
            "ar":       [miner.total_shares, 0],
            "algo":     "mrh256",
        }
        try:
            tmp = "/tmp/mrrobot-stats.json.tmp"
            with open(tmp, "w") as f:
                json.dump(stats, f)
            os.replace(tmp, "/tmp/mrrobot-stats.json")
        except Exception:
            pass

    async def refresh_oracle():
        nonlocal oracle_stats, treasury, buyback_data
        while True:
            try:
                oracle_stats = await miner.oracle.get_stats()
                treasury     = await miner.oracle.get_treasury()
                buyback_data = await miner.oracle.get_buyback()
            except Exception:
                pass
            _write_hiveos_stats()
            await asyncio.sleep(5)

    def oracle_refresh_thread():
        asyncio.run(refresh_oracle())

    t = threading.Thread(target=oracle_refresh_thread, daemon=True)
    t.start()

    try:
        with Live(
            make_dashboard(miner, args.oracle, oracle_stats, treasury, buyback_data),
            console=console,
            refresh_per_second=2,
            screen=False,
        ) as live:
            while True:
                live.update(
                    make_dashboard(miner, args.oracle, oracle_stats, treasury, buyback_data)
                )
                time.sleep(0.5)
    except KeyboardInterrupt:
        console.print("\n[bold green]Shutting down — fsociety signing off.[/bold green]")
        miner.stop()


if __name__ == "__main__":
    main()
