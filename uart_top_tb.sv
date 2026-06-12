module uart_top_tb;
parameter int MAIN_CLOCK = 50_000_000; // in Hz
parameter int PERIOD = 1_000_000_000 / MAIN_CLOCK; // in ns
parameter int L_BAUD = 115200;
parameter int BAUD = MAIN_CLOCK / (L_BAUD * 16);
parameter int TIMEOUT = 800 * BAUD; // 1 full byte sent = 160 bauds

parameter TX_IDLE = 2'b00;
parameter TX_START = 2'b01;
parameter TX_DATA = 2'b10;
parameter TX_STOP = 2'b11;

parameter RX_IDLE = 3'b000;
parameter RX_START = 3'b001;
parameter RX_DATA = 3'b010;
parameter RX_STOP = 3'b011;
parameter RX_ERROR = 3'b100;
parameter RX_CLEANUP = 3'b101;
parameter RX_DONE = 3'b111;

logic clk;
logic rstn;
logic tx_pin;
logic [7:0] tx_data;
logic tx_start;
logic tx_busy;
logic rx_pin;
logic [7:0] rx_data;
logic rx_done;
logic frame_error;

logic baud_tick;
logic test_passed;
int pass_count;

logic seize_tx, seize_value;
assign rx_pin = (seize_tx) ? seize_value : tx_pin;

baud_gen #(
    .BAUD_RATE(L_BAUD),
    .CLK_FREQUENCY(MAIN_CLOCK)
) u_baud_gen (.*);

uart_top #(
    .BAUD_RATE(L_BAUD),
    .CLK_FREQUENCY(MAIN_CLOCK)
) dut (.*);

initial clk = 0;
always #(PERIOD/2) clk = !clk;

task reset();
    $display("[%6t] Applying reset...", $time);
    rstn = 1;
    #1;
    rstn = 0;
    $display("[%6t] Reset applied.", $time);
    #1;
    rstn = 1;
endtask

task loopback_byte (
    input [7:0] data,
    input log,
    output test_passed
);
    begin
        if (log) $display("[%6t] Looping back: 8'h%2h", $time, data);
        @(posedge clk);
        test_passed = 0;
        tx_start = 0;
        @(posedge clk);
        tx_start = 1;
        tx_data = data;
        @(posedge clk);
        tx_start = 0;
        @(posedge clk);
        wait(dut.u_uart_rx.state != RX_IDLE);
        wait(rx_done || dut.u_uart_rx.state == RX_IDLE);
        test_passed = (frame_error == 0) && (data == rx_data);
        if (log) $display("[%6t] [%s] frame_error: %b | Sent: %2h | Received: %2h", $time, (test_passed) ? "PASS" : "FAIL", frame_error, data, rx_data);
    end
endtask

initial begin
    $display("------------------------------------------------------------");
    tx_start = 0; tx_data = '0; seize_tx = 0; seize_value = 0;
    reset();

    loopback_byte(8'hAA, 1, test_passed);
    $display("------------------------------------------------------------");

    $display("[%6t] Seizing start bit to cause error.", $time);
    fork
        loopback_byte(8'h99, 1, test_passed);
        begin
            wait(dut.u_uart_rx.state == RX_START);
            seize_tx = 1; seize_value = 1;
            @(posedge clk);
            wait(dut.u_uart_rx.state == RX_IDLE);
            seize_tx = 0; seize_value = 0;
            @(posedge clk);
        end
    join
    $display("[%6t] [%s] Start bit error executed.", $time, (test_passed) ? "FAIL" : "PASS",);
    $display("------------------------------------------------------------");

    $display("[%6t] Seizing stop bit to cause error.", $time);
    fork
        loopback_byte(8'hBB, 1, test_passed);
        begin
            wait(dut.u_uart_rx.state == RX_STOP);
            seize_tx = 1; seize_value = 0;
            @(posedge clk);
            wait(dut.u_uart_rx.state == RX_IDLE);
            seize_tx = 0; seize_value = 0;
            @(posedge clk);
        end
    join
    $display("[%6t] [%s] Stop bit error executed.", $time, (test_passed) ? "FAIL" : "PASS",);
    $display("------------------------------------------------------------");

    $display("[%6t] Testing from 8'00 to 8'FF", $time);
    pass_count = 256;
    for (int i = 0; i < 256; i++) begin
        loopback_byte(i[7:0], 0, test_passed);
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