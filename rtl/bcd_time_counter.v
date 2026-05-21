// =============================================================================
// MODULE : bcd_time_counter
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Maintains real-time clock as three 6-bit BCD registers: hh, mm, ss.
// Increments on every tick_1hz pulse with cascaded carry propagation.
// Supports synchronous load from time_set_fsm or uart time_loader.
// =============================================================================
`timescale 1ns/1ps

module bcd_time_counter (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,       // 1 Hz tick from clock_divider
    input  wire       load,       // synchronous load enable (one-cycle pulse)
    input  wire [5:0] load_hh,    // hours   to load (0-23)
    input  wire [5:0] load_mm,    // minutes to load (0-59)
    input  wire [5:0] load_ss,    // seconds to load (0-59)
    output reg  [5:0] hh,         // current hours
    output reg  [5:0] mm,         // current minutes
    output reg  [5:0] ss          // current seconds
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hh <= 6'd0;
            mm <= 6'd0;
            ss <= 6'd0;
        end else if (load) begin
            // synchronous load — from time_set_fsm or UART
            hh <= load_hh;
            mm <= load_mm;
            ss <= load_ss;
        end else if (tick) begin
            if (ss == 6'd59) begin
                ss <= 6'd0;
                if (mm == 6'd59) begin
                    mm <= 6'd0;
                    hh <= (hh == 6'd23) ? 6'd0 : hh + 1;
                end else begin
                    mm <= mm + 1;
                end
            end else begin
                ss <= ss + 1;
            end
        end
    end

endmodule
