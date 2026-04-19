`timescale 1ns / 10ps
module ahb_subordinate_usb (
   input logic clk,
   input logic n_rst,
   input logic hsel,
   input logic [3:0] haddr,
   input logic [2:0] hsize,
   input logic [2:0] hburst,
   input logic [1:0] htrans,
   input logic hwrite,
   input logic [31:0] hwdata,
   input logic [2:0] rx_packet,
   input logic rx_data_ready,
   input logic rx_transfer_active,
   input logic rx_error,
   input logic [7:0] rx_data,
   input logic [6:0] buffer_occupancy,
   input logic tx_transfer_active,
   input logic tx_error,
   output logic [31:0] hrdata,
   output logic hresp,
   output logic hready,
   output logic get_rx_data,
   output logic store_tx_data,
   output logic [7:0] tx_data,
   output logic clear,
   output logic [2:0] tx_packet,
   output logic d_mode
);

   localparam [1:0] HTRANS_IDLE   = 2'b00;
   localparam [1:0] HTRANS_NONSEQ = 2'b10;
   localparam [2:0] BURST_SINGLE  = 3'd0;

   localparam [2:0] SIZE_BYTE     = 3'd0;
   localparam [2:0] SIZE_HALFWORD = 3'd1;
   localparam [2:0] SIZE_WORD     = 3'd2;

   // Internal rx_packet encodings (must match control_fsm.sv)
   localparam [2:0] PID_DATA0 = 3'b001;
   localparam [2:0] PID_DATA1 = 3'b010;
   localparam [2:0] PID_ACK   = 3'b011;
   localparam [2:0] PID_OUT   = 3'b110;
   localparam [2:0] PID_IN    = 3'b111;

   localparam [2:0] TX_NONE   = 3'd0;
   localparam [2:0] TX_DATA0  = 3'd1;
   localparam [2:0] TX_DATA1  = 3'd2;
   localparam [2:0] TX_ACK    = 3'd3;
   localparam [2:0] TX_NAK    = 3'd4;
   localparam [2:0] TX_STALL  = 3'd5;

   localparam [2:0] ST_IDLE      = 3'd0;
   localparam [2:0] ST_ERR_1     = 3'd1;
   localparam [2:0] ST_ERR_2     = 3'd2;
   localparam [2:0] ST_BUF_WRITE = 3'd3;
   localparam [2:0] ST_BUF_READ  = 3'd4;

   logic [2:0] state;
   logic active_transfer;
   logic valid_transfer;
   logic current_error;
   logic prev_valid;
   logic prev_write;
   logic [3:0] prev_addr;
   logic [2:0] prev_size;
   logic [2:0] tx_packet_reg;
   logic flush_reg;
   logic status_new_data_reg;
   logic status_in_reg;
   logic status_out_reg;
   logic status_ack_reg;
   logic status_data0_reg;
   logic status_data1_reg;
   logic error_rx_reg;
   logic error_tx_reg;
   logic [15:0] status_word;
   logic [15:0] error_word;
   logic [7:0] byte0_data;
   logic [7:0] byte1_data;
   logic [7:0] byte2_data;
   logic [7:0] byte3_data;
   logic [31:0] next_hrdata;
   logic bypass_c;
   logic bypass_d;
   logic [7:0] bypass_data;
   logic start_buf_write;
   logic start_buf_read;
   logic [1:0] buf_count;
   logic [1:0] buf_index;
   logic [1:0] buf_lane;
   logic [31:0] buf_word;
   logic [31:0] buf_word_with_rx;
   logic tx_busy_seen;
   logic buf_write_overflow;
   logic buf_read_underflow;
   logic pending_xfr;
   logic pending_write;
   logic [3:0] pending_addr;
   logic [2:0] pending_size;
   logic [3:0] rd_addr;
   logic [2:0] rd_size;

   always_comb begin
       active_transfer = 1'b0;
       // With unused burst / SINGLE transfers, SEQ and BUSY are treated as non-enables (USB manual).
       if ((state == ST_IDLE) && (hsel == 1'b1) && (htrans == HTRANS_NONSEQ))
           active_transfer = 1'b1;
   end

   always_comb begin
       if (pending_xfr && !pending_write) begin
           rd_addr = pending_addr;
           rd_size = pending_size;
       end else begin
           rd_addr = haddr;
           rd_size = hsize;
       end
   end

   always_comb begin
       valid_transfer = 1'b0;
       if (active_transfer && (hburst == BURST_SINGLE)) begin
           case (rd_size)
               SIZE_BYTE: begin
                   if (!hwrite) begin
                       if ((haddr <= 4'h8) || (haddr == 4'hC) || (haddr == 4'hD))
                           valid_transfer = 1'b1;
                   end else begin
                       if ((haddr <= 4'h3) || (haddr == 4'hC) || (haddr == 4'hD))
                           valid_transfer = 1'b1;
                   end
               end
               SIZE_HALFWORD: begin
                   if (haddr[0] == 1'b0) begin
                       if (!hwrite) begin
                           if ((haddr == 4'h0) || (haddr == 4'h2) || (haddr == 4'h4) || (haddr == 4'h6))
                               valid_transfer = 1'b1;
                       end else begin
                           if ((haddr == 4'h0) || (haddr == 4'h2))
                               valid_transfer = 1'b1;
                       end
                   end
               end
               SIZE_WORD: begin
                   if (haddr == 4'h0)
                       valid_transfer = 1'b1;
               end
               default: valid_transfer = 1'b0;
           endcase
       end
   end

   always_comb begin
       current_error = 1'b0;
       if (active_transfer && !valid_transfer)
           current_error = 1'b1;
   end

   always_comb begin
       start_buf_write = 1'b0;
       if (prev_valid && prev_write) begin
           if ((prev_addr <= 4'h3) && ((prev_size == SIZE_HALFWORD) || (prev_size == SIZE_WORD)))
               start_buf_write = 1'b1;
       end
   end

   always_comb begin
       start_buf_read = 1'b0;
       if (prev_valid && !prev_write) begin
           if ((prev_addr <= 4'h3) && ((prev_size == SIZE_HALFWORD) || (prev_size == SIZE_WORD)))
               start_buf_read = 1'b1;
       end
   end

   always_comb begin
       buf_write_overflow = 1'b0;
       if (prev_valid && prev_write && (prev_addr <= 4'h3)) begin
           if ((prev_size == SIZE_HALFWORD) && (buffer_occupancy > 7'd62))
               buf_write_overflow = 1'b1;
           else if ((prev_size == SIZE_WORD) && (buffer_occupancy > 7'd60))
               buf_write_overflow = 1'b1;
       end
   end

   always_comb begin
       buf_read_underflow = 1'b0;
       if (prev_valid && !prev_write && (prev_addr <= 4'h3)) begin
           if ((prev_size == SIZE_HALFWORD) && (buffer_occupancy < 7'd2))
               buf_read_underflow = 1'b1;
           else if ((prev_size == SIZE_WORD) && (buffer_occupancy < 7'd4))
               buf_read_underflow = 1'b1;
       end
   end

   always_comb begin
       status_word = 16'h0000;
       status_word[0] = status_new_data_reg;
       status_word[1] = status_in_reg;
       status_word[2] = status_out_reg;
       status_word[3] = status_ack_reg;
       status_word[4] = status_data0_reg;
       status_word[5] = status_data1_reg;
       status_word[8] = rx_transfer_active;
       status_word[9] = tx_transfer_active;
   end

   always_comb begin
       error_word = 16'h0000;
       error_word[0] = error_rx_reg;
       error_word[8] = error_tx_reg;
   end

   always_comb begin
       byte0_data = 8'h00;
       byte1_data = 8'h00;
       byte2_data = 8'h00;
       byte3_data = 8'h00;

       case (rd_addr)
           4'h0: byte0_data = rx_data;
           4'h4: byte0_data = status_word[7:0];
           4'h5: byte0_data = status_word[15:8];
           4'h6: byte0_data = error_word[7:0];
           4'h7: byte0_data = error_word[15:8];
           4'h8: byte0_data = {1'b0, buffer_occupancy};
           4'hC: byte0_data = {5'd0, tx_packet_reg};
           4'hD: byte0_data = {7'd0, flush_reg};
           default: byte0_data = 8'h00;
       endcase

       case (rd_addr + 4'd1)
           4'h0: byte1_data = rx_data;
           4'h4: byte1_data = status_word[7:0];
           4'h5: byte1_data = status_word[15:8];
           4'h6: byte1_data = error_word[7:0];
           4'h7: byte1_data = error_word[15:8];
           4'h8: byte1_data = {1'b0, buffer_occupancy};
           4'hC: byte1_data = {5'd0, tx_packet_reg};
           4'hD: byte1_data = {7'd0, flush_reg};
           default: byte1_data = 8'h00;
       endcase

       case (rd_addr + 4'd2)
           4'h0: byte2_data = rx_data;
           default: byte2_data = 8'h00;
       endcase

       case (rd_addr + 4'd3)
           4'h0: byte3_data = rx_data;
           default: byte3_data = 8'h00;
       endcase
   end

   always_comb begin
       bypass_c = 1'b0;
       bypass_d = 1'b0;
       bypass_data = 8'h00;
       if (prev_valid && prev_write && (prev_size == SIZE_BYTE)) begin
           if (prev_addr == 4'hC) begin
               bypass_c = 1'b1;
               case (prev_addr[1:0])
                   2'd0: case (prev_addr[1:0])
                   2'd0: bypass_data = hwdata[7:0];
                   2'd1: bypass_data = hwdata[15:8];
                   2'd2: bypass_data = hwdata[23:16];
                   default: bypass_data = hwdata[31:24];
               endcase;
                   2'd1: bypass_data = hwdata[15:8];
                   2'd2: bypass_data = hwdata[23:16];
                   default: bypass_data = hwdata[31:24];
               endcase;
           end else if (prev_addr == 4'hD) begin
               bypass_d = 1'b1;
               bypass_data = hwdata[7:0];
           end
       end
   end

   always_comb begin
       buf_word_with_rx = buf_word;
       case (buf_lane)
           2'd0: buf_word_with_rx[7:0]   = rx_data;
           2'd1: buf_word_with_rx[15:8]  = rx_data;
           2'd2: buf_word_with_rx[23:16] = rx_data;
           default: buf_word_with_rx[31:24] = rx_data;
       endcase
   end

   always_comb begin
       next_hrdata = 32'h0000_0000;

       if ((state == ST_IDLE) && (pending_xfr && !pending_write) && !current_error && !start_buf_read) begin
           case (hsize)
               SIZE_BYTE: begin
                   if (rd_addr[1:0] == 2'd0)
                       next_hrdata = {24'h0, byte0_data};
                   else if (rd_addr[1:0] == 2'd1)
                       next_hrdata = {16'h0, byte0_data, 8'h0};
                   else if (rd_addr[1:0] == 2'd2)
                       next_hrdata = {8'h0, byte0_data, 16'h0};
                   else
                       next_hrdata = {byte0_data, 24'h0};

                   if (rd_addr == 4'hC && bypass_c) begin
                       if (rd_addr[1:0] == 2'd0)
                           next_hrdata = {24'h0, bypass_data};
                   end
                   if (rd_addr == 4'hD && bypass_d) begin
                       if (rd_addr[1:0] == 2'd1)
                           next_hrdata = {16'h0, bypass_data, 8'h0};
                   end
               end
               SIZE_HALFWORD: begin
                   if (rd_addr[1] == 1'b0)
                       next_hrdata = {16'h0000, byte1_data, byte0_data};
                   else
                       next_hrdata = {byte1_data, byte0_data, 16'h0000};
               end
               SIZE_WORD: begin
                   next_hrdata = {byte3_data, byte2_data, byte1_data, byte0_data};
               end
               default: next_hrdata = 32'h0000_0000;
           endcase
       end else if ((state == ST_BUF_READ) && (buf_index == buf_count)) begin
           // Include the current rx_data byte on the final beat.
           next_hrdata = buf_word_with_rx;
       end
   end

   always_comb begin
       hready = 1'b1;
       hresp  = 1'b0;
       get_rx_data = 1'b0;
       store_tx_data = 1'b0;
       tx_data = 8'h00;
       clear = flush_reg;

       case (state)
           ST_IDLE: begin
               // Always provide zero-wait OKAY in IDLE / address phase.
               hready = 1'b1;
               hresp  = 1'b0;
               // Byte reads pop in the data phase using latched pending_* transfer info.
               if (pending_xfr && !pending_write && (pending_addr <= 4'h3) && (pending_size == SIZE_BYTE) && (buffer_occupancy != 7'd0))
                   get_rx_data = 1'b1;
               if (prev_valid && prev_write && (prev_addr <= 4'h3) && (prev_size == SIZE_BYTE) && (buffer_occupancy < 7'd64)) begin
                   store_tx_data = 1'b1;
                   case (prev_addr[1:0])
                       2'd0: tx_data = hwdata[7:0];
                       2'd1: tx_data = hwdata[15:8];
                       2'd2: tx_data = hwdata[23:16];
                       default: tx_data = hwdata[31:24];
                   endcase
               end
           end
           ST_ERR_1: begin
               hready = 1'b0;
               hresp  = 1'b1;
           end
           ST_ERR_2: begin
               hready = 1'b1;
               hresp  = 1'b1;
           end
           ST_BUF_WRITE: begin
               hready = 1'b0;
               if (buffer_occupancy < 7'd64) begin
                   store_tx_data = 1'b1;
                   if (buf_lane == 2'd0)
                       tx_data = buf_word[7:0];
                   else if (buf_lane == 2'd1)
                       tx_data = buf_word[15:8];
                   else if (buf_lane == 2'd2)
                       tx_data = buf_word[23:16];
                   else
                       tx_data = buf_word[31:24];
               end
           end
           ST_BUF_READ: begin
               hready = 1'b0;
               if (buffer_occupancy != 7'd0)
                   get_rx_data = 1'b1;
           end
           default: begin
               hready = 1'b1;
               hresp  = 1'b0;
           end
       endcase
   end

   always_ff @(posedge clk or negedge n_rst) begin
       if (!n_rst) begin
           state <= ST_IDLE;
           pending_xfr <= 1'b0;
           pending_write <= 1'b0;
           pending_addr <= 4'h0;
           pending_size <= SIZE_BYTE;
           prev_valid <= 1'b0;
           prev_write <= 1'b0;
           prev_addr  <= 4'h0;
           prev_size  <= SIZE_BYTE;
           tx_packet_reg <= TX_NONE;
           flush_reg <= 1'b0;
           status_new_data_reg <= 1'b0;
           status_in_reg <= 1'b0;
           status_out_reg <= 1'b0;
           status_ack_reg <= 1'b0;
           status_data0_reg <= 1'b0;
           status_data1_reg <= 1'b0;
           error_rx_reg <= 1'b0;
           error_tx_reg <= 1'b0;
           buf_count <= 2'd0;
           buf_index <= 2'd0;
           buf_lane <= 2'd0;
           buf_word <= 32'h0;
           tx_busy_seen <= 1'b0;
           hrdata <= 32'h0;
       end
       else begin
           hrdata <= next_hrdata;

           if (rx_data_ready)
               status_new_data_reg <= 1'b1;
           if (buffer_occupancy == 7'd0)
               status_new_data_reg <= 1'b0;
           if (rx_packet == PID_IN)
               status_in_reg <= 1'b1;
           if (rx_packet == PID_OUT)
               status_out_reg <= 1'b1;
           if (rx_packet == PID_ACK)
               status_ack_reg <= 1'b1;
           if (rx_packet == PID_DATA0)
               status_data0_reg <= 1'b1;
           if (rx_packet == PID_DATA1)
               status_data1_reg <= 1'b1;
           if (rx_error)
               error_rx_reg <= 1'b1;
           if (tx_error)
               error_tx_reg <= 1'b1;

           if (tx_packet_reg != TX_NONE && tx_transfer_active)
               tx_busy_seen <= 1'b1;

           case (state)
               ST_IDLE: begin
                   if (current_error)
                       state <= ST_ERR_1;
                   else if (start_buf_write && buf_write_overflow)
                       state <= ST_ERR_1;
                   else if (start_buf_read && buf_read_underflow)
                       state <= ST_ERR_1;
                   else if (start_buf_write) begin
                       state <= ST_BUF_WRITE;
                       pending_xfr <= 1'b0;
                       if (prev_size == SIZE_HALFWORD)
                           buf_count <= 2'd1;
                       else
                           buf_count <= 2'd3;
                       buf_index <= 2'd0;
                       buf_lane <= prev_addr[1:0];
                       buf_word <= hwdata;
                   end else if (start_buf_read) begin
                       state <= ST_BUF_READ;
                       pending_xfr <= 1'b0;
                       if (prev_size == SIZE_HALFWORD)
                           buf_count <= 2'd1;
                       else
                           buf_count <= 2'd3;
                       buf_index <= 2'd0;
                       buf_lane <= prev_addr[1:0];
                       buf_word <= 32'h0;
                   end

                   if (pending_xfr && pending_write) begin
                       if (pending_size == SIZE_BYTE) begin
                           if (pending_addr == 4'hC) begin
                               case (pending_addr[1:0])
                                   2'd0: case (hwdata[7:0])
                                       8'd1: tx_packet_reg <= TX_DATA0;
                                       8'd2: tx_packet_reg <= TX_DATA1;
                                       8'd3: tx_packet_reg <= TX_ACK;
                                       8'd4: tx_packet_reg <= TX_NAK;
                                       8'd5: tx_packet_reg <= TX_STALL;
                                       default: tx_packet_reg <= tx_packet_reg;
                                   endcase
                                   2'd1: case (hwdata[15:8])
                                       8'd1: tx_packet_reg <= TX_DATA0;
                                       8'd2: tx_packet_reg <= TX_DATA1;
                                       8'd3: tx_packet_reg <= TX_ACK;
                                       8'd4: tx_packet_reg <= TX_NAK;
                                       8'd5: tx_packet_reg <= TX_STALL;
                                       default: tx_packet_reg <= tx_packet_reg;
                                   endcase
                                   2'd2: case (hwdata[23:16])
                                       8'd1: tx_packet_reg <= TX_DATA0;
                                       8'd2: tx_packet_reg <= TX_DATA1;
                                       8'd3: tx_packet_reg <= TX_ACK;
                                       8'd4: tx_packet_reg <= TX_NAK;
                                       8'd5: tx_packet_reg <= TX_STALL;
                                       default: tx_packet_reg <= tx_packet_reg;
                                   endcase
                                   default: case (hwdata[31:24])
                                       8'd1: tx_packet_reg <= TX_DATA0;
                                       8'd2: tx_packet_reg <= TX_DATA1;
                                       8'd3: tx_packet_reg <= TX_ACK;
                                       8'd4: tx_packet_reg <= TX_NAK;
                                       8'd5: tx_packet_reg <= TX_STALL;
                                       default: tx_packet_reg <= tx_packet_reg;
                                   endcase
                               endcase
                               tx_busy_seen <= 1'b0;
                           end
                           case (pending_addr[1:0])
                               2'd0: if (pending_addr == 4'hD && (hwdata[7:0] == 8'h01)) flush_reg <= 1'b1;
                               2'd1: if (pending_addr == 4'hD && (hwdata[15:8] == 8'h01)) flush_reg <= 1'b1;
                               2'd2: if (pending_addr == 4'hD && (hwdata[23:16] == 8'h01)) flush_reg <= 1'b1;
                               default: if (pending_addr == 4'hD && (hwdata[31:24] == 8'h01)) flush_reg <= 1'b1;
                           endcase
                        end
                    end

                   // USB manual: flush register clears after the buffer is cleared. Model that as:
                   // hold `clear` until occupancy hits 0, then self-clear the sticky flush flag.
                   if (flush_reg && (buffer_occupancy == 7'd0))
                       flush_reg <= 1'b0;

                   if (tx_busy_seen && !tx_transfer_active && tx_packet_reg != TX_NONE)
                       tx_packet_reg <= TX_NONE;

                   if (active_transfer && valid_transfer) begin
                       prev_valid <= 1'b1;
                       prev_write <= hwrite;
                       prev_addr  <= haddr;
                       prev_size  <= hsize;
                       pending_xfr <= 1'b1;
                       pending_write <= hwrite;
                       pending_addr <= haddr;
                       pending_size <= hsize;
                   end else if (pending_xfr && (state == ST_IDLE) && !start_buf_read && !start_buf_write && !current_error) begin
                       pending_xfr <= 1'b0;
                       prev_valid <= 1'b0;
                   end else if (!pending_xfr) begin
                       prev_valid <= 1'b0;
                   end
               end
               ST_ERR_1: begin
                   state <= ST_ERR_2;
                   prev_valid <= 1'b0;
                   pending_xfr <= 1'b0;
               end
               ST_ERR_2: begin
                   state <= ST_IDLE;
                   prev_valid <= 1'b0;
                   pending_xfr <= 1'b0;
               end
               ST_BUF_WRITE: begin
                   if (buffer_occupancy < 7'd64) begin
                       if (buf_index == buf_count) begin
                           state <= ST_IDLE;
                       end else begin
                           buf_index <= buf_index + 2'd1;
                           buf_lane  <= buf_lane + 2'd1;
                       end
                   end else begin
                       // Overflow during burst push is treated as bus error.
                       state <= ST_ERR_1;
                   end
                   prev_valid <= 1'b0;
               end
               ST_BUF_READ: begin
                   if (buffer_occupancy != 7'd0) begin
                       if (buf_lane == 2'd0)
                           buf_word[7:0] <= rx_data;
                       else if (buf_lane == 2'd1)
                           buf_word[15:8] <= rx_data;
                       else if (buf_lane == 2'd2)
                           buf_word[23:16] <= rx_data;
                       else
                           buf_word[31:24] <= rx_data;

                       if (buf_index == buf_count) begin
                           state <= ST_IDLE;
                       end else begin
                           buf_index <= buf_index + 2'd1;
                           buf_lane  <= buf_lane + 2'd1;
                       end
                   end else begin
                       state <= ST_ERR_1;
                   end
                   prev_valid <= 1'b0;
               end
               default: begin
                   state <= ST_IDLE;
                   prev_valid <= 1'b0;
               end
           endcase
       end
   end

   always_comb begin
       tx_packet = tx_packet_reg;
       d_mode = tx_transfer_active;
   end
endmodule
