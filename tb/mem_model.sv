// SPDX-License-Identifier: MIT
// mem_model : tiny byte-addressable simulation memory.
//
// Testbench only — uses non-synthesizable constructs. Supplies the bus
// handshake the CPU expects: a single-cycle response with no fault.

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

  // Read path: assemble a little-endian dword from the byte store. Out-of-
  // range accesses return X to flag bugs loudly in waveforms.
  always_comb begin
    bus_rdata = 32'hxxxx_xxxx;
    bus_fault = 1'b0;
    if (bus_read && grant) begin
      if (bus_addr + 3 < BYTES) begin
        bus_rdata = {store[bus_addr+3],
                     store[bus_addr+2],
                     store[bus_addr+1],
                     store[bus_addr+0]};
      end else begin
        bus_fault = 1'b1;
      end
    end
  end

  assign bus_ready = grant;

  // Write path.
  always_ff @(posedge clk) begin
    if (!reset && bus_write && grant) begin
      if (bus_addr + 3 < BYTES) begin
        if (bus_byte_en[0]) store[bus_addr+0] <= bus_wdata[ 7: 0];
        if (bus_byte_en[1]) store[bus_addr+1] <= bus_wdata[15: 8];
        if (bus_byte_en[2]) store[bus_addr+2] <= bus_wdata[23:16];
        if (bus_byte_en[3]) store[bus_addr+3] <= bus_wdata[31:24];
      end
    end
  end

  // Hex preload helper (testbench-only).
  task automatic load_hex(input string path);
    $readmemh(path, store);
  endtask

endmodule : mem_model
