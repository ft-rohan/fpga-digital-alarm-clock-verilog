#!/usr/bin/env python3
"""
ntp_uart_sync.py
================
FPGA Digital Alarm Clock — NTP Time Synchronisation over UART

Fetches current time via NTP (pool.ntp.org) and sends it to the FPGA
over UART as a 4-byte packet: [0xFF, HH, MM, SS]

The FPGA's time_loader module parses this packet and loads the time
into the bcd_time_counter module.

Usage:
    python ntp_uart_sync.py             # uses defaults
    python ntp_uart_sync.py --port COM5 --baud 115200

Install dependencies:
    pip install pyserial ntplib
"""

import argparse
import time
import sys
from datetime import datetime, timezone, timedelta

try:
    import ntplib
except ImportError:
    print("ERROR: ntplib not installed. Run: pip install ntplib")
    sys.exit(1)

try:
    import serial
except ImportError:
    print("ERROR: pyserial not installed. Run: pip install pyserial")
    sys.exit(1)


# ── IST offset ───────────────────────────────────────────────────────────────
IST_OFFSET = timedelta(hours=5, minutes=30)
NTP_SERVER = "pool.ntp.org"


def get_ntp_time_ist():
    """Fetch current time from NTP server and convert to IST."""
    client = ntplib.NTPClient()
    try:
        response = client.request(NTP_SERVER, version=3)
        utc_time = datetime.fromtimestamp(response.tx_time, tz=timezone.utc)
        ist_time = utc_time + IST_OFFSET
        print(f"[NTP] UTC  : {utc_time.strftime('%H:%M:%S')}")
        print(f"[NTP] IST  : {ist_time.strftime('%H:%M:%S')}")
        print(f"[NTP] Offset from local: {response.offset:.3f} s")
        return ist_time.hour, ist_time.minute, ist_time.second
    except ntplib.NTPException as e:
        print(f"[ERROR] NTP request failed: {e}")
        print("[FALLBACK] Using local system clock...")
        return get_local_time()


def get_local_time():
    """Fallback: use system clock (already NTP-synced by Windows)."""
    now = datetime.now()
    print(f"[LOCAL] Time: {now.strftime('%H:%M:%S')}")
    return now.hour, now.minute, now.second


def send_time_to_fpga(port, baud, hh, mm, ss):
    """Send 4-byte UART packet [0xFF, HH, MM, SS] to FPGA."""
    packet = bytes([0xFF, hh, mm, ss])
    print(f"\n[UART] Port  : {port}")
    print(f"[UART] Baud  : {baud}")
    print(f"[UART] Packet: {[hex(b) for b in packet]}")
    print(f"[UART] Time  : {hh:02d}:{mm:02d}:{ss:02d}")

    try:
        with serial.Serial(port, baud, timeout=2) as ser:
            time.sleep(0.1)             # let port settle after open
            ser.write(packet)
            ser.flush()
            print(f"[UART] Sent successfully.")
    except serial.SerialException as e:
        print(f"[ERROR] Serial error: {e}")
        print("Check that:")
        print("  1. The COM port is correct (check Device Manager)")
        print("  2. The Boolean Board is connected via USB")
        print("  3. No other program (PuTTY etc.) has the port open")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Send NTP time to FPGA digital clock over UART"
    )
    parser.add_argument("--port",  default="COM3",  help="Serial port (default: COM3)")
    parser.add_argument("--baud",  default=9600, type=int, help="Baud rate (default: 9600)")
    parser.add_argument("--local", action="store_true",
                        help="Use local clock instead of NTP")
    parser.add_argument("--loop",  action="store_true",
                        help="Sync every 60 seconds continuously")
    args = parser.parse_args()

    print("=" * 50)
    print("  FPGA Clock — NTP UART Time Sync")
    print("=" * 50)

    if args.loop:
        print("[MODE] Continuous sync every 60 seconds. Ctrl+C to stop.\n")
        try:
            while True:
                if args.local:
                    hh, mm, ss = get_local_time()
                else:
                    hh, mm, ss = get_ntp_time_ist()
                send_time_to_fpga(args.port, args.baud, hh, mm, ss)
                print(f"\n[WAIT] Next sync in 60 seconds...\n")
                time.sleep(60)
        except KeyboardInterrupt:
            print("\n[STOPPED] Sync stopped by user.")
    else:
        if args.local:
            hh, mm, ss = get_local_time()
        else:
            hh, mm, ss = get_ntp_time_ist()
        send_time_to_fpga(args.port, args.baud, hh, mm, ss)

    print("\n[DONE] FPGA clock synchronised.")


if __name__ == "__main__":
    main()
