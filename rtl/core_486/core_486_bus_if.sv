// SPDX-License-Identifier: MIT
// core_486_bus_if : external bus master interface. Skeleton — provides the
// pin set the top module exposes and a no-op behavior until Task 5 wires
// real fetch through it.

module core_486_bus_if (
    input  logic        clk,
    input  logic        reset,

    // CPU-side request port (sequenced by control/fetch).
    input  logic        req_valid,
    input  logic [31:0] req_addr,
    input  logic        req_write,
    input  logic [3:0]  req_byte_en,
    input  logic [31:0] req_wdata,
    output logic        req_ready,
    output logic [31:0] req_rdata,
    output logic        req_fault,

    // External pins (driven combinationally from the request port for now).
    output logic [31:0] bus_addr,
    output logic        bus_read,
    output logic        bus_write,
    output logic [3:0]  bus_byte_en,
    output logic [31:0] bus_wdata,
    input  logic        bus_ready,
    input  logic [31:0] bus_rdata,
    input  logic        bus_fault
);

  logic _unused;
  assign _unused = &{1'b0, clk, reset};

  assign bus_addr    = req_addr;
  assign bus_byte_en = req_byte_en;
  assign bus_wdata   = req_wdata;
  assign bus_read    = req_valid & ~req_write;
  assign bus_write   = req_valid &  req_write;

  assign req_ready = bus_ready;
  assign req_rdata = bus_rdata;
  assign req_fault = bus_fault;

endmodule : core_486_bus_if
