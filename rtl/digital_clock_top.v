// =============================================================================
// MODULE : digital_clock_top  ── TOP MODULE ──
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// BOARD  : Boolean Board — Xilinx Spartan-7 XC7S50-CSGA324
// AUTHOR : Rohan — E&TC Sem 4, PICT Pune
// =============================================================================
//
// SYSTEM OVERVIEW
// ───────────────
// Fully synchronous digital alarm clock with stopwatch and UART time sync.
// No microcontroller, no software — pure Verilog RTL.
// All flip-flops clocked on posedge of 100 MHz system clock.
//
// OPERATING MODES (mode[1:0] via SW0/SW1)
// ─────────────────────────────────────────
//   00 → Clock display   (real-time HH:MM on D1, SS on D0)
//   01 → Alarm set       (set alarm time via btn_sel/btn_inc)
//   10 → Stopwatch       (elapsed time, start/pause via btn_start_stop)
//   11 → Time set        (set clock time via btn_sel/btn_inc)
//
// PIN MAPPING (Boolean Board)
// ─────────────────────────────────────────
//   clk            → F14   100 MHz oscillator
//   rst            → J2    BTN0 — global synchronous reset
//   mode[0]        → V2    SW0
//   mode[1]        → U2    SW1
//   btn_inc        → J5    BTN1
//   btn_sel        → H2    BTN2
//   btn_start_stop → J1    BTN3
//   alarm_en       → T1    SW4
//   rx             → see XDC — USB-UART RX from FTDI chip
//   D1_seg[6:0]    → 7-segment left  display segments
//   D1_a[3:0]      → 7-segment left  display anodes  (active LOW)
//   D0_seg[6:0]    → 7-segment right display segments
//   D0_a[3:0]      → 7-segment right display anodes  (active LOW)
//   audio_out[1:0] → N13, N14 — stereo PWM audio
//   led[3:0]       → A4, B4, A3, B3 — mode LEDs
//
// MODULE HIERARCHY
// ─────────────────────────────────────────
//   digital_clock_top
//   ├── clock_divider
//   ├── mode_fsm
//   ├── bcd_time_counter
//   ├── stopwatch_counter
//   ├── time_set_fsm
//   ├── alarm_set_fsm
//   ├── alarm_register
//   ├── happy_birthday_alarm
//   ├── uart (universal — TX + RX)
//   ├── time_loader
//   ├── display_data_selector
//   ├── dual_display_controller
//   │   └── seg7_decoder (×2, instantiated inside)
//
// =============================================================================
`timescale 1ns/1ps

module digital_clock_top #(
    parameter CLK_FREQ  = 100_000_000,
    parameter SCAN_DIVN = 100_000,
    parameter BAUD_RATE = 9600
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [1:0] mode,
    input  wire       btn_inc,
    input  wire       btn_sel,
    input  wire       btn_start_stop,
    input  wire       alarm_en,
    input  wire       rx,              // UART RX from PC (via FTDI on Boolean Board)
    output wire [6:0] D1_seg,
    output wire [3:0] D1_a,
    output wire [6:0] D0_seg,
    output wire [3:0] D0_a,
    output wire [1:0] audio_out,
    output wire [3:0] led,
    // TX exposed at top level for loopback testing / echo (tie off if unused)
    output wire       tx
);

    // ── Internal wires ────────────────────────────────────────────────────────
    wire tick_1hz, tick_scan, tick_blink;
    wire clk_mode, alm_mode, sw_mode, set_mode;

    wire [5:0] clk_hh, clk_mm, clk_ss;
    wire [5:0] sw_hh,  sw_mm,  sw_ss;
    wire [5:0] set_hh, set_mm, set_ss;
    wire [5:0] alarm_hh, alarm_mm, alarm_ss;
    wire [3:0] hh_t, hh_u, mm_t, mm_u, ss_t, ss_u;

    wire       load_time_fsm;       // from time_set_fsm
    wire       load_time_uart;      // from time_loader
    wire [5:0] uart_hh, uart_mm, uart_ss;
    wire [1:0] field_sel;
    wire       alarm_trigger;

    // UART wires
    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;
    wire       uart_rx_parity_err;
    wire       uart_rx_frame_err;
    // TX driven LOW — not used in this design (expose for future echo/debug)
    wire       tx_busy_nc;

    // ── Merged load signals ───────────────────────────────────────────────────
    // Either time_set_fsm or UART time_loader can load the clock
    wire       load_any   = load_time_fsm | load_time_uart;
    wire [5:0] load_hh_w  = load_time_uart ? uart_hh : set_hh;
    wire [5:0] load_mm_w  = load_time_uart ? uart_mm : set_mm;
    wire [5:0] load_ss_w  = load_time_uart ? uart_ss : set_ss;

    // ── Blink state register ──────────────────────────────────────────────────
    reg blink_state;
    always @(posedge clk or posedge rst) begin
        if (rst) blink_state <= 1'b0;
        else if (tick_blink) blink_state <= ~blink_state;
    end

    // ── clock_divider ─────────────────────────────────────────────────────────
    clock_divider #(
        .CLK_FREQ (CLK_FREQ),
        .SCAN_DIVN(SCAN_DIVN)
    ) u_clkdiv (
        .clk      (clk),
        .rst      (rst),
        .tick_1hz (tick_1hz),
        .tick_scan(tick_scan),
        .tick_blink(tick_blink)
    );

    // ── mode_fsm ──────────────────────────────────────────────────────────────
    mode_fsm u_mode (
        .mode_sw (mode),
        .clk_mode(clk_mode),
        .alm_mode(alm_mode),
        .sw_mode (sw_mode),
        .set_mode(set_mode)
    );

    // ── bcd_time_counter ─────────────────────────────────────────────────────
    bcd_time_counter u_timecnt (
        .clk    (clk),
        .rst    (rst),
        .tick   (tick_1hz),
        .load   (load_any),
        .load_hh(load_hh_w),
        .load_mm(load_mm_w),
        .load_ss(load_ss_w),
        .hh     (clk_hh),
        .mm     (clk_mm),
        .ss     (clk_ss)
    );

    // ── stopwatch_counter ────────────────────────────────────────────────────
    stopwatch_counter u_sw (
        .clk       (clk),
        .rst       (rst),
        .tick      (tick_1hz & sw_mode),
        .start_stop(btn_start_stop & sw_mode),
        .sw_hh     (sw_hh),
        .sw_mm     (sw_mm),
        .sw_ss     (sw_ss)
    );

    // ── time_set_fsm ─────────────────────────────────────────────────────────
    time_set_fsm u_timeset (
        .clk      (clk),
        .rst      (rst),
        .active   (set_mode),
        .btn_sel  (btn_sel),
        .btn_inc  (btn_inc),
        .set_hh   (set_hh),
        .set_mm   (set_mm),
        .set_ss   (set_ss),
        .load_time(load_time_fsm),
        .field_sel(field_sel)
    );

    // ── alarm_set_fsm ────────────────────────────────────────────────────────
    alarm_set_fsm u_almset (
        .clk     (clk),
        .rst     (rst),
        .active  (alm_mode),
        .btn_sel (btn_sel),
        .btn_inc (btn_inc),
        .alarm_hh(alarm_hh),
        .alarm_mm(alarm_mm),
        .alarm_ss(alarm_ss)
    );

    // ── alarm_register ───────────────────────────────────────────────────────
    alarm_register u_alarm (
        .clk          (clk),
        .rst          (rst),
        .alarm_en     (alarm_en),
        .alarm_hh     (alarm_hh),
        .alarm_mm     (alarm_mm),
        .alarm_ss     (alarm_ss),
        .curr_hh      (clk_hh),
        .curr_mm      (clk_mm),
        .curr_ss      (clk_ss),
        .alarm_trigger(alarm_trigger)
    );

    // ── happy_birthday_alarm ─────────────────────────────────────────────────
    happy_birthday_alarm #(
        .CLK_FREQ(CLK_FREQ)
    ) u_hbd (
        .clk          (clk),
        .rst          (rst),
        .alarm_trigger(alarm_trigger),
        .audio_out    (audio_out)
    );

    // ── uart (universal RX + TX) ─────────────────────────────────────────────
    uart #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE),
        .DATA_BITS (8),
        .STOP_BITS (1),
        .PARITY_EN (0),
        .PARITY_ODD(0)
    ) u_uart (
        .clk          (clk),
        .rst          (rst),
        // TX — not used in normal operation; tie tx_start LOW
        .tx_start     (1'b0),
        .tx_data_in   (8'h00),
        .tx           (tx),
        .tx_busy      (tx_busy_nc),
        // RX — receives time packets from PC
        .rx           (rx),
        .rx_data_out  (uart_rx_data),
        .rx_data_valid(uart_rx_valid),
        .rx_parity_err(uart_rx_parity_err),
        .rx_frame_err (uart_rx_frame_err)
    );

    // ── time_loader ──────────────────────────────────────────────────────────
    time_loader u_tload (
        .clk       (clk),
        .rst       (rst),
        .data_in   (uart_rx_data),
        .data_valid(uart_rx_valid),
        .load_hh   (uart_hh),
        .load_mm   (uart_mm),
        .load_ss   (uart_ss),
        .load_time (load_time_uart)
    );

    // ── display_data_selector ────────────────────────────────────────────────
    display_data_selector u_datasel (
        .mode  (mode),
        .clk_hh(clk_hh), .clk_mm(clk_mm), .clk_ss(clk_ss),
        .alm_hh(alarm_hh),.alm_mm(alarm_mm),.alm_ss(alarm_ss),
        .sw_hh (sw_hh),  .sw_mm (sw_mm),  .sw_ss (sw_ss),
        .set_hh(set_hh), .set_mm(set_mm), .set_ss(set_ss),
        .hh_t  (hh_t),   .hh_u  (hh_u),
        .mm_t  (mm_t),   .mm_u  (mm_u),
        .ss_t  (ss_t),   .ss_u  (ss_u)
    );

    // ── dual_display_controller ──────────────────────────────────────────────
    dual_display_controller u_disp (
        .clk      (clk),
        .rst      (rst),
        .tick_scan(tick_scan),
        .hh_t     (hh_t), .hh_u(hh_u),
        .mm_t     (mm_t), .mm_u(mm_u),
        .ss_t     (ss_t), .ss_u(ss_u),
        .D1_seg   (D1_seg), .D1_a(D1_a),
        .D0_seg   (D0_seg), .D0_a(D0_a)
    );

    // ── LED mode indicators ──────────────────────────────────────────────────
    // led[0] → solid ON in clock mode
    // led[1] → blinks in alarm mode
    // led[2] → solid ON in stopwatch mode
    // led[3] → blinks in time-set mode
    assign led[0] = clk_mode;
    assign led[1] = alm_mode  ? blink_state : 1'b0;
    assign led[2] = sw_mode;
    assign led[3] = set_mode  ? blink_state : 1'b0;

endmodule
