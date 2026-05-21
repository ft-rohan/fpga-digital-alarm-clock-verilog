// =============================================================================
// MODULE : stopwatch_counter
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Tracks elapsed time independently of the real-time clock.
// start_stop input is edge-detected — each rising edge toggles running state.
// Active only when sw_mode is asserted by mode_fsm (gated tick and button).
// =============================================================================
`timescale 1ns/1ps

module stopwatch_counter (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,        // 1 Hz tick gated with sw_mode
    input  wire       start_stop,  // edge-detected start/stop button
    output reg  [5:0] sw_hh,
    output reg  [5:0] sw_mm,
    output reg  [5:0] sw_ss
);

    reg running;
    reg ss_prev;
    wire ss_edge = start_stop & ~ss_prev;   // rising edge detect

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sw_hh   <= 6'd0;
            sw_mm   <= 6'd0;
            sw_ss   <= 6'd0;
            running <= 1'b0;
            ss_prev <= 1'b0;
        end else begin
            ss_prev <= start_stop;

            // toggle running on rising edge of start_stop
            if (ss_edge)
                running <= ~running;

            // count up when running
            if (running && tick) begin
                if (sw_ss == 6'd59) begin
                    sw_ss <= 6'd0;
                    if (sw_mm == 6'd59) begin
                        sw_mm <= 6'd0;
                        sw_hh <= (sw_hh == 6'd23) ? 6'd0 : sw_hh + 1;
                    end else begin
                        sw_mm <= sw_mm + 1;
                    end
                end else begin
                    sw_ss <= sw_ss + 1;
                end
            end
        end
    end

endmodule
