
`timescale 1ns / 10ps

module controller (
    input  logic        clk,
    input  logic        n_rst,
    input  logic        bit_tick,
    input  logic [2:0]  tx_packet,
    input  logic [6:0]  buffer_occupancy,
    input  logic [7:0]  TX_Packet_Data,
    output logic [7:0]  load_byte,
    output logic        load_new_byte,
    output logic        get_tx_packet_data,
    output logic        tx_transfer_active,
    output logic        tx_error,
    output logic        eop_active
);

    typedef enum logic [2:0] {
        IDLE = 3'd0,
        SYNC = 3'd1,
        PID  = 3'd2,
        DATA = 3'd3,
        CRC  = 3'd4,
        EOP  = 3'd5,
        DONE = 3'd6
    } state_t;

    state_t state, next_state;

    logic [3:0] bit_counter, next_bit_counter;
    logic       bit_counter_reset;
    logic       crc_byte_count, next_crc_byte_count;


    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            state <= IDLE;
        else if (bit_tick)
            state <= next_state;
    end

    
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            bit_counter <= 4'd0;
        else
            bit_counter <= next_bit_counter;
    end

    
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            crc_byte_count <= 1'b0;
        else
            crc_byte_count <= next_crc_byte_count;
    end

   
    always_comb begin
        if (bit_counter_reset)
            next_bit_counter = 4'd0;
        else if (bit_tick)
            next_bit_counter = bit_counter + 4'd1;
        else
            next_bit_counter = bit_counter;
    end

    
    always_comb begin
        next_crc_byte_count = crc_byte_count;
        if (state != CRC)
            next_crc_byte_count = 1'b0;
        else if (bit_tick && bit_counter == 4'd7)
            next_crc_byte_count = crc_byte_count + 1'b1;
    end

    
    logic [7:0] pid_byte;
    always_comb begin
        case (tx_packet)
            3'd1:    pid_byte = 8'b11000011; // DATA0
            3'd2:    pid_byte = 8'b11010100; // DATA1
            3'd3:    pid_byte = 8'b01001011; // ACK
            3'd4:    pid_byte = 8'b01011010; // NAK
            3'd5:    pid_byte = 8'b00011110; // STALL
            default: pid_byte = 8'd0;
        endcase
    end

  
    always_comb begin
        next_state         = state;
        load_byte          = 8'd0;
        load_new_byte      = 1'b0;
        get_tx_packet_data = 1'b0;
        tx_transfer_active = 1'b0;
        tx_error           = 1'b0;
        eop_active         = 1'b0;
        bit_counter_reset  = 1'b0;

        case (state)

            IDLE: begin
                if (tx_packet != 3'd0 && bit_tick) begin
                    bit_counter_reset = 1'b1;
                    next_state        = SYNC;
                    load_new_byte      = 1'b1;
                end
            end

            SYNC: begin
                tx_transfer_active = 1'b1;
                load_byte          = 8'b00000001;
                
                if (bit_tick && bit_counter == 4'd7) begin
                    bit_counter_reset = 1'b1;
                    next_state        = PID;
                    load_byte          = pid_byte;
                    load_new_byte      = 1'b1;
                end
            end

            PID: begin
                tx_transfer_active = 1'b1;
                load_byte          = pid_byte;
                
                if (bit_tick && bit_counter == 4'd7) begin
                    bit_counter_reset = 1'b1;
                    if (tx_packet == 3'd1 || tx_packet == 3'd2) begin
                        get_tx_packet_data = 1'b1;
                        next_state         = DATA;
                        load_byte          = TX_Packet_Data;
                        load_new_byte      = 1'b1;
                    end else begin
                        next_state = EOP;
                    end
                end
            end

            DATA: begin
                tx_transfer_active = 1'b1;
                load_byte          = TX_Packet_Data;
                
                if (bit_tick && bit_counter == 4'd7) begin
                    bit_counter_reset = 1'b1;
                    if (buffer_occupancy == 7'd0) begin
                        next_state = CRC;
                        load_byte          = 8'hFF;
                        load_new_byte      = 1'b1;
                    end else begin
                        get_tx_packet_data = 1'b1;
                        load_byte          = TX_Packet_Data;
                        load_new_byte      = 1'b1;
                    end
                end
            end

            CRC: begin
                tx_transfer_active = 1'b1;
                load_byte          = 8'hFF;
                
                if (bit_tick && bit_counter == 4'd7) begin
                    bit_counter_reset = 1'b1;
                    if (crc_byte_count == 1'b0) begin
                        // first CRC byte done, stay for second
                        load_new_byte      = 1'b1;
                        load_byte = 8'hFF;
                    end else begin
                        next_state = EOP;
                    end
                end
            end

        
            EOP: begin
                tx_transfer_active = 1'b1;
                eop_active         = 1'b1;
                if (bit_tick && bit_counter == 4'd2) begin
                    next_state        = DONE;
                    bit_counter_reset = 1'b1;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end

        endcase
    end

endmodule
