// =============================================================================
// MODULE : mode_fsm
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Purely combinational mode decoder.
// Decodes 2-bit switch input into four one-hot active signals.
//   mode 00 → clk_mode (clock display)
//   mode 01 → alm_mode (alarm set)
//   mode 10 → sw_mode  (stopwatch)
//   mode 11 → set_mode (time set)
// =============================================================================
`timescale 1ns/1ps

module mode_fsm (
    input  wire [1:0] mode_sw,
    output wire       clk_mode,
    output wire       alm_mode,
    output wire       sw_mode,
    output wire       set_mode
);
    assign clk_mode = (mode_sw == 2'b00);
    assign alm_mode = (mode_sw == 2'b01);
    assign sw_mode  = (mode_sw == 2'b10);
    assign set_mode = (mode_sw == 2'b11);
endmodule
