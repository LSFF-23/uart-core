module uart_tx_tb;
timeunit 1ns;
timeprecision 1ns;

parameter int MAIN_CLOCK = 50_000_000; // in Hz
parameter int PERIOD = 1_000_000_000 / MAIN_CLOCK; // in ns
parameter int L_BAUD = 115200;
parameter int BAUD = MAIN_CLOCK / (L_BAUD * 16);
parameter int TIMEOUT = 800 * BAUD; // 1 full byte sent = 160 bauds

logic clk;
logic rstn;
logic baud_tick;
logic tx_start;
logic [7:0] tx_data;
logic tx_value;
logic tx_busy;

logic test_passed;
logic seize_tx, seize_value;
wire tx_pin = (seize_tx) ? seize_value : tx_value;

event start_cycle, stop_cycle;
int pass_count;

baud_gen #(
    .BAUD_RATE(L_BAUD),
    .CLK_FREQUENCY(MAIN_CLOCK)
) u_baud_gen (.*);

uart_tx dut (.*, .tx_pin(tx_value));

initial clk = 0;
always #(PERIOD/2) clk = !clk;

task reset();
    $display("[%10t] Applying reset...", $time);
    rstn = 1;
    #1;
    rstn = 0;
    #1;
    rstn = 1;
    $display("[%10t] Reset applied.", $time);
endtask

task send_byte (
    input logic [7:0] data, 
    input logic log, 
    output logic test_passed
);

    logic [7:0] buffer;
    int ticks_counter;
    begin
        test_passed = 0;
        @(posedge clk);
        tx_start <= 1'b1;
        tx_data <= data;
        buffer <= '0;
        @(posedge clk);
        tx_start <= 1'b0;
        if (log) $display("[%10t] [INFO] Starting communication.", $time);
        @(posedge clk);

        // STATE = START
        -> start_cycle;
        if (log) $display("[%10t] [INFO] START state started", $time);
        ticks_counter = 0;
        while (ticks_counter < 16) begin
            @(posedge baud_tick);
            if (ticks_counter == 7 && tx_pin == 1'b1) begin
                if (log) $display("[%10t] [FAIL] tx_pin still high when sampled at START state.", $time);
                return;
            end
            ticks_counter += 1;
            @(negedge baud_tick);
        end
        @(posedge clk);
        if (log) $display("[%10t] [PASS] tx_pin behaved correctly during START state.", $time);

        // STATE = DATA
        if (log) $display("[%10t] [INFO] DATA state started", $time);
        for (int i = 0; i < 8; i++) begin
            ticks_counter = 0;
            while (ticks_counter < 16) begin
                @(posedge baud_tick);
                if (ticks_counter == 7) begin
                    if (log) $display("[%10t] [DATA] Sampled bit %1d: %b | Expected: %b", $time, i+1, tx_pin, data[i]);
                    buffer[i] = tx_pin;
                end
                ticks_counter += 1;
                @(negedge baud_tick);
            end
            @(posedge clk);
        end

        // STATE = STOP
        -> stop_cycle;
        if (log) $display("[%10t] [INFO] STOP state started", $time);
        ticks_counter = 0;
        while (ticks_counter < 16) begin
            @(posedge baud_tick);
            if (ticks_counter == 7 && tx_pin == 1'b0) begin
                if (log) $display("[%10t] [FAIL] tx_pin is low when sampled at STOP state.", $time);
                return;
            end
            ticks_counter += 1;
            @(negedge baud_tick);
        end
        @(posedge clk);
        test_passed = (buffer == data);
        if (log) begin
            $display("[%10t] [PASS] tx_pin behaved correctly during STOP state.", $time);
            $display("[%10t] [%s] Received: %2h | Expected: %2h", $time, (test_passed) ? "PASS" : "FAIL", buffer, data);
            $display("[%10t] [INFO] Moving to IDLE.", $time);
        end
    end
endtask

initial begin
    seize_tx = 1'b0; seize_value = 1'b0;
    reset();

    $display("[%10t] Single run: Sending 8'hAA.", $time);
    send_byte(8'hAA, 1'b1, test_passed);

    $display("[%10t] Seizing start bit to cause error.", $time);
    fork
        send_byte(8'hFF, 1'b1, test_passed);
        begin
            @(start_cycle);
            seize_tx = 1'b1;
            seize_value = 1'b1;
            wait(!tx_busy);
            seize_tx = 1'b0;
        end
    join
    if (test_passed)
        $display("[%10t] [FAIL] Unexpected pass.", $time);
    else
        $display("[%10t] [PASS] Failed successfully.", $time);

    $display("[%10t] Seizing stop bit to cause error.", $time);
    fork
        send_byte(8'hFF, 1'b1, test_passed);
        begin
            @(stop_cycle);
            seize_tx = 1'b1;
            seize_value = 1'b0;
            wait(!tx_busy);
            seize_tx = 1'b0;
        end
    join
    if (test_passed)
        $display("[%10t] [FAIL] Unexpected pass.", $time);
    else
        $display("[%10t] [PASS] Failed successfully.", $time);

    $display("[%10t] Testing from 8'00 to 8'FF", $time);
    pass_count = 256;
    for (int i = 0; i < 256; i++) begin
        send_byte(i[7:0], 1'b0, test_passed);
        if (!test_passed) begin
            $display("[%10t] [FAIL] Value %2h failed.", $time, i[7:0]);
            pass_count -= 1;
        end
    end

    $display("[%10t] [INFO] %3d tests passed.", $time, pass_count);

    $finish(0);
end

int timeout_count = 0;
always @(posedge clk) begin
    if (tx_busy) begin
        timeout_count <= timeout_count + 1;
        if (timeout_count > TIMEOUT) begin
             $display("[%10t] [FATAL] Timeout while waiting for tx_busy.", $time);
             $finish(0);
        end
    end else
        timeout_count <= 0;
end

endmodule