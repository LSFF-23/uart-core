module uart_top #(
    parameter BAUD_RATE = 9600,
    parameter CLK_FREQUENCY = 50_000_000
) (
    input logic clk,
    input logic rstn,
    input logic tx_start,
    input logic [7:0] tx_data,
    output logic tx_pin,
    output logic tx_busy,
    input logic rx_pin,
    output logic [7:0] rx_data,
    output logic rx_done,
    output logic frame_error
);

logic baud_tick;

baud_gen #(
    .BAUD_RATE(BAUD_RATE),
    .CLK_FREQUENCY(CLK_FREQUENCY)
) u_baud_gen (.*);

uart_rx u_uart_rx (.*);

uart_tx u_uart_tx (.*);

endmodule