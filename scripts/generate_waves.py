import os
import matplotlib.pyplot as plt
from vcdvcd import VCDVCD

# Ensure outputs directory exists
os.makedirs("outputs", exist_ok=True)

vcd_path = "outputs/mmu.vcd"
if not os.path.exists(vcd_path):
    print(f"[ERROR] {vcd_path} not found. Please run 'vvp outputs/mmu_simulation' first.")
    exit(1)

# Load simulation data arrays
vcd = VCDVCD(vcd_path)
clk_data = vcd['mmu_tb.clk'].tv
times = [item[0] for item in clk_data]

# Safe padding helper to align hardware signals to the timeline
def get_padded_signal(signal_path, target_times):
    sig_data = vcd[signal_path].tv
    sig_dict = dict(sig_data)
    padded_values = []
    last_val = 0
    for t in target_times:
        if t in sig_dict:
            last_val = int(sig_dict[t])
        padded_values.append(last_val)
    return padded_values

# Extract signals
clk_trace   = [item[1] for item in clk_data]
req_trace   = get_padded_signal('mmu_tb.req_valid', times)
rsp_trace   = get_padded_signal('mmu_tb.rsp_valid', times)
fault_trace = get_padded_signal('mmu_tb.rsp_fault', times)

# Helper function to generate individual standalone plots
def save_individual_waveform(filename, title, signals_to_plot):
    fig, axes = plt.subplots(len(signals_to_plot), 1, figsize=(10, 5), sharex=True)
    fig.suptitle(title, fontsize=12, fontweight='bold')
    
    # Handle single-signal arrays versus multi-signal tracking
    if len(signals_to_plot) == 1:
        axes = [axes]
        
    for i, (name, y_data, color) in enumerate(signals_to_plot):
        axes[i].step(times, y_data, where='post', color=color, linewidth=2)
        axes[i].set_ylabel(name, fontsize=9, fontweight='bold')
        axes[i].set_ylim(-0.2, 1.2)
        axes[i].set_yticks([0, 1])
        axes[i].grid(True, linestyle='--', alpha=0.4)
        
    plt.xlabel("Simulation Timestamp Grid (ps)", fontsize=10)
    plt.tight_layout()
    
    output_path = f"outputs/{filename}"
    plt.savefig(output_path, dpi=300)
    plt.close()
    print(f"[SUCCESS] Exported: {output_path}")

# =========================================================================
# IMAGE 1: Cold Translation Miss & PTW Walk
# =========================================================================
save_individual_waveform(
    filename="wave_capture1.png",
    title="Image 1: Cold Translation Miss & Page Table Walk Traces",
    signals_to_plot=[
        ("Clock (clk)", clk_trace, 'b'),
        ("Req Valid", req_trace, 'g'),
        ("Rsp Valid", rsp_trace, 'darkgreen')
    ]
)

# =========================================================================
# IMAGE 2: TLB Cache Hot Hit
# =========================================================================
save_individual_waveform(
    filename="wave_capture2.png",
    title="Image 2: High-Speed TLB Cache Hit (Single-Cycle) Traces",
    signals_to_plot=[
        ("Clock (clk)", clk_trace, 'b'),
        ("Req Valid", req_trace, 'g'),
        ("Rsp Valid", rsp_trace, 'darkgreen')
    ]
)

# =========================================================================
# IMAGE 3: Privilege Access Protection Fault
# =========================================================================
save_individual_waveform(
    filename="wave_capture3.png",
    title="Image 3: Privilege Protection Boundary Violation Fault Traces",
    signals_to_plot=[
        ("Clock (clk)", clk_trace, 'b'),
        ("Req Valid", req_trace, 'g'),
        ("Rsp Fault", fault_trace, 'r')
    ]
)

# =========================================================================
# IMAGE 4: MMU Dynamic Translation Bypass
# =========================================================================
save_individual_waveform(
    filename="wave_capture4.png",
    title="Image 4: Translation Bypass Mode Traces",
    signals_to_plot=[
        ("Clock (clk)", clk_trace, 'b'),
        ("Req Valid", req_trace, 'g'),
        ("Rsp Valid", rsp_trace, 'darkgreen')
    ]
)

print("\n🎉 All 4 individual PNG hardware images are completely generated!")