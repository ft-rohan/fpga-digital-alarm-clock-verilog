// =============================================================================
// MODULE : alarm_register
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Compares current time against stored alarm time every clock cycle.
// alarm_trigger latches HIGH when time matches and alarm_en is asserted.
// Remains HIGH after the matching second passes (latched output).
// Clears immediately when alarm_en is deasserted (SW4 OFF).
// =============================================================================
`timescale 1ns/1ps

module alarm_register (
    input  wire       clk,
    input  wire       rst,
    input  wire       alarm_en,    // SW4 — level signal, alarm enable
    input  wire [5:0] alarm_hh,
    input  wire [5:0] alarm_mm,
    input  wire [5:0] alarm_ss,
    input  wire [5:0] curr_hh,
    input  wire [5:0] curr_mm,
    input  wire [5:0] curr_ss,
    output reg        alarm_trigger
);

    wire time_match = alarm_en
                    & (curr_hh == alarm_hh)
                    & (curr_mm == alarm_mm)
                    & (curr_ss == alarm_ss);

    always @(posedge clk or posedge rst) begin
        if (rst)
            alarm_trigger <= 1'b0;
        else if (!alarm_en)
            alarm_trigger <= 1'b0;      // SW4 OFF — force stop immediately
        else if (time_match)
            alarm_trigger <= 1'b1;      // latch ON at match
        // else: hold — keeps playing after the matching second passes
    end

endmodule
