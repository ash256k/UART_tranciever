module uart #(
    parameter CLOCKFREQ     = 50_000_000,
    parameter BAUDRATE      = 9600,
    parameter DATASIZE      = 8,
    parameter PARITY        = "NONE",   // "NONE", "EVEN", or "ODD"
    parameter STOPBITS      = 1,        // 1 or 2 stop bits
    parameter OVERSAMPLE    = 16
)(
    input  wire                 i_clk,
    input  wire                 i_rst_n,        // async, active-low reset

    // RX interface
    input  wire                 i_rx_line,      // physical Rx pin
    input  wire                 i_rx_en,        // Rx enable signal
    output wire [DATASIZE-1:0]  o_rx_data,
    output wire                 o_rx_done,
    output wire                 o_rx_frame_err,
    output wire                 o_rx_parity_err,

    // TX interface
    input  wire [DATASIZE-1:0]  i_tx_data,
    input  wire                 i_tx_en,        // Tx enable trigger
    output wire                 o_tx_line,      // physical Tx pin
    output wire                 o_tx_busy
);


    // Internal Signals -------------------------------------------------------

    wire tick;  // shared baud tick for RX and TX


    // Instantiations =========================================================

    // Baud rate generator ----------------------------------------------------
    baud_gen #(
        .CLOCKFREQ  (CLOCKFREQ),
        .BAUDRATE   (BAUDRATE),
        .OVERSAMPLE (OVERSAMPLE)
    ) u_baud_gen (
        .i_clk      (i_clk),
        .i_rst_n    (i_rst_n),
        .o_tick     (tick)
    );


    // UART Receiver ----------------------------------------------------------
    rx #(
        .CLOCKFREQ  (CLOCKFREQ),
        .BAUDRATE   (BAUDRATE),
        .DATASIZE   (DATASIZE),
        .PARITY     (PARITY),
        .STOPBITS   (STOPBITS),
        .OVERSAMPLE (OVERSAMPLE)
    ) u_rx (
        .i_clk          (i_clk),
        .i_rst_n        (i_rst_n),
        .i_tick         (tick),

        .i_rx_line      (i_rx_line),
        .i_rx_enable    (i_rx_en),

        .o_rx_data      (o_rx_data),
        .o_rx_done      (o_rx_done),
        .o_rx_frame_err (o_rx_frame_err),
        .o_rx_parity_err(o_rx_parity_err)
    );


    // UART Transmitter -------------------------------------------------------
    tx #(
        .OVERSAMPLE (OVERSAMPLE),
        .DATASIZE   (DATASIZE),
        .PARITY     (PARITY),
        .STOPBITS   (STOPBITS)
    ) u_tx (
        .i_clk      (i_clk),
        .i_rst_n    (i_rst_n),
        .i_tick     (tick),

        .i_tx_data  (i_tx_data),
        .i_tx_enable(i_tx_en),

        .o_tx_line  (o_tx_line),
        .o_busy     (o_tx_busy)
    );


endmodule