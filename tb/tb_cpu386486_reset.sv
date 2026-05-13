// SPDX-License-Identifier: MIT
// tb_cpu386486_reset : verifies CPU reset state for each personality.
//
// Reference: Intel 386 Manual §10.2 "Reset" and 486 Manual §10.2. After
// reset, EIP = 0xFFF0, CS selector = 0xF000 with hidden base = 0xFFFF0000
// and limit 0xFFFF. EFLAGS reset value is 0x00000002 (only the reserved-1
// bit set; IF cleared, all arithmetic flags cleared).

`timescale 1ns/1ps

module tb_cpu386486_reset;

  import cpu386486_pkg::*;

  logic clk;
  logic reset;

  // Bus tie-offs — reset state shouldn't issue bus traffic.
  logic [31:0] bus_addr;
  logic        bus_read;
  logic        bus_write;
  logic [3:0]  bus_byte_en;
  logic [31:0] bus_wdata;
  logic        bus_ready;
  logic [31:0] bus_rdata;
  logic        bus_fault;

  logic [31:0] dbg_eip;
  logic [31:0] dbg_eflags;

  // Memory model parked as a quiet responder.
  mem_model #(.BYTES(1024)) u_mem (
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

  cpu386486_top #(.PERSONALITY(P_386DX_25), .ENABLE_FPU(1'b0)) dut (
      .clk        (clk),
      .reset      (reset),
      .bus_addr   (bus_addr),
      .bus_read   (bus_read),
      .bus_write  (bus_write),
      .bus_byte_en(bus_byte_en),
      .bus_wdata  (bus_wdata),
      .bus_ready  (bus_ready),
      .bus_rdata  (bus_rdata),
      .bus_fault  (bus_fault),
      .intr_req   (1'b0),
      .intr_ack   (),
      .intr_vec   (8'h00),
      .nmi_req    (1'b0),
      .dbg_eip    (dbg_eip),
      .dbg_eflags (dbg_eflags)
  );

  // Clock.
  initial clk = 1'b0;
  always #5 clk = ~clk;

  int unsigned fail_count;

  task automatic check(input string label, input logic cond);
    if (!cond) begin
      $display("FAIL: %s", label);
      fail_count = fail_count + 1;
    end else begin
      $display(" ok : %s", label);
    end
  endtask

  initial begin
    fail_count = 0;
    reset = 1'b1;
    // Hold reset for a few cycles.
    repeat (4) @(posedge clk);
    @(negedge clk) reset = 1'b0;

    // Sample one cycle after de-assertion.
    @(posedge clk);
    @(posedge clk);

    check("reset EIP == 0xFFF0",      dbg_eip    == 32'h0000_FFF0);
    check("reset EFLAGS == 0x2",      dbg_eflags == 32'h0000_0002);
    check("no bus read during reset",  ~bus_read);
    check("no bus write during reset", ~bus_write);

    if (fail_count == 0) begin
      $display("PASS tb_cpu386486_reset");
      $finish(0);
    end else begin
      $display("FAIL tb_cpu386486_reset (%0d failures)", fail_count);
      $fatal(1);
    end
  end

  // Safety net: wall-clock timeout.
  initial begin
    #10_000;
    $display("FAIL tb_cpu386486_reset (timeout)");
    $fatal(1);
  end

endmodule : tb_cpu386486_reset
