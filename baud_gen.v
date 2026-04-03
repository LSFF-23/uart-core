module baud_gen #(
    parameter BAUD_RATE = 9600,
    parameter CLK_FREQUENCY = 50_000_000
) 
(
    input clk,
    input rstn,
    output baud_tick
);

localparam BAUD_LIMIT = CLK_FREQUENCY / (BAUD_RATE * 16);
localparam COUNTER_SIZE = $clog2(BAUD_LIMIT);

reg [COUNTER_SIZE - 1:0] baud_counter;
wire comparator = (baud_counter == (BAUD_LIMIT - 1));
assign baud_tick = comparator;

always @(posedge clk, negedge rstn) begin
    if (!rstn)
        baud_counter <= {COUNTER_SIZE{1'b0}};
    else begin
        if (comparator) 
            baud_counter <= {COUNTER_SIZE{1'b0}};
        else
            baud_counter <= baud_counter + 1'b1;
    end
end

endmodule