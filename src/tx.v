module tx #(
    parameter OVERSAMPLE    = 16,
    parameter DATASIZE      = 8,
    parameter PARITY        = "NONE",   // "NONE", "EVEN" or "ODD"
    parameter STOPBITS      = 1         // 1 or 2 stop bits
)(
    input  wire                 i_clk,
    input  wire                 i_rst_n,      // async, active-low reset
    input  wire                 i_tick,
    
    input  wire [DATASIZE-1:0]  i_tx_data,    
    input  wire                 i_tx_enable,  // Tx enable trigger

    output reg  o_tx_line,    // physical Tx line
    output reg  o_busy
);

    // Machine states ---------------------------------------------------------
    
    // TX_IDLE -> TX_START -> TX_DATA -> TX_PARITY -> TX_STOP -> TX_IDLE
    localparam TX_IDLE   = 3'd0;
    localparam TX_START  = 3'd1;
    localparam TX_DATA   = 3'd2;
    localparam TX_PARITY = 3'd3;
    localparam TX_STOP   = 3'd4;


    // Registers --------------------------------------------------------------

    reg [2:0]                       tx_state;
    reg [3:0]                       bit_cntr;
    reg [$clog2(OVERSAMPLE)-1:0]    tick_cntr;
    reg [1:0]                       stop_cntr;  // counter for multi-stop-bit support
    

    // Internal Signals -------------------------------------------------------

    reg piso_load;
    reg piso_shift_en;
    wire piso_bit;


    // Instantiations =========================================================

    piso #(.DATASIZE(DATASIZE)) u_piso (
        .i_clk(i_clk), .i_rst_n(i_rst_n), 
        .i_load(piso_load), .i_shift_en(piso_shift_en), 
        .i_data(i_tx_data), .o_bit(piso_bit)
    );

    // Parity Generator -------------------------------------------------------
    wire calc_parity;
    
    generate
        if (PARITY == "EVEN" || PARITY == "ODD") begin : gen_parity
             parity_gen #(.PARITY(PARITY)) u_parity (
                .i_clk(i_clk), .i_rst_n(i_rst_n),
                .i_clear(tx_state == TX_IDLE),
                // i_en timing: Sample bit at end of current bit duration.
                // Works because NBA (<=) ensures parity captures CURRENT bit 
                // before PISO shifts it away on the next clock.
                .i_en(tx_state == TX_DATA && i_tick && tick_cntr == OVERSAMPLE-1), 
                .i_bit(piso_bit),
                .o_parity(calc_parity)
             );
        end else begin
             assign calc_parity = 1'b0;
        end
    endgenerate


    // Tx core ================================================================

    always @(posedge i_clk or negedge i_rst_n) begin

        if (!i_rst_n) begin
             tx_state  <= TX_IDLE;
             o_tx_line <= 1'b1; // HIGH at IDLE
             o_busy    <= 1'b0;
             tick_cntr <= 0;
             bit_cntr  <= 0;
             stop_cntr <= 0;
             piso_load <= 0;
             piso_shift_en <= 0;

        end else begin

            piso_load  <= 0;
            piso_shift_en <= 0;
            
            case (tx_state)

                // ------------------------------------------------------------
                TX_IDLE: begin
                    o_tx_line <= 1'b1;
                    tick_cntr <= 0;
                    bit_cntr  <= 0;
                    stop_cntr <= 0;

                    if (i_tx_enable) begin
                        tx_state  <= TX_START;
                        o_busy    <= 1'b1;
                        piso_load <= 1'b1;

                    end else begin
                        o_busy    <= 1'b0;
                    end
                end

                // ------------------------------------------------------------
                TX_START: begin
                    o_tx_line <= 1'b0;  // START Bit

                    if (i_tick) begin
                        if (tick_cntr == OVERSAMPLE-1) begin
                            tick_cntr <= 0;
                            tx_state  <= TX_DATA;

                        end else begin
                            tick_cntr <= tick_cntr + 1'b1;
                        end
                    end
                end

                // ------------------------------------------------------------
                TX_DATA: begin
                    o_tx_line <= piso_bit;
                    
                    if (i_tick) begin
                        if (tick_cntr == OVERSAMPLE-1) begin
                            tick_cntr <= 0;

                            if (bit_cntr == DATASIZE-1) begin
                                bit_cntr <= 0;

                                if (PARITY != "NONE") 
                                    tx_state <= TX_PARITY;
                                else             
                                    tx_state <= TX_STOP;

                            end else begin
                                bit_cntr   <= bit_cntr + 1'b1;
                                // Shift PISO to next bit. Note: Parity generator (if enabled)
                                // has already sampled the current bit on this same clock edge.
                                piso_shift_en <= 1'b1;
                            end

                        end else begin
                            tick_cntr <= tick_cntr + 1'b1;
                        end
                    end
                end

                // ------------------------------------------------------------
                TX_PARITY: begin

                    o_tx_line <= calc_parity;
                    if (i_tick) begin
                        if (tick_cntr == OVERSAMPLE-1) begin
                            tick_cntr <= 0;
                            tx_state <= TX_STOP;
                        end else begin
                            tick_cntr <= tick_cntr + 1'b1;
                        end
                    end
                    
                end

                // ------------------------------------------------------------
                TX_STOP: begin
                    o_tx_line <= 1'b1;
                    if (i_tick) begin
                        if (tick_cntr == OVERSAMPLE-1) begin
                            tick_cntr <= 0;
                            if (stop_cntr == STOPBITS-1) begin
                                // All stop bits transmitted
                                tx_state  <= TX_IDLE;
                                o_busy    <= 1'b0;
                                stop_cntr <= 0;
                            end else begin
                                stop_cntr <= stop_cntr + 1'b1;
                            end
                        end else begin
                            tick_cntr <= tick_cntr + 1'b1;
                        end
                    end
                end
                
                // ------------------------------------------------------------
                default: tx_state <= TX_IDLE;

            endcase
        end
    end

endmodule