`timescale 1ns / 10ps
/* verilator coverage_off */
module tb_ahb_usb();
    localparam CLK_PERIOD   = 10ns;
    localparam BURST_SINGLE = 3'd0;

    logic clk, n_rst;
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
    logic dp_in, dm_in, dp_out, dm_out, d_mode;

    int pass_count;
    int fail_count;
    string test_name;

    initial begin
        $dumpfile("waveform_top.fst");
        $dumpvars(0, tb_ahb_usb);
    end

    always begin
        clk = 1'b0;
        #(CLK_PERIOD/2.0);
        clk = 1'b1;
        #(CLK_PERIOD/2.0);
    end

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

    ahb_usb UUT (
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
        .dp_in(dp_in),
        .dm_in(dm_in),
        .dp_out(dp_out),
        .dm_out(dm_out),
        .d_mode(d_mode)
    );

//RX Tasks
    task reset_dut;
    begin
        n_rst = 1'b0;
        dp_in = 1'b1;
        dm_in = 1'b0;
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        n_rst = 1'b1;
        @(negedge clk);
        @(negedge clk);
    end
    endtask

        task sync_byte;
    begin
        /*10000000*/
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        #(83.33333ns);
    end
    endtask

    task ack_pid;
    begin
        /*11010010*/
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        #(83.33333ns);
        #(83.33333ns);
    end
    endtask

    task in_pid;
    begin
        /*01101001*/
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
    end
    endtask

    task out_pid;
    begin
        /*11100001*/
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        #(83.33333ns);
        #(83.33333ns);
        #(83.33333ns);
    end
    endtask
    
    task data0_pid;
    begin
        /*11000011*/
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        #(83.33333ns);
        #(83.33333ns);
    end
    endtask

    task data1_pid;
    begin
        /*01001011*/
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
    end
    endtask

    task data_crc;
    begin
          /*00000001_00000001*/
        #(83.4ns);
        dp_in = 1;
        dm_in = 0;
        #(83.4ns);
        dp_in = 0;
        dm_in = 1;
        #(83.4ns);
        dp_in = 1;
        dm_in = 0;
        #(83.4ns);
        dp_in = 0;
        dm_in = 1;
        #(83.4ns);
        dp_in = 1;
        dm_in = 0;
        #(83.4ns);
        dp_in = 0;
        dm_in = 1;
        #(83.4ns);
        dp_in = 1;
        dm_in = 0;
        #(83.4ns);

        #(83.4ns);
        dp_in = 0;
        dm_in = 1;
        #(83.4ns);
        dp_in = 1;
        dm_in = 0;
        #(83.4ns);
        dp_in = 0;
        dm_in = 1;
        #(83.4ns);
        dp_in = 1;
        dm_in = 0;
        #(83.4ns);
        dp_in = 0;
        dm_in = 1;
        #(83.4ns);
        dp_in = 1;
        dm_in = 0;
        #(83.4ns);
        dp_in = 0;
        dm_in = 1;
        #(83.4ns);
    end
    endtask

    task token_data_crc;
    begin
        /*01110_0000_0111110*/
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        #(83.33333ns);
        #(83.33333ns);
        #(83.33333ns);
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        #(83.33333ns);
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        
    end
    endtask

    task random_data;
    begin
        /*10101010_01010101 = aa_55*/
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);

        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 1;
        dm_in = 0;
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 0;
        dm_in = 1;
        #(83.33333ns);
        #(83.33333ns);
    end
    endtask

    task eop;
    begin
        dp_in = 0;
        dm_in = 0;
        #(83.33333ns);
        #(83.33333ns);
        dp_in = 1;
        #(83.33333ns);
    end
    endtask


    task enqueue_read(input logic [3:0] addr, input logic [1:0] size, input logic [31:0] exp_read);
        logic [31:0] data[];
    begin
        data = new[1];
        data[0] = exp_read;
        BFM.enqueue_transaction(1'b1, 1'b0, addr, data, 1'b0, {1'b0,size}, BURST_SINGLE, 1'b1);
    end
    endtask

    task enqueue_write(input logic [3:0] addr, input logic [1:0] size, input logic [31:0] wdata);
        logic [31:0] data[];
    begin
        data = new[1];
        data[0] = wdata;
        BFM.enqueue_transaction(1'b1, 1'b1, addr, data, 1'b0, {1'b0,size}, BURST_SINGLE, 1'b0);
    end
    endtask

    task execute_transactions(input int num_transactions);
       BFM.run_transactions(num_transactions);
    endtask


    task finish_transactions();
       BFM.wait_done();
    endtask


    initial begin

        n_rst = 1;
        dp_in = 1;
        dm_in = 0;

        test_name = "Reset defaults";
        reset_dut();
        enqueue_read(4'h4, 2'd1, 32'h0000_0000);
        execute_transactions(1);
        finish_transactions();
        enqueue_read(4'h6, 2'd1, 32'h0000_0000);
        execute_transactions(1);
        finish_transactions();
        enqueue_read(4'h8, 2'd0, 32'h0000_0000);
        execute_transactions(1);
        finish_transactions();

        test_name = "ACK status after RX done";
        reset_dut();
        sync_byte();
        ack_pid();
        eop();
        #(83.33333);
        #(83.33333);
        enqueue_read(4'h4, 2'd1, 32'h0000_0008);
        execute_transactions(1);
        finish_transactions();

        test_name = "Status during ACK receive";
        reset_dut();
        fork
            begin
                sync_byte();
                ack_pid();
                eop();
            end
            begin
                #(900ns);
                enqueue_read(4'h4, 2'd1, 32'h0000_0100);
                execute_transactions(1);
                finish_transactions();
            end
        join

        test_name = "DATA0 occupancy and status";
        reset_dut();
        sync_byte();
        data0_pid();
        random_data();
        data_crc();
        eop();
        #(83.33333);
        #(83.33333);
        enqueue_read(4'h8, 2'd0, 32'h0000_0002);
        execute_transactions(1);
        finish_transactions();
        enqueue_read(4'h4, 2'd1, 32'h0000_0011);
        execute_transactions(1);
        finish_transactions();

        test_name = "DATA0 read byte low";
        enqueue_read(4'h0, 2'd0, 32'h0000_0055);
        execute_transactions(1);
        finish_transactions();
        enqueue_read(4'h8, 2'd0, 32'h0000_0001);
        execute_transactions(1);
        finish_transactions();

        test_name = "DATA0 read byte high";
        enqueue_read(4'h0, 2'd0, 32'h0000_00aa);
        execute_transactions(1);
        finish_transactions();
        enqueue_read(4'h8, 2'd0, 32'h0000_0000);
        execute_transactions(1);
        finish_transactions();

        test_name = "DATA0 halfword read";
        reset_dut();
        sync_byte();
        data0_pid();
        random_data();
        data_crc();
        eop();
        #(83.33333);
        #(83.33333);
        enqueue_read(4'h8, 2'd0, 32'h0000_0002);
        execute_transactions(1);
        finish_transactions();
        enqueue_read(4'h0, 2'd1, 32'h0000_aa55);
        execute_transactions(1);
        finish_transactions();
        enqueue_read(4'h8, 2'd0, 32'h0000_0000);
        execute_transactions(1);
        finish_transactions();

        test_name = "OUT then DATA0 host to endpoint";
        reset_dut();
        sync_byte();
        out_pid();
        token_data_crc();
        eop();
        #(400ns);
        sync_byte();
        data0_pid();
        random_data();
        data_crc();
        eop();
        #(83.33333);
        #(83.33333);
        enqueue_read(4'h4, 2'd1, 32'h0000_0014);
        execute_transactions(1);
        finish_transactions();
        enqueue_read(4'h8, 2'd0, 32'h0000_0002);
        execute_transactions(1);
        finish_transactions();
        enqueue_read(4'h0, 2'd0, 32'h0000_0055);
        execute_transactions(1);
        finish_transactions();
        enqueue_read(4'h0, 2'd0, 32'h0000_00aa);
        execute_transactions(1);
        finish_transactions();
        enqueue_read(4'h8, 2'd0, 32'h0000_0000);
        execute_transactions(1);
        finish_transactions();

        $finish;
    end
endmodule
/* verilator coverage_on */
