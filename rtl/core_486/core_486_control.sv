// SPDX-License-Identifier: MIT
// core_486_control : top-level control / fetch-consumer.
//
// Task 5 scope: stream bytes out of the prefetcher and "execute" NOP
// (opcode 0x90) by simply consuming the byte. Any non-NOP byte is held
// (not consumed) until the decoder lands in Task 6 — this gives the
// Task 5 test something definitive to check: a small NOP slide should
// retire one byte per round-trip while a non-NOP should stall.

module core_486_control (
    input  logic       clk,
    input  logic       reset,

    input  logic       byte_valid,
    input  logic [7:0] byte_data,
    output logic       consume,

    // Halt indicator: non-NOP byte seen at the head of the stream.
    output logic       halted,

    // Count of bytes retired since reset — for testbench observability.
    output logic [31:0] retired_count,

    output logic       running
);

  localparam logic [7:0] NOP_OPCODE = 8'h90;

  logic running_q;
  logic halted_q;
  logic [31:0] retired_q;

  always_ff @(posedge clk) begin
    if (reset) begin
      running_q <= 1'b0;
      halted_q  <= 1'b0;
      retired_q <= 32'h0;
    end else begin
      running_q <= 1'b1;
      if (byte_valid && !halted_q) begin
        if (byte_data == NOP_OPCODE) retired_q <= retired_q + 1'b1;
        else                          halted_q  <= 1'b1;
      end
    end
  end

  assign consume       = byte_valid & (byte_data == NOP_OPCODE) & ~halted_q;
  assign halted        = halted_q;
  assign retired_count = retired_q;
  assign running       = running_q;

endmodule : core_486_control
