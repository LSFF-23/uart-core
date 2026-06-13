package uart_pkg;

localparam int MAIN_CLOCK = 50_000_000; // in Hz
localparam int PERIOD = 1_000_000_000 / MAIN_CLOCK; // in ns
localparam int L_BAUD = 115200;
localparam int BAUD = MAIN_CLOCK / (L_BAUD * 16);
localparam int TIMEOUT = 3 * 176 * BAUD; // 1 byte = 176 bauds

typedef enum logic [2:0] {
    TX_IDLE = 3'b000,
    TX_START = 3'b001,
    TX_DATA = 3'b010,
    TX_STOP = 3'b011,
    TX_PARITY = 3'b100
} tx_states;

task automatic reset (ref logic rstn);
    $display("[%6t] Applying reset...", $time);
    rstn = 1;
    #1;
    rstn = 0;
    #1;
    rstn = 1;
    $display("[%6t] Reset applied.", $time);
endtask

endpackage