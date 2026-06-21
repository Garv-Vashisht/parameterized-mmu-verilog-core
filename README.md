# Fully Synthesizable Memory Management Unit (MMU) in Verilog HDL

A high-performance, modular Memory Management Unit (MMU) implemented in IEEE 1364-2001/SystemVerilog hybrid HDL. This hardware engine features a dual-stage Translation Lookaside Buffer (TLB), an autonomous state-machine-driven Page Table Walker (PTW), and hardware-level permission validation circuits designed for FPGA targeting.

---

## 🛠️ Project Architecture

```text
MMU-Design-Verilog-HDL/
├── rtl/                # Hardware Description Source Code
│   ├── tlb.v           # Translation Lookaside Buffer (Cache Array)
│   ├── perm.v          # Permission Validation Unit
│   ├── ptw.v           # Autonomous Page Table Walker FSM
│   └── mmu.v           # Top-Level System Integration Module
├── tb/                 # Verification Environment & Stimulus
│   ├── mem_bram.v      # Synthesizable Dual-Port Block RAM Behavioral Model
│   └── mmu_tb.v        # Testbench with Automated Assertion Checkers
├── constraints/        # Physical Board Hardware Target Mapping
│   └── physical.xdc    # AMD/Xilinx Vivado Placement Constraints
├── outputs/            # Simulation Captures, Logs, and Waveform Files
└── scripts/            # Compilation and Build Automation Manifests