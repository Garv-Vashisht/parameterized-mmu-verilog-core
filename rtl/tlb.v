`timescale 1ns/1ps

module tlb #(
    parameter VAW = 32,
    parameter PAW = 32,
    parameter ASIDW = 8,
    parameter SETS = 16,
    parameter WAYS = 4
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 en,
    // Lookup Interfaces
    input  wire [VAW-13:0]      vpn,
    input  wire [ASIDW-1:0]     asid,
    output reg                  hit,
    output reg  [PAW-13:0]      ppn,
    output reg                  perm_r,
    output reg                  perm_w,
    output reg                  perm_x,
    output reg                  perm_u,
    output reg                  valid,
    // Refill Interfaces
    input  wire                 refill,
    input  wire [VAW-13:0]      rf_vpn,
    input  wire [ASIDW-1:0]     rf_asid,
    input  wire [PAW-13:0]      rf_ppn,
    input  wire                 rf_r,
    input  wire                 rf_w,
    input  wire                 rf_x,
    input  wire                 rf_u,
    input  wire                 rf_v
);

    localparam IDXW = $clog2(SETS);
    localparam TAGW = (VAW - 12) - IDXW;

    wire [IDXW-1:0] idx = vpn[IDXW-1:0];
    wire [TAGW-1:0] lookup_tag = vpn[VAW-13:IDXW];

    // Core Internal Array Declarations
    reg [TAGW-1:0]   tag_array   [0:SETS-1][0:WAYS-1];
    reg [ASIDW-1:0]  asid_array  [0:SETS-1][0:WAYS-1];
    reg              vbit_array  [0:SETS-1][0:WAYS-1];
    reg [PAW-13:0]   ppn_array   [0:SETS-1][0:WAYS-1];
    reg              r_array     [0:SETS-1][0:WAYS-1];
    reg              w_array     [0:SETS-1][0:WAYS-1];
    reg              x_array     [0:SETS-1][0:WAYS-1];
    reg              u_array     [0:SETS-1][0:WAYS-1];
    
    // Pseudo-LRU age state arrays (3 bits per line array for 4-Ways)
    reg [WAYS-2:0]   plru        [0:SETS-1];

    integer w_idx;
    
    // Combinational Hit Detection Architecture
    always @(*) begin
        hit    = 1'b0;
        ppn    = {(PAW-12){1'b0}};
        perm_r = 1'b0;
        perm_w = 1'b0;
        perm_x = 1'b0;
        perm_u = 1'b0;
        valid  = 1'b0;
        
        for (w_idx = 0; w_idx < WAYS; w_idx = w_idx + 1) begin
            if (vbit_array[idx][w_idx] && 
                (tag_array[idx][w_idx] == lookup_tag) && 
                (asid_array[idx][w_idx] == asid)) begin
                
                hit    = 1'b1;
                ppn    = ppn_array[idx][w_idx];
                perm_r = r_array[idx][w_idx];
                perm_w = w_array[idx][w_idx];
                perm_x = x_array[idx][w_idx];
                perm_u = u_array[idx][w_idx];
                valid  = vbit_array[idx][w_idx];
            end
        end
    end

    // Tree Pseudo-LRU Target Calculation Functions
    function [WAYS-2:0] next_plru;
        input [WAYS-2:0] current_bits;
        input integer matched_way;
        begin
            next_plru = current_bits;
            if (matched_way < 2) begin
                next_plru[2] = 1'b1; // Direct toward right side
                next_plru[1] = (matched_way == 0) ? 1'b1 : 1'b0;
            end else begin
                next_plru[2] = 1'b0; // Direct toward left side
                next_plru[0] = (matched_way == 2) ? 1'b1 : 1'b0;
            end
        end
    endfunction

    function integer get_victim_way;
        input [WAYS-2:0] current_bits;
        begin
            if (current_bits[2] == 1'b0) begin
                get_victim_way = (current_bits[1] == 1'b0) ? 1 : 0;
            end else begin
                get_victim_way = (current_bits[0] == 1'b0) ? 3 : 2;
            end
        end
    endfunction

    integer s, w;
    integer target_victim;

    // Sequential State Transformations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (s = 0; s < SETS; s = s + 1) begin
                plru[s] <= {(WAYS-1){1'b0}};
                for (w = 0; w < WAYS; w = w + 1) begin
                    vbit_array[s][w] <= 1'b0;
                    tag_array[s][w]  <= {TAGW{1'b0}};
                    asid_array[s][w] <= {ASIDW{1'b0}};
                    ppn_array[s][w]  <= {(PAW-12){1'b0}};
                    r_array[s][w]    <= 1'b0;
                    w_array[s][w]    <= 1'b0;
                    x_array[s][w]    <= 1'b0;
                    u_array[s][w]    <= 1'b0;
                end
            end
        end else if (en) begin
            if (hit) begin
                for (w = 0; w < WAYS; w = w + 1) begin
                    if (vbit_array[idx][w] && (tag_array[idx][w] == lookup_tag) && (asid_array[idx][w] == asid)) begin
                        plru[idx] <= next_plru(plru[idx], w);
                    end
                end
            end
            
            if (refill) begin
                target_victim = get_victim_way(plru[rf_vpn[IDXW-1:0]]);
                tag_array[rf_vpn[IDXW-1:0]][target_victim]  <= rf_vpn[VAW-13:IDXW];
                asid_array[rf_vpn[IDXW-1:0]][target_victim] <= rf_asid;
                ppn_array[rf_vpn[IDXW-1:0]][target_victim]  <= rf_ppn;
                r_array[rf_vpn[IDXW-1:0]][target_victim]    <= rf_r;
                w_array[rf_vpn[IDXW-1:0]][target_victim]    <= rf_w;
                x_array[rf_vpn[IDXW-1:0]][target_victim]    <= rf_x;
                u_array[rf_vpn[IDXW-1:0]][target_victim]    <= rf_u;
                vbit_array[rf_vpn[IDXW-1:0]][target_victim] <= rf_v;
                
                plru[rf_vpn[IDXW-1:0]] <= next_plru(plru[rf_vpn[IDXW-1:0]], target_victim);
            end
        end
    end
endmodule