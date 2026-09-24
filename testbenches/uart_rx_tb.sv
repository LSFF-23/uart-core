module uart_rx_tb;
timeunit 1ns;
timeprecision 1ns;

import uart_pkg::*;

localparam PARITY = 0;

logic clk;
logic rstn;
logic baud_tick;
logic rx_pin;
logic [7:0] rx_data;
logic rx_done;
logic frame_error;
logic parity_error;

logic test_passed;
int pass_count;

baud_gen u_baud_gen (.*);
uart_rx #(.PARITY(PARITY)) dut (.*);

initial clk = 0;
always #(PERIOD/2) clk = !clk;

task receive_byte (
    input logic [7:0] data, 
    input logic log, 
    output logic test_passed
);
    begin
        @(posedge clk);
        rx_pin = 1;
        @(posedge clk);
        test_passed = 0;
        rx_pin = 0;
        @(posedge clk);
        if (log) $display("[%6t] [INFO] Byte to be sent: 8'h%2X", $time, data);

        // STATE = START
        repeat (8) @(posedge baud_tick);
        if (rx_pin == 1) begin
            if (log) $display("[%6t] [FAIL] Start bit found high, moving to IDLE.", $time);
            wait(dut.state == RX_IDLE);
            return;
        end
        repeat (8) @(posedge baud_tick);
        @(posedge clk);
        if (log) $display("[%6t] [INFO] Start bit (rx = %b) sent.", $time, rx_pin);

        // STATE = DATA
        for (int i = 0; i < 8; i++) begin
            rx_pin = data[i];
            repeat (16) @(posedge baud_tick);
            if (log) $display("[%6t] [INFO] Data bit %1d: %b sent.", $time, i+1, rx_pin);
        end
        @(posedge clk);

        // STATE = PARITY
        if (PARITY inside {[0:1]}) begin
            rx_pin = ^data ^ PARITY[0];
            repeat (16) @(posedge baud_tick);
            @(posedge clk);
            if (log) $display("[%6t] [INFO] Parity bit (rx = %b) sent.", $time, rx_pin);
        end

        // STATE = STOP
        rx_pin = 1;
        repeat (16) @(posedge baud_tick);
        if (log) $display("[%6t] [INFO] Stop bit (rx = %b) sent.", $time, rx_pin);
        wait(rx_done || dut.state == RX_IDLE);
        test_passed = (rx_data == data) && !(frame_error) && !(parity_error);
        if (log) begin
            $display("[%6t] [%s] Received: %2h | Expected: %2h | frame_error: %b | parity_error: %b", $time, (test_passed) ? "PASS" : "FAIL", rx_data, data, frame_error, parity_error);
            $display("[%6t] [INFO] Moving to IDLE", $time);
        end
        wait(dut.state == RX_IDLE);
    end
endtask

initial begin
    $display("------------------------------------------------------------");
    reset(.rstn(rstn));
    $display("------------------------------------------------------------");

    receive_byte(8'hAB, 1, test_passed);
    $display("------------------------------------------------------------");

    $display("[%6t] Triggering a start bit error", $time);
    fork
        receive_byte(8'hCD, 1, test_passed);
        begin
            wait(dut.state == RX_START);
            repeat (3) @(posedge baud_tick);
            rx_pin = 1;
        end
    join
    $display("[%6t] [%s] Start bit error executed.", $time, (test_passed) ? "FAIL" : "PASS");
    $display("------------------------------------------------------------");

    $display("[%6t] Triggering a frame error", $time);
    fork
        receive_byte(8'hEF, 1, test_passed);
        begin
            wait(dut.state == RX_STOP);
            repeat (3) @(posedge baud_tick);
            rx_pin = 0;
        end
    join
    $display("[%6t] [%s] Stop bit error executed.", $time, (test_passed) ? "FAIL" : "PASS");
    $display("------------------------------------------------------------");

    if (PARITY inside {[0:1]}) begin
        $display("[%6t] Triggering a parity error", $time);
        fork
            receive_byte(8'h12, 1, test_passed);
            begin
                wait(dut.state == RX_PARITY);
                repeat (3) @(posedge baud_tick);
                rx_pin = !rx_pin;
            end
        join
        $display("[%6t] [%s] Parity bit error executed.", $time, (test_passed) ? "FAIL" : "PASS");
        $display("------------------------------------------------------------");

        $display("[%6t] Triggering a parity error AND frame error", $time);
        fork
            receive_byte(8'h34, 1, test_passed);
            begin
                wait(dut.state == RX_PARITY);
                repeat (3) @(posedge baud_tick);
                rx_pin = !rx_pin;
                wait(dut.state == RX_STOP);
                repeat (3) @(posedge baud_tick);
                rx_pin = 0;
            end
        join
        $display("[%6t] [%s] Parity+Frame bit error executed.", $time, (test_passed) ? "FAIL" : "PASS");
        $display("------------------------------------------------------------");
    end

    $display("[%6t] Testing from 8'00 to 8'FF", $time);
    pass_count = 256;
    for (int i = 0; i < 256; i++) begin
        receive_byte(i[7:0], 1'b0, test_passed);
        if (!test_passed) begin
            $display("[%6t] [FAIL] Value %2h failed.", $time, i[7:0]);
            pass_count -= 1;
        end
    end
    $display("[%6t] [%s] %3d tests passed.", $time, pass_count == 256 ? "PASS" : "FAIL", pass_count);
    $display("------------------------------------------------------------");

    $finish(0);
end

int timeout_count = 0;
logic done_sync1 = 0;
logic done_sync2 = 0;
always @(posedge clk) begin
    done_sync1 <= rx_done;
    done_sync2 <= done_sync1;
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