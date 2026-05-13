// SPDX-License-Identifier: MIT
// cpu386486_prefetch : instruction prefetch queue (stub). A simple
// single-byte handshake will land in Task 5; the 16-byte queue arrives later.

module cpu386486_prefetch (
    input  logic        clk,
    input  logic        reset,
    input  logic        consume,
    output logic        byte_valid,
    output logic [7:0]  byte_data
);

  logic _unused;
  assign _unused = &{1'b0, clk, reset, consume};

  assign byte_valid = 1'b0;
  assign byte_data  = 8'h00;

endmodule : cpu386486_prefetch
