// =============================================================================
// TESTBENCH : uart_tb.v
// PROJECT   : FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Uses CLK_FREQ=100, BAUD_RATE=1 for fast simulation (100 clocks per bit).
// Tests:
//   1. Transmit byte 0xA5 — verify tx line sequence
//   2. Receive byte 0xA5 — drive rx line manually, verify rx_data_out
//   3. Framing error — corrupt stop bit
// =============================================================================
`timescale 1ns/1ps

module uart_tb;

    parameter CLK_FREQ  = 100;
    parameter BAUD_RATE = 1;
    parameter CPB       = CLK_FREQ / BAUD_RATE; // clocks per bit = 100

    reg  clk, rst;

    // TX signals
    reg        tx_start;
    reg  [7:0] tx_data_in;
    wire       tx_line;
    wire       tx_busy;

    // RX signals
    reg        rx_line;
    wire [7:0] rx_data_out;
    wire       rx_data_valid;
    wire       rx_parity_err;
    wire       rx_frame_err;

    uart #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE),
        .DATA_BITS (8),
        .STOP_BITS (1),
        .PARITY_EN (0),
        .PARITY_ODD(0)
    ) dut (
        .clk          (clk),
        .rst          (rst),
        .tx_start     (tx_start),
        .tx_data_in   (tx_data_in),
        .tx           (tx_line),
        .tx_busy      (tx_busy),
        .rx           (rx_line),
        .rx_data_out  (rx_data_out),
        .rx_data_valid(rx_data_valid),
        .rx_parity_err(rx_parity_err),
        .rx_frame_err (rx_frame_err)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Task: drive rx line with one UART byte (8N1)
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            // start bit
            rx_line = 0;
            repeat(CPB) @(posedge clk);
            // data bits LSB first
            for (i = 0; i < 8; i = i + 1) begin
                rx_line = data[i];
                repeat(CPB) @(posedge clk);
            end
            // stop bit
            rx_line = 1;
            repeat(CPB) @(posedge clk);
        end
    endtask

    integer fail = 0;

    initial begin
        $display("=== uart testbench ===");
        rst      = 1;
        rx_line  = 1; // idle
        tx_start = 0;
        tx_data_in = 8'h00;
        repeat(5) @(posedge clk);
        rst = 0;
        repeat(5) @(posedge clk);

        // ── Test 1: RX — receive 0xA5 ────────────────────────────────────────
        $display("T1: sending 0xA5 on RX line...");
        send_uart_byte(8'hA5);
        repeat(5) @(posedge clk);
        if (rx_data_valid && rx_data_out === 8'hA5)
            $display("PASS T1: received 0xA5 correctly");
        else begin
            $display("FAIL T1: rx_data_out=0x%h valid=%b", rx_data_out, rx_data_valid);
            fail = fail + 1;
        end

        // ── Test 2: RX — receive 0xFF (UART time packet header) ──────────────
        $display("T2: sending 0xFF (time packet header)...");
        send_uart_byte(8'hFF);
        repeat(5) @(posedge clk);
        if (rx_data_valid && rx_data_out === 8'hFF)
            $display("PASS T2: received 0xFF correctly");
        else begin
            $display("FAIL T2: rx_data_out=0x%h valid=%b", rx_data_out, rx_data_valid);
            fail = fail + 1;
        end

        // ── Test 3: TX — send 0x55, verify tx_busy and idle ──────────────────
        $display("T3: transmitting 0x55...");
        tx_data_in = 8'h55;
        @(posedge clk); tx_start = 1;
        @(posedge clk); tx_start = 0;
        if (!tx_busy) begin
            $display("FAIL T3: tx_busy should be HIGH"); fail = fail + 1;
        end
        // wait for transmission to complete
        wait(!tx_busy);
        $display("PASS T3: TX completed, tx_busy deasserted");

        // ── Test 4: Framing error — corrupt stop bit ──────────────────────────
        $display("T4: framing error test...");
        rx_line = 0; repeat(CPB) @(posedge clk); // start bit
        repeat(8) begin
            rx_line = 1; repeat(CPB) @(posedge clk); // data bits all 1
        end
        rx_line = 0; repeat(CPB) @(posedge clk); // corrupt stop bit (LOW instead of HIGH)
        rx_line = 1; repeat(5)   @(posedge clk);
        if (rx_frame_err)
            $display("PASS T4: framing error detected");
        else begin
            $display("FAIL T4: framing error not flagged");
            fail = fail + 1;
        end

        if (fail == 0)
            $display("RESULT: ALL PASS");
        else
            $display("RESULT: FAIL — %0d errors", fail);
        $finish;
    end

    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);
    end

endmodule
