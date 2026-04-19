`timescale 1ns / 10ps

module sync #(parameter RST_VAL = 0) (input logic clk, input logic n_rst, input logic async_in, output logic sync_out);

logic out;

always_ff @(posedge clk, negedge n_rst) begin : flipflopone
    
    if (n_rst == 0)begin
        out <= RST_VAL;
    end
    else begin
        out <= async_in;
    end
end

always_ff @( posedge clk, negedge n_rst) begin : flipfloptwo
    if (n_rst == 0)begin
        sync_out <= RST_VAL;
    end
    else begin
        sync_out <= out;
    end
end

endmodule

