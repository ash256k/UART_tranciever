module parity_gen #(
    parameter PARITY = "EVEN"   // "EVEN" or "ODD" ONLY

)(
    input  wire i_clk,
    input  wire i_rst_n,

    input  wire i_clear,
    input  wire i_en,
    input  wire i_bit,       
    
    output wire o_parity     
);

    // Elaboration check ------------------------------------------------------
    generate
        if (PARITY != "EVEN" && PARITY != "ODD") begin : invalid_config
            // Will trigger during synthesis
            initial begin
                $error("ERROR: parity_gen instantiated with unsupported PARITY value");
            end
        end
    endgenerate


    // Registers --------------------------------------------------------------

    reg r_parity;


    // Parity generator core ==================================================

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_parity <= (PARITY == "ODD"); // 1 for ODD, 0 for EVEN

        end else if (i_clear) begin
            r_parity <= (PARITY == "ODD"); 

        end else if (i_en) begin
            r_parity <= r_parity ^ i_bit;
        end
    end

    assign o_parity = r_parity;

endmodule