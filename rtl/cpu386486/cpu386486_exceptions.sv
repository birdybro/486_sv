// SPDX-License-Identifier: MIT
// cpu386486_exceptions : exception-vector arbitration (stub). Task 10 wires
// real fault/trap sources in.

module cpu386486_exceptions (
    input  logic       reset,
    input  logic       raise_ud,
    input  logic       raise_nm,
    input  logic       raise_de,
    input  logic       raise_pf,
    output logic       exc_pending,
    output logic [7:0] exc_vector
);

  logic _unused;
  assign _unused = &{1'b0, reset};

  // Lowest vector number wins (rough first cut; real priority is fault class).
  always_comb begin
    exc_pending = raise_de | raise_ud | raise_nm | raise_pf;
    if      (raise_de) exc_vector = 8'd0;
    else if (raise_ud) exc_vector = 8'd6;
    else if (raise_nm) exc_vector = 8'd7;
    else if (raise_pf) exc_vector = 8'd14;
    else               exc_vector = 8'd0;
  end

endmodule : cpu386486_exceptions
