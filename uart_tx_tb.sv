module uart_tx_tb;
timeunit 1ns;
timeprecision 1ns;

import uart_pkg::*;

localparam PARITY = 0;

logic clk;
logic rstn;
logic baud_tick;
logic tx_start;
logic [7:0] tx_data;
logic tx_value;
logic tx_busy;

logic seize_tx, seize_value;
wire tx_pin = (seize_tx) ? seize_value : tx_value;

logic test_passed;
int pass_count;

baud_gen u_baud_gen (.*);
uart_tx#(.PARITY(PARITY)) dut (.*, .tx_pin(tx_value));

initial clk = 0;
always #(PERIOD/2) clk = !clk;

task send_byte (
    input logic [7:0] data, 
    input logic log, 
    output logic test_passed
);

    logic [7:0] buffer;
    logic parity;
    begin
        @(posedge clk);
        test_passed = 0;
        tx_start = 1;
        tx_data = data;
        buffer = '0;
        @(posedge clk);
        tx_start = 0;
        if (log) $display("[%6t] [INFO] Byte to be sent: 8'h%2X", $time, data);
        @(posedge clk);

        // STATE = START
        repeat (8) @(posedge baud_tick);  
        if (log) $display("[%6t] [%s] START: tx_pin = %b", $time, (tx_pin != 0) ? "FAIL" : "PASS", tx_pin);
        if (tx_pin != 0) begin
            wait(dut.state == TX_IDLE);
            return;
        end
        repeat(8) @(posedge baud_tick);

        // STATE = DATA
        for (int i = 0; i < 8; i++) begin
            repeat (8) @(posedge baud_tick);
            if (log) $display("[%6t] [%s] DATA: Sampled bit %1d: %b | Expected: %b", $time, tx_pin == data[i] ? "PASS" : "FAIL", i+1, tx_pin, data[i]);
            buffer[i] = tx_pin;
            repeat (8) @(posedge baud_tick);
        end

        // STATE = PARITY
        if (PARITY inside {[0:1]}) begin
            parity = ^buffer ^ PARITY[0];
            repeat (8) @(posedge baud_tick);
            if (log) $display("[%6t] [%s] PARITY: tx_pin = %b | parity = %b", $time, (tx_pin == parity) ? "PASS" : "FAIL", tx_pin, parity);
            if (tx_pin != parity) begin
                wait(dut.state == TX_IDLE);
                return;
            end
            repeat(8) @(posedge baud_tick);
        end

        // STATE = STOP
        repeat (8) @(posedge baud_tick);  
        if (log) $display("[%6t] [%s] STOP: tx_pin = %b", $time, (tx_pin == 0) ? "FAIL" : "PASS", tx_pin);
        if (tx_pin == 0) begin
            wait(dut.state == TX_IDLE);
            return;
        end
        repeat(8) @(posedge baud_tick);

        test_passed = (buffer == data);
        if (log) begin
            $display("[%6t] [%s] Received: %2h | Expected: %2h", $time, (test_passed) ? "PASS" : "FAIL", buffer, data);
            $display("[%6t] [INFO] Moving to IDLE", $time);
        end
        wait(dut.state == TX_IDLE);
    end
endtask

initial begin
    $display("------------------------------------------------------------");
    seize_tx = 0; seize_value = 0;
    reset(.rstn(rstn));
    $display("------------------------------------------------------------");

    send_byte(8'hAA, 1, test_passed);
    $display("------------------------------------------------------------");

    $display("[%6t] Seizing start bit to cause error.", $time);
    fork
        send_byte(8'hFF, 1, test_passed);
        begin
            wait(dut.state == TX_START);
            seize_tx = 1;
            seize_value = 1;
            wait(!tx_busy);
            seize_tx = 0;
        end
    join
    $display("[%6t] [%s] Start bit error executed.", $time, (test_passed) ? "FAIL" : "PASS");
    $display("------------------------------------------------------------");

    $display("[%6t] Seizing stop bit to cause error.", $time);
    fork
        send_byte(8'hFF, 1, test_passed);
        begin
            wait(dut.state == TX_STOP);
            seize_tx = 1;
            seize_value = 0;
            wait(!tx_busy);
            seize_tx = 0;
        end
    join
    $display("[%6t] [%s] Stop bit error executed.", $time, (test_passed) ? "FAIL" : "PASS");
    $display("------------------------------------------------------------");

    $display("[%6t] Testing from 8'00 to 8'FF", $time);
    pass_count = 256;
    for (int i = 0; i < 256; i++) begin
        send_byte(i[7:0], 1'b0, test_passed);
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
always @(posedge clk) begin
    if (tx_busy) begin
        timeout_count <= timeout_count + 1;
        if (timeout_count > TIMEOUT) begin
            $display("[%6t] [FATAL] Timeout while waiting for tx_busy.", $time);
            $finish(0);
        end
    end else
        timeout_count <= 0;
end

endmodule