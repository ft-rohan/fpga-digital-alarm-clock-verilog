// =============================================================================
// MODULE : time_set_fsm
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// 4-state Mealy FSM for setting the real-time clock.
// States: IDLE -> EDIT_HH -> EDIT_MM -> EDIT_SS -> IDLE
// btn_sel advances state; btn_inc increments the active field.
// Both buttons are edge-detected internally.
// On final btn_sel (EDIT_SS -> IDLE), load_time is pulsed HIGH for one cycle.
// Active only when set_mode is asserted (mode == 2'b11).
// =============================================================================
`timescale 1ns/1ps

module time_set_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       active,      // assert when mode == 2'b11
    input  wire       btn_sel,     // select / advance field
    input  wire       btn_inc,     // increment active field
    output reg  [5:0] set_hh,
    output reg  [5:0] set_mm,
    output reg  [5:0] set_ss,
    output reg        load_time,   // one-cycle pulse to load bcd_time_counter
    output reg  [1:0] field_sel    // 0=HH, 1=MM, 2=SS (for display blink)
);

    localparam IDLE    = 2'd0;
    localparam EDIT_HH = 2'd1;
    localparam EDIT_MM = 2'd2;
    localparam EDIT_SS = 2'd3;

    reg [1:0] state;
    reg sel_p, inc_p;
    wire sel_e = btn_sel & ~sel_p;  // rising edge of btn_sel
    wire inc_e = btn_inc & ~inc_p;  // rising edge of btn_inc

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            set_hh    <= 6'd0;
            set_mm    <= 6'd0;
            set_ss    <= 6'd0;
            load_time <= 1'b0;
            field_sel <= 2'd0;
            sel_p     <= 1'b0;
            inc_p     <= 1'b0;
        end else begin
            sel_p     <= btn_sel;
            inc_p     <= btn_inc;
            load_time <= 1'b0;      // default: deassert every cycle

            if (!active) begin
                state <= IDLE;
            end else begin
                case (state)
                    IDLE: begin
                        field_sel <= 2'd0;
                        if (sel_e) state <= EDIT_HH;
                    end

                    EDIT_HH: begin
                        field_sel <= 2'd0;
                        if (inc_e) set_hh <= (set_hh == 6'd23) ? 6'd0 : set_hh + 1;
                        if (sel_e) state  <= EDIT_MM;
                    end

                    EDIT_MM: begin
                        field_sel <= 2'd1;
                        if (inc_e) set_mm <= (set_mm == 6'd59) ? 6'd0 : set_mm + 1;
                        if (sel_e) state  <= EDIT_SS;
                    end

                    EDIT_SS: begin
                        field_sel <= 2'd2;
                        if (inc_e) set_ss <= (set_ss == 6'd59) ? 6'd0 : set_ss + 1;
                        if (sel_e) begin
                            load_time <= 1'b1;  // single-cycle load pulse
                            state     <= IDLE;
                        end
                    end

                    default: state <= IDLE;
                endcase
            end
        end
    end

endmodule
