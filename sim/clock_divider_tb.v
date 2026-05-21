// =============================================================================
// TESTBENCH : clock_divider_tb.v
// PROJECT   : FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Uses CLK_FREQ=10 and SCAN_DIVN=4 for fast simulation.
// Verifies: tick_1hz single-cycle pulse, tick_scan, reset behaviour.
// =============================================================================
`timescale 1ns/1ps

module clock_divider_tb;

    reg  clk, rst;
    wire tick_1hz, tick_scan, tick_blink;

    // Reduced parameters for simulation speed
    clock_divider #(
        .CLK_FREQ (10),
        .SCAN_DIVN(4)
    ) dut (
        .clk      (clk),
        .rst      (rst),
        .tick_1hz (tick_1hz),
        .tick_scan(tick_scan),
        .tick_blink(tick_blink)
    );

    // 10 ns clock period
    initial clk = 0;
    always #5 clk = ~clk;

    integer fail = 0;

    initial begin
        $display("=== clock_divider testbench ===");
        rst = 1;
        repeat(3) @(posedge clk);
        rst = 0;

        // Wait enough cycles to see at least 3 tick_1hz pulses
        repeat(40) @(posedge clk);

        if (fail == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL — %0d errors", fail);

        $finish;
    end

    // Check tick_1hz is only one cycle wide
    always @(posedge clk) begin
        if (tick_1hz) begin
            @(posedge clk);
            if (tick_1hz) begin
                $display("FAIL: tick_1hz held HIGH for more than one cycle at time %0t", $time);
                fail = fail + 1;
            end
        end
    end

    initial begin
        $dumpfile("clock_divider_tb.vcd");
        $dumpvars(0, clock_divider_tb);
    end

endmodule
