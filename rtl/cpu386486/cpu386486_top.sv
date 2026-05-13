// SPDX-License-Identifier: MIT
// cpu386486_top : top-level CPU module.
//
// Wires the skeleton submodules together. Most internal nets are currently
// stubbed; this file's job at Task 2 is to establish the interface and
// make sure everything elaborates lint-clean. Functional behavior arrives
// task by task.
//
// FPU compilation modes — see docs/386_486_cpu_core_spec.md §5:
//   * `CPU386486_ENABLE_FPU` undefined : the FPU interface is not compiled
//     in. The decoder still routes FPU opcodes through an internal "no
//     interface" responder that raises #NM unconditionally.
//   * `CPU386486_ENABLE_FPU` defined   : cpu386486_fpu_if is instantiated;
//     the ENABLE_FPU parameter then chooses absent vs present behavior.

module cpu386486_top
  import cpu386486_pkg::*;
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
    output seg_reg_t    dbg_seg   [cpu386486_pkg::NUM_SEGS],
    output logic [31:0] dbg_cr0,
    output logic [31:0] dbg_cr2,
    output logic [31:0] dbg_cr3,
    output logic [31:0] dbg_cr4
);

  // ----------------------------------------------------------------------
  // Configuration.
  // ----------------------------------------------------------------------
  cpu_features_t features;
  cpu386486_config #(.PERSONALITY(PERSONALITY)) u_cfg (.features(features));

  // ----------------------------------------------------------------------
  // Register file. Write enables are held low at the top level until
  // Task 5+ wire up real execution; debug ports give the testbench full
  // observability.
  // ----------------------------------------------------------------------
  logic [31:0] gpr_rd1_data;
  logic [31:0] gpr_rd2_data;
  seg_reg_t    seg_rd_data;
  logic [31:0] eip;
  logic [31:0] eflags;
  logic [31:0] cr_rd_data;

  op_size_e c_sz32;
  logic [2:0] c_seg_cs;
  seg_reg_t   c_seg_zero;
  assign c_sz32     = SZ_32;
  assign c_seg_cs   = 3'(SEG_CS);
  assign c_seg_zero = '0;

  cpu386486_regs #(.PERSONALITY(PERSONALITY)) u_regs (
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
      .eip_inc_en    (1'b0),
      .eip_inc_val   (32'h0),
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

  // Convenience views still used by the rest of the skeleton.
  // iverilog 12 has trouble with struct-field access via unpacked-array
  // index in continuous assigns, so we route CS through an explicit seg
  // read port and unpack into scalar wires.
  seg_reg_t cs_desc;
  assign cs_desc = seg_rd_data;  // tied to seg_rd_sel = SEG_CS above
  wire [31:0] cs_base  = cs_desc.base;
  wire [31:0] cs_limit = cs_desc.limit;
  wire [15:0] cs_sel   = cs_desc.selector;
  wire [31:0] cr0      = dbg_cr0;

  // ----------------------------------------------------------------------
  // Control / sequencer / microcode (all stubs).
  // ----------------------------------------------------------------------
  logic running;
  cpu386486_control u_control (
      .clk    (clk),
      .reset  (reset),
      .running(running)
  );

  logic seq_idle;
  cpu386486_microcode u_microcode (
      .clk     (clk),
      .reset   (reset),
      .seq_idle(seq_idle)
  );

  // ----------------------------------------------------------------------
  // Prefetch + decode (stubs).
  // ----------------------------------------------------------------------
  logic       pf_byte_valid;
  logic [7:0] pf_byte_data;
  cpu386486_prefetch u_prefetch (
      .clk       (clk),
      .reset     (reset),
      .consume   (1'b0),
      .byte_valid(pf_byte_valid),
      .byte_data (pf_byte_data)
  );

  logic decode_busy;
  logic fpu_op_seen;
  cpu386486_decode u_decode (
      .clk        (clk),
      .reset      (reset),
      .byte_valid (pf_byte_valid),
      .byte_in    (pf_byte_data),
      .decode_busy(decode_busy),
      .fpu_op_seen(fpu_op_seen)
  );

  // ----------------------------------------------------------------------
  // ALU + segmentation + paging (stubs).
  // ----------------------------------------------------------------------
  logic [31:0] alu_result;
  logic [31:0] alu_flags;
  cpu386486_alu u_alu (
      .a        (32'h0),
      .b        (32'h0),
      .op       (4'h0),
      .result   (alu_result),
      .flags_out(alu_flags)
  );

  logic [31:0] linear_addr;
  cpu386486_segment u_segment (
      .seg_base   (cs_base),
      .offset     (eip),
      .linear_addr(linear_addr)
  );

  logic [31:0] phys_addr;
  logic        page_fault;
  cpu386486_paging u_paging (
      .paging_en  (cr0[CR0_PG]),
      .linear_addr(linear_addr),
      .phys_addr  (phys_addr),
      .page_fault (page_fault)
  );

  // ----------------------------------------------------------------------
  // Exception arbiter (stub).
  // ----------------------------------------------------------------------
  logic       exc_pending;
  logic [7:0] exc_vector;
  cpu386486_exceptions u_exc (
      .reset      (reset),
      .raise_ud   (1'b0),
      .raise_nm   (fpu_op_seen),  // routed through fpu_if below in full build
      .raise_de   (1'b0),
      .raise_pf   (page_fault),
      .exc_pending(exc_pending),
      .exc_vector (exc_vector)
  );

  // ----------------------------------------------------------------------
  // FPU interface (conditionally compiled).
  // ----------------------------------------------------------------------
`ifdef CPU386486_ENABLE_FPU
  logic fpu_busy;
  logic fpu_raise_nm;
  logic fpu_complete;
  cpu386486_fpu_if #(.ENABLE_FPU(ENABLE_FPU)) u_fpu_if (
      .clk         (clk),
      .reset       (reset),
      .fpu_op_valid(fpu_op_seen),
      .fpu_op_byte (pf_byte_data),
      .fpu_busy    (fpu_busy),
      .fpu_raise_nm(fpu_raise_nm),
      .fpu_complete(fpu_complete)
  );
`else
  // Suppress unread-parameter lint when the FPU interface is excluded.
  logic _unused_fpu;
  assign _unused_fpu = &{1'b0, ENABLE_FPU};
`endif

  // ----------------------------------------------------------------------
  // Bus interface.
  // ----------------------------------------------------------------------
  logic        bus_req_ready;
  logic [31:0] bus_req_rdata;
  logic        bus_req_fault;
  cpu386486_bus_if u_bus (
      .clk        (clk),
      .reset      (reset),
      .req_valid  (1'b0),
      .req_addr   (phys_addr),
      .req_write  (1'b0),
      .req_byte_en(4'h0),
      .req_wdata  (32'h0),
      .req_ready  (bus_req_ready),
      .req_rdata  (bus_req_rdata),
      .req_fault  (bus_req_fault),
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
  // Interrupt handshake (not yet implemented).
  // ----------------------------------------------------------------------
  assign intr_ack = 1'b0;

  // ----------------------------------------------------------------------
  // Debug observability.
  // ----------------------------------------------------------------------
  assign dbg_eip    = eip;
  assign dbg_eflags = eflags;

  // ----------------------------------------------------------------------
  // Tie off currently-unused signals to keep lint quiet without hiding the
  // real wiring we'll add later. Every name here has a TODO owner.
  // ----------------------------------------------------------------------
  logic _unused_top;
  assign _unused_top = &{1'b0,
                         features,        // TODO Task 5: use clock_mult
                         cs_sel,          // TODO Task 5: drive far-jump path
                         cs_limit,        // TODO Task 12: protection
                         running,         // TODO Task 5: gate fetch
                         seq_idle,        // TODO Task 6
                         decode_busy,     // TODO Task 6
                         alu_result,      // TODO Task 7
                         alu_flags,       // TODO Task 7
                         exc_pending,     // TODO Task 10
                         exc_vector,      // TODO Task 10
                         intr_req,        // TODO Task 10
                         intr_vec,        // TODO Task 10
                         nmi_req,         // TODO Task 10
                         bus_req_ready,   // TODO Task 5
                         bus_req_rdata,   // TODO Task 5
                         bus_req_fault,   // TODO Task 5
                         gpr_rd1_data,    // TODO Task 7
                         gpr_rd2_data,    // TODO Task 7
                         seg_rd_data,     // TODO Task 9
                         cr_rd_data};     // TODO Task 12

endmodule : cpu386486_top
