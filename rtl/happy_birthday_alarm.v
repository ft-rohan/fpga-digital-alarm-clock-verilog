// =============================================================================
// MODULE : happy_birthday_alarm
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Plays "Happy Birthday" melody for 20 seconds on alarm_trigger rising edge.
// Uses a function-based ROM lookup (synthesisable — no initial blocks).
// Inter-note silence gap of 20 ms for staccato articulation.
// Fixed duty cycle ~0.4% (quiet setting) via notes[idx] >> 8.
// Stereo PWM output on audio_out[1:0].
// =============================================================================
`timescale 1ns/1ps

module happy_birthday_alarm #(
    parameter CLK_FREQ = 100_000_000
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       alarm_trigger,
    output wire [1:0] audio_out
);

    // ── Note period dividers at 100 MHz ──────────────────────────────────────
    localparam C4 = 32'd191571;
    localparam D4 = 32'd170648;
    localparam E4 = 32'd151515;
    localparam F4 = 32'd143266;
    localparam G4 = 32'd127551;
    localparam A4 = 32'd113636;
    localparam B4 = 32'd101214;
    localparam REST = 32'd0;

    // ── ROM lookup functions (synthesisable) ─────────────────────────────────
    function [31:0] get_note;
        input [4:0] idx;
        case (idx)
            5'd0:  get_note = G4; 5'd1:  get_note = G4; 5'd2:  get_note = A4;
            5'd3:  get_note = G4; 5'd4:  get_note = C4; 5'd5:  get_note = B4;
            5'd6:  get_note = G4; 5'd7:  get_note = G4; 5'd8:  get_note = A4;
            5'd9:  get_note = G4; 5'd10: get_note = D4; 5'd11: get_note = C4;
            5'd12: get_note = G4; 5'd13: get_note = G4; 5'd14: get_note = G4;
            5'd15: get_note = E4; 5'd16: get_note = C4; 5'd17: get_note = B4;
            5'd18: get_note = A4; 5'd19: get_note = F4; 5'd20: get_note = F4;
            5'd21: get_note = E4; 5'd22: get_note = C4; 5'd23: get_note = D4;
            5'd24: get_note = C4;
            default: get_note = REST;
        endcase
    endfunction

    function [31:0] get_dur;
        input [4:0] idx;
        case (idx)
            5'd0:  get_dur = 32'd25_000_000;  5'd1:  get_dur = 32'd25_000_000;
            5'd2:  get_dur = 32'd50_000_000;  5'd3:  get_dur = 32'd50_000_000;
            5'd4:  get_dur = 32'd50_000_000;  5'd5:  get_dur = 32'd100_000_000;
            5'd6:  get_dur = 32'd25_000_000;  5'd7:  get_dur = 32'd25_000_000;
            5'd8:  get_dur = 32'd50_000_000;  5'd9:  get_dur = 32'd50_000_000;
            5'd10: get_dur = 32'd50_000_000;  5'd11: get_dur = 32'd100_000_000;
            5'd12: get_dur = 32'd25_000_000;  5'd13: get_dur = 32'd25_000_000;
            5'd14: get_dur = 32'd50_000_000;  5'd15: get_dur = 32'd50_000_000;
            5'd16: get_dur = 32'd50_000_000;  5'd17: get_dur = 32'd50_000_000;
            5'd18: get_dur = 32'd100_000_000; 5'd19: get_dur = 32'd25_000_000;
            5'd20: get_dur = 32'd25_000_000;  5'd21: get_dur = 32'd50_000_000;
            5'd22: get_dur = 32'd50_000_000;  5'd23: get_dur = 32'd50_000_000;
            5'd24: get_dur = 32'd100_000_000;
            default: get_dur = 32'd50_000_000;
        endcase
    endfunction

    // ── 20-second play timer ──────────────────────────────────────────────────
    localparam PLAY_DURATION = 32'd2_000_000_000; // 20 × 100 MHz

    reg [31:0] play_timer;
    reg        playing;
    reg        alarm_prev;
    wire       alarm_start = alarm_trigger & ~alarm_prev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            playing    <= 1'b0;
            play_timer <= 32'd0;
            alarm_prev <= 1'b0;
        end else begin
            alarm_prev <= alarm_trigger;
            if (alarm_start) begin
                playing    <= 1'b1;
                play_timer <= 32'd0;
            end else if (playing) begin
                if (play_timer >= PLAY_DURATION || !alarm_trigger) begin
                    playing    <= 1'b0;
                    play_timer <= 32'd0;
                end else begin
                    play_timer <= play_timer + 1;
                end
            end
        end
    end

    // ── Melody FSM ────────────────────────────────────────────────────────────
    reg [4:0]  note_index;
    reg [31:0] time_counter;
    reg        is_resting;

    wire [31:0] cur_note = get_note(note_index);
    wire [31:0] cur_dur  = get_dur(note_index);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            note_index   <= 5'd0;
            time_counter <= 32'd0;
            is_resting   <= 1'b0;
        end else if (!playing) begin
            note_index   <= 5'd0;
            time_counter <= 32'd0;
            is_resting   <= 1'b0;
        end else begin
            if (time_counter >= cur_dur) begin
                time_counter <= 32'd0;
                note_index   <= (note_index < 5'd24) ? note_index + 1 : 5'd0;
                is_resting   <= 1'b0;
            end else begin
                time_counter <= time_counter + 1;
                // 20 ms silence gap at end of each note
                is_resting <= (time_counter > (cur_dur - 32'd2_000_000));
            end
        end
    end

    // ── Tone generator ────────────────────────────────────────────────────────
    reg [31:0] tone_cnt;
    reg        speaker;
    wire [31:0] duty_limit = cur_note >> 8; // ~0.4% duty cycle

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            speaker  <= 1'b0;
            tone_cnt <= 32'd0;
        end else if (is_resting || cur_note == REST || !playing) begin
            speaker  <= 1'b0;
            tone_cnt <= 32'd0;
        end else begin
            if (tone_cnt >= cur_note)
                tone_cnt <= 32'd0;
            else
                tone_cnt <= tone_cnt + 1;
            speaker <= (tone_cnt < duty_limit);
        end
    end

    assign audio_out = {speaker, speaker}; // stereo — both channels identical

endmodule
