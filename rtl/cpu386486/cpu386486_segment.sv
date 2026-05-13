// SPDX-License-Identifier: MIT
// cpu386486_segment : effective-address / linear-address generation + segment
// protection checks. Stub: returns base+offset with no checks. Task 9 / 12
// flesh this out.

module cpu386486_segment (
    input  logic [31:0] seg_base,
    input  logic [31:0] offset,
    output logic [31:0] linear_addr
);

  assign linear_addr = seg_base + offset;

endmodule : cpu386486_segment
