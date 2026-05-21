// =============================================================================
// MODULE : clock_divider
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// BOARD  : Boolean Board — Xilinx Spartan-7 XC7S50-CSGA324
// AUTHOR : Rohan — E&TC Sem 4, PICT Pune
// -----------------------------------------------------------------------------
// Generates three tick signals from the 100 MHz system clock:
//   tick_1hz   — 1 Hz  : drives real-time clock and stopwatch counters
//   tick_scan  — 1 kHz : drives 7-segment display multiplexer
//   tick_blink — 2 Hz  : drives LED blink during set modes
// All ticks are single-cycle HIGH pulses (not square waves).
// =============================================================================
`timescale 1ns/1ps

module clock_divider #(
    parameter CLK_FREQ  = 100_000_000,  // system clock frequency in Hz
    parameter SCAN_DIVN = 100_000       // divider for scan tick (1 kHz default)
)(
    input  wire clk,
    input  wire rst,
    output reg  tick_1hz,
    output reg  tick_scan,
    output reg  tick_blink
);

    // ── 1 Hz tick ────────────────────────────────────────────────────────────
    integer cnt_1hz;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt_1hz  <= 0;
            tick_1hz <= 1'b0;
        end else if (cnt_1hz == CLK_FREQ - 1) begin
            tick_1hz <= 1'b1;
            cnt_1hz  <= 0;
        end else begin
            tick_1hz <= 1'b0;
            cnt_1hz  <= cnt_1hz + 1;
        end
    end

    // ── Scan tick (~1 kHz) ───────────────────────────────────────────────────
    integer cnt_scan;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt_scan  <= 0;
            tick_scan <= 1'b0;
        end else if (cnt_scan == SCAN_DIVN - 1) begin
            tick_scan <= 1'b1;
            cnt_scan  <= 0;
        end else begin
            tick_scan <= 1'b0;
            cnt_scan  <= cnt_scan + 1;
        end
    end

    // ── Blink tick (~2 Hz) ───────────────────────────────────────────────────
    // Toggles blink_phase every CLK_FREQ/4 cycles → 2 Hz visible blink
    integer cnt_blink;
    reg     blink_phase;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt_blink   <= 0;
            blink_phase <= 1'b0;
            tick_blink  <= 1'b0;
        end else if (cnt_blink == CLK_FREQ/4 - 1) begin
            tick_blink  <= 1'b1;
            blink_phase <= ~blink_phase;
            cnt_blink   <= 0;
        end else begin
            tick_blink <= 1'b0;
            cnt_blink  <= cnt_blink + 1;
        end
    end

endmodule
