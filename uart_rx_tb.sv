module uart_rx_tb;
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
logic rx_pin;
logic [7:0] rx_data;
logic rx_done;
logic frame_error;

logic test_passed;
event start_cycle, stop_cycle;
int pass_count;

baud_gen #(
    .BAUD_RATE(L_BAUD),
    .CLK_FREQUENCY(MAIN_CLOCK)
) u_baud_gen (.*);

uart_rx dut (.*);

initial clk = 0;
always #(PERIOD/2) clk = !clk;

task reset();
    $display("[%6t] Applying reset...", $time);
    rstn = 1;
    #1;
    rstn = 0;
    #1;
    rstn = 1;
    $display("[%6t] Reset applied.", $time);
endtask

task receive_byte (
    input logic [7:0] data, 
    input logic log, 
    output logic test_passed
);
    int ticks_counter;
    begin
        test_passed = 0;
        // FORCING IDLE -> START
        @(posedge clk);
        rx_pin = 1'b0;
        @(posedge clk);
        if (log) $display("[%6t] [INFO] Starting communication.", $time);

        // STATE = START
        -> start_cycle;
        if (log) $display("[%6t] [INFO] START state started", $time);
        ticks_counter = 0;
        while (ticks_counter < 16) begin
            @(posedge baud_tick);
            if (ticks_counter == 7 && rx_pin == 1'b1) begin
                if (log) $display("[%6t] [FAIL] Noise detected, moving to IDLE.", $time);
                return;
            end
            ticks_counter += 1;
            @(negedge baud_tick);
        end
        @(posedge clk);
        if (log) $display("[%6t] [INFO] Start bit checked.", $time);

        // STATE = DATA
        if (log) $display("[%6t] [INFO] DATA state started", $time);
        for (int i = 0; i < 8; i++) begin
            ticks_counter = 0;
            rx_pin = data[i];
            if (log) $display("[%6t] [DATA] #%1d Sending bit: %b", $time, i+1, data[i]);
            while (ticks_counter < 16) begin
                @(posedge baud_tick);
                ticks_counter += 1;
                @(negedge baud_tick);
            end
            @(posedge clk);
        end
        if (log) $display("[%6t] [DATA] Byte 8'%2h sent.", $time, data);

        // STATE = STOP
        -> stop_cycle;
        if (log) $display("[%6t] [INFO] STOP state started", $time);
        rx_pin = 1'b1;
        ticks_counter = 0;
        while (ticks_counter < 16) begin
            @(posedge baud_tick);
            if (ticks_counter == 7 && rx_pin == 1'b0) begin
                if (log) $display("[%6t] [FAIL] rx_pin found low during STOP state, triggering error flag.", $time);
            end
            ticks_counter += 1;
            @(negedge baud_tick);
        end
        @(posedge clk);
        if (log) $display("[%6t] [INFO] Stop bit checked.", $time);

        // STATE = EITHER DONE OR ERROR
        wait(rx_done);
        test_passed = (data == rx_data) && (frame_error == 1'b0);
        if (log) begin
            $display("[%6t] [%s] frame_error: %b | Sent: %2h | Received: %2h", $time, (test_passed) ? "PASS" : "FAIL", frame_error, data, rx_data);
            $display("[%6t] [INFO] Moving to IDLE.", $time);
        end
    end
endtask

initial begin
    $display("------------------------------------------------------------");
    rx_pin = 1'b1;
    reset();

    $display("[%6t] Single run: Receiving 8'hAA.", $time);
    receive_byte(8'hAA, 1'b1, test_passed);
    $display("------------------------------------------------------------");

    $display("[%6t] Line will be pulled high on 4th baud tick.", $time);
    fork
        receive_byte(8'hAA, 1'b1, test_passed);
        begin
            @(start_cycle);
            repeat (3) @(negedge baud_tick);
            rx_pin = 1'b1;
        end
    join
    $display("------------------------------------------------------------");

    $display("[%6t] Triggering a frame error", $time);
    fork
        receive_byte(8'hAA, 1'b1, test_passed);
        begin
            @(stop_cycle);
            repeat (3) @(negedge baud_tick);
            rx_pin = 1'b0;
            wait(frame_error);
            @(posedge clk);
            rx_pin = 1'b1;
        end
    join
    $display("------------------------------------------------------------");

    $display("[%6t] Testing from 8'00 to 8'FF", $time);
    pass_count = 256;
    for (int i = 0; i < 256; i++) begin
        receive_byte(i[7:0], 1'b0, test_passed);
        if (!test_passed) begin
            $display("[%6t] [FAIL] Value %2h failed.", $time, i[7:0]);
            pass_count -= 1;
        end
    end
    $display("[%6t] [INFO] %3d tests passed.", $time, pass_count);
    $display("------------------------------------------------------------");

    $finish(0);
end

int timeout_count = 0;
logic done_sync1 = 0;
logic done_sync2 = 0;
always @(posedge clk) begin
    done_sync1 <= rx_done;
    done_sync2 <= done_sync2;
    if (done_sync1 == done_sync2) begin
        timeout_count <= timeout_count + 1;
        if (timeout_count > TIMEOUT) begin
            $display("[%6t] [FATAL] Timeout while waiting for rx_done.", $time);
            $finish(0);
        end
    end else
        timeout_count <= 0;
end

endmodule