module rx #(
    parameter CLOCKFREQ     = 50_000_000,
    parameter BAUDRATE      = 9600,
    parameter DATASIZE      = 8,
    parameter PARITY        = "NONE",   // "NONE", "EVEN" or "ODD"
    parameter STOPBITS      = 1,        // 1 or 2 stop bits
    parameter OVERSAMPLE    = 16
)(
    input wire  i_clk,
    input wire  i_rst_n,    // async, active-low reset
    input wire  i_tick,

    input wire  i_rx_line,  // physical Rx line
    input wire  i_rx_enable, // Rx enable signal
    
    output wire [DATASIZE-1:0]  o_rx_data,
    output reg                  o_rx_done,
    output wire                 o_rx_frame_err,
    output wire                 o_rx_parity_err
);


    // Machine states ---------------------------------------------------------

    // RX_IDLE -> RX_START -> RX_DATA -> RX_PARITY -> RX_STOP -> RX_IDLE
    localparam RX_IDLE   = 3'd0;
    localparam RX_START  = 3'd1;
    localparam RX_DATA   = 3'd2;
    localparam RX_PARITY = 3'd3;
    localparam RX_STOP   = 3'd4;


    // Registers --------------------------------------------------------------

    reg [2:0] rx_state;
    reg [3:0] bit_cntr;
    reg [1:0] stop_cntr;    // counter for multi-stop-bit support
    
    // Internal Signals
    wire        sampler_bit;
    wire        sampler_bit_valid;
    wire        start_edge;
    reg         sampler_enable;
    
    // New signals
    wire [$clog2(OVERSAMPLE)-1:0] tick_cntr;
    wire        rx_sync_line;
    
    reg         sipo_shift_en;
    reg         sipo_clear;
    wire [DATASIZE-1:0] sipo_data;
    
    assign o_rx_data = sipo_data;
    wire calc_parity;

    // Additional Error Detection Signals
    reg r_frame_err;
    reg r_parity_err;
    
    assign o_rx_frame_err   = r_frame_err;
    assign o_rx_parity_err  = r_parity_err;



    // Instantiations =========================================================

    // Sampler ----------------------------------------------------------------
    sampler #(.OVERSAMPLE(OVERSAMPLE)) u_sampler (
        .i_clk(i_clk), .i_rst_n(i_rst_n), .i_tick(i_tick),
        .i_enable(sampler_enable), .i_rx_line(i_rx_line),
        .o_bit(sampler_bit), .o_bit_valid(sampler_bit_valid), .o_start_edge(start_edge),
        .o_tick_cntr(tick_cntr), .o_rx_sync(rx_sync_line)
    );

    // SIPO -------------------------------------------------------------------
    sipo #(.DATASIZE(DATASIZE)) u_sipo (
        .i_clk(i_clk), .i_rst_n(i_rst_n),
        .i_clear(sipo_clear),
        .i_shift_en(sipo_shift_en), .i_bit(sampler_bit),
        .o_data(sipo_data)
    );

    // Parity generator -------------------------------------------------------
    // (if required)
    generate
        if (PARITY == "EVEN" || PARITY == "ODD" ) begin : gen_parity_block
            
            // parity_gen.v
            parity_gen # (.PARITY(PARITY)) u_parity_calc (
                .i_clk      (i_clk),
                .i_rst_n    (i_rst_n),

                .i_clear    (rx_state == RX_IDLE), 
                .i_en       (rx_state == RX_DATA && sampler_bit_valid),
                .i_bit      (sampler_bit),

                .o_parity   (calc_parity)
            );

        end else begin : gen_no_parity
            assign calc_parity = 1'b0;
        end
    endgenerate


    // Rx core logic ==========================================================

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            rx_state        <= RX_IDLE;
            bit_cntr        <= 0;
            stop_cntr       <= 0;
            o_rx_done       <= 0;
            r_frame_err     <= 0;
            r_parity_err    <= 0;
            sampler_enable  <= 0;
            sipo_shift_en   <= 0;
            sipo_clear      <= 0;

        end else if (!i_rx_enable) begin
            rx_state        <= RX_IDLE;
            bit_cntr        <= 0;
            stop_cntr       <= 0;
            o_rx_done       <= 0;
            r_frame_err     <= 0;
            r_parity_err    <= 0;
            sampler_enable  <= 0;
            sipo_shift_en   <= 0;
            sipo_clear      <= 0;

        end else begin
            o_rx_done       <= 0;
            sipo_shift_en   <= 0;
            sipo_clear      <= 0;

            case(rx_state)

                // ------------------------------------------------------------
                RX_IDLE: begin
                    sampler_enable <= 0; 
                    bit_cntr       <= 0;
                    stop_cntr      <= 0;
                    
                    if (start_edge) begin
                        rx_state       <= RX_START;
                        sampler_enable <= 1;
                        sipo_clear     <= 1;
                        r_frame_err    <= 0;  // Clear errors on new frame start
                        r_parity_err   <= 0;
                    end
                end

                // ------------------------------------------------------------
                RX_START: begin
                    // False Start Bit Recovery
                    // Check at MIDSAMPLE (Tick 8 for OVERSAMPLE=16).
                    // If line is HIGH, it was a glitch. Abort.
                    if (tick_cntr == (OVERSAMPLE/2)) begin
                        if (rx_sync_line == 1'b1) begin
                             rx_state       <= RX_IDLE;
                             sampler_enable <= 0;
                        end
                    end
                
                    if (sampler_bit_valid) begin
                        if (sampler_bit == 1'b0) begin
                             rx_state <= RX_DATA;
                        end else begin
                             rx_state       <= RX_IDLE; 
                             sampler_enable <= 0;
                        end
                    end
                end

                // ------------------------------------------------------------
                RX_DATA: begin
                    if (sampler_bit_valid) begin
                        sipo_shift_en <= 1; 
                        if (bit_cntr == DATASIZE-1) begin
                            bit_cntr <= 0;
                            if (PARITY != "NONE") rx_state <= RX_PARITY;
                            else                  rx_state <= RX_STOP;
                        end else begin
                            bit_cntr <= bit_cntr + 1'b1;
                        end
                    end
                end

                // ------------------------------------------------------------
                RX_PARITY: begin

                    if (sampler_bit_valid) begin
                         if (sampler_bit != calc_parity) begin
                             r_parity_err <= 1'b1;
                         end
                         rx_state <= RX_STOP;
                    end

                end

                // ------------------------------------------------------------
                RX_STOP: begin
                     if (sampler_bit_valid) begin
                         if (sampler_bit != 1'b1) begin
                             r_frame_err <= 1;
                         end

                         if (stop_cntr == STOPBITS-1) begin
                             o_rx_done      <= 1;
                             rx_state       <= RX_IDLE;
                             sampler_enable <= 0;
                             stop_cntr      <= 0;
                         end else begin
                             stop_cntr <= stop_cntr + 1'b1;
                         end
                     end
                end
                
                // ------------------------------------------------------------
                default: rx_state <= RX_IDLE;

            endcase
        end
    end


endmodule