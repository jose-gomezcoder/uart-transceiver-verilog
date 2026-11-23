`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_uart.v - Loopback testbench: uart_tx output wired straight into uart_rx.
// Sends a list of bytes and checks every one comes back unchanged, with no
// framing errors. Prints PASS or FAIL at the end.
// -----------------------------------------------------------------------------
module tb_uart;
    localparam integer CLK_FREQ  = 10_000_000;   // 10 MHz -> 100 ns period
    localparam integer BAUD_RATE = 1_000_000;    // 10 clocks per bit (fast sim)
    localparam integer NBYTES    = 8;

    reg clk = 1'b0;
    reg rst = 1'b1;
    always #50 clk = ~clk;

    reg  [7:0] tx_data  = 8'd0;
    reg        tx_start = 1'b0;
    wire       line, tx_busy;
    wire [7:0] rx_data;
    wire       rx_valid, rx_error;

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) dut_tx (
        .clk(clk), .rst(rst), .tx_data(tx_data), .tx_start(tx_start),
        .tx(line), .tx_busy(tx_busy)
    );

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) dut_rx (
        .clk(clk), .rst(rst), .rx(line),
        .rx_data(rx_data), .rx_valid(rx_valid), .rx_error(rx_error)
    );

    reg [7:0] vectors [0:NBYTES-1];
    integer i;
    integer received = 0;
    integer errors   = 0;

    // Scoreboard
    always @(posedge clk) begin
        if (rx_valid) begin
            if (rx_data !== vectors[received]) begin
                $display("FAIL: byte %0d expected 0x%02h, got 0x%02h",
                         received, vectors[received], rx_data);
                errors = errors + 1;
            end else begin
                $display("  ok: byte %0d = 0x%02h", received, rx_data);
            end
            received = received + 1;
        end
        if (rx_error) begin
            $display("FAIL: framing error");
            errors = errors + 1;
        end
    end

    initial begin
        $dumpfile("tb_uart.vcd");
        $dumpvars(0, tb_uart);

        vectors[0] = 8'h55; vectors[1] = 8'hAA; vectors[2] = 8'h00; vectors[3] = 8'hFF;
        vectors[4] = 8'h41; vectors[5] = 8'h0D; vectors[6] = 8'h80; vectors[7] = 8'h01;

        repeat (5) @(negedge clk);
        rst = 1'b0;

        for (i = 0; i < NBYTES; i = i + 1) begin
            @(negedge clk);
            while (tx_busy) @(negedge clk);
            tx_data  = vectors[i];
            tx_start = 1'b1;
            @(negedge clk);
            tx_start = 1'b0;
        end

        wait (received == NBYTES);
        repeat (20) @(negedge clk);

        if (errors == 0)
            $display("PASS: %0d bytes looped back correctly", NBYTES);
        else
            $display("FAIL: %0d error(s)", errors);
        $finish;
    end

    initial begin
        #5_000_000;
        $display("FAIL: timeout (received %0d of %0d bytes)", received, NBYTES);
        $finish;
    end
endmodule
