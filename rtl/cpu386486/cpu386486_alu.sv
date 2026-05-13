// SPDX-License-Identifier: MIT
// cpu386486_alu : integer ALU (stub). Full implementation in Task 7.

module cpu386486_alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  op,
    output logic [31:0] result,
    output logic [31:0] flags_out
);

  // Stub: identity passthrough so the rest of the core can elaborate.
  logic _unused;
  assign _unused = &{1'b0, b, op};

  assign result    = a;
  assign flags_out = 32'h0000_0002;  // reserved-one bit only

endmodule : cpu386486_alu
