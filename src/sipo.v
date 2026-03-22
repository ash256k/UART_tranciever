module sipo #(
    parameter integer DATASIZE = 8
)(
    input  wire i_clk,
    input  wire i_rst_n,
    
    input  wire i_clear,    // clear shift register
    input  wire i_shift_en, 
    input  wire i_bit,      

    output reg [DATASIZE-1:0] o_data
);

    always @(posedge i_clk or negedge i_rst_n) begin
    
        if (!i_rst_n) begin
            o_data <= {DATASIZE{1'b0}};

        end else if (i_clear) begin
            o_data <= {DATASIZE{1'b0}};

        end else if (i_shift_en) begin 
            o_data <= {i_bit, o_data[DATASIZE-1:1]};
        end
    end

endmodule