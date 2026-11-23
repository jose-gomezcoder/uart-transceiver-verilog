`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// uart_rx.v - UART receiver, 8N1
//
// The asynchronous rx input goes through a 2-flop synchronizer. After a
// falling edge the receiver waits half a bit, re-checks the start bit (to
// reject glitches), then samples each data bit and the stop bit at its centre.
// rx_valid pulses for one clock with the received byte on rx_data.
// rx_error pulses for one clock if the stop bit is not high (framing error).
// CLK_FREQ / BAUD_RATE must be >= 4.
// -----------------------------------------------------------------------------
module uart_rx #(
    parameter integer CLK_FREQ  = 100_000_000,
    parameter integer BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst,        // synchronous, active high
    input  wire       rx,
    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        rx_error
);
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;
    localparam integer CNT_W        = $clog2(CLKS_PER_BIT + 1);

    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    // 2-flop synchronizer (idle level is high)
    (* ASYNC_REG = "TRUE" *) reg rx_meta;
    (* ASYNC_REG = "TRUE" *) reg rx_sync;

    always @(posedge clk) begin
        if (rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    reg [1:0]       state;
    reg [CNT_W-1:0] clk_cnt;
    reg [2:0]       bit_idx;
    reg [7:0]       shreg;

    always @(posedge clk) begin
        if (rst) begin
            state    <= S_IDLE;
            clk_cnt  <= 0;
            bit_idx  <= 3'd0;
            shreg    <= 8'd0;
            rx_data  <= 8'd0;
            rx_valid <= 1'b0;
            rx_error <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            rx_error <= 1'b0;

            case (state)
                S_IDLE: begin
                    clk_cnt <= 0;
                    bit_idx <= 3'd0;
                    if (!rx_sync)
                        state <= S_START;
                end

                S_START: begin
                    if (clk_cnt == HALF_BIT - 1) begin
                        clk_cnt <= 0;
                        state   <= rx_sync ? S_IDLE : S_DATA;  // glitch -> back to idle
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        shreg   <= {rx_sync, shreg[7:1]};      // LSB first
                        if (bit_idx == 3'd7)
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        state   <= S_IDLE;
                        if (rx_sync) begin
                            rx_data  <= shreg;
                            rx_valid <= 1'b1;
                        end else begin
                            rx_error <= 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
            endcase
        end
    end
endmodule
