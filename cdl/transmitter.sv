`timescale 1ns / 10ps

module transmitter (
    input  logic        clk,
    input  logic        n_rst,

    // from data buffer
    input  logic [7:0]  TX_Packet_Data,
    input  logic [6:0]  buffer_occupancy,

  
    input  logic [2:0]  tx_packet,

 
    output logic        get_tx_packet_data,


    output logic        tx_transfer_active,
    output logic        tx_error,

    // USB wire outputs
    output logic        dp_out,
    output logic        dm_out
);

    logic        bit_tick;
    logic        load_new_byte;
    logic [7:0]  load_byte;
    logic        eop_active;
    logic        current_bit;
    logic        line_state;
    logic        next_line_state;
    logic [3:0]  adjust_count_out;

    logic [3:0] rollover_val;

    always_comb begin
        if (adjust_count_out == 4'd2)
            rollover_val = 4'd9;
        else
            rollover_val = 4'd8;
    end
    
    flex_counter #(.SIZE(4)) adjust_counter (
        .clk          (clk),
        .n_rst        (n_rst),
        .clear        (1'b0),
        .count_enable (bit_tick),
        .rollover_val (4'd3),
        .count_out    (adjust_count_out),
        .rollover_flag()
    );

    
    flex_counter #(.SIZE(4)) bit_clock (
        .clk          (clk),
        .n_rst        (n_rst),
        .clear        (1'b0),
        .count_enable (1'b1),
        .rollover_val (rollover_val),
        .count_out    (),
        .rollover_flag(bit_tick)
    );


    flex_sr #(.SIZE(8), .MSB_FIRST(0)) shift_reg (
        .clk          (clk),
        .n_rst        (n_rst),
        .shift_enable (bit_tick),
        .load_enable  (load_new_byte),
        .serial_in    (1'b0),
        .parallel_in  (load_byte),
        .serial_out   (current_bit),
        .parallel_out ()
    );

    controller controller_inst (
        .clk               (clk),
        .n_rst             (n_rst),
        .bit_tick          (bit_tick),
        .tx_packet         (tx_packet),
        .buffer_occupancy  (buffer_occupancy),
        .TX_Packet_Data    (TX_Packet_Data),
        .load_byte         (load_byte),
        .load_new_byte     (load_new_byte),
        .get_tx_packet_data(get_tx_packet_data),
        .tx_transfer_active(tx_transfer_active),
        .tx_error          (tx_error),
        .eop_active        (eop_active)
    );

  
    always_comb begin
        if (eop_active)
            next_line_state = line_state;
        else if (bit_tick)
            next_line_state = dp_out;
        else
            next_line_state = line_state;
    end

 
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            line_state <= 1'b1;
        else
            line_state <= next_line_state;
    end

    
    always_comb begin
        if (eop_active) begin
            dp_out = 1'b0;
            dm_out = 1'b0;
        end else if (current_bit == 1'b0) begin
            dp_out = ~line_state;
            dm_out = line_state;
        end else begin
            dp_out = line_state;
            dm_out = ~line_state;
        end
    end

endmodule
