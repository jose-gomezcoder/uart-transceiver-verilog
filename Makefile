SRC = rtl/uart_tx.v rtl/uart_rx.v
TB  = tb/tb_uart.v

.PHONY: sim wave clean

sim:
	iverilog -g2012 -Wall -o tb_uart.vvp $(TB) $(SRC)
	vvp tb_uart.vvp

wave: sim
	gtkwave tb_uart.vcd

clean:
	rm -f *.vvp *.vcd
