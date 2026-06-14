module uart_rx # (
    parameter PARITY = 2 // 0 = EVEN, 1 = ODD, 2 = NONE
) (
    input logic clk,
    input logic rstn,
    input logic baud_tick,
    input logic rx_pin,
    output logic [7:0] rx_data,
    output logic rx_done,
    output logic frame_error,
    output logic parity_error
);

import uart_pkg::*;

rx_states state, next_state;
always_ff @(posedge clk, negedge rstn) begin
    if (!rstn)
        state <= RX_IDLE;
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
        RX_IDLE:  if (rx_falling) next_state = RX_START;
        RX_START: if (baud_tick && middle_tick && rx_sync2 != 1'b0) next_state = RX_IDLE;
                  else if (baud_tick && end_tick) next_state = RX_DATA;
        RX_DATA: if (baud_tick && end_tick && end_bit) next_state = (PARITY inside {[0:1]}) ? RX_PARITY : RX_STOP;
        RX_PARITY: if (baud_tick && end_tick) next_state = RX_STOP;
        RX_STOP: if (baud_tick && end_tick) next_state = RX_DONE;
        RX_DONE: next_state = RX_IDLE;
        default: next_state = RX_IDLE;
    endcase
end

logic [7:0] data_reg;
logic parity_bit;
generate
    if (PARITY inside {[0:1]}) begin: SOME_PARITY
        assign parity_bit = (^data_reg ^ PARITY[0]);
    end else begin: NO_PARITY
        assign parity_bit = 0;
    end
endgenerate

logic pe_flag, fe_flag;
always_ff @(posedge clk, negedge rstn) begin
    if (!rstn) begin
        tick_counter <= '0;
        bit_counter <= '0;
        data_reg <= '0;
        pe_flag <= 0;
        fe_flag <= 0;
    end else begin
        case (state)
            RX_IDLE: begin
                if (rx_falling) begin
                    tick_counter <= '0;
                    bit_counter <= '0;
                    pe_flag <= 0;
                    fe_flag <= 0;
                end
            end
            RX_START: if (baud_tick) tick_counter <= tick_counter + 1'b1;
            RX_DATA: begin
                if (baud_tick) begin
                    tick_counter <= tick_counter + 1'b1;
                    if (middle_tick) data_reg <= {rx_sync2, data_reg[7:1]};
                    else if (end_tick) bit_counter <= bit_counter + 1'b1;
                end
            end
            RX_PARITY: begin
                if (baud_tick) begin
                    tick_counter <= tick_counter + 1'b1;
                    if (middle_tick) pe_flag <= rx_sync2 != parity_bit;
                end
            end
            RX_STOP: begin
                if (baud_tick) begin
                    tick_counter <= tick_counter + 1'b1;
                    if (middle_tick) fe_flag <= rx_sync2 != 1;
                end
            end
        endcase
    end
end

assign rx_data = data_reg;
assign rx_done = state == RX_DONE;
assign frame_error = state == RX_DONE && fe_flag;
assign parity_error = state == RX_DONE && pe_flag;

endmodule