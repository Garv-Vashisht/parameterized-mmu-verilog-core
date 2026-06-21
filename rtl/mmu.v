`timescale 1ns/1ps

module mmu #(
    parameter VAW = 32,
    parameter PAW = 32,
    parameter ASIDW = 8,
    parameter SETS = 16,
    parameter WAYS = 4
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               en,
    input  wire               translate_en,
    input  wire [PAW-13:0]    satp_base_ppn,
    input  wire [ASIDW-1:0]   csr_asid,
    input  wire               req_valid,
    input  wire [VAW-1:0]     req_va,
    input  wire [1:0]         req_acc,  
    input  wire               req_priv, 
    output reg                rsp_valid,
    output reg  [PAW-1:0]     rsp_pa,
    output reg                rsp_fault,
    output reg                rsp_xfault,
    output wire               mem_req,
    output wire [PAW-1:0]     mem_addr,
    input  wire               mem_rdy,
    input  wire [31:0]        mem_rdata,
    input  wire               mem_err
);

    wire [VAW-13:0] current_vpn = req_va[VAW-1:12];
    wire [11:0]     current_off = req_va[11:0];

    wire tlb_hit;
    wire [PAW-13:0] tlb_ppn;
    wire tlb_r, tlb_w, tlb_x, tlb_u, tlb_v;

    wire ptw_rf_valid;
    wire [VAW-13:0] ptw_rf_vpn;
    wire [ASIDW-1:0] ptw_rf_asid;
    wire [PAW-13:0] ptw_rf_ppn;
    wire ptw_rf_r, ptw_rf_w, ptw_rf_x, ptw_rf_u, ptw_rf_v;
    wire ptw_bus_fault;

    reg ptw_miss_req;

    tlb #(.VAW(VAW), .PAW(PAW), .ASIDW(ASIDW), .SETS(SETS), .WAYS(WAYS)) internal_tlb (
        .clk(clk), .rst_n(rst_n), .en(en),
        .vpn(current_vpn), .asid(csr_asid),
        .hit(tlb_hit), .ppn(tlb_ppn),
        .perm_r(tlb_r), .perm_w(tlb_w), .perm_x(tlb_x), .perm_u(tlb_u), .valid(tlb_v),
        .refill(ptw_rf_valid), .rf_vpn(ptw_rf_vpn), .rf_asid(ptw_rf_asid), .rf_ppn(ptw_rf_ppn),
        .rf_r(ptw_rf_r), .rf_w(ptw_rf_w), .rf_x(ptw_rf_x), .rf_u(ptw_rf_u), .rf_v(ptw_rf_v)
    );

    ptw #(.VAW(VAW), .PAW(PAW)) internal_ptw (
        .clk(clk), .rst_n(rst_n), .en(en),
        .miss_req(ptw_miss_req), .miss_vpn(current_vpn), .miss_asid(csr_asid), .satp_base_ppn(satp_base_ppn),
        .mem_req(mem_req), .mem_addr(mem_addr), .mem_rdy(mem_rdy), .mem_rdata(mem_rdata), .mem_err(mem_err),
        .rf_valid(ptw_rf_valid), .rf_vpn(ptw_rf_vpn), .rf_asid(ptw_rf_asid), .rf_ppn(ptw_rf_ppn),
        .rf_r(ptw_rf_r), .rf_w(ptw_rf_w), .rf_x(ptw_rf_x), .rf_u(ptw_rf_u), .rf_v(ptw_rf_v),
        .bus_fault(ptw_bus_fault)
    );

    wire acc_load   = (req_acc == 2'b01);
    wire acc_store  = (req_acc == 2'b10);
    wire acc_ifetch = (req_acc == 2'b00);

    wire perm_allow, perm_pfault, perm_xfault;
    
    wire active_v = tlb_hit ? tlb_v : ptw_rf_v;
    wire active_r = tlb_hit ? tlb_r : ptw_rf_r;
    wire active_w = tlb_hit ? tlb_w : ptw_rf_w;
    wire active_x = tlb_hit ? tlb_x : ptw_rf_x;
    wire active_u = tlb_hit ? tlb_u : ptw_rf_u;
    wire [PAW-13:0] active_ppn = tlb_hit ? tlb_ppn : ptw_rf_ppn;

    perm_check permissions_unit (
        .priv(req_priv), .acc_load(acc_load), .acc_store(acc_store), .acc_ifetch(acc_ifetch),
        .pV(active_v), .pR(active_r), .pW(active_w), .pX(active_x), .pU(active_u),
        .allow(perm_allow), .pfault(perm_pfault), .xfault(perm_xfault)
    );

    localparam MMU_IDLE = 2'b00;
    localparam MMU_WALK = 2'b01;
    localparam MMU_EVAL = 2'b10;

    reg [1:0] mmu_state, mmu_nstate;

    // Fixed FSM Logic
    always @(*) begin
        mmu_nstate = mmu_state;
        ptw_miss_req = 1'b0;
        case (mmu_state)
            MMU_IDLE: begin
                if (req_valid && translate_en) begin
                    if (tlb_hit) mmu_nstate = MMU_EVAL;
                    else begin
                        mmu_nstate = MMU_WALK;
                        ptw_miss_req = 1'b1;
                    end
                end
            end
            MMU_WALK: begin
                if (ptw_rf_valid) mmu_nstate = MMU_EVAL;
                else if (ptw_bus_fault) mmu_nstate = MMU_IDLE;
            end
            MMU_EVAL: begin
                mmu_nstate = MMU_IDLE;
            end
            default: mmu_nstate = MMU_IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mmu_state  <= MMU_IDLE;
            rsp_valid  <= 1'b0;
            rsp_pa     <= {PAW{1'b0}};
            rsp_fault  <= 1'b0;
            rsp_xfault <= 1'b0;
        end else if (en) begin
            mmu_state <= mmu_nstate;
            
            if (!translate_en && req_valid) begin
                rsp_valid  <= 1'b1;
                rsp_pa     <= req_va;
                rsp_fault  <= 1'b0;
                rsp_xfault <= 1'b0;
            end else if (!translate_en && !req_valid) begin
                rsp_valid  <= 1'b0;
            end else begin
                case (mmu_state)
                    MMU_IDLE: begin
                        rsp_valid <= 1'b0;
                    end
                    MMU_WALK: begin
                        if (ptw_bus_fault) begin
                            rsp_valid  <= 1'b1;
                            rsp_fault  <= 1'b1;
                            rsp_xfault <= 1'b0;
                        end
                    end
                    MMU_EVAL: begin
                        rsp_valid <= 1'b1;
                        if (perm_allow) begin
                            rsp_pa     <= {active_ppn, current_off};
                            rsp_fault  <= 1'b0;
                            rsp_xfault <= 1'b0;
                        end else begin
                            rsp_pa     <= {PAW{1'b0}};
                            rsp_fault  <= perm_pfault;
                            rsp_xfault <= perm_xfault;
                        end
                    end
                endcase
            end
        end
    end
endmodule