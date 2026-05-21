# FPGA Digital Alarm Clock with Stopwatch

**RTL Design on Xilinx Spartan-7 XC7S50 (Boolean Board) using Verilog HDL**

> Tool: Xilinx Vivado 
> Board: Boolean Board — Spartan-7 XC7S50-1CSGA324  
> Clock: 100 MHz on-board oscillator  

---

## Overview

A fully synchronous, hardware-based digital alarm clock with integrated stopwatch, implemented entirely in Verilog HDL. No microcontroller, no software — pure RTL logic. Verified through RTL behavioural simulation in Vivado and validated on hardware.

**Key features:**
- Accurate 1 Hz timekeeping via hardware clock division (no software jitter)
- FSM-based alarm with *Happy Birthday* melody on PWM audio output (20 seconds)
- Integrated stopwatch with start/pause/resume
- Multiplexed 7-segment display — HH:MM on D1, SS on D0 (1 kHz scan, flicker-free)
- Four operating modes via 2-bit switch
- **UART time sync** — send current NTP time from PC over serial (Python or PowerShell)

---

## Operating Modes

| mode[1:0] | SW1 | SW0 | Function |
|-----------|-----|-----|----------|
| `00` | 0 | 0 | Clock display (real-time HH:MM:SS) |
| `01` | 0 | 1 | Alarm set (btn_sel/btn_inc to configure) |
| `10` | 1 | 0 | Stopwatch (btn_start_stop to start/pause) |
| `11` | 1 | 1 | Time set (btn_sel/btn_inc to configure) |

---

## Module Hierarchy

```
digital_clock_top
├── clock_divider           — tick_1hz · tick_scan · tick_blink
├── mode_fsm                — combinational mode decoder
├── bcd_time_counter        — real-time clock (hh/mm/ss BCD registers)
├── stopwatch_counter       — elapsed time with start/pause/resume
├── time_set_fsm            — FSM: IDLE→HH→MM→SS→IDLE
├── alarm_set_fsm           — FSM: IDLE→HH→MM→SS→IDLE
├── alarm_register          — time comparator + latched trigger
├── happy_birthday_alarm    — melody FSM + tone generator + PWM
├── uart                    — universal UART TX + RX (8N1, parameterised)
├── time_loader             — UART packet parser → load pulse
├── display_data_selector   — mode-based time bus mux
└── dual_display_controller — 4-digit scanning driver
    └── seg7_decoder (×2)   — BCD → 7-segment ROM
```

---

## Pin Mapping

| Signal | Pin | Description |
|--------|-----|-------------|
| `clk` | F14 | 100 MHz oscillator |
| `rst` | J2 | BTN0 — global reset |
| `mode[0]` | V2 | SW0 |
| `mode[1]` | U2 | SW1 |
| `btn_inc` | J5 | BTN1 — increment field |
| `btn_sel` | H2 | BTN2 — select field |
| `btn_start_stop` | J1 | BTN3 — stopwatch |
| `alarm_en` | T1 | SW4 — alarm enable |
| `rx` | B18 | UART RX (FTDI) |
| `tx` | A18 | UART TX (FTDI) |
| `audio_out[0]` | N13 | PWM audio left |
| `audio_out[1]` | N14 | PWM audio right |
| `led[3:0]` | A4,B4,A3,B3 | Mode indicators |

> ⚠️ Verify D1/D0 segment and anode pins against your Boolean Board schematic before implementation.

---

## Post-Implementation Results

| Resource | Used | Available | Utilisation |
|----------|------|-----------|-------------|
| Slice LUTs | 312 | 32,600 | 0.96 % |
| Slice Registers (FFs) | 284 | 65,200 | 0.44 % |
| Block RAM Tiles | 0 | 75 | 0.00 % |
| DSP48E1 Slices | 0 | 120 | 0.00 % |
| Bonded IOBs | 34 | 210 | 16.19 % |
| **WNS** | **+2.14 ns** | — | **Timing MET** |

---

## UART Time Sync

The FPGA accepts a 4-byte packet over UART to set the clock time:

```
[ 0xFF | HH | MM | SS ]
```

`0xFF` is the sync/header byte. The `time_loader` module parses incoming bytes and pulses the `load` input of `bcd_time_counter` for one clock cycle.

### Option 1 — Python (NTP sync)

```bash
pip install pyserial ntplib
python scripts/ntp_uart_sync.py --port COM3 --baud 9600
```

Options:
```
--port   COM port (default: COM3)
--baud   Baud rate (default: 9600)
--local  Use system clock instead of NTP
--loop   Sync every 60 seconds continuously
```

### Option 2 — PowerShell (no installation)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/sync_time.ps1
```

Edit `$COM_PORT` inside the script to match your port.

---

## Repository Structure

```
fpga_clock/
├── rtl/
│   ├── digital_clock_top.v       ← top module
│   ├── clock_divider.v
│   ├── bcd_time_counter.v
│   ├── stopwatch_counter.v
│   ├── time_set_fsm.v
│   ├── alarm_set_fsm.v
│   ├── alarm_register.v
│   ├── happy_birthday_alarm.v
│   ├── uart.v                    ← universal UART TX+RX
│   ├── time_loader.v             ← UART packet parser
│   ├── display_modules.v         ← seg7_decoder + selector + controller
│   └── mode_fsm.v
├── sim/
│   ├── clock_divider_tb.v
│   ├── bcd_time_counter_tb.v
│   ├── uart_tb.v
│   └── time_loader_tb.v
├── constraints/
│   └── boolean_board.xdc
├── scripts/
│   ├── ntp_uart_sync.py
│   └── sync_time.ps1
└── README.md
```

---

## How to Run in Vivado

1. Create a new Vivado project targeting `xc7s50csga324-1`
2. Add all files in `rtl/` as design sources
3. Add `constraints/boolean_board.xdc` as constraint source
4. Set `digital_clock_top` as the top module
5. Run Simulation → Add testbenches from `sim/`
6. Run Synthesis → Implementation → Generate Bitstream
7. Program the Boolean Board via JTAG

---

## Design Decisions

- **No `initial` blocks** — ROM lookup uses `case` statement function (synthesisable)
- **Edge detection** on all buttons — prevents repeated FSM transitions while held
- **Active-LOW anodes** — correct for Boolean Board 7-segment displays
- **Single-cycle tick pulses** — tick_1hz is HIGH for exactly one 100 MHz clock cycle
- **Registered alarm_trigger** — latches HIGH after match, holds until `alarm_en` cleared
- **Double-flop synchroniser** on UART RX line — eliminates metastability

---

## Future Work

- [ ] SPI master — OLED display upgrade
- [ ] Multiple alarm slots
- [ ] Countdown timer mode

---


