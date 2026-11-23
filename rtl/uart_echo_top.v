`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// uart_echo_top.v - Board top level (Digilent Basys 3)
//
// Every byte received on RsRx is sent back on RsTx, and the last received byte
// is shown on led[7:0]. btnC is the reset. Open a serial terminal at
// 115200 8N1 on the board's USB-UART port and type: characters echo back.
// -----------------------------------------------------------------------------
module uart_echo_top #(
    parameter integer CLK_FREQ  = 100_000_000,
    parameter integer BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       btnC,
    input  wire       RsRx,
    output wire       RsTx,
    output reg  [7:0] led
);
    wire       rst = btnC;

    wire [7:0] rx_data;
    wire       rx_valid;
    wire       rx_error;
    wire       tx_busy;

    reg  [7:0] pend_data;
    reg        pend_valid;
    reg        tx_start;

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_rx (
        .clk(clk), .rst(rst), .rx(RsRx),
        .rx_data(rx_data), .rx_valid(rx_valid), .rx_error(rx_error)
    );

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_tx (
        .clk(clk), .rst(rst), .tx_data(pend_data), .tx_start(tx_start),
        .tx(RsTx), .tx_busy(tx_busy)
    );

    // One-byte holding register between the receiver and the transmitter
    always @(posedge clk) begin
        if (rst) begin
            pend_data  <= 8'd0;
            pend_valid <= 1'b0;
            tx_start   <= 1'b0;
            led        <= 8'd0;
        end else begin
            tx_start <= 1'b0;
            if (rx_valid) begin
                pend_data  <= rx_data;
                pend_valid <= 1'b1;
                led        <= rx_data;
            end else if (pend_valid && !tx_busy && !tx_start) begin
                tx_start   <= 1'b1;
                pend_valid <= 1'b0;
            end
        end
    end
endmodule
