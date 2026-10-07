module uart_top #(
    parameter BAUD_RATE = 115200,
    parameter CLK_FREQUENCY = 50_000_000,
    parameter PARITY = 2
) (
    input logic clk,
    input logic rstn,
    output logic tx_pin
);

logic rst_sync, rst_n;

logic baud_tick;
logic [7:0] tx_data;
logic tx_start, tx_busy;

localparam MSG_LEN = 13;
wire [MSG_LEN*8 - 1:0] msg = {"Hello UART!", 16'h0d0a}; // 16'h0d0a = CRLF
logic [$clog2(MSG_LEN):0] msg_i;
logic [$clog2(CLK_FREQUENCY):0] delay_i, led_i;
logic [3:0] msg_cnt;

enum logic [2:0] {
	IDLE, LOAD_BYTE, WAIT_BUSY, SENDING, INCREMENT, DELAY
} state, next_state;

always_ff @(posedge clk) begin
    rst_sync <= !rstn;
    rst_n <= rst_sync;
end

always_ff @(posedge clk)
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;

assign tx_start = state == WAIT_BUSY;
always_comb begin
    next_state = state;
    case (state)
        IDLE: if (msg_cnt < 10) next_state = LOAD_BYTE;
        LOAD_BYTE: next_state = WAIT_BUSY;
        WAIT_BUSY: if (tx_busy) next_state = SENDING;
        SENDING: if (!tx_busy) next_state = INCREMENT;
        INCREMENT: next_state = (msg_i == MSG_LEN - 1) ? DELAY : LOAD_BYTE;
        DELAY: if (delay_i == CLK_FREQUENCY - 1) next_state = IDLE;
    endcase
end

always_ff @(posedge clk)
    if (!rst_n) begin
        msg_i <= 0;
        delay_i <= 0;
        tx_data <= 0;
        msg_cnt <= 0;
    end else begin
        case (state)
            IDLE: begin
                msg_i <= 0;
                delay_i <= 0;
                tx_data <= 0; 
                if (msg_cnt < 10) msg_cnt <= msg_cnt + 1;
            end
            LOAD_BYTE: tx_data <= msg[(MSG_LEN - 1 - msg_i)*8 +: 8];
            INCREMENT: msg_i <= (msg_i == MSG_LEN - 1) ? 0 : msg_i + 1;
            DELAY: delay_i <= (delay_i == CLK_FREQUENCY - 1) ? 0 : delay_i + 1;
        endcase
    end

baud_gen #(
    .BAUD_RATE(BAUD_RATE),
    .CLK_FREQUENCY(CLK_FREQUENCY)
) u_baud_gen (.*, .rstn(rst_n));

uart_tx #(
    .PARITY(PARITY)
) u_uart_tx (.*, .rstn(rst_n));

endmodule