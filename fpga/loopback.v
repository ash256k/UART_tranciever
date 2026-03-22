module loopback #(
    parameter CLOCKFREQ     = 50_000_000,
    parameter BAUDRATE      = 9600,
    parameter DATASIZE      = 8,
    parameter PARITY        = "NONE",
    parameter STOPBITS      = 1,
    parameter OVERSAMPLE    = 16
)(
    input  wire i_clk,
    input  wire i_rst_n,

    input  wire i_rx_line,
    input  wire i_rx_en,
    
    output wire o_tx_line,
    
    // Status flags
    output wire o_rx_done,
    output wire o_rx_frame_err,
    output wire o_rx_parity_err,
    output wire o_tx_busy
);

    // Internal signals
    wire [DATASIZE-1:0] rx_data;
    wire                rx_done;
    
    assign o_rx_done = rx_done;

    // Instantiate UART
    uart #(
        .CLOCKFREQ  (CLOCKFREQ),
        .BAUDRATE   (BAUDRATE),
        .DATASIZE   (DATASIZE),
        .PARITY     (PARITY),
        .STOPBITS   (STOPBITS),
        .OVERSAMPLE (OVERSAMPLE)
    ) u_uart (
        .i_clk          (i_clk),
        .i_rst_n        (i_rst_n),

        // RX
        .i_rx_line      (i_rx_line),
        .i_rx_en        (i_rx_en),
        .o_rx_data      (rx_data),
        .o_rx_done      (rx_done),
        .o_rx_frame_err (o_rx_frame_err),
        .o_rx_parity_err(o_rx_parity_err),

        // TX
        .i_tx_data      (rx_data),
        .i_tx_en        (rx_done), // Loopback: Tx whenever Rx is done
        .o_tx_line      (o_tx_line),
        .o_tx_busy      (o_tx_busy)
    );

endmodule
