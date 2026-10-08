# UART SystemVerilog Controller

This repository contains a parameterizable UART (Universal Asynchronous Receiver-Transmitter) controller implemented in SystemVerilog. The design was synthesized and tested on the Tang Primer 25K FPGA, with LEDs connected via PMOD and serial communication routed through a USB-C dock to a Windows PC running PuTTY.

## Key Features

* **Configurable Parameters**: The baud rate, system clock frequency, and parity setting (0 for Even, 1 for Odd, 2 for None) are easily customized via parameters at the top level.


* **Robust Data Recovery**: The system utilizes a 16x oversampling approach, allowing the receiver to reliably sample the incoming data bit precisely at its midpoint.


* **Metastability Mitigation**: The receive line includes a 3-stage synchronizer to prevent metastability and accurately detect the falling edge of the start bit.


* **Error Detection**: The receiver identifies and flags both framing errors and parity errors during the transaction cycle.


* **Interactive Demonstration**: The top module automatically sends a 15-byte "Hello UART!" string, inclusive of carriage return and line feed, using a state machine and delay counters.


* **Hardware Interfacing**: Received ASCII characters ('1' through '8') are decoded to toggle the corresponding bits on an 8-bit LED register.



## Module Architecture

* **`uart_top`**: The main integration module that instantiates the baud generator, transmitter, and receiver. It includes a specialized state machine to iterate through the transmission string array and update LED registers based on incoming UART traffic.


* **`uart_tx`**: Drives asynchronous transmission through a 5-state machine (IDLE, START, DATA, PARITY, STOP). It actively calculates the parity bit dynamically based on the configuration parameter and incoming data.


* **`uart_rx`**: Manages asynchronous reception using synchronized inputs, a tick counter, and a bit counter. It extracts data payload, compares received parity, and raises `fe_flag` or `pe_flag` upon completion if discrepancies are found.


* **`baud_gen`**: Generates a continuous `baud_tick` strobe from the main system clock based on the `CLK_FREQUENCY / (BAUD_RATE * 16)` limit.


* **`uart_pkg`**: A central package containing module state enumerations, timing constants (defaulting to 50 MHz clock and 115200 baud), and a simulated reset task.



## Hardware Setup & Constraints

The physical implementation targets the Gowin GW5A-25 device on the Tang Primer 25K board.

* **Clock**: Driven by a 50 MHz input (`sys_clk`) on pin E2.


* **UART Routing**: The TX pin outputs on C3, and the RX pin receives on B3.


* **LED Display**: Output pins are mapped to an external PMOD via pins F5, G5, G7, G8, H8, H7, H5, and J5 using 3.3V LVCMOS I/O standard.


* **Reset**: An active-low reset signal is bound to pin H11 with a pull-down resistor. The top module additionally registers this input to create an internal synchronous reset (`rst_sync`, `rst_n`).
