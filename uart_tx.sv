module uart_tx # (
    parameter PARITY = 2 // 0 = EVEN, 1 = ODD, 2 = NONE
) (
    input logic clk,
    input logic rstn,
    input logic baud_tick,
    input logic tx_start,
    input logic [7:0] tx_data,
    output logic tx_pin,
    output logic tx_busy
);

import uart_pkg::*;

tx_states state, next_state;

always_ff @(posedge clk, negedge rstn) begin
    if (!rstn)
        state <= TX_IDLE;
    else
        state <= next_state;
end

logic [3:0] tick_counter;
logic [2:0] bit_counter;
wire end_tick = (tick_counter == 4'hf);
wire end_bit = (bit_counter == 3'h7);
always_comb begin
    next_state = state;
    case (state)
        TX_IDLE: if (tx_start) next_state = TX_START;
        TX_START: if (baud_tick && end_tick) next_state = TX_DATA;
        TX_DATA: if (baud_tick && end_tick && end_bit) next_state = (PARITY inside {[0:1]}) ? TX_PARITY : TX_STOP;
        TX_PARITY: if (baud_tick && end_tick) next_state = TX_STOP;
        TX_STOP: if (baud_tick && end_tick) next_state = TX_IDLE;
        default: next_state = TX_IDLE;
    endcase
end

logic [7:0] data_reg;
logic parity_bit;
generate
    if (PARITY inside {[0:1]}) begin: SOME_PARITY
        assign parity_bit = ^data_reg ^ PARITY[0];
    end else begin: NO_PARITY
        assign parity_bit = 0;
    end
endgenerate

always_ff @(posedge clk, negedge rstn) begin
    if (!rstn) begin
        tick_counter <= 4'b0;
        bit_counter <= 3'b0;
        data_reg <= 8'b0;
    end else begin
        case (state)
            TX_IDLE: begin
                if (tx_start) begin
                    tick_counter <= 4'b0;
                    bit_counter <= 3'b0;
                    data_reg <= tx_data;
                end
            end
            TX_START, TX_PARITY, TX_STOP: begin
                if (baud_tick)
                    tick_counter <= tick_counter + 1'b1;
            end
            TX_DATA: begin
                if (baud_tick) begin
                    tick_counter <= tick_counter + 1'b1;
                    if (end_tick)
                        bit_counter <= bit_counter + 1'b1;
                end
            end
        endcase
    end
end

wire is_idle = (state == TX_IDLE);
wire is_stop = (state == TX_STOP);
wire data_high = ((state == TX_DATA) && (data_reg[bit_counter]));
wire parity_high = ((state == TX_PARITY) && parity_bit);
assign tx_busy = (state != TX_IDLE);
assign tx_pin =  is_idle || is_stop || data_high || parity_high;

endmodule