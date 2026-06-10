module baud_gen_tb;
timeunit 1ns;
timeprecision 1ns;

parameter int MAIN_CLOCK = 50_000_000; // in Hz
parameter int PERIOD = 1_000_000_000 / MAIN_CLOCK; // in ns
parameter int L_BAUD = 115200;
parameter int EXPECTED = MAIN_CLOCK / (16 * L_BAUD);

logic clk, rstn, baud_tick;

baud_gen #(
    .BAUD_RATE(L_BAUD),
    .CLK_FREQUENCY(MAIN_CLOCK)
) dut (.*);

task reset();
    $display("[%5t] Applying reset...", $time);
    rstn = 1;
    #1;
    rstn = 0;
    #1;
    rstn = 1;
    $display("[%5t] Reset applied.", $time);
endtask

initial clk = 0;
always #(PERIOD/2) clk = !clk;

integer clock_ticks = 0;
integer baud_ticks = 0;
always @(posedge clk)
    if (baud_tick) begin
        $display("[%5t] Detected Tick n° %02d | Clock Cycles Counted: %3d | Clock Cycles Expected: %3d", $time, baud_ticks + 1, clock_ticks + 1, EXPECTED);
        baud_ticks <= baud_ticks + 1;
        clock_ticks <= 0;
    end else
        clock_ticks = clock_ticks + 1;

initial begin
    reset();
    wait(baud_ticks == 10);
    repeat (5) @(posedge clk);
    $finish(0);
end

endmodule