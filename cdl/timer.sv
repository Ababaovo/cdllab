`timescale 1ns / 10ps

module timer (input logic clk, n_rst, enable_timer, input logic [4:0] data_size, input logic [13:0] bit_period, output logic shift_strobe, packet_done);

    logic rollover_en;
    logic [13:0] unused1; 
    logic [4:0] unused2, rollover_val_data_size;

    assign rollover_val_data_size = data_size + 1;

    flex_counter #(.SIZE(14)) counter1 (
        .clk(clk),
        .n_rst(n_rst),
        .clear(~enable_timer),  
        .count_enable(enable_timer),
        .rollover_val(bit_period),
        .count_out(unused1),
        .rollover_flag(rollover_en));


    flex_counter #(.SIZE(5)) counter2 (
        .clk(clk),
        .n_rst(n_rst),
        .clear(~enable_timer),  
        .count_enable(rollover_en),
        .rollover_val(rollover_val_data_size),
        .count_out(unused2),
        .rollover_flag(packet_done));

    assign shift_strobe = rollover_en;

endmodule
