// SPDX-License-Identifier: MIT
// cpu386486_regs : architectural register file (stub — to be implemented in
// Task 4). Holds GPRs, segment registers (selector + hidden descriptor),
// EIP, EFLAGS, and CR0/CR2/CR3/CR4 placeholders.
//
// At present, this stub only models reset state and provides combinational
// read ports for the rest of the core to compile against.

module cpu386486_regs
  import cpu386486_pkg::*;
#(
    parameter cpu_personality_e PERSONALITY = P_386DX_25
) (
    input  logic        clk,
    input  logic        reset,

    // Read ports used by fetch / decode in later tasks.
    output logic [15:0] cs_selector,
    output logic [31:0] cs_base,
    output logic [31:0] cs_limit,
    output logic [31:0] eip,
    output logic [31:0] eflags,
    output logic [31:0] cr0
);

  logic [15:0] cs_sel_q;
  logic [31:0] cs_base_q;
  logic [31:0] cs_limit_q;
  logic [31:0] eip_q;
  logic [31:0] eflags_q;
  logic [31:0] cr0_q;

  // Family-aware reset CR0.
  cpu_features_t features;
  cpu386486_config #(.PERSONALITY(PERSONALITY)) u_cfg (.features(features));
  wire [31:0] cr0_reset_val = (features.family == FAM_486)
                            ? RESET_CR0_486 : RESET_CR0_386;

  always_ff @(posedge clk) begin
    if (reset) begin
      cs_sel_q   <= RESET_CS_SEL;
      cs_base_q  <= RESET_CS_BASE;
      cs_limit_q <= RESET_CS_LIMIT;
      eip_q      <= RESET_EIP;
      eflags_q   <= RESET_EFLAGS;
      cr0_q      <= cr0_reset_val;
    end
  end

  assign cs_selector = cs_sel_q;
  assign cs_base     = cs_base_q;
  assign cs_limit    = cs_limit_q;
  assign eip         = eip_q;
  assign eflags      = eflags_q;
  assign cr0         = cr0_q;

endmodule : cpu386486_regs
