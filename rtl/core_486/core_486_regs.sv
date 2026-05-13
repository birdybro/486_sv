// SPDX-License-Identifier: MIT
// core_486_regs : architectural register file.
//
// Holds:
//   * Eight 32-bit GPRs (EAX..EDI) with 8/16/32-bit access windows.
//   * Six segment registers (selector + hidden descriptor cache).
//   * EIP and EFLAGS.
//   * CR0/CR2/CR3 (and CR4 for 486 personalities).
//
// Two GPR read ports + one GPR write port match the bandwidth a simple
// integer ALU stage needs. The 8-bit register encoding follows Intel's
// reg field semantics — encoding 0..3 selects the low byte of
// EAX/ECX/EDX/EBX, encoding 4..7 selects the high byte (AH/CH/DH/BH) of
// the same group.
//
// References: Intel 80386 PRM §2 (registers, flags), Intel i486 PRM §2,
// and §10 for reset semantics.

module core_486_regs
  import core_486_pkg::*;
#(
    parameter cpu_personality_e PERSONALITY = P_386DX_25
) (
    input  logic              clk,
    input  logic              reset,

    // ------------------------------------------------------------------
    // GPR ports.
    // ------------------------------------------------------------------
    input  logic [2:0]        gpr_rd1_sel,
    input  op_size_e          gpr_rd1_size,
    output logic [31:0]       gpr_rd1_data,

    input  logic [2:0]        gpr_rd2_sel,
    input  op_size_e          gpr_rd2_size,
    output logic [31:0]       gpr_rd2_data,

    input  logic              gpr_wr_en,
    input  logic [2:0]        gpr_wr_sel,
    input  op_size_e          gpr_wr_size,
    input  logic [31:0]       gpr_wr_data,

    // ------------------------------------------------------------------
    // Segment register ports.
    // ------------------------------------------------------------------
    input  logic [2:0]        seg_rd_sel,
    output seg_reg_t          seg_rd_data,
    input  logic              seg_wr_en,
    input  logic [2:0]        seg_wr_sel,
    input  seg_reg_t          seg_wr_data,

    // ------------------------------------------------------------------
    // EIP port. eip_set_en performs an arbitrary write; the prefetch path
    // commonly uses eip_inc_en with eip_inc_val to advance.
    // ------------------------------------------------------------------
    input  logic              eip_set_en,
    input  logic [31:0]       eip_set_val,
    input  logic              eip_inc_en,
    input  logic [31:0]       eip_inc_val,
    output logic [31:0]       eip_q,

    // ------------------------------------------------------------------
    // EFLAGS port. write_mask gates which bits the caller wants to commit
    // (the register file additionally enforces EFLAGS_SUPPORTED_MASK and
    // the reserved-1 bit).
    // ------------------------------------------------------------------
    input  logic              eflags_wr_en,
    input  logic [31:0]       eflags_wr_val,
    input  logic [31:0]       eflags_wr_mask,
    output logic [31:0]       eflags_q,

    // ------------------------------------------------------------------
    // Control registers.
    // ------------------------------------------------------------------
    input  logic              cr_wr_en,
    input  logic [2:0]        cr_wr_sel,    // 0=CR0, 2=CR2, 3=CR3, 4=CR4
    input  logic [31:0]       cr_wr_val,
    input  logic [2:0]        cr_rd_sel,
    output logic [31:0]       cr_rd_data,

    // ------------------------------------------------------------------
    // Debug observability (for testbenches and waveform debugging only).
    // ------------------------------------------------------------------
    output logic [31:0]       dbg_gpr[8],
    output seg_reg_t          dbg_seg[NUM_SEGS],
    output logic [31:0]       dbg_cr0,
    output logic [31:0]       dbg_cr2,
    output logic [31:0]       dbg_cr3,
    output logic [31:0]       dbg_cr4
);

  // ----------------------------------------------------------------------
  // Configuration lookup (drives CR0 reset value and CR4 visibility).
  // ----------------------------------------------------------------------
  cpu_features_t features;
  core_486_config #(.PERSONALITY(PERSONALITY)) u_cfg (.features(features));

  wire [31:0] cr0_reset_val =
      (features.family == FAM_486) ? RESET_CR0_486 : RESET_CR0_386;

  // EFLAGS supported mask, narrowed for 386 (no AC bit).
  wire [31:0] eflags_personality_mask =
      EFLAGS_SUPPORTED_MASK & (features.supports_alignchk
                               ? 32'hFFFF_FFFF
                               : ~(32'h1 << EFLAGS_AC));

  // ----------------------------------------------------------------------
  // GPR storage.
  //
  // The read paths use combinational logic. The 8-bit Intel reg encoding
  // selects AL/CL/DL/BL when sel[2]=0 and AH/CH/DH/BH (bits[15:8] of the
  // low-group EAX/ECX/EDX/EBX) when sel[2]=1.
  // ----------------------------------------------------------------------
  logic [31:0] gpr_q [8];

  // Read port 1.
  logic [2:0]  rd1_lo_idx;
  logic        rd1_hi_byte;
  logic [31:0] rd1_full;
  always_comb begin
    rd1_hi_byte = (gpr_rd1_size == SZ_8) && gpr_rd1_sel[2];
    rd1_lo_idx  = rd1_hi_byte ? {1'b0, gpr_rd1_sel[1:0]} : gpr_rd1_sel;
    if (rd1_hi_byte) rd1_full = {24'h0, gpr_q[rd1_lo_idx][15:8]};
    else             rd1_full = gpr_q[rd1_lo_idx];
    case (gpr_rd1_size)
      SZ_8:    gpr_rd1_data = {24'h0, rd1_full[7:0]};
      SZ_16:   gpr_rd1_data = {16'h0, rd1_full[15:0]};
      default: gpr_rd1_data = rd1_full;
    endcase
  end

  // Read port 2.
  logic [2:0]  rd2_lo_idx;
  logic        rd2_hi_byte;
  logic [31:0] rd2_full;
  always_comb begin
    rd2_hi_byte = (gpr_rd2_size == SZ_8) && gpr_rd2_sel[2];
    rd2_lo_idx  = rd2_hi_byte ? {1'b0, gpr_rd2_sel[1:0]} : gpr_rd2_sel;
    if (rd2_hi_byte) rd2_full = {24'h0, gpr_q[rd2_lo_idx][15:8]};
    else             rd2_full = gpr_q[rd2_lo_idx];
    case (gpr_rd2_size)
      SZ_8:    gpr_rd2_data = {24'h0, rd2_full[7:0]};
      SZ_16:   gpr_rd2_data = {16'h0, rd2_full[15:0]};
      default: gpr_rd2_data = rd2_full;
    endcase
  end

  // Write path: compute target index and merged value combinationally.
  logic [2:0]  wr_tgt;
  logic        wr_hi_byte;
  logic [31:0] wr_cur;
  logic [31:0] wr_merged;
  always_comb begin
    wr_hi_byte = (gpr_wr_size == SZ_8) && gpr_wr_sel[2];
    wr_tgt     = wr_hi_byte ? {1'b0, gpr_wr_sel[1:0]} : gpr_wr_sel;
    wr_cur     = gpr_q[wr_tgt];
    case (gpr_wr_size)
      SZ_8:    wr_merged = wr_hi_byte
                         ? {wr_cur[31:16], gpr_wr_data[7:0], wr_cur[7:0]}
                         : {wr_cur[31:8],  gpr_wr_data[7:0]};
      SZ_16:   wr_merged = {wr_cur[31:16], gpr_wr_data[15:0]};
      default: wr_merged = gpr_wr_data;
    endcase
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      for (int i = 0; i < 8; i++) gpr_q[i] <= 32'h0;
    end else if (gpr_wr_en) begin
      gpr_q[wr_tgt] <= wr_merged;
    end
  end

  // ----------------------------------------------------------------------
  // Segment storage.
  //
  // CS gets the magic high-base reset state; all others get base 0, limit
  // 0xFFFF in real-mode descriptor form. We use a single seg_reg_t for
  // both "CS reset" and "default reset" to keep simulators (Icarus 12)
  // away from function-return-struct constructs.
  // ----------------------------------------------------------------------
  seg_reg_t seg_q [NUM_SEGS];

  seg_reg_t cs_reset_val;
  seg_reg_t other_reset_val;
  always_comb begin
    cs_reset_val.selector    = RESET_CS_SEL;
    cs_reset_val.base        = RESET_CS_BASE;
    cs_reset_val.limit       = RESET_CS_LIMIT;
    cs_reset_val.access      = 12'h093;
    other_reset_val.selector = 16'h0000;
    other_reset_val.base     = RESET_OTHER_BASE;
    other_reset_val.limit    = RESET_OTHER_LIM;
    other_reset_val.access   = 12'h093;
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      for (int i = 0; i < NUM_SEGS; i++) begin
        if (i == int'(SEG_CS)) seg_q[i] <= cs_reset_val;
        else                   seg_q[i] <= other_reset_val;
      end
    end else if (seg_wr_en) begin
      seg_q[seg_wr_sel] <= seg_wr_data;
    end
  end

  assign seg_rd_data = seg_q[seg_rd_sel];

  // ----------------------------------------------------------------------
  // EIP.
  // ----------------------------------------------------------------------
  logic [31:0] eip_r;

  always_ff @(posedge clk) begin
    if (reset)               eip_r <= RESET_EIP;
    else if (eip_set_en)     eip_r <= eip_set_val;
    else if (eip_inc_en)     eip_r <= eip_r + eip_inc_val;
  end

  assign eip_q = eip_r;

  // ----------------------------------------------------------------------
  // EFLAGS.
  // ----------------------------------------------------------------------
  logic [31:0] eflags_r;

  wire [31:0] eflags_effective_mask = eflags_wr_mask & eflags_personality_mask;

  always_ff @(posedge clk) begin
    if (reset) begin
      eflags_r <= RESET_EFLAGS;
    end else if (eflags_wr_en) begin
      eflags_r <= ((eflags_r & ~eflags_effective_mask)
                 | (eflags_wr_val & eflags_effective_mask))
                | EFLAGS_RESERVED_ONE_MASK;
    end
  end

  assign eflags_q = eflags_r | EFLAGS_RESERVED_ONE_MASK;

  // ----------------------------------------------------------------------
  // Control registers.
  // ----------------------------------------------------------------------
  logic [31:0] cr0_r;
  logic [31:0] cr2_r;
  logic [31:0] cr3_r;
  logic [31:0] cr4_r;

  always_ff @(posedge clk) begin
    if (reset) begin
      cr0_r <= cr0_reset_val;
      cr2_r <= 32'h0;
      cr3_r <= 32'h0;
      cr4_r <= 32'h0;
    end else if (cr_wr_en) begin
      case (cr_wr_sel)
        3'd0: cr0_r <= cr_wr_val;
        3'd2: cr2_r <= cr_wr_val;
        3'd3: cr3_r <= cr_wr_val;
        3'd4: if (features.supports_cr4) cr4_r <= cr_wr_val;
        default: ; // ignore
      endcase
    end
  end

  always_comb begin
    cr_rd_data = 32'h0;
    case (cr_rd_sel)
      3'd0: cr_rd_data = cr0_r;
      3'd2: cr_rd_data = cr2_r;
      3'd3: cr_rd_data = cr3_r;
      3'd4: cr_rd_data = features.supports_cr4 ? cr4_r : 32'h0;
      default: cr_rd_data = 32'h0;
    endcase
  end

  // ----------------------------------------------------------------------
  // Debug observability.
  // ----------------------------------------------------------------------
  always_comb begin
    for (int i = 0; i < 8; i++)         dbg_gpr[i] = gpr_q[i];
    for (int i = 0; i < NUM_SEGS; i++)  dbg_seg[i] = seg_q[i];
  end

  assign dbg_cr0 = cr0_r;
  assign dbg_cr2 = cr2_r;
  assign dbg_cr3 = cr3_r;
  assign dbg_cr4 = cr4_r;

endmodule : core_486_regs
