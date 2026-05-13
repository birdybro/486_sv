// SPDX-License-Identifier: MIT
// core_486_fpu_stub : placeholder "absent FPU" responder. Held as a separate
// module from core_486_fpu_if so that the real x87 can drop in later
// without renaming. Currently unused at the top level — the interface
// module itself handles the absent case — but kept reserved for the
// FPU-iface-in / FPU-real-absent build matrix described in the spec.

module core_486_fpu_stub (
    input  logic clk,
    input  logic reset,
    output logic absent
);

  logic _unused;
  assign _unused = &{1'b0, clk, reset};

  assign absent = 1'b1;

endmodule : core_486_fpu_stub
