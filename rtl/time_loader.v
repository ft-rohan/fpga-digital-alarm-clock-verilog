// =============================================================================
// MODULE : time_loader
// PROJECT: FPGA Digital Alarm Clock with Stopwatch
// -----------------------------------------------------------------------------
// Parses incoming UART bytes and generates a load pulse for bcd_time_counter.
//
// Packet format (4 bytes): [ 0xFF | HH | MM | SS ]
//   0xFF — header/sync byte
//   HH   — hours   (0-23)
//   MM   — minutes (0-59)
//   SS   — seconds (0-59)
//
// On receiving a complete valid packet:
//   - load_hh, load_mm, load_ss are updated
//   - load_time is pulsed HIGH for exactly one clock cycle
//   - bcd_time_counter immediately loads the new time
//
// If any byte other than 0xFF is seen in WAIT_HDR state, it is ignored.
// This ensures resync on partial or corrupted packets.
// =============================================================================
`timescale 1ns/1ps

module time_loader (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data_in,      // from uart rx_data_out
    input  wire       data_valid,   // from uart rx_data_valid (one-cycle pulse)
    output reg  [5:0] load_hh,
    output reg  [5:0] load_mm,
    output reg  [5:0] load_ss,
    output reg        load_time     // one-cycle pulse — connects to bcd_time_counter
);

    localparam WAIT_HDR = 2'd0;
    localparam RECV_HH  = 2'd1;
    localparam RECV_MM  = 2'd2;
    localparam RECV_SS  = 2'd3;

    reg [1:0] state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= WAIT_HDR;
            load_hh   <= 6'd0;
            load_mm   <= 6'd0;
            load_ss   <= 6'd0;
            load_time <= 1'b0;
        end else begin
            load_time <= 1'b0;  // default deassert every cycle

            if (data_valid) begin
                case (state)
                    WAIT_HDR: begin
                        if (data_in == 8'hFF)
                            state <= RECV_HH;
                        // else: ignore — wait for next sync byte
                    end

                    RECV_HH: begin
                        load_hh <= data_in[5:0];
                        state   <= RECV_MM;
                    end

                    RECV_MM: begin
                        load_mm <= data_in[5:0];
                        state   <= RECV_SS;
                    end

                    RECV_SS: begin
                        load_ss   <= data_in[5:0];
                        load_time <= 1'b1;      // pulse load for one cycle
                        state     <= WAIT_HDR;  // ready for next packet
                    end

                    default: state <= WAIT_HDR;
                endcase
            end
        end
    end

endmodule
