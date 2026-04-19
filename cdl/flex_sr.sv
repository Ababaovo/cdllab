`timescale 1ns / 10ps

module flex_sr #(
    SIZE = 8,
    MSB_FIRST = 0
) (
    input logic clk,
    input logic n_rst,
    input logic shift_enable,
    input logic load_enable,
    input logic serial_in,
    input logic [SIZE-1:0] parallel_in,
    output logic serial_out,
    output logic [SIZE -1:0] parallel_out
);

logic [SIZE-1:0] Q, D;


always_ff @(posedge clk or negedge n_rst) begin

    if(!n_rst) begin
        Q <= '1;
        end
    else begin
        Q <= D;
    end

end


always_comb begin

    D = Q;
    
    if(load_enable) begin
        D = parallel_in;
    end
    else if(shift_enable) begin
        if(MSB_FIRST) begin
            D = {Q[SIZE-2 :0], serial_in};
        end
        else begin
        D = {serial_in, Q[SIZE - 1:1]};
        end
    end
end


assign parallel_out = Q;
assign serial_out = MSB_FIRST ? Q[SIZE - 1] : Q[0];

endmodule

