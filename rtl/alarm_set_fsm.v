// =============================================================================
// MODULE : alarm_set_fsm
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// 4-state FSM for setting the alarm time.
// Identical structure to time_set_fsm but writes to alarm_hh/mm/ss registers.
// No load pulse needed — alarm_register reads alarm_hh/mm/ss directly.
// Active only when alm_mode is asserted (mode == 2'b01).
// =============================================================================
`timescale 1ns/1ps

module alarm_set_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       active,      // assert when mode == 2'b01
    input  wire       btn_sel,
    input  wire       btn_inc,
    output reg  [5:0] alarm_hh,
    output reg  [5:0] alarm_mm,
    output reg  [5:0] alarm_ss
);

    localparam IDLE    = 2'd0;
    localparam EDIT_HH = 2'd1;
    localparam EDIT_MM = 2'd2;
    localparam EDIT_SS = 2'd3;

    reg [1:0] state;
    reg sel_p, inc_p;
    wire sel_e = btn_sel & ~sel_p;
    wire inc_e = btn_inc & ~inc_p;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            alarm_hh <= 6'd0;
            alarm_mm <= 6'd0;
            alarm_ss <= 6'd0;
            sel_p    <= 1'b0;
            inc_p    <= 1'b0;
        end else begin
            sel_p <= btn_sel;
            inc_p <= btn_inc;

            if (!active) begin
                state <= IDLE;
            end else begin
                case (state)
                    IDLE:    if (sel_e) state <= EDIT_HH;

                    EDIT_HH: begin
                        if (inc_e) alarm_hh <= (alarm_hh == 6'd23) ? 6'd0 : alarm_hh + 1;
                        if (sel_e) state    <= EDIT_MM;
                    end

                    EDIT_MM: begin
                        if (inc_e) alarm_mm <= (alarm_mm == 6'd59) ? 6'd0 : alarm_mm + 1;
                        if (sel_e) state    <= EDIT_SS;
                    end

                    EDIT_SS: begin
                        if (inc_e) alarm_ss <= (alarm_ss == 6'd59) ? 6'd0 : alarm_ss + 1;
                        if (sel_e) state    <= IDLE;
                    end

                    default: state <= IDLE;
                endcase
            end
        end
    end

endmodule
