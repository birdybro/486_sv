// SPDX-License-Identifier: MIT
// cpu386486_paging : optional 4 KiB paging translation (stub). Until Task 13,
// paging is treated as disabled (CR0.PG = 0) and linear == physical.

module cpu386486_paging (
    input  logic        paging_en,
    input  logic [31:0] linear_addr,
    output logic [31:0] phys_addr,
    output logic        page_fault
);

  // No translation yet. When paging_en goes 1 before Task 13 is in, raise a
  // fault so a buggy bring-up cannot silently issue wrong addresses.
  assign phys_addr  = linear_addr;
  assign page_fault = paging_en;

endmodule : cpu386486_paging
