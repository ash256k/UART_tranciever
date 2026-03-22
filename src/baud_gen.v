module baud_gen #(
    parameter CLOCKFREQ     = 50_000_000,
    parameter BAUDRATE      = 9600,
    parameter OVERSAMPLE    = 16            // Typically  8, 16, 32.
)(
    input  wire i_clk,
    input  wire i_rst_n,    // async, active-low reset

    output reg  o_tick      // tick; will be used by Rx and Tx
);

    // Derived params ---------------------------------------------------------
    
    localparam TICK_RATE    = CLOCKFREQ / (BAUDRATE * OVERSAMPLE);
    localparam TICK_CNTR_W  = $clog2(TICK_RATE);


    // Registers --------------------------------------------------------------

    reg [TICK_CNTR_W-1:0] tick_counter; 


    // Baud generator core ====================================================

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            tick_counter <= 0;
            o_tick       <= 1'b0;

        end else begin
            if (tick_counter == TICK_RATE-1) begin
                tick_counter <= 0;
                o_tick       <= 1'b1;

            end else begin
                tick_counter <= tick_counter + 1'b1;
                o_tick       <= 1'b0;
            end

        end
    end

endmodule