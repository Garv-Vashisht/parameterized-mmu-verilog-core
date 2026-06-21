`timescale 1ns/1ps

module mem_bram #(
    parameter PAW = 32,
    parameter DEPTH = 256
)(
    input  wire           clk,
    input  wire           req,
    input  wire [PAW-1:0] addr,
    output reg            rdy,
    output reg  [31:0]    rdata,
    output reg            err
);
    reg [31:0] internal_ram [0:DEPTH-1];

    always @(posedge clk) begin
        rdy <= 1'b0;
        err <= 1'b0;
        if (req) begin
            // Derive localized safe index bounds 
            if (addr[7:2] < DEPTH) begin
                rdata <= internal_ram[addr[7:2]];
                rdy   <= 1'b1;
            end else begin
                err   <= 1'b1;
            end
        end
    end
endmodule