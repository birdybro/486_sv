// SPDX-License-Identifier: MIT
// core_486_decode : instruction decoder (stub). Real implementation arrives
// in Task 6 — prefix handling, ModRM/SIB, opcode → microcode entry.

module core_486_decode (
    input  logic        clk,
    input  logic        reset,
    input  logic        byte_valid,
    input  logic [7:0]  byte_in,
    output logic        decode_busy,
    output logic        fpu_op_seen
);

  // Until Task 6, decode is dormant. Outputs are tied to safe defaults.
  // `_unused` keeps lint quiet about unread inputs.
  logic _unused;
  assign _unused = &{1'b0, clk, reset, byte_valid, byte_in};

  assign decode_busy = 1'b0;
  assign fpu_op_seen = 1'b0;

endmodule : core_486_decode
