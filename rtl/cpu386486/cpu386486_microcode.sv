// SPDX-License-Identifier: MIT
// cpu386486_microcode : sequencer for multi-step instructions (stub).
// Filled in as instructions land in Tasks 7+.

module cpu386486_microcode (
    input  logic       clk,
    input  logic       reset,
    output logic       seq_idle
);

  logic _unused;
  assign _unused = &{1'b0, clk, reset};

  assign seq_idle = 1'b1;

endmodule : cpu386486_microcode
