// SPDX-License-Identifier: MIT
// cpu386486_control : top-level control/sequencing stub. The real sequencer
// is split between this module and cpu386486_microcode in later tasks.

module cpu386486_control (
    input  logic clk,
    input  logic reset,
    output logic running
);

  logic running_q;

  always_ff @(posedge clk) begin
    if (reset) running_q <= 1'b0;
    else       running_q <= 1'b1;
  end

  assign running = running_q;

endmodule : cpu386486_control
