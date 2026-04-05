module uart_tx (
    input clk,
    input rstn,
    input baud_tick,
    input tx_start,
    input [7:0] tx_data,
    output tx_pin,
    output tx_busy
);

localparam  IDLE = 2'b00,
            START = 2'b01,
            DATA = 2'b10,
            STOP = 2'b11;

reg [1:0] state, next_state;
always @(posedge clk, negedge rstn) begin
    if (!rstn)
        state <= IDLE;
    else
        state <= next_state;
end

reg [3:0] tick_counter;
reg [2:0] bit_counter;
wire end_tick = (tick_counter == 4'hf);
wire end_bit = (bit_counter == 3'h7);
always @* begin
    next_state = state;
    case (state)
        IDLE: if (tx_start) next_state = START;
        START: if (baud_tick && end_tick) next_state = DATA;
        DATA: if (baud_tick && end_tick && end_bit) next_state = STOP;
        STOP: if (baud_tick && end_tick) next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

reg [7:0] data_reg;
always @(posedge clk, negedge rstn) begin
    if (!rstn) begin
        tick_counter <= 4'b0;
        bit_counter <= 3'b0;
        data_reg <= 8'b0;
    end else begin
        case (state)
            IDLE: begin
                if (tx_start) begin
                    tick_counter <= 4'b0;
                    bit_counter <= 3'b0;
                    data_reg <= tx_data;
                end
            end
            START: begin
                if (baud_tick)
                    tick_counter <= tick_counter + 1'b1;
            end
            DATA: begin
                if (baud_tick) begin
                    tick_counter <= tick_counter + 1'b1;
                    if (end_tick)
                        bit_counter <= bit_counter + 1'b1;
                end
            end
            STOP: begin
                if (baud_tick)
                    tick_counter <= tick_counter + 1'b1;
            end
        endcase
    end
end

wire is_idle = (state == IDLE);
wire is_stop = (state == STOP);
wire data_high = ((state == DATA) && (data_reg[bit_counter]));
assign tx_busy = (state != IDLE);
assign tx_pin =  is_idle || is_stop || data_high;

endmodule