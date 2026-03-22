module piso #(
    parameter DATASIZE = 8
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,
    input  wire                  i_load,      // load trigger
    input  wire                  i_shift_en,  // shift trigger
    input  wire [DATASIZE-1:0]   i_data,      

    output wire                  o_bit
);

    // Registers --------------------------------------------------------------

    reg [DATASIZE-1:0] data_reg;


    // PISO core ==============================================================

    assign o_bit = data_reg[0]; // LSB

    always @(posedge i_clk or negedge i_rst_n) begin

        if (!i_rst_n) begin
            data_reg <= {DATASIZE{1'b1}}; 

        end else if (i_load) begin
            data_reg <= i_data;

        end else if (i_shift_en) begin
            data_reg <= {1'b1, data_reg[DATASIZE-1:1]}; // Shift and fill with 1s

        end
    end
    
endmodule