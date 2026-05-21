## =============================================================================
## CONSTRAINTS : digital_clock_top.xdc
## PROJECT     : FPGA Digital Alarm Clock with Stopwatch
## BOARD       : Boolean Board — Xilinx Spartan-7 XC7S50-CSGA324
## AUTHOR      : Rohan — E&TC Sem 4, PICT Pune
## =============================================================================

## ── Clock ────────────────────────────────────────────────────────────────────
set_property PACKAGE_PIN F14 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

## ── Reset (BTN0) ─────────────────────────────────────────────────────────────
set_property PACKAGE_PIN J2  [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

## ── Mode switches ────────────────────────────────────────────────────────────
set_property PACKAGE_PIN V2  [get_ports {mode[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {mode[0]}]
set_property PACKAGE_PIN U2  [get_ports {mode[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {mode[1]}]

## ── Buttons ──────────────────────────────────────────────────────────────────
set_property PACKAGE_PIN J5  [get_ports btn_inc]
set_property IOSTANDARD LVCMOS33 [get_ports btn_inc]

set_property PACKAGE_PIN H2  [get_ports btn_sel]
set_property IOSTANDARD LVCMOS33 [get_ports btn_sel]

set_property PACKAGE_PIN J1  [get_ports btn_start_stop]
set_property IOSTANDARD LVCMOS33 [get_ports btn_start_stop]

## ── Alarm enable switch (SW4) ────────────────────────────────────────────────
set_property PACKAGE_PIN T1  [get_ports alarm_en]
set_property IOSTANDARD LVCMOS33 [get_ports alarm_en]

## ── UART RX (from FTDI USB-UART chip on Boolean Board) ───────────────────────
## Check your Boolean Board reference manual for the exact RX pin
## Common pin for Boolean Board FTDI UART RX:
set_property PACKAGE_PIN B18 [get_ports rx]
set_property IOSTANDARD LVCMOS33 [get_ports rx]

## ── UART TX (to FTDI USB-UART chip) ─────────────────────────────────────────
set_property PACKAGE_PIN A18 [get_ports tx]
set_property IOSTANDARD LVCMOS33 [get_ports tx]

## ── D1 Left Display — 7-segment segments ────────────────────────────────────
## Verify exact pins from Boolean Board reference manual for your display wiring
set_property PACKAGE_PIN W4  [get_ports {D1_seg[0]}]
set_property PACKAGE_PIN V4  [get_ports {D1_seg[1]}]
set_property PACKAGE_PIN U4  [get_ports {D1_seg[2]}]
set_property PACKAGE_PIN U2  [get_ports {D1_seg[3]}]
set_property PACKAGE_PIN W3  [get_ports {D1_seg[4]}]
set_property PACKAGE_PIN V3  [get_ports {D1_seg[5]}]
set_property PACKAGE_PIN W5  [get_ports {D1_seg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {D1_seg[*]}]

## ── D1 Left Display — anodes (active LOW) ────────────────────────────────────
set_property PACKAGE_PIN W4  [get_ports {D1_a[0]}]
set_property PACKAGE_PIN V4  [get_ports {D1_a[1]}]
set_property PACKAGE_PIN U4  [get_ports {D1_a[2]}]
set_property PACKAGE_PIN U2  [get_ports {D1_a[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {D1_a[*]}]

## ── D0 Right Display — 7-segment segments ────────────────────────────────────
set_property PACKAGE_PIN W4  [get_ports {D0_seg[0]}]
set_property PACKAGE_PIN V4  [get_ports {D0_seg[1]}]
set_property PACKAGE_PIN U4  [get_ports {D0_seg[2]}]
set_property PACKAGE_PIN U2  [get_ports {D0_seg[3]}]
set_property PACKAGE_PIN W3  [get_ports {D0_seg[4]}]
set_property PACKAGE_PIN V3  [get_ports {D0_seg[5]}]
set_property PACKAGE_PIN W5  [get_ports {D0_seg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {D0_seg[*]}]

## ── D0 Right Display — anodes (active LOW) ───────────────────────────────────
set_property PACKAGE_PIN W4  [get_ports {D0_a[0]}]
set_property PACKAGE_PIN V4  [get_ports {D0_a[1]}]
set_property PACKAGE_PIN U4  [get_ports {D0_a[2]}]
set_property PACKAGE_PIN U2  [get_ports {D0_a[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {D0_a[*]}]

## NOTE: D1 and D0 share segment lines in a typical Boolean Board wiring.
## Replace pin numbers above with actual pin assignments from your Boolean Board
## reference manual / schematic before running implementation.

## ── Audio output (PWM stereo) ─────────────────────────────────────────────────
set_property PACKAGE_PIN N13 [get_ports {audio_out[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {audio_out[0]}]
set_property PACKAGE_PIN N14 [get_ports {audio_out[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {audio_out[1]}]

## ── LED mode indicators ───────────────────────────────────────────────────────
set_property PACKAGE_PIN A4  [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN B4  [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN A3  [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN B3  [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

## ── Bitstream settings ───────────────────────────────────────────────────────
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
