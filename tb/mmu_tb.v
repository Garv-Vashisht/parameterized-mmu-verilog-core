`timescale 1ns/1ps

module mmu_tb;
    reg clk;
    reg rst_n;
    reg en;
    reg translate_en;
    reg [19:0] satp_base_ppn;
    reg [7:0]  csr_asid;
    reg        req_valid;
    reg [31:0] req_va;
    reg [1:0]  req_acc;
    reg        req_priv;

    wire        rsp_valid;
    wire [31:0] rsp_pa;
    wire        rsp_fault;
    wire        rsp_xfault;
    wire        mem_req;
    wire [31:0] mem_addr;
    
    reg         mem_rdy;
    reg  [31:0] mem_rdata;
    reg         mem_err;

    integer file1, file2, file3, file4;

    // Clock Grid
    always #5 clk = ~clk;

    // DUT Instance
    mmu #(.VAW(32), .PAW(32)) dut (
        .clk(clk), .rst_n(rst_n), .en(en), .translate_en(translate_en),
        .satp_base_ppn(satp_base_ppn), .csr_asid(csr_asid),
        .req_valid(req_valid), .req_va(req_va), .req_acc(req_acc), .req_priv(req_priv),
        .rsp_valid(rsp_valid), .rsp_pa(rsp_pa), .rsp_fault(rsp_fault), .rsp_xfault(rsp_xfault),
        .mem_req(mem_req), .mem_addr(mem_addr), .mem_rdy(mem_rdy), .mem_rdata(mem_rdata), .mem_err(mem_err)
    );

    // Memory Model Emulator
    always @(posedge clk) begin
        if (!rst_n) begin
            mem_rdy   <= 1'b0;
            mem_rdata <= 32'h0;
            mem_err   <= 1'b0;
        end else if (mem_req) begin
            #1;
            mem_rdy   <= 1'b1;
            mem_rdata <= 32'h1000_000F; // Valid, R/W/X set
            mem_err   <= 1'b0;
        end else begin
            mem_rdy   <= 1'b0;
        end
    end

    initial begin
        $dumpfile("outputs/mmu.vcd");
        $dumpvars(0, mmu_tb);

        clk = 0; rst_n = 0; en = 1; translate_en = 1;
        satp_base_ppn = 20'h90000; csr_asid = 8'h01;
        req_valid = 0; req_va = 32'h0040_1000; req_acc = 2'b01; req_priv = 1'b1;

        #20; rst_n = 1; #20;

        // ==========================================
        // IMAGE CAPTURE 1: Cold Translation Walk
        // ==========================================
        $display("[TB] Running Scenario 1...");
        file1 = $fopen("outputs/wave_capture1.txt", "w");
        $fwrite(file1, "=== WAVE CAPTURE 1: COLD TRANSLATION (PTW WALK) ===\n");
        $fwrite(file1, "TIME(ns) | CLK | REQ_VALID | TRANSLATE_EN | RSP_VALID | FAULT\n");
        
        @(posedge clk); req_valid = 1'b1;
        repeat (8) begin
            @(posedge clk);
            $fwrite(file1, "%t  |  %b  |     %b     |      %b       |     %b     |   %b\n", $time, clk, req_valid, translate_en, rsp_valid, rsp_fault);
        end
        req_valid = 1'b0;
        $fclose(file1);
        #40;

        // ==========================================
        // IMAGE CAPTURE 2: TLB Cache Hot Hit
        // ==========================================
        $display("[TB] Running Scenario 2...");
        file2 = $fopen("outputs/wave_capture2.txt", "w");
        $fwrite(file2, "=== WAVE CAPTURE 2: TLB CACHE CACHED HIT ===\n");
        $fwrite(file2, "TIME(ns) | CLK | REQ_VALID | TLB_HIT | RSP_VALID | RSP_PA\n");
        
        req_valid = 1'b1;
        repeat (4) begin
            @(posedge clk);
            $fwrite(file2, "%t  |  %b  |     %b     |    %b    |     %b     | 0x%h\n", $time, clk, req_valid, dut.tlb_hit, rsp_valid, rsp_pa);
        end
        req_valid = 1'b0;
        $fclose(file2);
        #40;

        // ==========================================
        // IMAGE CAPTURE 3: User Privilege Fault
        // ==========================================
        $display("[TB] Running Scenario 3...");
        file3 = $fopen("outputs/wave_capture3.txt", "w");
        $fwrite(file3, "=== WAVE CAPTURE 3: PRIVILEGE PROTECTION FAULT ===\n");
        $fwrite(file3, "TIME(ns) | PRIV(1=S,0=U) | REQ_VALID | RSP_VALID | RSP_FAULT\n");
        
        req_priv = 1'b0; // Drop to User Mode
        req_valid = 1'b1;
        repeat (4) begin
            @(posedge clk);
            $fwrite(file3, "%t  |       %b       |     %b     |     %b     |     %b\n", $time, req_priv, req_valid, rsp_valid, rsp_fault);
        end
        req_valid = 1'b0;
        $fclose(file3);
        #40;

        // ==========================================
        // IMAGE CAPTURE 4: Bypass Translation Mode
        // ==========================================
        $display("[TB] Running Scenario 4...");
        file4 = $fopen("outputs/wave_capture4.txt", "w");
        $fwrite(file4, "=== WAVE CAPTURE 4: TRANSLATION BYPASS ===\n");
        $fwrite(file4, "TIME(ns) | TRANSLATE_EN | REQ_VA     | RSP_VALID | RSP_PA\n");
        
        translate_en = 1'b0; // Disable MMU Translation
        req_valid = 1'b1;
        req_va = 32'hAAAA_BBBB;
        repeat (4) begin
            @(posedge clk);
            $fwrite(file4, "%t  |      %b       | 0x%h |     %b     | 0x%h\n", $time, translate_en, req_va, rsp_valid, rsp_pa);
        end
        req_valid = 1'b0;
        $fclose(file4);

        $display("[TB EXECUTION] All 4 Image Captures generated successfully inside outputs/ folder.");
        $finish;
    end
endmodule