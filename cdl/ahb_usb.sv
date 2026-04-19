`timescale 1ns / 10ps

// Course manual recommended name/file for the USB peripheral top (USB.pdf A.1).
// Same hierarchy as `top_level` so TB hierarchical references (e.g. u_top.data_buf) resolve.
module ahb_usb (
    input  logic        clk,
    input  logic        n_rst,

    input  logic        hsel,
    input  logic [3:0]  haddr,
    input  logic [2:0]  hsize,
    input  logic [2:0]  hburst,
    input  logic [1:0]  htrans,
    input  logic        hwrite,
    input  logic [31:0] hwdata,
    output logic [31:0] hrdata,
    output logic        hresp,
    output logic        hready,

    input  logic        dp_in,
    input  logic        dm_in,
    output logic        dp_out,
    output logic        dm_out,
    output logic        d_mode
);

    logic        store_tx_data;
    logic [7:0]  tx_data;
    logic        get_rx_data;
    logic        clear;
    logic [2:0]  tx_packet;
    logic        get_tx_packet_data;
    logic [7:0]  TX_Packet_Data;
    logic [6:0]  buffer_occupancy;
    logic [7:0]  rx_data;
    logic        store_rx_packet_data;
    logic [7:0]  rx_packet_data;
    logic        flush;
    logic [2:0]  rx_packet;
    logic        rx_data_ready;
    logic        rx_transfer_active;
    logic        rx_error;
    logic        tx_transfer_active;
    logic        tx_error;

    ahb_subordinate_usb ahb_sub (
        .clk                (clk),
        .n_rst              (n_rst),
        .hsel               (hsel),
        .haddr              (haddr),
        .hsize              (hsize),
        .hburst             (hburst),
        .htrans             (htrans),
        .hwrite             (hwrite),
        .hwdata             (hwdata),
        .hrdata             (hrdata),
        .hresp              (hresp),
        .hready             (hready),
        .rx_packet          (rx_packet),
        .rx_data_ready      (rx_data_ready),
        .rx_transfer_active (rx_transfer_active),
        .rx_error           (rx_error),
        .rx_data            (rx_data),
        .buffer_occupancy   (buffer_occupancy),
        .tx_transfer_active (tx_transfer_active),
        .tx_error           (tx_error),
        .get_rx_data        (get_rx_data),
        .store_tx_data      (store_tx_data),
        .tx_data            (tx_data),
        .clear              (clear),
        .tx_packet          (tx_packet),
        .d_mode             (d_mode)
    );

    data_buffer data_buf (
        .clk                  (clk),
        .n_rst                (n_rst),
        .store_tx_data        (store_tx_data),
        .tx_data              (tx_data),
        .get_rx_data          (get_rx_data),
        .store_rx_packet_data (store_rx_packet_data),
        .rx_packet_data       (rx_packet_data),
        .get_tx_packet_data   (get_tx_packet_data),
        .flush                (flush),
        .clear                (clear),
        .rx_data              (rx_data),
        .tx_packet_data       (TX_Packet_Data),
        .buffer_occupancy     (buffer_occupancy)
    );

    transmitter tx_inst (
        .clk                (clk),
        .n_rst              (n_rst),
        .TX_Packet_Data     (TX_Packet_Data),
        .buffer_occupancy   (buffer_occupancy),
        .tx_packet          (tx_packet),
        .get_tx_packet_data (get_tx_packet_data),
        .tx_transfer_active (tx_transfer_active),
        .tx_error           (tx_error),
        .dp_out             (dp_out),
        .dm_out             (dm_out)
    );

    usb_rx rx_inst (
        .clk                  (clk),
        .n_rst                (n_rst),
        .dp_in                (dp_in),
        .dm_in                (dm_in),
        .buffer_occupancy     (buffer_occupancy),
        .rx_data_ready        (rx_data_ready),
        .rx_transfer_active   (rx_transfer_active),
        .rx_error             (rx_error),
        .flush                (flush),
        .store_rx_packet_data (store_rx_packet_data),
        .rx_packet            (rx_packet),
        .rx_packet_data       (rx_packet_data)
    );

endmodule
