// SPDX-License-Identifier: MIT
// core_486_top : top-level CPU module.
//
// Tasks 0–4 stand up the skeleton and register file. Task 5 wires the
// prefetch path: prefetch issues bus reads at linear(CS:EIP), control
// consumes NOPs (other opcodes await Task 6/7), and prefetch pulses
// eip_inc_en on each consume so the register file advances EIP.
//
// FPU compilation modes — see docs/386_486_cpu_core_spec.md §5:
//   * `CORE_486_ENABLE_FPU` undefined : the FPU interface is not compiled
//     in. The decoder still routes FPU opcodes through an internal "no
//     interface" responder that raises #NM unconditionally.
//   * `CORE_486_ENABLE_FPU` defined   : core_486_fpu_if is instantiated;
//     the ENABLE_FPU parameter then chooses absent vs present behavior.

module core_486_top
  import core_486_pkg::*;
#(
    parameter cpu_personality_e PERSONALITY = P_486DX2_66,
    parameter bit               ENABLE_FPU  = 1'b0
) (
    input  logic        clk,
    input  logic        reset,

    // External bus master.
    output logic [31:0] bus_addr,
    output logic        bus_read,
    output logic        bus_write,
    output logic [3:0]  bus_byte_en,
    output logic [31:0] bus_wdata,
    input  logic        bus_ready,
    input  logic [31:0] bus_rdata,
    input  logic        bus_fault,

    // Interrupts.
    input  logic        intr_req,
    output logic        intr_ack,
    input  logic [7:0]  intr_vec,
    input  logic        nmi_req,

    // Debug / observability.
    output logic [31:0] dbg_eip,
    output logic [31:0] dbg_eflags,
    output logic [31:0] dbg_gpr   [8],
    output seg_reg_t    dbg_seg   [core_486_pkg::NUM_SEGS],
    output logic [31:0] dbg_cr0,
    output logic [31:0] dbg_cr2,
    output logic [31:0] dbg_cr3,
    output logic [31:0] dbg_cr4,
    output logic [31:0] dbg_retired_count,
    output logic        dbg_halted
);

  // ----------------------------------------------------------------------
  // Configuration.
  // ----------------------------------------------------------------------
  cpu_features_t features;
  core_486_config #(.PERSONALITY(PERSONALITY)) u_cfg (.features(features));

  // ----------------------------------------------------------------------
  // Register file.
  // ----------------------------------------------------------------------
  logic [31:0] gpr_rd1_data;
  logic [31:0] gpr_rd2_data;
  seg_reg_t    seg_rd_data;
  logic [31:0] eip;
  logic [31:0] eflags;
  logic [31:0] cr_rd_data;

  // Prefetch-driven EIP increment.
  logic        eip_inc_en;
  logic [31:0] eip_inc_val;

  op_size_e c_sz32;
  logic [2:0] c_seg_cs;
  seg_reg_t   c_seg_zero;
  assign c_sz32     = SZ_32;
  assign c_seg_cs   = 3'(SEG_CS);
  assign c_seg_zero = '0;

  core_486_regs #(.PERSONALITY(PERSONALITY)) u_regs (
      .clk           (clk),
      .reset         (reset),
      .gpr_rd1_sel   (3'd0),
      .gpr_rd1_size  (c_sz32),
      .gpr_rd1_data  (gpr_rd1_data),
      .gpr_rd2_sel   (3'd0),
      .gpr_rd2_size  (c_sz32),
      .gpr_rd2_data  (gpr_rd2_data),
      .gpr_wr_en     (1'b0),
      .gpr_wr_sel    (3'd0),
      .gpr_wr_size   (c_sz32),
      .gpr_wr_data   (32'h0),
      .seg_rd_sel    (c_seg_cs),
      .seg_rd_data   (seg_rd_data),
      .seg_wr_en     (1'b0),
      .seg_wr_sel    (c_seg_cs),
      .seg_wr_data   (c_seg_zero),
      .eip_set_en    (1'b0),
      .eip_set_val   (32'h0),
      .eip_inc_en    (eip_inc_en),
      .eip_inc_val   (eip_inc_val),
      .eip_q         (eip),
      .eflags_wr_en  (1'b0),
      .eflags_wr_val (32'h0),
      .eflags_wr_mask(32'h0),
      .eflags_q      (eflags),
      .cr_wr_en      (1'b0),
      .cr_wr_sel     (3'd0),
      .cr_wr_val     (32'h0),
      .cr_rd_sel     (3'd0),
      .cr_rd_data    (cr_rd_data),
      .dbg_gpr       (dbg_gpr),
      .dbg_seg       (dbg_seg),
      .dbg_cr0       (dbg_cr0),
      .dbg_cr2       (dbg_cr2),
      .dbg_cr3       (dbg_cr3),
      .dbg_cr4       (dbg_cr4)
  );

  // Convenience views from the CS read port.
  seg_reg_t cs_desc;
  assign cs_desc = seg_rd_data;
  wire [31:0] cs_base  = cs_desc.base;
  wire [31:0] cs_limit = cs_desc.limit;
  wire [15:0] cs_sel   = cs_desc.selector;
  wire [31:0] cr0      = dbg_cr0;

  // ----------------------------------------------------------------------
  // Segmentation + paging (paging disabled until Task 13).
  // ----------------------------------------------------------------------
  logic [31:0] linear_addr;
  core_486_segment u_segment (
      .seg_base   (cs_base),
      .offset     (eip),
      .linear_addr(linear_addr)
  );

  logic [31:0] phys_addr;
  logic        page_fault;
  core_486_paging u_paging (
      .paging_en  (cr0[CR0_PG]),
      .linear_addr(linear_addr),
      .phys_addr  (phys_addr),
      .page_fault (page_fault)
  );

  // ----------------------------------------------------------------------
  // Prefetch ↔ bus_if ↔ external bus.
  // ----------------------------------------------------------------------
  logic        pf_req_valid;
  logic [31:0] pf_req_addr;
  logic [3:0]  pf_req_byte_en;
  logic        pf_req_ready;
  logic [31:0] pf_req_rdata;
  logic        pf_req_fault;

  logic        pf_byte_valid;
  logic [7:0]  pf_byte_data;
  logic        pf_consume;
  logic        pf_fetch_fault;

  core_486_prefetch u_prefetch (
      .clk         (clk),
      .reset       (reset),
      .linear_addr (phys_addr),
      .req_valid   (pf_req_valid),
      .req_addr    (pf_req_addr),
      .req_byte_en (pf_req_byte_en),
      .req_ready   (pf_req_ready),
      .req_rdata   (pf_req_rdata),
      .req_fault   (pf_req_fault),
      .byte_valid  (pf_byte_valid),
      .byte_data   (pf_byte_data),
      .consume     (pf_consume),
      .eip_inc_en  (eip_inc_en),
      .eip_inc_val (eip_inc_val),
      .fetch_fault (pf_fetch_fault)
  );

  core_486_bus_if u_bus (
      .clk        (clk),
      .reset      (reset),
      .req_valid  (pf_req_valid),
      .req_addr   (pf_req_addr),
      .req_write  (1'b0),
      .req_byte_en(pf_req_byte_en),
      .req_wdata  (32'h0),
      .req_ready  (pf_req_ready),
      .req_rdata  (pf_req_rdata),
      .req_fault  (pf_req_fault),
      .bus_addr   (bus_addr),
      .bus_read   (bus_read),
      .bus_write  (bus_write),
      .bus_byte_en(bus_byte_en),
      .bus_wdata  (bus_wdata),
      .bus_ready  (bus_ready),
      .bus_rdata  (bus_rdata),
      .bus_fault  (bus_fault)
  );

  // ----------------------------------------------------------------------
  // Decode (stub) + control (NOP-streamer for Task 5).
  // ----------------------------------------------------------------------
  logic decode_busy;
  logic fpu_op_seen;
  core_486_decode u_decode (
      .clk        (clk),
      .reset      (reset),
      .byte_valid (pf_byte_valid),
      .byte_in    (pf_byte_data),
      .decode_busy(decode_busy),
      .fpu_op_seen(fpu_op_seen)
  );

  logic running;
  core_486_control u_control (
      .clk          (clk),
      .reset        (reset),
      .byte_valid   (pf_byte_valid),
      .byte_data    (pf_byte_data),
      .consume      (pf_consume),
      .halted       (dbg_halted),
      .retired_count(dbg_retired_count),
      .running      (running)
  );

  logic seq_idle;
  core_486_microcode u_microcode (
      .clk     (clk),
      .reset   (reset),
      .seq_idle(seq_idle)
  );

  // ----------------------------------------------------------------------
  // ALU placeholder (real wiring lands in Task 7).
  // ----------------------------------------------------------------------
  logic [31:0] alu_result;
  logic [31:0] alu_flags;
  core_486_alu u_alu (
      .a        (32'h0),
      .b        (32'h0),
      .op       (4'h0),
      .result   (alu_result),
      .flags_out(alu_flags)
  );

  // ----------------------------------------------------------------------
  // Exception arbiter — now sees the prefetch fault.
  // ----------------------------------------------------------------------
  logic       exc_pending;
  logic [7:0] exc_vector;
  core_486_exceptions u_exc (
      .reset      (reset),
      .raise_ud   (1'b0),
      .raise_nm   (fpu_op_seen),
      .raise_de   (1'b0),
      .raise_pf   (page_fault | pf_fetch_fault),
      .exc_pending(exc_pending),
      .exc_vector (exc_vector)
  );

  // ----------------------------------------------------------------------
  // FPU interface (conditionally compiled).
  // ----------------------------------------------------------------------
`ifdef CORE_486_ENABLE_FPU
  logic fpu_busy;
  logic fpu_raise_nm;
  logic fpu_complete;
  core_486_fpu_if #(.ENABLE_FPU(ENABLE_FPU)) u_fpu_if (
      .clk         (clk),
      .reset       (reset),
      .fpu_op_valid(fpu_op_seen),
      .fpu_op_byte (pf_byte_data),
      .fpu_busy    (fpu_busy),
      .fpu_raise_nm(fpu_raise_nm),
      .fpu_complete(fpu_complete)
  );
`else
  logic _unused_fpu;
  assign _unused_fpu = &{1'b0, ENABLE_FPU};
`endif

  // ----------------------------------------------------------------------
  // Misc.
  // ----------------------------------------------------------------------
  assign intr_ack   = 1'b0;
  assign dbg_eip    = eip;
  assign dbg_eflags = eflags;

  // ----------------------------------------------------------------------
  // Unused tie-off sink.
  // ----------------------------------------------------------------------
  logic _unused_top;
  assign _unused_top = &{1'b0,
                         features,
                         cs_sel, cs_limit,
                         running, seq_idle, decode_busy,
                         alu_result, alu_flags,
                         exc_pending, exc_vector,
                         intr_req, intr_vec, nmi_req,
                         gpr_rd1_data, gpr_rd2_data,
                         seg_rd_data, cr_rd_data};

endmodule : core_486_top
