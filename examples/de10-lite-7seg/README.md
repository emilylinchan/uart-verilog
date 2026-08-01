# UART IP Core on the DE10-Lite — Keyboard to 7-Segment Display

A demonstration of a custom UART IP core written in Verilog, running on a Terasic DE10-Lite FPGA (Intel MAX 10). Characters typed into a serial terminal on a PC are transmitted over UART to the FPGA, where they are decoded and their hexadecimal ASCII value is displayed in real time on the onboard 7-segment displays. The received byte is also echoed straight back to the terminal.

🎬 **[Watch the video demo](https://youtu.be/gm2INJvLMKM)**

## How It Works
```text
PC keyboard -> terminal -> serial cable -> i_uart_rx -> uart core
    -> latch byte on o_rx_valid -> split into two nibbles
    -> binary_to_7segment x2 -> segment pins
```

Typing a character sends its ASCII code over UART. For example, pressing `A` sends `0x41`, so the display reads `41` (upper digit = high nibble, lower digit = low nibble).

The design also includes an asynchronous reset (active-low push button) that is synchronized into the clock domain with a 2-flip-flop synchronizer before being used anywhere else in the design.

## Files

| File | Description |
| --- | --- |
| [uart_7seg.v](uart_7seg.v) | Top-level entity: instantiates the UART core and reset synchronizer, latches received bytes, and drives the two 7-segment decoders |
| [uart_7seg.qpf](uart_7seg.qpf) | Quartus project file |
| [uart_7seg.qsf](uart_7seg.qsf) | Quartus settings and pin assignments |

This example references the UART core (`uart.v`, `uart_tx.v`, `uart_rx.v`, `baud_gen.v`) which can be found under [`rtl/`](../../rtl).

## Hardware Setup

| Signal | DE10-Lite pin | Function |
| --- | --- | --- |
| `i_clk` | `PIN_P11` | 50 MHz onboard clock |
| `i_rst_n` | `PIN_B8` | `KEY0`, active-low reset |
| `i_uart_rx` | `PIN_V10` | UART RX (from PC) |
| `o_uart_tx` | `PIN_W10` | UART TX (to PC) |
| `o_segment1_*` | `PIN_C18`/`D18`/`E18`/`B16`/`A17`/`A18`/`B17` | Upper 7-segment digit (high nibble) |
| `o_segment2_*` | `PIN_C14`/`E15`/`C15`/`C16`/`E16`/`D17`/`C17` | Lower 7-segment digit (low nibble) |

`i_uart_rx`/`o_uart_tx` are wired to a GPIO header. The DE10-Lite has no onboard USB-UART bridge, so a USB-to-TTL serial adapter is needed to connect those pins to a PC (grounds tied together). This was built and tested with a [DTECH PL2303 USB to TTL serial cable](https://www.amazon.ca/dp/B08G1JTN4N) (3.3V logic, 4-pin TX/RX).

## Building and Running

1. Open `uart_7seg.qpf` in Quartus and run **Compile Design** to generate the programming file.
2. Program the DE10-Lite via **Tools > Programmer** (JTAG, `.sof` file).
3. Connect a USB-to-serial adapter as described above, and open a serial terminal on your PC at **115200 baud, 8 data bits, no parity, 1 stop bit**.
4. Type any character — its hex ASCII value should appear on the two 7-segment displays, and the same character should be echoed back in the terminal.

Default parameters (`CLK_FREQ = 50_000_000`, `BAUD_RATE = 115_200`) match the DE10-Lite's onboard clock; adjust the module parameters in `uart_7seg.v` if your baud rate or clock source differs.

## Reference

DE10-Lite User Manual: https://faculty-web.msoe.edu/johnsontimoj/Common/FILES/DE10_Lite_User_Manual.pdf
