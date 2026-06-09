module uart_top #(
    parameter BAUD_RATE = 9600,
    parameter CLK_FREQUENCY = 50_000_000
) (
    input logic clk,
    input logic rstn,
    input logic rx_pin,
    input logic tx_start,
    input logic [7:0] tx_data,
    output logic tx_pin,
    output logic [7:0] rx_data,
    output logic rx_done,
    output logic frame_error,
    output logic tx_busy
);

logic baud_tick;

baud_gen #(
    .BAUD_RATE(BAUD_RATE),
    .CLK_FREQUENCY(CLK_FREQUENCY)
) u_baud_gen (
    .clk(clk),
    .rstn(rstn),
    .baud_tick(baud_tick)
);

uart_rx u_uart_rx (
    .clk(clk),
    .rstn(rstn),
    .baud_tick(baud_tick),
    .rx_pin(rx_pin),
    .rx_data(rx_data),
    .rx_done(rx_done),
    .frame_error(frame_error)
);

uart_tx u_uart_tx (
    .clk(clk),
    .rstn(rstn),
    .baud_tick(baud_tick),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .tx_pin(tx_pin),
    .tx_busy(tx_busy)
);

endmodule