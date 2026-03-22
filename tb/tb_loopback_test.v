`timescale 1ns/1ps

module tb_loopback_test;

    // Parameters
    parameter CLOCKFREQ     = 50_000_000;
    parameter BAUDRATE      = 9600;
    parameter DATASIZE      = 8;
    parameter PARITY        = "EVEN";
    parameter STOPBITS      = 1;
    parameter OVERSAMPLE    = 16;
    

    localparam BIT_PERIOD_NS = 104167; // 1/9600
    
    // Signals
    reg                 clk;
    reg                 rst_n;
    
    // Loopback net
    wire                loopback_line;
    
    // RX
    reg                 rx_en;
    wire [DATASIZE-1:0] rx_data;
    wire                rx_done;
    wire                rx_frame_err;
    wire                rx_parity_err;
    
    // TX
    reg [DATASIZE-1:0]  tx_data_in;
    reg                 tx_en;
    wire                tx_busy;

    // DUT 
    uart #(
        .CLOCKFREQ  (CLOCKFREQ),
        .BAUDRATE   (BAUDRATE),
        .DATASIZE   (DATASIZE),
        .PARITY     (PARITY),
        .STOPBITS   (STOPBITS),
        .OVERSAMPLE (OVERSAMPLE)
    ) u_uart (
        .i_clk          (clk),
        .i_rst_n        (rst_n),

        .i_rx_line      (loopback_line),
        .i_rx_en        (rx_en),
        .o_rx_data      (rx_data),
        .o_rx_done      (rx_done),
        .o_rx_frame_err (rx_frame_err),
        .o_rx_parity_err(rx_parity_err),

        .i_tx_data      (tx_data_in),
        .i_tx_en        (tx_en),
        .o_tx_line      (loopback_line),
        .o_tx_busy      (tx_busy)
    );


    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50MHz
    end

    // Error Counter
    integer err_count = 0;
    
    // Task: Transmit and Verify Loopback Byte
    task loopback_verify;
        input [7:0] test_data;
        begin
            // 1. Wait for Tx to be idle
            wait(!tx_busy);
            
            // 2. Start Transmission
            @(negedge clk);
            tx_data_in = test_data;
            tx_en = 1;
            @(negedge clk);
            tx_en = 0;
            
            $display("Time: %0t | Initiated TX for 0x%h", $time, test_data);
            
            // 3. Wait for RX Done
            // Using a fork to add a timeout just in case it hangs
            fork
                begin
                    wait(rx_done);
                    @(posedge clk); #1;
                    
                    // Verify Received Data and Errors immediately after rx_done
                    if (rx_data !== test_data) begin
                        $display("ERROR: Time: %0t | Data mismatch! Expected: 0x%h, Got: 0x%h", $time, test_data, rx_data);
                        err_count = err_count + 1;
                    end else begin
                        $display("Time: %0t | Passed: Received 0x%h correctly", $time, rx_data);
                    end
                    
                    if (rx_parity_err) begin
                        $display("ERROR: Time: %0t | Unexpected Parity Error for data 0x%h", $time, test_data);
                        err_count = err_count + 1;
                    end
                    
                    if (rx_frame_err) begin
                        $display("ERROR: Time: %0t | Unexpected Frame Error for data 0x%h", $time, test_data);
                        err_count = err_count + 1;
                    end
                end
                begin
                    #(BIT_PERIOD_NS * 15); // Wait 15 bit periods (more than a frame)
                    $display("ERROR: Time: %0t | Timeout waiting for rx_done for data 0x%h", $time, test_data);
                    err_count = err_count + 1;
                end
            join_any
            disable fork;
            
            // Wait for rx_done to clear before moving to next 
            // Takes 1 clock tick since it's a pulse
            @(posedge clk);
        end
    endtask

    // Main tests
    initial begin
        $dumpfile("tb_loopback_test.vcd");
        $dumpvars(0, tb_loopback_test);
        
        // Initialize
        rst_n   = 0;
        rx_en   = 0;
        tx_en   = 0;
        tx_data_in = 0;
        
        #(100);
        rst_n = 1;
        rx_en = 1;
        #(200);

        $display("-----------------------------------------");
        $display("Starting Full UART Loopback Test");
        $display("-----------------------------------------");

        // Send a burst of different byte patterns
        
        // Pattern 1: Alternating bits
        loopback_verify(8'h55);
        loopback_verify(8'hAA);
        
        // Pattern 2: Walking ones
        loopback_verify(8'h01);
        loopback_verify(8'h02);
        loopback_verify(8'h04);
        loopback_verify(8'h08);
        loopback_verify(8'h10);
        loopback_verify(8'h20);
        loopback_verify(8'h40);
        loopback_verify(8'h80);
        
        // Pattern 3: Extremes
        loopback_verify(8'h00);
        loopback_verify(8'hFF);
        
        // Pattern 4: Random
        loopback_verify(8'hA5);
        loopback_verify(8'h7E);
        loopback_verify(8'hC3);
        loopback_verify(8'h3C);

        $display("-----------------------------------------");
        if (err_count == 0) begin
            $display("PASS: All loopback tests completed successfully!");
        end else begin
            $display("FAIL: Loopback tests completed with %0d errors.", err_count);
        end
        $display("-----------------------------------------");
        
        $finish;
    end
    
    // Failsafe Watchdog Timer
    initial begin
        #50_000_000; // 50ms absolute timeout
        $display("FATAL: Watchdog timer triggered in tb_loopback_test!");
        $finish;
    end

endmodule
