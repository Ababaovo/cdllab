`timescale 1ns / 10ps


// $Id: $
// File name:   flex_counter.sv
// Created:     
// Author:      
// Description: Flexible counter with parameterized size

//If the counter ever gets > rollover_val, something abnormal happened - probably a parameter mismatch, glitch during reset.
// The most reasonable choice is to treat it as a rollover condition and go to 1 to recover normal operation


module flex_counter #(
    parameter SIZE = 8
) (
    input logic clk,
    input logic n_rst,
    input logic clear,
    input logic count_enable,
    input logic [SIZE-1:0] rollover_val,
    output logic [SIZE-1:0] count_out,
    output logic rollover_flag
);

    logic [SIZE-1:0] next_count, current_count;
    logic next_flag, current_flag;

    // Combinational logic for next_count
    always_comb begin 
        if (clear) begin
            next_count = '0;
        end
        else if ((current_count >= rollover_val) && count_enable) begin
            next_count = 1;
        end
        else if (count_enable) begin
            next_count = current_count + 1;
        end
        else begin
            next_count = current_count;
        end
    end

    // Combinational logic for next_flag
    always_comb begin 
        if (clear) begin
            next_flag = 0;
        end
        else if (next_count == rollover_val) begin
            next_flag = 1;
        end
        else begin
            next_flag = 0;
        end
    end

    // State register
    always_ff @(posedge clk, negedge n_rst) begin
        if (!n_rst) begin
            current_count <= '0;
            current_flag <= '0;
        end
        else begin
            current_count <= next_count;
            current_flag <= next_flag;
        end
    end

    // Output assignments
    assign count_out = current_count;
    assign rollover_flag = current_flag;

endmodule
































