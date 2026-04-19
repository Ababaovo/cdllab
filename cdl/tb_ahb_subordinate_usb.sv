`timescale 1ns / 10ps
/* verilator coverage_off */
module tb_ahb_subordinate_usb ();

   localparam CLK_PERIOD = 10ns;
   localparam TIMEOUT = 1000;

   localparam BURST_SINGLE = 3'd0;
   localparam BURST_INCR   = 3'd1;
   localparam BURST_WRAP4  = 3'd2;
   localparam BURST_INCR4  = 3'd3;
   localparam BURST_WRAP8  = 3'd4;
   localparam BURST_INCR8  = 3'd5;
   localparam BURST_WRAP16 = 3'd6;
   localparam BURST_INCR16 = 3'd7;

   initial begin
       $dumpfile("waveform.fst");
       $dumpvars;
   end


   logic clk, n_rst;

   //clockgen
   always begin
       clk = 0;
       #(CLK_PERIOD / 2.0);
       clk = 1;
       #(CLK_PERIOD / 2.0);
   end

   task reset_dut;
   begin
       n_rst = 0;
       @(posedge clk);
       @(posedge clk);
       @(negedge clk);
       n_rst = 1;
       @(negedge clk);
       @(negedge clk);
   end
   endtask


   logic hsel;
   logic [3:0] haddr;
   logic [2:0] hsize;
   logic [2:0] hburst;
   logic [1:0] htrans;
   logic hwrite;
   logic [31:0] hwdata;
   logic [31:0] hrdata;
   logic hresp;
   logic hready;
   string test_name;


   //bus model connections
   ahb_model_updated #(
       .ADDR_WIDTH(4),
       .DATA_WIDTH(4)
   ) BFM (
       .clk(clk),
       .hsel(hsel),
       .haddr(haddr),
       .hsize(hsize),
       .htrans(htrans),
       .hburst(hburst),
       .hwrite(hwrite),
       .hwdata(hwdata),
       .hrdata(hrdata),
       .hresp(hresp),
       .hready(hready)
   );


   // Supporting Tasks
   task reset_model;
       BFM.reset_model();
   endtask


   // Read from a register without checking the value
   task enqueue_poll ( input logic [3:0] addr, input logic [1:0] size );
       logic [31:0] data [];
   begin
       data = new [1];
       data[0] = {32'hXXXX};
       //              Fields: hsel,  R/W, addr, data, exp err,         size, burst, chk prdata or not
       BFM.enqueue_transaction(1'b1, 1'b0, addr, data,    1'b0, {1'b0, size},  3'b0,            1'b0);
   end
   endtask


   // Read from a register until a requested value is observed
   task poll_until ( input logic [3:0] addr, input logic [1:0] size, input logic [31:0] data);
       int iters;
   begin
       for (iters = 0; iters < TIMEOUT; iters++) begin
           enqueue_poll(addr, size);
           execute_transactions(1);
           if(BFM.get_last_read() == data) break;
       end
       if(iters >= TIMEOUT) begin
           $error("Bus polling timeout hit.");
       end
   end
   endtask


   // Read Transaction, verifying a specific value is read
   task enqueue_read(input logic [3:0] addr, input logic [1:0] size, input logic [31:0] exp_read);
       logic [31:0] data [];
   begin
       data = new [1];
       data[0] = exp_read;
       BFM.enqueue_transaction(1'b1, 1'b0, addr, data, 1'b0, {1'b0, size}, BURST_SINGLE, 1'b1);
   end
   endtask


   task enqueue_write(input logic [3:0] addr, input logic [1:0] size, input logic [31:0] wdata);
       logic [31:0] data [];
   begin
       data = new [1];
       data[0] = wdata;
       BFM.enqueue_transaction(1'b1, 1'b1, addr, data, 1'b0, {1'b0, size}, BURST_SINGLE, 1'b0);
   end
   endtask


   // Write Transaction Intended for a different subordinate from yours
   task enqueue_fakewrite(input logic [3:0] addr, input logic [1:0] size, input logic [31:0] wdata);
       logic [31:0] data [];
   begin
       data = new [1];
       data[0] = wdata;
       BFM.enqueue_transaction(1'b0, 1'b1, addr, data, 1'b0, {1'b0, size}, BURST_SINGLE, 1'b0);
   end
   endtask


   // Create a burst read of size based on the burst type.
   // If INCR, burst size dependent on dynamic array size
   task enqueue_burst_read ( input logic [3:0] base_addr, input logic [1:0] size, input logic [2:0] burst, input logic [31:0] data [] );
       BFM.enqueue_transaction(1'b1, 1'b0, base_addr, data, 1'b0, {1'b0, size}, burst, 1'b1);
   endtask


   // Create a burst write of size based on the burst type.
   task enqueue_burst_write ( input logic [3:0] base_addr, input logic [1:0] size, input logic [2:0] burst, input logic [31:0] data [] );
       BFM.enqueue_transaction(1'b1, 1'b1, base_addr, data, 1'b0, {1'b0, size}, burst, 1'b1);
   endtask


   task execute_transactions(input int num_transactions);
       BFM.run_transactions(num_transactions);
   endtask


   task finish_transactions();
       BFM.wait_done();
   endtask


   logic [2:0] rx_packet;
   logic rx_data_ready;
   logic rx_transfer_active;
   logic rx_error;
   logic [7:0] rx_data;
   logic get_rx_data;
   logic [6:0] buffer_occupancy;
   logic store_tx_data;
   logic [7:0] tx_data;
   logic clear;
   logic [2:0] tx_packet;
   logic tx_transfer_active;
   logic tx_error;
   logic d_mode;


   logic [7:0] fifo_mem [0:63];
   integer i;
   logic [31:0] tx_ctrl_baseline;


   ahb_subordinate_usb DUT (
       .clk(clk),
       .n_rst(n_rst),
       .hsel(hsel),
       .haddr(haddr),
       .hsize(hsize),
       .hburst(hburst),
       .htrans(htrans),
       .hwrite(hwrite),
       .hwdata(hwdata),
       .hrdata(hrdata),
       .hresp(hresp),
       .hready(hready),
       .rx_packet(rx_packet),
       .rx_data_ready(rx_data_ready),
       .rx_transfer_active(rx_transfer_active),
       .rx_error(rx_error),
       .rx_data(rx_data),
       .get_rx_data(get_rx_data),
       .buffer_occupancy(buffer_occupancy),
       .store_tx_data(store_tx_data),
       .tx_data(tx_data),
       .clear(clear),
       .tx_packet(tx_packet),
       .tx_transfer_active(tx_transfer_active),
       .tx_error(tx_error),
       .d_mode(d_mode)
   );


   always_ff @(posedge clk or negedge n_rst) begin
       if (!n_rst) begin
           buffer_occupancy <= 7'd0;
           rx_data <= 8'h00;
           for (i = 0; i < 64; i = i + 1)
               fifo_mem[i] <= 8'h00;
       end else begin
           if (clear) begin
               buffer_occupancy <= 7'd0;
               rx_data <= 8'h00;
           end else begin
               if (store_tx_data) begin
                   fifo_mem[buffer_occupancy] <= tx_data;
                   buffer_occupancy <= buffer_occupancy + 7'd1;
               end
               if (get_rx_data && (buffer_occupancy != 7'd0)) begin
                   for (i = 0; i < 63; i = i + 1)
                       fifo_mem[i] <= fifo_mem[i+1];
                   buffer_occupancy <= buffer_occupancy - 7'd1;
               end
               if (buffer_occupancy != 7'd0)
                   rx_data <= fifo_mem[0];
               else
                   rx_data <= 8'h00;
           end
       end
   end


   initial begin
       n_rst = 1'b1;
       rx_packet = 3'd0;
       rx_data_ready = 1'b0;
       rx_transfer_active = 1'b0;
       rx_error = 1'b0;
       tx_transfer_active = 1'b0;
       tx_error = 1'b0;


       reset_model();

       // 1) Reset / default state
       test_name = "Reset / Default State";
       reset_dut();
       enqueue_read(4'h4, 2'd1, 32'h0000_0000); // status
       enqueue_read(4'h6, 2'd1, 32'h0000_0000); // error
       enqueue_read(4'h8, 2'd0, 32'h0000_0000); // occupancy
       execute_transactions(3);
       finish_transactions();


       // 2) Status register mapping
       test_name = "Status Register Read";
       reset_dut();
       rx_packet = 3'd7; @(posedge clk); // IN
       rx_packet = 3'd6; @(posedge clk); // OUT
       rx_packet = 3'd3; @(posedge clk); // ACK
       rx_packet = 3'd1; @(posedge clk); // DATA0
       rx_packet = 3'd2; @(posedge clk); // DATA1
       rx_packet = 3'd0;
       rx_transfer_active = 1'b1;
       tx_transfer_active = 1'b1;
       enqueue_read(4'h4, 2'd1, 32'h0000_033E);
       execute_transactions(1);
       finish_transactions();
       rx_transfer_active = 1'b0;
       tx_transfer_active = 1'b0;


       // 3) Error register mapping
       test_name = "Error Register Read";
       reset_dut();
       rx_error = 1'b1; tx_error = 1'b1;
       @(posedge clk);
       rx_error = 1'b0; tx_error = 1'b0;
       enqueue_read(4'h6, 2'd1, 32'h0000_0101);
       execute_transactions(1);
       finish_transactions();


       // 4) Buffer BYTE write
       test_name = "Buffer BYTE Write";
       reset_dut();
       enqueue_write(4'h0, 2'd0, 32'h0000_00AA);
       execute_transactions(1);
       finish_transactions();
       enqueue_read(4'h8, 2'd0, 32'h0000_0001);
       execute_transactions(1);
       finish_transactions();


       // 5) Buffer HALFWORD write
       test_name = "Buffer HALFWORD Write";
       reset_dut();
       enqueue_write(4'h0, 2'd1, 32'h0000_2211);
       execute_transactions(1);
       finish_transactions();
       enqueue_read(4'h8, 2'd0, 32'h0000_0002);
       execute_transactions(1);
       finish_transactions();


       // 6) Buffer WORD write
       test_name = "Buffer WORD Write";
       reset_dut();
       enqueue_write(4'h0, 2'd2, 32'h4433_2211);
       execute_transactions(1);
       finish_transactions();
       enqueue_read(4'h8, 2'd0, 32'h0000_0004);
       execute_transactions(1);
       finish_transactions();


       // 7) Occupancy read after mixed writes
       test_name = "Occupancy Read";
       reset_dut();
       enqueue_write(4'h0, 2'd0, 32'h0000_00AA); // +1
       enqueue_write(4'h0, 2'd1, 32'h0000_BBCC); // +2
       enqueue_write(4'h0, 2'd2, 32'h4433_2211); // +4
       execute_transactions(3);
       finish_transactions();
       enqueue_read(4'h8, 2'd0, 32'h0000_0007);  // total 7
       execute_transactions(1);
       finish_transactions();


       // 8) Buffer BYTE read
       test_name = "Buffer BYTE Read";
       reset_dut();
       enqueue_write(4'h0, 2'd0, 32'h0000_00AB);
       execute_transactions(1);
       finish_transactions();
       enqueue_read (4'h0, 2'd0, 32'h0000_00AB);
       enqueue_read (4'h8, 2'd0, 32'h0000_0000);
       execute_transactions(2);
       finish_transactions();


       // 9) Buffer HALFWORD read
       test_name = "Buffer HALFWORD Read";
       reset_dut();
       enqueue_write(4'h0, 2'd1, 32'h0000_2211);
       execute_transactions(1);
       finish_transactions();
       enqueue_read (4'h0, 2'd1, 32'h0000_2211);
       enqueue_read (4'h8, 2'd0, 32'h0000_0000);
       execute_transactions(2);
       finish_transactions();


       // 10) Buffer WORD read
       test_name = "Buffer WORD Read";
       reset_dut();
       enqueue_write(4'h0, 2'd2, 32'h4433_2211);
       execute_transactions(1);
       finish_transactions();
       enqueue_read (4'h0, 2'd2, 32'h4433_2211);
       enqueue_read (4'h8, 2'd0, 32'h0000_0000);
       execute_transactions(2);
       finish_transactions();


       // 11) Byte-lane alignment (0x0..0x3)
       test_name = "Byte-Lane Alignment";
       reset_dut();
       enqueue_write(4'h0, 2'd0, 32'h0000_0011);
       enqueue_write(4'h1, 2'd0, 32'h0000_0022);
       enqueue_write(4'h2, 2'd0, 32'h0000_0033);
       enqueue_write(4'h3, 2'd0, 32'h0000_0044);
       execute_transactions(4);
       finish_transactions();
       enqueue_read (4'h0, 2'd2, 32'h4433_2211);
       execute_transactions(1);
       finish_transactions();


       // 12) TX control write path (1..5 => DATA0, DATA1, ACK, NAK, STALL)
       test_name = "TX Control WRITE";
       reset_dut();
       enqueue_write(4'hC, 2'd0, 32'h0000_0001);
       enqueue_read (4'hC, 2'd0, 32'h0000_0001);
       enqueue_write(4'hC, 2'd0, 32'h0000_0002);
       enqueue_read (4'hC, 2'd0, 32'h0000_0002);
       enqueue_write(4'hC, 2'd0, 32'h0000_0003);
       enqueue_read (4'hC, 2'd0, 32'h0000_0003);
       enqueue_write(4'hC, 2'd0, 32'h0000_0004);
       enqueue_read (4'hC, 2'd0, 32'h0000_0004);
       enqueue_write(4'hC, 2'd0, 32'h0000_0005);
       enqueue_read (4'hC, 2'd0, 32'h0000_0005);
       execute_transactions(10);
       finish_transactions();


       // 13) Flush buffer write path
       test_name = "Flush Buffer WRITE";
       reset_dut();
       enqueue_write(4'h0, 2'd2, 32'h4433_2211);
       execute_transactions(1);
       finish_transactions();
       enqueue_read (4'h8, 2'd0, 32'h0000_0004);
       execute_transactions(1);
       finish_transactions();
       enqueue_write(4'hD, 2'd0, 32'h0000_0001);
       execute_transactions(1);
       finish_transactions();
       poll_until(4'h8, 2'd0, 32'h0000_0000);


       // hsel=0 behavior (kept from earlier debug)
       test_name = "Ignore Unselected Write";
       reset_dut();
       enqueue_poll(4'hC, 2'd0);
       execute_transactions(1);
       finish_transactions();
       tx_ctrl_baseline = BFM.get_last_read();
       enqueue_fakewrite(4'hC, 2'd0, 32'h0000_0005);
       enqueue_read(4'hC, 2'd0, tx_ctrl_baseline);
       execute_transactions(2);
       finish_transactions();


       // 14) Controlled illegal-access demo (explicit error expected)
       // Invalid write: status register is read-only
       test_name = "Illegal Access - Invalid Write";
       data = new [1];
       data[0] = 32'h0000_00AA;
       BFM.enqueue_transaction(1'b1, 1'b1, 4'h4, data, 1'b1, {1'b0, 2'd0}, BURST_SINGLE, 1'b0);
       execute_transactions(1);
       finish_transactions();

       // Invalid read: halfword read from occupancy register is unsupported
       test_name = "Illegal Access - Invalid Read";
       data = new [1];
       data[0] = 32'h0000_0000;
       BFM.enqueue_transaction(1'b1, 1'b0, 4'h8, data, 1'b1, {1'b0, 2'd1}, BURST_SINGLE, 1'b0);
       execute_transactions(1);
       finish_transactions();

       // Sanity check after illegal transactions: subordinate still responds normally
       test_name = "Post-Error Recovery";
       enqueue_read(4'h8, 2'd0, 32'h0000_0000);
       execute_transactions(1);
       finish_transactions();

       $finish;
   end
endmodule
/* verilator coverage_on */




