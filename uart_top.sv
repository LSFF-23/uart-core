module uart_top #(
    parameter BAUD_RATE = 115200,
    parameter CLK_FREQUENCY = 50_000_000,
    parameter PARITY = 2
) (
    input logic clk,
    input logic rstn,
    output logic tx_pin,
    input logic rx_pin,
    output logic [7:0] leds
);

localparam DELAY_CYCLES = CLK_FREQUENCY * 2;
localparam DELAY_TURNS = 10;

logic rst_sync, rst_n;

logic baud_tick;
logic [7:0] tx_data, rx_data;
logic tx_start, tx_busy, rx_done, frame_error, parity_error;

logic [7:0] leds_reg;
logic wb_flag, wb_requested;

localparam MSG_LEN = 15;
wire [MSG_LEN*8 - 1:0] msg = {16'h0d0a, "Hello UART!", 16'h0d0a}; // 16'h0d0a = CRLF
logic [$clog2(MSG_LEN):0] msg_i;
logic [$clog2(DELAY_CYCLES):0] delay_i;
logic [3:0] msg_cnt;

enum logic [2:0] {
	IDLE, LOAD_BYTE, WAIT_BUSY, SENDING, INCREMENT, REQUESTED, DELAY
} state, next_state;

always_ff @(posedge clk) begin
    rst_sync <= !rstn;
    rst_n <= rst_sync;
end

assign leds = ~leds_reg;
always_ff @(posedge clk)
    if (!rst_n) begin
        leds_reg <= 0;
        wb_flag <= 0;
    end else if (rx_done) begin
        wb_flag <= 1;
        case (rx_data)
            "1": leds_reg <= 8'b0000_0001;
            "2": leds_reg <= 8'b0000_0011;
            "3": leds_reg <= 8'b0000_0111;
            "4": leds_reg <= 8'b0000_1111;
            "5": leds_reg <= 8'b0001_1111;
            "6": leds_reg <= 8'b0011_1111;
            "7": leds_reg <= 8'b0111_1111;
            "8": leds_reg <= 8'b1111_1111;
            default: leds_reg <= 0;
        endcase
    end else if (wb_requested) begin
        wb_flag <= 0;
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
        IDLE: if (msg_cnt < DELAY_TURNS || wb_flag) next_state = LOAD_BYTE;
        LOAD_BYTE: next_state = WAIT_BUSY;
        WAIT_BUSY: if (tx_busy) next_state = SENDING;
        SENDING: if (!tx_busy) next_state = INCREMENT;
        INCREMENT: next_state = (wb_requested) ? REQUESTED : (msg_i == MSG_LEN - 1) ? DELAY : LOAD_BYTE;
        REQUESTED: next_state = DELAY;
        DELAY: if (delay_i == DELAY_CYCLES - 1 || wb_flag) next_state = IDLE;
    endcase
end

always_ff @(posedge clk)
    if (!rst_n) begin
        msg_i <= 0;
        delay_i <= 0;
        tx_data <= 0;
        msg_cnt <= 0;
        wb_requested <= 0;
    end else begin
        case (state)
            IDLE: begin
                msg_i <= 0;
                delay_i <= 0;
                tx_data <= 0;
                if (wb_flag) wb_requested <= 1;
                else if (msg_cnt < DELAY_TURNS) msg_cnt <= msg_cnt + 1;
            end
            LOAD_BYTE: tx_data <= (wb_requested) ? rx_data : msg[(MSG_LEN - 1 - msg_i)*8 +: 8];
            INCREMENT: if (!wb_requested) msg_i <= (msg_i == MSG_LEN - 1) ? 0 : msg_i + 1;
            REQUESTED: wb_requested <= 0;
            DELAY: delay_i <= (delay_i == DELAY_CYCLES) ? 0 : delay_i + 1;
        endcase
    end

baud_gen #(
    .BAUD_RATE(BAUD_RATE),
    .CLK_FREQUENCY(CLK_FREQUENCY)
) u_baud_gen (.*, .rstn(rst_n));

uart_tx #(
    .PARITY(PARITY)
) u_uart_tx (.*, .rstn(rst_n));

uart_rx #(
    .PARITY(PARITY)
) u_uart_rx (.*, .rstn(rst_n));

endmodule