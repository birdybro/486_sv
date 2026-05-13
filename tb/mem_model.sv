// SPDX-License-Identifier: MIT
// mem_model : tiny byte-addressable simulation memory.
//
// Testbench only — uses non-synthesizable constructs. Supplies the bus
// handshake the CPU expects: a single-cycle response with no fault.
//
// Addresses wrap modulo BYTES so that the 486 reset vector at 0xFFFFFFF0
// aliases into the high end of a small RAM (e.g. 0xFFFF0 within a 1 MiB
// model). This matches the typical real-mode BIOS-ROM mirroring trick.

module mem_model #(
    parameter int unsigned BYTES   = 1 << 20,   // 1 MiB default
    parameter int unsigned LATENCY = 0          // additional ready-delay cycles
) (
    input  logic        clk,
    input  logic        reset,

    input  logic [31:0] bus_addr,
    input  logic        bus_read,
    input  logic        bus_write,
    input  logic [3:0]  bus_byte_en,
    input  logic [31:0] bus_wdata,
    output logic        bus_ready,
    output logic [31:0] bus_rdata,
    output logic        bus_fault
);

  // The store is logic [7:0] so we can preload it from $readmemh files.
  logic [7:0] store [0:BYTES-1];

  // Latency counter — 0 means combinational ready when a request is active.
  int unsigned wait_ctr;

  always_ff @(posedge clk) begin
    if (reset)
      wait_ctr <= 0;
    else if (bus_read || bus_write) begin
      if (wait_ctr == LATENCY) wait_ctr <= 0;
      else                     wait_ctr <= wait_ctr + 1;
    end else
      wait_ctr <= 0;
  end

  wire active = bus_read | bus_write;
  wire grant  = active & (wait_ctr == LATENCY);

  // Wrap addresses into [0, BYTES). The mask works correctly because
  // testbenches always pick BYTES as a power of two.
  wire [31:0] mask  = BYTES - 1;
  wire [31:0] addr0 = (bus_addr + 0) & mask;
  wire [31:0] addr1 = (bus_addr + 1) & mask;
  wire [31:0] addr2 = (bus_addr + 2) & mask;
  wire [31:0] addr3 = (bus_addr + 3) & mask;

  // Read path: assemble a little-endian dword from the byte store.
  always_comb begin
    bus_rdata = 32'h0;
    bus_fault = 1'b0;
    if (bus_read && grant) begin
      bus_rdata = {store[addr3], store[addr2], store[addr1], store[addr0]};
    end
  end

  assign bus_ready = grant;

  // Write path.
  always_ff @(posedge clk) begin
    if (!reset && bus_write && grant) begin
      if (bus_byte_en[0]) store[addr0] <= bus_wdata[ 7: 0];
      if (bus_byte_en[1]) store[addr1] <= bus_wdata[15: 8];
      if (bus_byte_en[2]) store[addr2] <= bus_wdata[23:16];
      if (bus_byte_en[3]) store[addr3] <= bus_wdata[31:24];
    end
  end

  // Hex preload helper (testbench-only).
  task automatic load_hex(input string path);
    $readmemh(path, store);
  endtask

endmodule : mem_model
