`timescale 1ns/1ps

module perm_check(
    input  wire       priv, // 0: User-space, 1: Supervisor-space
    input  wire       acc_load,
    input  wire       acc_store,
    input  wire       acc_ifetch,
    input  wire       pV,
    input  wire       pR,
    input  wire       pW,
    input  wire       pX,
    input  wire       pU,
    output wire       allow,
    output wire       pfault,
    output wire       xfault
);
    // User Mode Isolation Validation Rules
    wire privilege_valid = (~priv) ? (pU == 1'b1) : 1'b1;

    wire read_allowed    = acc_load   ? (pR & privilege_valid) : 1'b1;
    wire write_allowed   = acc_store  ? (pW & privilege_valid) : 1'b1;
    wire execute_allowed = acc_ifetch ? (pX & privilege_valid) : 1'b1;

    assign allow  = pV & read_allowed & write_allowed & execute_allowed;
    assign pfault = pV & privilege_valid & ((acc_load & ~pR) | (acc_store & ~pW));
    assign xfault = pV & privilege_valid & (acc_ifetch & ~pX);
endmodule