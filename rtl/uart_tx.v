`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// uart_tx.v - UART transmitter, 8 data bits, no parity, 1 stop bit (8N1)
//
// Pulse tx_start for one clock while tx_busy is low; tx_data is latched on
// that cycle. The line idles high. CLK_FREQ / BAUD_RATE must be >= 4.
// -----------------------------------------------------------------------------
module uart_tx #(
    parameter integer CLK_FREQ  = 100_000_000,
    parameter integer BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst,        // synchronous, active high
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx,
    output wire       tx_busy
);
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer CNT_W        = $clog2(CLKS_PER_BIT + 1);

    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    reg [1:0]       state;
    reg [CNT_W-1:0] clk_cnt;
    reg [2:0]       bit_idx;
    reg [7:0]       shreg;

    wire bit_done = (clk_cnt == CLKS_PER_BIT - 1);

    assign tx_busy = (state != S_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            tx      <= 1'b1;
            clk_cnt <= 0;
            bit_idx <= 3'd0;
            shreg   <= 8'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx      <= 1'b1;
                    clk_cnt <= 0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        shreg <= tx_data;
                        state <= S_START;
                    end
                end

                S_START: begin
                    tx <= 1'b0;
                    if (bit_done) begin
                        clk_cnt <= 0;
                        state   <= S_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_DATA: begin
                    tx <= shreg[0];                    // LSB first
                    if (bit_done) begin
                        clk_cnt <= 0;
                        shreg   <= {1'b0, shreg[7:1]};
                        if (bit_idx == 3'd7)
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_STOP: begin
                    tx <= 1'b1;
                    if (bit_done) begin
                        clk_cnt <= 0;
                        state   <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
            endcase
        end
    end
endmodule
