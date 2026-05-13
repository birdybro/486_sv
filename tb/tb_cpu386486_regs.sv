// SPDX-License-Identifier: MIT
// tb_cpu386486_regs : directed tests for the architectural register file.
//
// Exercises 8/16/32-bit GPR access paths (including AH/BH/CH/DH high-byte
// addressing), segment register loads, EIP arbitrary-write and increment
// paths, EFLAGS write-mask semantics + reserved-1 bit, and CR0/CR2/CR3/CR4
// access (including CR4 gating on 386 personalities).

`timescale 1ns/1ps

module tb_cpu386486_regs;

  import cpu386486_pkg::*;

  // ----------------------------------------------------------------------
  // DUT instances — one 386, one 486.
  // ----------------------------------------------------------------------
  logic clk;
  logic reset;

  // Common stimulus.
  logic [2:0]   rd1_sel,  rd2_sel,  wr_sel;
  op_size_e     rd1_size, rd2_size, wr_size;
  logic         wr_en;
  logic [31:0]  wr_data;

  logic [2:0]   seg_rd_sel,  seg_wr_sel;
  logic         seg_wr_en;
  seg_reg_t     seg_wr_data;

  logic         eip_set_en, eip_inc_en;
  logic [31:0]  eip_set_val, eip_inc_val;

  logic         ef_wr_en;
  logic [31:0]  ef_wr_val, ef_wr_mask;

  logic         cr_wr_en;
  logic [2:0]   cr_wr_sel, cr_rd_sel;
  logic [31:0]  cr_wr_val;

  // DUT-A: 386DX (no CR4, no AC).
  logic [31:0] a_rd1, a_rd2, a_eip, a_ef, a_cr;
  seg_reg_t    a_seg;
  logic [31:0] a_gpr[8];
  seg_reg_t    a_segs[NUM_SEGS];
  logic [31:0] a_cr0, a_cr2, a_cr3, a_cr4;

  cpu386486_regs #(.PERSONALITY(P_386DX_25)) dut_a (
      .clk(clk), .reset(reset),
      .gpr_rd1_sel(rd1_sel), .gpr_rd1_size(rd1_size), .gpr_rd1_data(a_rd1),
      .gpr_rd2_sel(rd2_sel), .gpr_rd2_size(rd2_size), .gpr_rd2_data(a_rd2),
      .gpr_wr_en(wr_en), .gpr_wr_sel(wr_sel), .gpr_wr_size(wr_size), .gpr_wr_data(wr_data),
      .seg_rd_sel(seg_rd_sel), .seg_rd_data(a_seg),
      .seg_wr_en(seg_wr_en), .seg_wr_sel(seg_wr_sel), .seg_wr_data(seg_wr_data),
      .eip_set_en(eip_set_en), .eip_set_val(eip_set_val),
      .eip_inc_en(eip_inc_en), .eip_inc_val(eip_inc_val), .eip_q(a_eip),
      .eflags_wr_en(ef_wr_en), .eflags_wr_val(ef_wr_val), .eflags_wr_mask(ef_wr_mask),
      .eflags_q(a_ef),
      .cr_wr_en(cr_wr_en), .cr_wr_sel(cr_wr_sel), .cr_wr_val(cr_wr_val),
      .cr_rd_sel(cr_rd_sel), .cr_rd_data(a_cr),
      .dbg_gpr(a_gpr), .dbg_seg(a_segs),
      .dbg_cr0(a_cr0), .dbg_cr2(a_cr2), .dbg_cr3(a_cr3), .dbg_cr4(a_cr4)
  );

  // DUT-B: 486DX2 (CR4 visible, AC supported).
  logic [31:0] b_rd1, b_rd2, b_eip, b_ef, b_cr;
  seg_reg_t    b_seg;
  logic [31:0] b_gpr[8];
  seg_reg_t    b_segs[NUM_SEGS];
  logic [31:0] b_cr0, b_cr2, b_cr3, b_cr4;

  cpu386486_regs #(.PERSONALITY(P_486DX2_66)) dut_b (
      .clk(clk), .reset(reset),
      .gpr_rd1_sel(rd1_sel), .gpr_rd1_size(rd1_size), .gpr_rd1_data(b_rd1),
      .gpr_rd2_sel(rd2_sel), .gpr_rd2_size(rd2_size), .gpr_rd2_data(b_rd2),
      .gpr_wr_en(wr_en), .gpr_wr_sel(wr_sel), .gpr_wr_size(wr_size), .gpr_wr_data(wr_data),
      .seg_rd_sel(seg_rd_sel), .seg_rd_data(b_seg),
      .seg_wr_en(seg_wr_en), .seg_wr_sel(seg_wr_sel), .seg_wr_data(seg_wr_data),
      .eip_set_en(eip_set_en), .eip_set_val(eip_set_val),
      .eip_inc_en(eip_inc_en), .eip_inc_val(eip_inc_val), .eip_q(b_eip),
      .eflags_wr_en(ef_wr_en), .eflags_wr_val(ef_wr_val), .eflags_wr_mask(ef_wr_mask),
      .eflags_q(b_ef),
      .cr_wr_en(cr_wr_en), .cr_wr_sel(cr_wr_sel), .cr_wr_val(cr_wr_val),
      .cr_rd_sel(cr_rd_sel), .cr_rd_data(b_cr),
      .dbg_gpr(b_gpr), .dbg_seg(b_segs),
      .dbg_cr0(b_cr0), .dbg_cr2(b_cr2), .dbg_cr3(b_cr3), .dbg_cr4(b_cr4)
  );

  // ----------------------------------------------------------------------
  // Clock.
  // ----------------------------------------------------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  int unsigned fails;

  task automatic check(string lbl, logic cond);
    if (!cond) begin $display("FAIL: %s", lbl); fails = fails + 1; end
    else            $display(" ok : %s", lbl);
  endtask

  task automatic check_eq32(string lbl, logic [31:0] got, logic [31:0] exp);
    if (got !== exp) begin
      $display("FAIL: %s got=0x%08x exp=0x%08x", lbl, got, exp);
      fails = fails + 1;
    end else $display(" ok : %s = 0x%08x", lbl, got);
  endtask

  task automatic idle_inputs;
    wr_en       = 1'b0; wr_sel = 3'd0; wr_size = SZ_32; wr_data = 32'h0;
    seg_wr_en   = 1'b0; seg_wr_sel = 3'd0; seg_wr_data = '0;
    eip_set_en  = 1'b0; eip_set_val = 32'h0;
    eip_inc_en  = 1'b0; eip_inc_val = 32'h0;
    ef_wr_en    = 1'b0; ef_wr_val = 32'h0; ef_wr_mask = 32'h0;
    cr_wr_en    = 1'b0; cr_wr_sel = 3'd0; cr_wr_val = 32'h0;
  endtask

  task automatic write_gpr(input logic [2:0] sel, input op_size_e sz, input logic [31:0] data);
    @(negedge clk);
    wr_en   = 1'b1; wr_sel = sel; wr_size = sz; wr_data = data;
    @(posedge clk);
    @(negedge clk);
    wr_en   = 1'b0;
  endtask

  initial begin
    fails = 0;
    idle_inputs();
    rd1_sel = 3'd0; rd1_size = SZ_32; rd2_sel = 3'd0; rd2_size = SZ_32;
    seg_rd_sel = 3'd0;
    cr_rd_sel  = 3'd0;

    reset = 1'b1;
    repeat (3) @(posedge clk);
    @(negedge clk) reset = 1'b0;
    @(posedge clk);

    // ------------------------------------------------------------------
    // 32-bit GPR write/read round-trip.
    // ------------------------------------------------------------------
    write_gpr(3'd0, SZ_32, 32'hDEAD_BEEF);   // EAX
    rd1_sel = 3'd0; rd1_size = SZ_32; #1;
    check_eq32("EAX 32b round-trip", a_rd1, 32'hDEAD_BEEF);

    // ------------------------------------------------------------------
    // 16-bit write keeps upper half.
    // ------------------------------------------------------------------
    write_gpr(3'd0, SZ_16, 32'h0000_1234);   // AX
    rd1_size = SZ_16; #1;
    check_eq32("AX after 16b write",   a_rd1, 32'h0000_1234);
    rd1_size = SZ_32; #1;
    check_eq32("EAX upper preserved",  a_rd1, 32'hDEAD_1234);

    // ------------------------------------------------------------------
    // 8-bit AL write keeps AH and upper.
    // ------------------------------------------------------------------
    write_gpr(3'd0, SZ_8, 32'h0000_0042);    // AL
    rd1_size = SZ_8; #1;
    check_eq32("AL after 8b write",    a_rd1, 32'h0000_0042);
    rd1_size = SZ_32; #1;
    check_eq32("EAX after AL write",   a_rd1, 32'hDEAD_1242);

    // ------------------------------------------------------------------
    // 8-bit AH write affects only bits [15:8].
    // ------------------------------------------------------------------
    write_gpr(3'd4, SZ_8, 32'h0000_00A7);    // AH = 0xA7 (encoding 4 + sz=8)
    rd1_sel = 3'd4; rd1_size = SZ_8; #1;
    check_eq32("AH after 8b write",    a_rd1, 32'h0000_00A7);
    rd1_sel = 3'd0; rd1_size = SZ_32; #1;
    check_eq32("EAX after AH write",   a_rd1, 32'hDEAD_A742);

    // ------------------------------------------------------------------
    // Encoding 4..7 in 16/32 mode goes to ESP/EBP/ESI/EDI.
    // ------------------------------------------------------------------
    write_gpr(3'd4, SZ_32, 32'h1111_2222);   // ESP
    rd1_sel = 3'd4; rd1_size = SZ_32; #1;
    check_eq32("ESP 32b round-trip",   a_rd1, 32'h1111_2222);
    // And EAX is untouched.
    rd1_sel = 3'd0; #1;
    check_eq32("EAX undisturbed by ESP", a_rd1, 32'hDEAD_A742);

    // ------------------------------------------------------------------
    // Segment register write/read.
    // ------------------------------------------------------------------
    @(negedge clk);
    seg_wr_en = 1'b1;
    seg_wr_sel = 3'(SEG_DS);
    seg_wr_data.selector = 16'h1234;
    seg_wr_data.base     = 32'h0001_2340;
    seg_wr_data.limit    = 32'h0000_FFFF;
    seg_wr_data.access   = 12'h093;
    @(posedge clk);
    @(negedge clk);
    seg_wr_en = 1'b0;
    seg_rd_sel = 3'(SEG_DS); #1;
    check_eq32("DS base after write",    a_seg.base,            32'h0001_2340);
    check    ("DS selector after write", a_seg.selector == 16'h1234);

    // ------------------------------------------------------------------
    // EIP arbitrary set + increment.
    // ------------------------------------------------------------------
    @(negedge clk);
    eip_set_en = 1'b1; eip_set_val = 32'h0001_0000;
    @(posedge clk);
    @(negedge clk);
    eip_set_en = 1'b0;
    check_eq32("EIP after set",  a_eip, 32'h0001_0000);

    @(negedge clk);
    eip_inc_en = 1'b1; eip_inc_val = 32'd4;
    @(posedge clk);
    @(negedge clk);
    eip_inc_en = 1'b0;
    check_eq32("EIP after +4 inc", a_eip, 32'h0001_0004);

    // ------------------------------------------------------------------
    // EFLAGS write mask: only CF should flip; reserved-1 stays.
    // ------------------------------------------------------------------
    @(negedge clk);
    ef_wr_en  = 1'b1;
    ef_wr_val = 32'hFFFF_FFFF;
    ef_wr_mask = 32'h1 << EFLAGS_CF;
    @(posedge clk);
    @(negedge clk);
    ef_wr_en  = 1'b0;
    check_eq32("EFLAGS CF set, others 0",
               a_ef, 32'h0000_0003);

    // ------------------------------------------------------------------
    // 386 personality must mask AC bit even when caller requests it.
    // ------------------------------------------------------------------
    @(negedge clk);
    ef_wr_en  = 1'b1;
    ef_wr_val = 32'h1 << EFLAGS_AC;
    ef_wr_mask= 32'h1 << EFLAGS_AC;
    @(posedge clk);
    @(negedge clk);
    ef_wr_en  = 1'b0;
    check("386 EFLAGS.AC stays clear", a_ef[EFLAGS_AC] == 1'b0);
    check("486 EFLAGS.AC can be set",  b_ef[EFLAGS_AC] == 1'b1);

    // ------------------------------------------------------------------
    // CR4: writable on 486, ignored on 386.
    // ------------------------------------------------------------------
    @(negedge clk);
    cr_wr_en = 1'b1; cr_wr_sel = 3'd4; cr_wr_val = 32'h0000_00FF;
    @(posedge clk);
    @(negedge clk);
    cr_wr_en = 1'b0;
    cr_rd_sel = 3'd4; #1;
    check_eq32("386 CR4 read == 0", a_cr, 32'h0);
    check_eq32("486 CR4 honored",   b_cr, 32'h0000_00FF);

    // ------------------------------------------------------------------
    // CR0 reset value differs between families.
    // ------------------------------------------------------------------
    check_eq32("386 reset CR0", a_cr0, 32'h0000_0000);
    check_eq32("486 reset CR0", b_cr0, 32'h0000_0010);

    if (fails == 0) begin
      $display("PASS tb_cpu386486_regs");
      $finish(0);
    end else begin
      $display("FAIL tb_cpu386486_regs (%0d failures)", fails);
      $fatal(1);
    end
  end

  initial begin
    #50_000;
    $display("FAIL tb_cpu386486_regs (timeout)");
    $fatal(1);
  end

endmodule : tb_cpu386486_regs
