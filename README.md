# UART Transceiver in Verilog

A parameterized UART transmitter and receiver (8N1) written in synthesizable Verilog, with a self-checking loopback testbench and a Basys 3 top level that echoes everything you type in a serial terminal.

## Features

- **Configurable** clock frequency and baud rate through parameters (`CLK_FREQ`, `BAUD_RATE`)
- **Transmitter:** four-state FSM (idle, start, data, stop), LSB first, `tx_busy` handshake
- **Receiver:**
  - 2-flop input synchronizer with `ASYNC_REG` attributes
  - samples each bit at its centre
  - rejects start-bit glitches
  - flags framing errors (`rx_error`)
- **Echo top level** for the Digilent Basys 3: a one-byte buffer sits between RX and TX, and the last received byte is shown on the LEDs
- **Self-checking testbench:** TX is wired straight into RX, eight test bytes are sent (including `0x00`, `0xFF`, `0x55` and `0xAA`), and the testbench prints PASS or FAIL

## Repository layout

```
rtl/
  uart_tx.v          UART transmitter
  uart_rx.v          UART receiver
  uart_echo_top.v    Basys 3 top level (echo + LEDs)
tb/
  tb_uart.v          loopback testbench
constraints/
  basys3.xdc         pin constraints for Basys 3 (Artix-7)
Makefile             Icarus Verilog simulation
```

## Block diagram

```
          +-----------+   rx_data/rx_valid   +----------+   tx_start   +-----------+
 RsRx --->|  uart_rx  |--------------------->| 1-byte   |------------->|  uart_tx  |---> RsTx
          | (2FF sync)|                      |  buffer  |<-------------|           |
          +-----------+                      +----------+   tx_busy    +-----------+
                                                  |
                                                  +--> led[7:0]
```

## Simulate

You need [Icarus Verilog](https://steveicarus.github.io/iverilog/) (and optionally GTKWave to view the waveforms).

```bash
make sim     # compile and run the testbench
make wave    # open tb_uart.vcd in GTKWave
```

The testbench runs at 10 clocks per bit so it finishes quickly, and prints `PASS` or `FAIL` at the end.

## Run on a Basys 3

1. Create a Vivado project for part `xc7a35tcpg236-1`.
2. Add the files in `rtl/` as design sources and `constraints/basys3.xdc` as a constraint.
3. Set `uart_echo_top` as the top module, then generate the bitstream and program the board.
4. Open a serial terminal on the board's USB-UART port at **115200 baud, 8N1**. Characters you type echo back, and their ASCII code shows on the LEDs.
5. The centre button (`btnC`) resets the design.

## Interface

| Module    | Port                          | Description                                  |
|-----------|-------------------------------|----------------------------------------------|
| `uart_tx` | `tx_data[7:0]`, `tx_start`    | byte to send, one-cycle start pulse          |
|           | `tx`, `tx_busy`               | serial output, high while a frame is sent    |
| `uart_rx` | `rx`                          | serial input (asynchronous)                  |
|           | `rx_data[7:0]`, `rx_valid`    | received byte, one-cycle valid pulse         |
|           | `rx_error`                    | one-cycle pulse on a bad stop bit            |

`CLK_FREQ / BAUD_RATE` must be at least 4.
