// SPDX-License-Identifier: MIT
// cpu386486_fpu_if : optional FPU interface boundary.
//
// Build modes (see docs/386_486_cpu_core_spec.md §5):
//   * FPU not compiled       : `CPU386486_ENABLE_FPU` undefined → this module
//                              is not instantiated in cpu386486_top.
//   * FPU compiled, disabled : ENABLE_FPU = 0 → fpu_stub responds "absent".
//   * FPU compiled, enabled  : ENABLE_FPU = 1 → real x87 module (future).
//
// The handshake is intentionally minimal: the decoder presents an FPU op and
// the interface tells the core whether to execute, trap (#NM), or wait.

module cpu386486_fpu_if #(
    parameter bit ENABLE_FPU = 1'b0
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        fpu_op_valid,
    input  logic [7:0]  fpu_op_byte,
    output logic        fpu_busy,
    output logic        fpu_raise_nm,
    output logic        fpu_complete
);

  logic _unused;
  assign _unused = &{1'b0, clk, reset, fpu_op_byte};

  // Both stub variants currently behave the same: not busy, raise #NM when
  // an FPU op is presented and no real FPU is wired up. A real x87 will
  // replace this module when ENABLE_FPU = 1; until then the synthesis-time
  // parameter just sets the "absent" reason.
  assign fpu_busy     = 1'b0;
  assign fpu_raise_nm = fpu_op_valid & ~ENABLE_FPU;
  assign fpu_complete = 1'b0;

endmodule : cpu386486_fpu_if
