    task send_byte;
        input [7:0] data;
        input       force_parity_err;
        input       force_frame_err;
        
        integer i;
        reg     parity_bit;
        begin
            parity_bit = ^data; 
            if (force_parity_err) parity_bit = ~parity_bit;

            // START
            rx_line = 0;
            repeat(OVERSAMPLE) @(posedge tick);
            
            // DATA
            for(i=0; i<8; i=i+1) begin
                rx_line = data[i];
                repeat(OVERSAMPLE) @(posedge tick);
            end
            
            // PARITY
            rx_line = parity_bit;
            repeat(OVERSAMPLE) @(posedge tick);
            
            // STOP
            if (force_frame_err) rx_line = 0;
            else                 rx_line = 1;
            repeat(OVERSAMPLE) @(posedge tick);
            
            // IDLE
            rx_line = 1;
            repeat(OVERSAMPLE) @(posedge tick);
        end
    endtask
