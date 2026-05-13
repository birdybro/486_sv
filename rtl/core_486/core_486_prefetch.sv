// SPDX-License-Identifier: MIT
// core_486_prefetch : single-byte instruction prefetch (Task 5).
//
// Minimal but correct first implementation. The bus master sees a
// dword-aligned read at linear(CS:EIP); we pick the byte indicated by
// the low two address bits out of the returned dword, hold it, and wait
// for the decoder to consume it. EIP advances one byte per consume.
//
// Address path is purely combinational (request always reflects the
// current linear_addr from the segment+paging units). This works because
// the upstream EIP register is not advanced until consume pulses, so
// linear_addr is stable across the S_REQ → S_DELIVER transition.

module core_486_prefetch (
    input  logic        clk,
    input  logic        reset,

    input  logic [31:0] linear_addr,

    output logic        req_valid,
    output logic [31:0] req_addr,
    output logic [3:0]  req_byte_en,
    input  logic        req_ready,
    input  logic [31:0] req_rdata,
    input  logic        req_fault,

    output logic        byte_valid,
    output logic [7:0]  byte_data,
    input  logic        consume,

    output logic        eip_inc_en,
    output logic [31:0] eip_inc_val,

    output logic        fetch_fault
);

  typedef enum logic [1:0] {
    S_REQ     = 2'd0,
    S_DELIVER = 2'd1,
    S_FAULT   = 2'd2
  } fetch_state_e;

  fetch_state_e state_q;
  logic [7:0]   byte_q;

  always_comb begin
    req_addr    = {linear_addr[31:2], 2'b00};
    req_byte_en = 4'h1 << linear_addr[1:0];
    req_valid   = (state_q == S_REQ);
  end

  logic [7:0] picked_byte;
  always_comb begin
    case (linear_addr[1:0])
      2'd0:    picked_byte = req_rdata[ 7: 0];
      2'd1:    picked_byte = req_rdata[15: 8];
      2'd2:    picked_byte = req_rdata[23:16];
      default: picked_byte = req_rdata[31:24];
    endcase
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      state_q <= S_REQ;
      byte_q  <= 8'h00;
    end else begin
      case (state_q)
        S_REQ: begin
          if (req_ready) begin
            if (req_fault) begin
              state_q <= S_FAULT;
            end else begin
              byte_q  <= picked_byte;
              state_q <= S_DELIVER;
            end
          end
        end
        S_DELIVER: begin
          if (consume) state_q <= S_REQ;
        end
        S_FAULT: ; // sticky until reset
        default: state_q <= S_REQ;
      endcase
    end
  end

  assign byte_valid  = (state_q == S_DELIVER);
  assign byte_data   = byte_q;
  assign eip_inc_en  = (state_q == S_DELIVER) & consume;
  assign eip_inc_val = 32'h1;
  assign fetch_fault = (state_q == S_FAULT);

endmodule : core_486_prefetch
