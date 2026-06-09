module uart_rx (
    input logic clk,
    input logic rstn,
    input logic baud_tick,
    input logic rx_pin,
    output logic [7:0] rx_data,
    output logic rx_done,
    output logic frame_error
);

enum logic [2:0] {
    IDLE = 3'b000,
    START = 3'b001,
    DATA = 3'b010,
    STOP = 3'b011,
    ERROR = 3'b100,
    CLEANUP = 3'b101,
    DONE = 3'b111
} state, next_state;

always_ff @(posedge clk, negedge rstn) begin
    if (!rstn)
        state <= IDLE;
    else
        state <= next_state;
end

logic rx_sync1, rx_sync2, rx_sync3;
wire rx_falling = (rx_sync2 == 1'b0 && rx_sync3 == 1'b1);
always_ff @(posedge clk) begin
    if (!rstn) begin
        rx_sync1 <= 1'b1;
        rx_sync2 <= 1'b1;
        rx_sync3 <= 1'b1;
    end else begin
        rx_sync1 <= rx_pin;
        rx_sync2 <= rx_sync1;
        rx_sync3 <= rx_sync2;
    end
end

logic [3:0] tick_counter;
logic [2:0] bit_counter;
wire end_tick = tick_counter == 4'hf;
wire middle_tick = tick_counter == 4'h7;
wire end_bit = bit_counter == 3'h7;
always_comb begin
    next_state = state;
    case (state)
        IDLE: begin
            if (rx_falling)
                next_state = START;
        end
        START: begin
            if (baud_tick) begin
                if (middle_tick && rx_sync2 != 1'b0)
                    next_state = IDLE;
                if (end_tick)
                    next_state = DATA;
            end
        end
        DATA: begin
            if (baud_tick && end_tick && end_bit)
                next_state = STOP;
        end
        STOP: begin
            if (baud_tick) begin
                if (middle_tick && rx_sync2 != 1'b1)
                    next_state = CLEANUP;
                if (end_tick)
                    next_state = DONE;
            end
        end
        CLEANUP: if (baud_tick && end_tick) next_state = ERROR;
        DONE, ERROR: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

logic [7:0] data_reg;
always_ff @(posedge clk, negedge rstn) begin
    if (!rstn) begin
        tick_counter <= 4'b0;
        bit_counter <= 3'b0;
        data_reg <= 8'b0;
    end else begin
        case (state)
            IDLE: begin
                if (rx_falling) begin
                    tick_counter <= 4'b0;
                    bit_counter <= 3'b0;
                end
            end
            START, STOP, CLEANUP: begin
                if (baud_tick)
                    tick_counter <= tick_counter + 1'b1;
            end
            DATA: begin
                if (baud_tick) begin
                    tick_counter <= tick_counter + 1'b1;
                    if (middle_tick)
                        data_reg <= {rx_sync2, data_reg[7:1]};
                    if (end_tick)
                        bit_counter <= bit_counter + 1'b1;
                end
            end
        endcase
    end
end

assign rx_data = data_reg;
assign rx_done = (state == DONE);
assign frame_error = (state == ERROR);

endmodule