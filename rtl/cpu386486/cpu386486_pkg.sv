// SPDX-License-Identifier: MIT
// cpu386486_pkg : shared types, enums, and parameter helpers for the 386/486 core.
//
// Reference: Intel 80386 Programmer's Reference Manual (1986) §2, and Intel
// i486 Programmer's Reference Manual (1990) §2 for programming model and
// register layouts.

`ifndef CPU386486_PKG_SV
`define CPU386486_PKG_SV

package cpu386486_pkg;

  // -----------------------------------------------------------------------
  // Personality identification.
  //
  // The enum values are kept stable across revisions; new personalities are
  // appended. Each personality resolves to a cpu_features_t record via
  // cpu386486_config::personality_features().
  // -----------------------------------------------------------------------

  typedef enum logic [3:0] {
    P_386DX_25    = 4'd0,
    P_386DX_40    = 4'd1,
    P_486SX_25    = 4'd2,
    P_486SX_33    = 4'd3,
    P_486DX_33    = 4'd4,
    P_486DX2_66   = 4'd5,
    P_486DX4_100  = 4'd6
  } cpu_personality_e;

  typedef enum logic [1:0] {
    FAM_386 = 2'd0,
    FAM_486 = 2'd1
  } cpu_family_e;

  // -----------------------------------------------------------------------
  // Feature record produced by the configuration helper. RTL queries this
  // record rather than introspecting the personality enum directly, so that
  // adding a new personality only touches cpu386486_config.sv.
  // -----------------------------------------------------------------------

  typedef struct packed {
    cpu_family_e family;
    logic        has_on_die_fpu;     // personality permits on-die FPU
    logic        has_on_die_cache;   // L1 is part of personality
    logic [15:0] cache_kib_x100;     // cache size * 100 (so 8.0 KiB = 800)
    logic [7:0]  clock_mult_x2;      // 2x integer clock multiplier (so DX2 = 4)
    logic [7:0]  base_mhz;           // bus / external clock MHz hint
    logic        supports_cr4;       // CR4 visible & writable
    logic        supports_alignchk;  // EFLAGS.AC + CR0.AM
  } cpu_features_t;

  // -----------------------------------------------------------------------
  // Operand size and register encodings (Intel reg field semantics).
  //
  // GPR encoding is identical for 16- and 32-bit operands. For 8-bit
  // operands the encoding selects AL/CL/DL/BL/AH/CH/DH/BH, where the high
  // four refer to bits[15:8] of EAX/ECX/EDX/EBX.
  //
  // Segment encoding matches MOV Sreg semantics from the Intel manuals.
  // -----------------------------------------------------------------------

  typedef enum logic [1:0] {
    SZ_8  = 2'd0,
    SZ_16 = 2'd1,
    SZ_32 = 2'd2
  } op_size_e;

  typedef enum logic [2:0] {
    GP_EAX = 3'd0, GP_ECX = 3'd1, GP_EDX = 3'd2, GP_EBX = 3'd3,
    GP_ESP = 3'd4, GP_EBP = 3'd5, GP_ESI = 3'd6, GP_EDI = 3'd7
  } gpr_e;

  typedef enum logic [2:0] {
    SEG_ES = 3'd0, SEG_CS = 3'd1, SEG_SS = 3'd2,
    SEG_DS = 3'd3, SEG_FS = 3'd4, SEG_GS = 3'd5
  } seg_e;

  // Number of segment registers we model (ES, CS, SS, DS, FS, GS).
  localparam int unsigned NUM_SEGS = 6;

  // Hidden descriptor cache fields, kept compact. Limit is stored as the
  // already-byte-granular limit (so real-mode limit fits in 16 bits but the
  // field is widened to 32 to admit 4 GiB protected-mode limits later).
  typedef struct packed {
    logic [15:0] selector;
    logic [31:0] base;
    logic [31:0] limit;
    logic [11:0] access;   // descriptor-access bits (G, D/B, AVL, DPL, S, type, P, etc.)
  } seg_reg_t;

  // -----------------------------------------------------------------------
  // EFLAGS bit positions (subset implemented in this core).
  // -----------------------------------------------------------------------

  localparam int unsigned EFLAGS_CF      = 0;
  localparam int unsigned EFLAGS_PF      = 2;
  localparam int unsigned EFLAGS_AF      = 4;
  localparam int unsigned EFLAGS_ZF      = 6;
  localparam int unsigned EFLAGS_SF      = 7;
  localparam int unsigned EFLAGS_TF      = 8;
  localparam int unsigned EFLAGS_IF      = 9;
  localparam int unsigned EFLAGS_DF      = 10;
  localparam int unsigned EFLAGS_OF      = 11;
  localparam int unsigned EFLAGS_IOPL_LO = 12;
  localparam int unsigned EFLAGS_IOPL_HI = 13;
  localparam int unsigned EFLAGS_NT      = 14;
  localparam int unsigned EFLAGS_RF      = 16;
  localparam int unsigned EFLAGS_VM      = 17;
  localparam int unsigned EFLAGS_AC      = 18;  // 486+ only

  // Bit-2 of EFLAGS is reserved and always reads 1 per Intel spec.
  localparam logic [31:0] EFLAGS_RESERVED_ONE_MASK = 32'h0000_0002;

  // Bits we accept on EFLAGS writes (everything else is forced to its
  // reset/reserved value). AC is included for the 486+ personalities; the
  // register file's external write mask further filters this for 386
  // builds.
  localparam logic [31:0] EFLAGS_SUPPORTED_MASK =
      (32'h1 << EFLAGS_CF) | (32'h1 << EFLAGS_PF) | (32'h1 << EFLAGS_AF) |
      (32'h1 << EFLAGS_ZF) | (32'h1 << EFLAGS_SF) | (32'h1 << EFLAGS_TF) |
      (32'h1 << EFLAGS_IF) | (32'h1 << EFLAGS_DF) | (32'h1 << EFLAGS_OF) |
      (32'h1 << EFLAGS_IOPL_LO) | (32'h1 << EFLAGS_IOPL_HI) |
      (32'h1 << EFLAGS_NT) | (32'h1 << EFLAGS_RF) | (32'h1 << EFLAGS_VM) |
      (32'h1 << EFLAGS_AC);

  // -----------------------------------------------------------------------
  // CR0 bits we model (others reserved-zero).
  // -----------------------------------------------------------------------

  localparam int unsigned CR0_PE = 0;   // protection enable
  localparam int unsigned CR0_MP = 1;   // monitor coprocessor
  localparam int unsigned CR0_EM = 2;   // emulate coprocessor
  localparam int unsigned CR0_TS = 3;   // task switched
  localparam int unsigned CR0_ET = 4;   // extension type (387 vs 287)
  localparam int unsigned CR0_NE = 5;   // 486+: numeric error
  localparam int unsigned CR0_WP = 16;  // 486+: write protect
  localparam int unsigned CR0_AM = 18;  // 486+: alignment mask
  localparam int unsigned CR0_NW = 29;  // 486+: not write through
  localparam int unsigned CR0_CD = 30;  // 486+: cache disable
  localparam int unsigned CR0_PG = 31;  // paging

  // -----------------------------------------------------------------------
  // Architectural reset values (real-silicon-faithful where it matters).
  // 386: EIP=FFF0, CS selector=F000, CS base=FFFF0000 (note the high base
  // until the first far jump). 486 matches.
  // -----------------------------------------------------------------------

  localparam logic [31:0] RESET_EIP        = 32'h0000_FFF0;
  localparam logic [15:0] RESET_CS_SEL     = 16'hF000;
  localparam logic [31:0] RESET_CS_BASE    = 32'hFFFF_0000;
  localparam logic [31:0] RESET_CS_LIMIT   = 32'h0000_FFFF;
  localparam logic [31:0] RESET_OTHER_BASE = 32'h0000_0000;
  localparam logic [31:0] RESET_OTHER_LIM  = 32'h0000_FFFF;
  localparam logic [31:0] RESET_EFLAGS     = 32'h0000_0002;
  localparam logic [31:0] RESET_CR0_386    = 32'h0000_0000;
  // 486 sets ET = 1 at reset to advertise 387-style FPU (when present).
  localparam logic [31:0] RESET_CR0_486    = 32'h0000_0010;

  // -----------------------------------------------------------------------
  // Exception vector numbers we will care about.
  // -----------------------------------------------------------------------

  localparam logic [7:0] VEC_DE  = 8'd0;   // divide error
  localparam logic [7:0] VEC_DB  = 8'd1;   // debug
  localparam logic [7:0] VEC_NMI = 8'd2;
  localparam logic [7:0] VEC_BP  = 8'd3;   // breakpoint
  localparam logic [7:0] VEC_OF  = 8'd4;   // overflow (INTO)
  localparam logic [7:0] VEC_BR  = 8'd5;   // BOUND range
  localparam logic [7:0] VEC_UD  = 8'd6;   // invalid opcode
  localparam logic [7:0] VEC_NM  = 8'd7;   // device not available (no FPU)
  localparam logic [7:0] VEC_DF  = 8'd8;   // double fault
  localparam logic [7:0] VEC_TS  = 8'd10;
  localparam logic [7:0] VEC_NP  = 8'd11;
  localparam logic [7:0] VEC_SS  = 8'd12;
  localparam logic [7:0] VEC_GP  = 8'd13;
  localparam logic [7:0] VEC_PF  = 8'd14;
  localparam logic [7:0] VEC_MF  = 8'd16;  // x87 floating-point error
  localparam logic [7:0] VEC_AC  = 8'd17;  // 486+: alignment check

endpackage : cpu386486_pkg

`endif // CPU386486_PKG_SV
