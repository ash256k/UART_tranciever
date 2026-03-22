(* top *) module main #(
    parameter CLOCKFREQ = 50_000_000,
    parameter BAUDRATE  = 9600
)(
    // Only absolute necessary platform pins
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) input i_rst, // Reset pin from RP2040
    (* iopad_external_pin *) output clk_en,
    (* iopad_external_pin *) output clk_en_en, // Output enable for clk_en
    
    // UART Physical Pins
    (* iopad_external_pin *) input  rx_pin,
    (* iopad_external_pin *) output tx_pin,
    (* iopad_external_pin *) output tx_pin_en, // Output enable for tx_pin

    // Debug LED
    (* iopad_external_pin *) output rx_done_led,
    (* iopad_external_pin *) output rx_done_led_en
);

    // Platform enables pulled HIGH
    assign clk_en         = 1'b1;
    assign clk_en_en      = 1'b1;
    assign tx_pin_en      = 1'b1;
    assign rx_done_led_en = 1'b1;

    // Pulse stretcher for LED 
    wire rx_done_pulse;
    reg [23:0] pulse_extender;
    assign rx_done_led = (pulse_extender != 0);

    always @(posedge clk) begin
        if (rx_done_pulse) begin
            pulse_extender <= 24'hFFFFFF; // ~0.3s at 50MHz
        end else if (pulse_extender != 0) begin
            pulse_extender <= pulse_extender - 1'b1;
        end
    end

    // Instantiate the loopback module with hardwired enables
    loopback #(
        .CLOCKFREQ  (CLOCKFREQ), 
        .BAUDRATE   (BAUDRATE),
        .DATASIZE   (8),
        .PARITY     ("NONE"),
        .STOPBITS   (1),
        .OVERSAMPLE (16)
    ) u_loopback (
        .i_clk          (clk),
        .i_rst_n        (~i_rst), // Active-low internally    
        .i_rx_en        (1'b1),    
        .i_rx_line      (rx_pin),
        .o_tx_line      (tx_pin),
        
        .o_rx_done       (rx_done_pulse),
        .o_rx_frame_err  (),
        .o_rx_parity_err (),
        .o_tx_busy       ()
    );

endmodule
