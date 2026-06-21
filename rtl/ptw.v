`timescale 1ns/1ps

module ptw #(
    parameter VAW = 32,
    parameter PAW = 32
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire        miss_req,
    input  wire [19:0] miss_vpn,
    input  wire [7:0]  miss_asid,
    input  wire [19:0] satp_base_ppn,
    
    output reg         mem_req,
    output reg  [PAW-1:0] mem_addr,
    input  wire        mem_rdy,
    input  wire [31:0] mem_rdata,
    input  wire        mem_err,
    
    output reg         rf_valid,
    output reg  [19:0] rf_vpn,
    output reg  [7:0]  rf_asid,
    output reg  [19:0] rf_ppn,
    output reg         rf_r, rf_w, rf_x, rf_u, rf_v,
    output reg         bus_fault
);

    // PTW States
    localparam IDLE  = 2'b00;
    localparam LEVEL1 = 2'b01;
    localparam LEVEL0 = 2'b10;
    localparam FAULT  = 2'b11;

    reg [1:0] state, nstate;
    reg [3:0] watchdog_count; // Safety counter to prevent infinite hangs

    always @(*) begin
        nstate = state;
        case (state)
            IDLE: begin
                if (miss_req) nstate = LEVEL1;
            end
            LEVEL1: begin
                if (watchdog_count >= 4'd12) nstate = FAULT; // Loop breaker
                else if (mem_rdy) nstate = LEVEL0;
                else if (mem_err) nstate = FAULT;
            end
            LEVEL0: begin
                if (watchdog_count >= 4'd12) nstate = FAULT; // Loop breaker
                else if (mem_rdy) nstate = IDLE;
                else if (mem_err) nstate = FAULT;
            end
            FAULT: begin
                nstate = IDLE;
            end
            default: nstate = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            mem_req        <= 1'b0;
            mem_addr       <= {PAW{1'b0}};
            rf_valid       <= 1'b0;
            rf_vpn         <= 20'b0;
            rf_asid        <= 8'b0;
            rf_ppn         <= 20'b0;
            {rf_r, rf_w, rf_x, rf_u, rf_v} <= 5'b0;
            bus_fault      <= 1'b0;
            watchdog_count <= 4'b0;
        end else if (en) begin
            state <= nstate;
            
            // Watchdog management
            if (state == LEVEL1 || state == LEVEL0) begin
                watchdog_count <= watchdog_count + 1'b1;
            end else begin
                watchdog_count <= 4'b0;
            end

            case (state)
                IDLE: begin
                    bus_fault <= 1'b0;
                    rf_valid  <= 1'b0;
                    if (miss_req) begin
                        mem_req  <= 1'b1;
                        mem_addr <= {satp_base_ppn, miss_vpn[19:10], 2'b00}; 
                    end
                end
                
                LEVEL1: begin
                    if (mem_rdy || watchdog_count >= 4'd12) begin
                        mem_addr <= {mem_rdata[29:10], miss_vpn[9:0], 2'b00};
                        if (watchdog_count >= 4'd12) mem_req <= 1'b0;
                    end
                end
                
                LEVEL0: begin
                    if (mem_rdy || watchdog_count >= 4'd12) begin
                        mem_req   <= 1'b0;
                        rf_valid  <= 1'b1;
                        rf_vpn    <= miss_vpn;
                        rf_asid   <= miss_asid;
                        rf_ppn    <= mem_rdata[29:10];
                        rf_v      <= mem_rdata[0];
                        rf_r      <= mem_rdata[1];
                        rf_w      <= mem_rdata[2];
                        rf_x      <= mem_rdata[3];
                        rf_u      <= mem_rdata[4];
                    end
                end
                
                FAULT: begin
                    mem_req   <= 1'b0;
                    bus_fault <= 1'b1;
                    rf_valid  <= 1'b0;
                end
            endcase
        end
    end
endmodule