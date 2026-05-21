// =============================================================================
// MODULE : seg7_decoder
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Combinational BCD to 7-segment decoder.
// Output is active-LOW (0 = segment ON) for Boolean Board.
// Segment order: seg[6:0] = {g, f, e, d, c, b, a}
// =============================================================================
`timescale 1ns/1ps

module seg7_decoder (
    input  wire [3:0] bcd,
    output reg  [6:0] seg
);
    always @(*) begin
        case (bcd)
            4'd0: seg = ~7'b0111111; // a b c d e f on
            4'd1: seg = ~7'b0000110;
            4'd2: seg = ~7'b1011011;
            4'd3: seg = ~7'b1001111;
            4'd4: seg = ~7'b1100110;
            4'd5: seg = ~7'b1101101;
            4'd6: seg = ~7'b1111101;
            4'd7: seg = ~7'b0000111;
            4'd8: seg = ~7'b1111111;
            4'd9: seg = ~7'b1101111;
            default: seg = 7'b1111111; // all segments OFF
        endcase
    end
endmodule


// =============================================================================
// MODULE : display_data_selector
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Mode-based multiplexer — routes the correct time bus to the display pipeline.
//   mode 00: real-time clock  (clk_hh/mm/ss)
//   mode 01: alarm time       (alm_hh/mm/ss)
//   mode 10: stopwatch        (sw_hh/mm/ss)
//   mode 11: time being set   (set_hh/mm/ss)
// Outputs tens and units digits for each field.
// =============================================================================
module display_data_selector (
    input  wire [1:0] mode,
    input  wire [5:0] clk_hh, clk_mm, clk_ss,
    input  wire [5:0] alm_hh, alm_mm, alm_ss,
    input  wire [5:0] sw_hh,  sw_mm,  sw_ss,
    input  wire [5:0] set_hh, set_mm, set_ss,
    output reg  [3:0] hh_t, hh_u,
    output reg  [3:0] mm_t, mm_u,
    output reg  [3:0] ss_t, ss_u
);
    reg [5:0] show_hh, show_mm, show_ss;

    always @(*) begin
        case (mode)
            2'b00: begin show_hh = clk_hh; show_mm = clk_mm; show_ss = clk_ss; end
            2'b01: begin show_hh = alm_hh; show_mm = alm_mm; show_ss = alm_ss; end
            2'b10: begin show_hh = sw_hh;  show_mm = sw_mm;  show_ss = sw_ss;  end
            2'b11: begin show_hh = set_hh; show_mm = set_mm; show_ss = set_ss; end
        endcase

        hh_t = show_hh / 10;
        hh_u = show_hh % 10;
        mm_t = show_mm / 10;
        mm_u = show_mm % 10;
        ss_t = show_ss / 10;
        ss_u = show_ss % 10;
    end
endmodule


// =============================================================================
// MODULE : dual_display_controller
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Scans two 4-digit 7-segment displays at 1 kHz (tick_scan).
// D1 (left)  shows HH:MM — all 4 digits always active.
// D0 (right) shows __:SS — only digits 1 and 0 active (tens/units of seconds).
// Anodes are active-LOW for Boolean Board.
//
// digit_sel mapping:
//   3 → D1 digit 3 (HH tens)   D0 OFF
//   2 → D1 digit 2 (HH units)  D0 OFF
//   1 → D1 digit 1 (MM tens)   D0 digit 1 (SS tens)
//   0 → D1 digit 0 (MM units)  D0 digit 0 (SS units)
// =============================================================================
module dual_display_controller (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick_scan,
    input  wire [3:0] hh_t, hh_u,
    input  wire [3:0] mm_t, mm_u,
    input  wire [3:0] ss_t, ss_u,
    output reg  [6:0] D1_seg,
    output reg  [3:0] D1_a,
    output reg  [6:0] D0_seg,
    output reg  [3:0] D0_a
);
    reg [1:0] digit_sel;

    // ── Digit selector counter ────────────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) digit_sel <= 2'd0;
        else if (tick_scan) digit_sel <= digit_sel + 1;
    end

    // ── D1 BCD mux ───────────────────────────────────────────────────────────
    reg [3:0] d1_bcd;
    always @(*) begin
        case (digit_sel)
            2'd3: d1_bcd = hh_t;
            2'd2: d1_bcd = hh_u;
            2'd1: d1_bcd = mm_t;
            2'd0: d1_bcd = mm_u;
        endcase
    end

    // ── D0 BCD mux ───────────────────────────────────────────────────────────
    reg [3:0] d0_bcd;
    always @(*) begin
        case (digit_sel)
            2'd3: d0_bcd = 4'hF; // blank
            2'd2: d0_bcd = 4'hF; // blank
            2'd1: d0_bcd = ss_t;
            2'd0: d0_bcd = ss_u;
        endcase
    end

    // ── Instantiate decoders ──────────────────────────────────────────────────
    wire [6:0] d1_seg_dec, d0_seg_dec;
    seg7_decoder u_d1 (.bcd(d1_bcd), .seg(d1_seg_dec));
    seg7_decoder u_d0 (.bcd(d0_bcd), .seg(d0_seg_dec));

    // ── Register outputs + anode drive ───────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            D1_seg <= 7'b1111111;
            D0_seg <= 7'b1111111;
            D1_a   <= 4'b1111;
            D0_a   <= 4'b1111;
        end else begin
            D1_seg <= d1_seg_dec;
            D0_seg <= d0_seg_dec;
            case (digit_sel)
                2'd3: begin D1_a <= 4'b0111; D0_a <= 4'b1111; end // D0 blank
                2'd2: begin D1_a <= 4'b1011; D0_a <= 4'b1111; end // D0 blank
                2'd1: begin D1_a <= 4'b1101; D0_a <= 4'b1101; end
                2'd0: begin D1_a <= 4'b1110; D0_a <= 4'b1110; end
            endcase
        end
    end
endmodule
