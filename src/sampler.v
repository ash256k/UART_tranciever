module sampler #(
    parameter OVERSAMPLE    = 16
)(
    input  wire i_clk,      
    input  wire i_rst_n,    // async, active-low reset
    input  wire i_tick,     // tick from baud_gen 
    input  wire i_enable,   // 
    input  wire i_rx_line,  // async RX pin

    output reg  o_bit,          // final, sampled bit
    output reg  o_bit_valid, 
    output wire o_start_edge,    // pulse to wake up rx_core
    
    // Exposed for False Start Detection
    output wire [$clog2(OVERSAMPLE)-1:0] o_tick_cntr,
    output wire       o_rx_sync

);

    // Derived params ---------------------------------------------------------
    localparam integer MIDSAMPLE    = (OVERSAMPLE / 2);
    localparam integer OS_CNTR_W    = $clog2(OVERSAMPLE);


    // Registers --------------------------------------------------------------
    reg [OS_CNTR_W-1:0] os_cntr;    // oversample counter
    reg [1:0]           majority;   


    // 3-stage Input synchronizer =============================================

    reg [2:0] rx_sync;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            rx_sync <= 3'b111;
        end else begin
            rx_sync <= {rx_sync[1:0], i_rx_line};
        end
    end

    wire i_rx = rx_sync[2];  // Use final stage for max MTBF

    // Debug removed
    // always @(posedge i_clk) begin
    //     if (rx_sync != 3'b111 && rx_sync != 3'b000) begin
    //          $display("Time %t | Sampler Sync: %b | Line: %b", $time, rx_sync, i_rx_line);
    //     end
    // end


    // START edge detection ===================================================

    // if i_rx drops from 1 to 0, START detected
    assign o_start_edge = (rx_sync[2] && !rx_sync[1]);
    
    assign o_rx_sync    = i_rx;
    assign o_tick_cntr  = os_cntr;


    // Sampler core ===========================================================
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            os_cntr     <= 0;
            majority    <= 0;
            o_bit       <= 1'b1;
            o_bit_valid <= 1'b0;

        end else begin
            o_bit_valid <= 1'b0;

            if (!i_enable) begin
                os_cntr     <= 0;
                majority    <= 0;

            end else if (i_tick) begin   
                
                // updating os_cntr -------------------------------------------
                if (os_cntr == OVERSAMPLE-1) begin
                    os_cntr <= 0;
                end else begin
                    os_cntr <= os_cntr + 1'b1;
                end

                // determining majority ---------------------------------------
                if (os_cntr >= MIDSAMPLE-1 && os_cntr <= MIDSAMPLE+1) begin 
                    majority <= majority + i_rx;
                end

                if (os_cntr == OVERSAMPLE-1) begin
                    o_bit_valid <= 1'b1;
                    o_bit       <= (majority >= 2 ? 1'b1 : 1'b0);
                    majority    <= 0;   //resetting majority
                end
            end
        end
    end

endmodule