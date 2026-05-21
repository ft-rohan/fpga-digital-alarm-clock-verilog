// =============================================================================
// MODULE : uart
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Universal UART — Transmitter + Receiver in one module.
// Fully parameterised: CLK_FREQ, BAUD_RATE, DATA_BITS, STOP_BITS, PARITY.
// Synthesisable — no initial blocks, all registered logic.
//
// TX usage:
//   Assert tx_start HIGH for exactly one clock cycle with data on tx_data_in.
//   Wait for tx_busy to go LOW before sending next byte.
//
// RX usage:
//   Monitor rx_data_valid — pulses HIGH for one cycle when a byte is received.
//   Read rx_data_out on the same cycle as rx_data_valid.
//   Check rx_frame_err and rx_parity_err for error detection.
//
// Packet protocol for time sync: [0xFF, HH, MM, SS]
// Parsed by time_loader module.
// =============================================================================
`timescale 1ns/1ps

module uart #(
    parameter CLK_FREQ   = 100_000_000,
    parameter BAUD_RATE  = 9600,
    parameter DATA_BITS  = 8,
    parameter STOP_BITS  = 1,       // 1 or 2
    parameter PARITY_EN  = 0,       // 0 = none, 1 = enabled
    parameter PARITY_ODD = 0        // 0 = even parity, 1 = odd parity
)(
    input  wire                  clk,
    input  wire                  rst,

    // ── TX ────────────────────────────────────────────────────────────────────
    input  wire                  tx_start,       // pulse HIGH one cycle to send
    input  wire [DATA_BITS-1:0]  tx_data_in,     // byte to transmit
    output wire                  tx,             // serial TX line (idle HIGH)
    output wire                  tx_busy,        // HIGH while transmitting

    // ── RX ────────────────────────────────────────────────────────────────────
    input  wire                  rx,             // serial RX line
    output wire [DATA_BITS-1:0]  rx_data_out,    // received byte
    output wire                  rx_data_valid,  // one-cycle pulse — byte ready
    output wire                  rx_parity_err,  // parity mismatch
    output wire                  rx_frame_err    // stop bit framing error
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // =========================================================================
    // TRANSMITTER
    // =========================================================================
    localparam TX_IDLE   = 3'd0;
    localparam TX_START  = 3'd1;
    localparam TX_DATA   = 3'd2;
    localparam TX_PARITY = 3'd3;
    localparam TX_STOP   = 3'd4;

    reg [2:0]                       tx_state;
    reg [DATA_BITS-1:0]             tx_shift;
    reg [$clog2(CLKS_PER_BIT+1)-1:0] tx_clk_cnt;
    reg [$clog2(DATA_BITS)-1:0]     tx_bit_idx;
    reg                             tx_reg;
    reg                             tx_busy_reg;
    reg                             tx_parity_bit;

    assign tx      = tx_reg;
    assign tx_busy = tx_busy_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_state      <= TX_IDLE;
            tx_reg        <= 1'b1;
            tx_busy_reg   <= 1'b0;
            tx_clk_cnt    <= 0;
            tx_bit_idx    <= 0;
            tx_shift      <= 0;
            tx_parity_bit <= 1'b0;
        end else begin
            case (tx_state)

                TX_IDLE: begin
                    tx_reg      <= 1'b1;        // idle line HIGH
                    tx_busy_reg <= 1'b0;
                    tx_clk_cnt  <= 0;
                    tx_bit_idx  <= 0;
                    if (tx_start && !tx_busy_reg) begin
                        tx_shift      <= tx_data_in;
                        tx_busy_reg   <= 1'b1;
                        tx_parity_bit <= PARITY_ODD ? ~^tx_data_in : ^tx_data_in;
                        tx_state      <= TX_START;
                    end
                end

                TX_START: begin
                    tx_reg <= 1'b0;             // start bit LOW
                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= 0;
                        tx_bit_idx <= 0;
                        tx_state   <= TX_DATA;
                    end else tx_clk_cnt <= tx_clk_cnt + 1;
                end

                TX_DATA: begin
                    tx_reg <= tx_shift[tx_bit_idx]; // LSB first
                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= 0;
                        if (tx_bit_idx == DATA_BITS - 1)
                            tx_state <= PARITY_EN ? TX_PARITY : TX_STOP;
                        else
                            tx_bit_idx <= tx_bit_idx + 1;
                    end else tx_clk_cnt <= tx_clk_cnt + 1;
                end

                TX_PARITY: begin
                    tx_reg <= tx_parity_bit;
                    if (tx_clk_cnt == CLKS_PER_BIT - 1) begin
                        tx_clk_cnt <= 0;
                        tx_state   <= TX_STOP;
                    end else tx_clk_cnt <= tx_clk_cnt + 1;
                end

                TX_STOP: begin
                    tx_reg <= 1'b1;             // stop bit(s) HIGH
                    if (tx_clk_cnt == (CLKS_PER_BIT * STOP_BITS) - 1) begin
                        tx_clk_cnt  <= 0;
                        tx_busy_reg <= 1'b0;
                        tx_state    <= TX_IDLE;
                    end else tx_clk_cnt <= tx_clk_cnt + 1;
                end

                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    // =========================================================================
    // RECEIVER
    // =========================================================================
    localparam RX_IDLE   = 3'd0;
    localparam RX_START  = 3'd1;
    localparam RX_DATA   = 3'd2;
    localparam RX_PARITY = 3'd3;
    localparam RX_STOP   = 3'd4;

    // ── Double-flop synchroniser (eliminates metastability on async RX line) ──
    reg rx_sync1, rx_sync2;
    always @(posedge clk or posedge rst) begin
        if (rst) begin rx_sync1 <= 1'b1; rx_sync2 <= 1'b1; end
        else     begin rx_sync1 <= rx;   rx_sync2 <= rx_sync1; end
    end

    reg [2:0]                       rx_state;
    reg [DATA_BITS-1:0]             rx_shift;
    reg [DATA_BITS-1:0]             rx_data_reg;
    reg [$clog2(CLKS_PER_BIT+1)-1:0] rx_clk_cnt;
    reg [$clog2(DATA_BITS)-1:0]     rx_bit_idx;
    reg                             rx_valid_reg;
    reg                             rx_parity_reg;
    reg                             rx_frame_reg;
    reg                             rx_parity_calc;

    assign rx_data_out   = rx_data_reg;
    assign rx_data_valid = rx_valid_reg;
    assign rx_parity_err = rx_parity_reg;
    assign rx_frame_err  = rx_frame_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_state       <= RX_IDLE;
            rx_shift       <= 0;
            rx_data_reg    <= 0;
            rx_clk_cnt     <= 0;
            rx_bit_idx     <= 0;
            rx_valid_reg   <= 1'b0;
            rx_parity_reg  <= 1'b0;
            rx_frame_reg   <= 1'b0;
            rx_parity_calc <= 1'b0;
        end else begin
            // default — deassert single-cycle signals
            rx_valid_reg  <= 1'b0;
            rx_parity_reg <= 1'b0;
            rx_frame_reg  <= 1'b0;

            case (rx_state)

                RX_IDLE: begin
                    rx_clk_cnt <= 0;
                    rx_bit_idx <= 0;
                    if (rx_sync2 == 1'b0)       // falling edge = start bit
                        rx_state <= RX_START;
                end

                RX_START: begin
                    // wait to mid-point of start bit before sampling
                    if (rx_clk_cnt == CLKS_PER_BIT/2 - 1) begin
                        rx_clk_cnt     <= 0;
                        rx_parity_calc <= 1'b0;
                        rx_state       <= RX_DATA;
                    end else rx_clk_cnt <= rx_clk_cnt + 1;
                end

                RX_DATA: begin
                    if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
                        rx_clk_cnt              <= 0;
                        rx_shift[rx_bit_idx]    <= rx_sync2;   // mid-bit sample
                        rx_parity_calc          <= rx_parity_calc ^ rx_sync2;
                        if (rx_bit_idx == DATA_BITS - 1)
                            rx_state <= PARITY_EN ? RX_PARITY : RX_STOP;
                        else
                            rx_bit_idx <= rx_bit_idx + 1;
                    end else rx_clk_cnt <= rx_clk_cnt + 1;
                end

                RX_PARITY: begin
                    if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
                        rx_clk_cnt <= 0;
                        rx_parity_reg <= PARITY_ODD
                            ? ~(rx_parity_calc ^ rx_sync2)
                            :  (rx_parity_calc ^ rx_sync2);
                        rx_state <= RX_STOP;
                    end else rx_clk_cnt <= rx_clk_cnt + 1;
                end

                RX_STOP: begin
                    if (rx_clk_cnt == CLKS_PER_BIT - 1) begin
                        rx_clk_cnt <= 0;
                        if (rx_sync2 == 1'b1) begin     // valid stop bit
                            rx_data_reg  <= rx_shift;
                            rx_valid_reg <= 1'b1;
                        end else begin
                            rx_frame_reg <= 1'b1;       // framing error
                        end
                        rx_state <= RX_IDLE;
                    end else rx_clk_cnt <= rx_clk_cnt + 1;
                end

                default: rx_state <= RX_IDLE;
            endcase
        end
    end

endmodule
