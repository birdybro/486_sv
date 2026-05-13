// SPDX-License-Identifier: MIT
// tb_core_486_fetch : exercises the real-mode fetch path on a NOP slide.
//
// The 486 reset vector linearises to 0xFFFFFFF0. The simulation memory is
// 1 MiB and wraps modulo BYTES, so the reset linear address aliases to
// 0xFFFF0 inside the model. Loading 0x90 (NOP) at that offset gives the
// CPU a slide it can step through one byte per fetch.
//
// References: Intel 80386 PRM §10.2 (reset), §17 (instruction set, NOP),
// Intel i486 PRM §10.2.

`timescale 1ns/1ps

module tb_core_486_fetch;

  import core_486_pkg::*;

  logic clk, reset;

  // Bus.
  logic [31:0] bus_addr;
  logic        bus_read, bus_write;
  logic [3:0]  bus_byte_en;
  logic [31:0] bus_wdata, bus_rdata;
  logic        bus_ready, bus_fault;

  // Debug.
  logic [31:0] dbg_eip, dbg_eflags;
  logic [31:0] dbg_gpr [8];
  seg_reg_t    dbg_seg [NUM_SEGS];
  logic [31:0] dbg_cr0, dbg_cr2, dbg_cr3, dbg_cr4;
  logic [31:0] dbg_retired_count;
  logic        dbg_halted;

  // Memory: 64 KiB, wraps so 0xFFFFFFF0 aliases to 0xFFF0.
  // (Larger sizes slow Icarus elaboration considerably on Windows.)
  localparam int unsigned MEM_BYTES = 1 << 16;
  localparam int unsigned RESET_ALIAS_OFFSET = 32'hFFFFFFF0 & (MEM_BYTES - 1);

  mem_model #(.BYTES(MEM_BYTES)) u_mem (
      .clk        (clk),
      .reset      (reset),
      .bus_addr   (bus_addr),
      .bus_read   (bus_read),
      .bus_write  (bus_write),
      .bus_byte_en(bus_byte_en),
      .bus_wdata  (bus_wdata),
      .bus_ready  (bus_ready),
      .bus_rdata  (bus_rdata),
      .bus_fault  (bus_fault)
  );

  core_486_top #(.PERSONALITY(P_386DX_25), .ENABLE_FPU(1'b0)) dut (
      .clk              (clk),
      .reset            (reset),
      .bus_addr         (bus_addr),
      .bus_read         (bus_read),
      .bus_write        (bus_write),
      .bus_byte_en      (bus_byte_en),
      .bus_wdata        (bus_wdata),
      .bus_ready        (bus_ready),
      .bus_rdata        (bus_rdata),
      .bus_fault        (bus_fault),
      .intr_req         (1'b0),
      .intr_ack         (),
      .intr_vec         (8'h00),
      .nmi_req          (1'b0),
      .dbg_eip          (dbg_eip),
      .dbg_eflags       (dbg_eflags),
      .dbg_gpr          (dbg_gpr),
      .dbg_seg          (dbg_seg),
      .dbg_cr0          (dbg_cr0),
      .dbg_cr2          (dbg_cr2),
      .dbg_cr3          (dbg_cr3),
      .dbg_cr4          (dbg_cr4),
      .dbg_retired_count(dbg_retired_count),
      .dbg_halted       (dbg_halted)
  );

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

  initial begin
    fails = 0;

    // Preload a 16-byte NOP slide at the wrapped reset address.
    for (int i = 0; i < 16; i++)
      u_mem.store[RESET_ALIAS_OFFSET + i] = 8'h90;
    // Plant a non-NOP one byte past the slide so the halt latches.
    u_mem.store[RESET_ALIAS_OFFSET + 16] = 8'hF4;  // HLT

    reset = 1'b1;
    repeat (4) @(posedge clk);
    @(negedge clk) reset = 1'b0;

    // Let the CPU run long enough to chew through the slide and trip on HLT.
    repeat (400) @(posedge clk);

    check    ("CPU eventually halted",  dbg_halted);
    check_eq32("Retired count == 16",   dbg_retired_count, 32'd16);
    check_eq32("EIP advanced by 16",    dbg_eip,           RESET_ALIAS_OFFSET + 32'd16);

    if (fails == 0) begin
      $display("PASS tb_core_486_fetch");
      $finish(0);
    end else begin
      $display("FAIL tb_core_486_fetch (%0d failures)", fails);
      $fatal(1);
    end
  end

  initial begin
    #20_000;
    $display("FAIL tb_core_486_fetch (timeout) dbg_eip=0x%08x retired=%0d halted=%b",
             dbg_eip, dbg_retired_count, dbg_halted);
    $fatal(1);
  end

endmodule : tb_core_486_fetch
