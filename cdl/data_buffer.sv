`timescale 1ns / 10ps

module data_buffer (
    input  logic        clk,
    input  logic        n_rst,

    input  logic        store_tx_data,
    input  logic [7:0]  tx_data,

    input  logic        get_rx_data,

    input  logic        store_rx_packet_data,
    input  logic [7:0]  rx_packet_data,
    input  logic        get_tx_packet_data,

    input  logic        flush,
    input  logic        clear,

    output logic [7:0]  rx_data,
    output logic [7:0]  tx_packet_data,
    output logic [6:0]  buffer_occupancy
);

    logic [5:0]  write_ptr, read_ptr;
    logic [5:0]  next_write_ptr, next_read_ptr;
    logic [6:0]  occupancy, next_occupancy;
    logic        write_en, read_en, flush_en;
    logic [7:0]  write_data;
    logic [7:0]  buffer      [0:63];
    logic [7:0]  next_buffer [0:63];

    always_comb begin
        write_data     = '0;
        write_en       = 1'b0;
        read_en        = 1'b0;
        flush_en       = 1'b0;
        next_write_ptr = write_ptr;
        next_read_ptr  = read_ptr;
        next_occupancy = occupancy;
        next_buffer    = buffer;

        if (store_tx_data)
            write_data = tx_data;
        else
            write_data = rx_packet_data;

        write_en = (store_tx_data | store_rx_packet_data)
                   && (occupancy != 7'd64);

        read_en = (get_rx_data | get_tx_packet_data)
                  && (occupancy != 7'd0);

        flush_en = clear | flush;

        if (flush_en) begin
            next_write_ptr = 6'd0;
            next_read_ptr  = 6'd0;
            next_occupancy = 7'd0;
            next_buffer    = buffer;
        end else begin
            if (write_en) begin
                next_buffer[write_ptr] = write_data;
                next_write_ptr = (write_ptr == 6'd63) ? 6'd0 : write_ptr + 6'd1;
            end
            if (read_en) begin
                next_read_ptr = (read_ptr == 6'd63) ? 6'd0 : read_ptr + 6'd1;
            end
            if (write_en && !read_en)
                next_occupancy = occupancy + 7'd1;
            else if (read_en && !write_en)
                next_occupancy = occupancy - 7'd1;
            else
                next_occupancy = occupancy;
        end
    end

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            buffer <= '{default: '0};
        else
            buffer <= next_buffer;
    end

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            write_ptr <= 6'd0;
        else
            write_ptr <= next_write_ptr;
    end

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            read_ptr <= 6'd0;
        else
            read_ptr <= next_read_ptr;
    end

    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst)
            occupancy <= 7'd0;
        else
            occupancy <= next_occupancy;
    end

    assign rx_data          = buffer[read_ptr];
    assign tx_packet_data   = buffer[read_ptr];
    assign buffer_occupancy = occupancy;

endmodule
