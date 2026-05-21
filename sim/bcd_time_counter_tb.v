// =============================================================================
// TESTBENCH : bcd_time_counter_tb.v
// PROJECT   : FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Verifies: second increment, minute rollover, hour rollover, load override.
// =============================================================================
`timescale 1ns/1ps

module bcd_time_counter_tb;

    reg        clk, rst, tick, load;
    reg  [5:0] load_hh, load_mm, load_ss;
    wire [5:0] hh, mm, ss;

    bcd_time_counter dut (
        .clk(clk), .rst(rst), .tick(tick), .load(load),
        .load_hh(load_hh), .load_mm(load_mm), .load_ss(load_ss),
        .hh(hh), .mm(mm), .ss(ss)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task send_tick;
        begin
            @(posedge clk); tick = 1;
            @(posedge clk); tick = 0;
        end
    endtask

    integer fail = 0;

    initial begin
        $display("=== bcd_time_counter testbench ===");
        rst = 1; tick = 0; load = 0;
        load_hh = 0; load_mm = 0; load_ss = 0;
        repeat(3) @(posedge clk);
        rst = 0;

        // ── Test 1: basic second increment ───────────────────────────────────
        send_tick;
        if (ss !== 6'd1) begin
            $display("FAIL T1: ss=%0d expected 1", ss); fail=fail+1;
        end else $display("PASS T1: ss increments to 1");

        // ── Test 2: load override ─────────────────────────────────────────────
        load_hh = 6'd7; load_mm = 6'd30; load_ss = 6'd55;
        @(posedge clk); load = 1;
        @(posedge clk); load = 0;
        if (hh !== 6'd7 || mm !== 6'd30 || ss !== 6'd55) begin
            $display("FAIL T2: load not applied. hh=%0d mm=%0d ss=%0d", hh, mm, ss); fail=fail+1;
        end else $display("PASS T2: load sets 07:30:55");

        // ── Test 3: second rollover 59 -> 00, mm increments ──────────────────
        // ss is now 55 — send 4 more ticks to reach 59, then 1 more
        repeat(4) send_tick;  // ss = 59
        send_tick;             // ss rolls to 00, mm = 31
        if (ss !== 6'd0 || mm !== 6'd31) begin
            $display("FAIL T3: rollover. ss=%0d mm=%0d", ss, mm); fail=fail+1;
        end else $display("PASS T3: ss rolls 59->00, mm increments to 31");

        // ── Test 4: load time 23:59:58 and verify midnight rollover ───────────
        load_hh = 6'd23; load_mm = 6'd59; load_ss = 6'd58;
        @(posedge clk); load = 1;
        @(posedge clk); load = 0;
        send_tick; // ss = 59
        send_tick; // ss = 00, mm = 00, hh should go to 00 (midnight)
        if (hh !== 6'd0 || mm !== 6'd0 || ss !== 6'd0) begin
            $display("FAIL T4: midnight rollover. hh=%0d mm=%0d ss=%0d", hh, mm, ss); fail=fail+1;
        end else $display("PASS T4: midnight rollover 23:59:59->00:00:00");

        if (fail == 0)
            $display("RESULT: ALL PASS");
        else
            $display("RESULT: FAIL — %0d errors", fail);
        $finish;
    end

    initial begin
        $dumpfile("bcd_time_counter_tb.vcd");
        $dumpvars(0, bcd_time_counter_tb);
    end

endmodule
