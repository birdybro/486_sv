# 386/486 CPU Core — Architectural Specification

This document is the architectural source-of-truth for the `cpu386486` core.
All RTL decisions defer to:

1. **Intel 80386 Programmer's Reference Manual, 1986** —
   https://css.csail.mit.edu/6.858/2014/readings/i386.pdf
2. **Intel i486 Processor Programmer's Reference Manual, 1990** —
   https://archive.org/details/bitsavers_intel80486mmersReferenceManual1990_29642780
3. **Intel i486 Hardware Reference Manual** —
   https://www.manualslib.com/manual/1013042/Intel-I486.html

86Box (https://github.com/86Box/86Box, https://86box.net/) is the preferred
behavioral reference for full-system comparisons. ao486
(https://github.com/MiSTer-devel/ao486_MiSTer) is consulted only as a
secondary FPGA-implementation reference. **No source from any of these
projects is copied into this repository.**

## 1. Scope and non-goals

### In scope

- Synthesizable SystemVerilog core configurable as 386DX or 486 (SX/DX/DX2/DX4).
- Real-mode integer subset first; then protected mode, paging, 486 additions,
  cache-control instructions, optional x87/FPU.
- Behavioral fidelity sufficient for **DOS-era gaming workloads**.
- Optional x87 with both compile-time and synthesis-time removal.

### Non-goals (this core)

- Pentium-class features (MMX, P5 dual-issue, APIC, MTRRs, RDTSC semantics
  beyond a trivial monotonic counter, SMM beyond minimal stub).
- Full cycle-exact 486 timing (not initial goal; revisited in Task 17).
- SMP, on-die L2, modern microarchitectural features.

## 2. Supported personalities

Personalities are selected through `cpu_personality_e` in `cpu386486_pkg.sv`
and resolve to a feature/timing record in `cpu386486_config.sv`.

| Personality      | Family | FPU on die | Cache         | Default mult | Notes                              |
| ---------------- | ------ | ---------- | ------------- | ------------ | ---------------------------------- |
| `P_386DX_25`     | 386DX  | external   | none on-die   | 1x @ 25 MHz  | First milestone target             |
| `P_386DX_40`     | 386DX  | external   | none on-die   | 1x @ 40 MHz  | Faster 386 variant                 |
| `P_486SX_25`     | 486SX  | absent     | 8 KiB unified | 1x @ 25 MHz  | FPU opcodes → #NM                  |
| `P_486SX_33`     | 486SX  | absent     | 8 KiB unified | 1x @ 33 MHz  | FPU opcodes → #NM                  |
| `P_486DX_33`     | 486DX  | optional   | 8 KiB unified | 1x @ 33 MHz  | x87 if `ENABLE_FPU`                |
| `P_486DX2_66`    | 486DX2 | optional   | 8 KiB unified | 2x @ 66 MHz  | **Long-term default for DOS games**|
| `P_486DX4_100`   | 486DX4 | optional   | 16 KiB unified| 3x @ 100 MHz | High-end 486 DOS-gaming target     |

Notes:

- Cache size is a personality hint surfaced via configuration. The L1 model
  itself is not implemented until cache-control work (post-Task 11).
- "Optional" FPU means the personality *permits* an on-die FPU; whether one
  exists depends on `ENABLE_FPU` (parameter) and `CPU386486_ENABLE_FPU`
  (define). See §5.

## 3. Milestones

| # | Milestone                                | Personality scope     | Tasks      |
| - | ---------------------------------------- | --------------------- | ---------- |
| 1 | 386 real-mode integer core               | 386DX                 | 1–11       |
| 2 | Protected mode + paging                  | 386DX, 486SX/DX       | 12–13      |
| 3 | DOS compatibility programs               | 386DX → 486DX2/66     | 14         |
| 4 | 486 personalities and timing             | 486SX/DX/DX2/DX4      | 15–17      |
| 5 | Optional x87/FPU                         | 486DX/DX2/DX4         | 18–19      |
| 6 | DOS gaming platform integration notes    | all                   | 20         |

## 4. Programmer-visible state

Authoritative reference: 386 Manual §2 (registers and flags) and 486 Manual
§2 (programming model). 486-only state (CR4 hooks, alignment-check, cache
control bits) is added behind personality gating.

### 4.1 General purpose registers

```
EAX = [ EAX[31:16] | AH | AL ]      EBX = [ EBX[31:16] | BH | BL ]
ECX = [ ECX[31:16] | CH | CL ]      EDX = [ EDX[31:16] | DH | DL ]
ESI, EDI, EBP, ESP : 32-bit with 16-bit aliases (SI, DI, BP, SP).
```

The register file presents synchronous 32-bit reads/writes plus
combinational 8/16-bit windows for the decoder/ALU. AH/BH/CH/DH addressing
is exposed via a small mux rather than separate storage. See Task 4.

### 4.2 Segment registers and hidden descriptors

`CS, DS, ES, SS, FS, GS` selectors plus a hidden descriptor cache per
segment (base, limit, access rights). In real mode `base = selector << 4`
and `limit = 0xFFFF`. The cache is *always present* in hardware; the
distinction between real and protected mode is solely how it is loaded.

### 4.3 EIP and EFLAGS

EIP is 32-bit. EFLAGS layout (386 + 486 differences):

| Bit | Name | Notes                                                   |
| --- | ---- | ------------------------------------------------------- |
| 0   | CF   |                                                         |
| 2   | PF   |                                                         |
| 4   | AF   |                                                         |
| 6   | ZF   |                                                         |
| 7   | SF   |                                                         |
| 8   | TF   |                                                         |
| 9   | IF   |                                                         |
| 10  | DF   |                                                         |
| 11  | OF   |                                                         |
| 12–13 | IOPL |                                                     |
| 14  | NT   |                                                         |
| 16  | RF   | 386+                                                    |
| 17  | VM   | 386+ (V86 mode)                                         |
| 18  | AC   | **486+ only** (alignment check, gated by personality)   |

ID/VIF/VIP are Pentium and intentionally absent.

### 4.4 Control registers

| Reg | Width | 386 bits used                | 486 additions                  |
| --- | ----- | ---------------------------- | ------------------------------ |
| CR0 | 32    | PE, MP, EM, TS, ET, PG       | NE, WP, AM, NW, CD             |
| CR2 | 32    | page-fault linear address    | same                           |
| CR3 | 32    | PDBR                         | + PCD, PWT                     |
| CR4 | 32    | (n/a on 386)                 | partial (VME/PVI/TSD/DE/PSE…)  |

For the 386 personality, 486-specific CR0/CR4 bits read as zero and writes
are masked. CR4 access (MOV CR4, …) on a 386 personality raises #UD.

## 5. FPU configurability

Goal: choose between three builds without forking the codebase.

| Build mode                | Parameter  | Define                       | Behavior                                                                                                  |
| ------------------------- | ---------- | ---------------------------- | --------------------------------------------------------------------------------------------------------- |
| **FPU not compiled**      | n/a        | `CPU386486_ENABLE_FPU` unset | `cpu386486_fpu_if` and any FPU datapath modules are entirely ``ifdef``-excluded. Synthesis sees no FPU.  |
| **FPU compiled, disabled**| `ENABLE_FPU = 1'b0` | `CPU386486_ENABLE_FPU` set | Interface and stub are present; behaves as FPU-absent. Personality decides whether #NM or #UD is raised. |
| **FPU compiled, enabled** | `ENABLE_FPU = 1'b1` | `CPU386486_ENABLE_FPU` set | Real (or stub-real) FPU is wired in. Allowed personalities: 486DX/DX2/DX4.                               |

Rules:

- `ENABLE_FPU = 1` while the active personality has `fpu_on_die = 0`
  (e.g., 486SX) is a configuration error caught by an `initial` assertion
  in simulation and an `assert property` in `cpu386486_config.sv`. The
  decoder still raises #NM for FPU opcodes in that case, but the build
  warns loudly.
- The personality `P_386DX_*` always reports "no on-die FPU". A real 386
  pairs with an external 387 over a coprocessor bus; the optional external
  FPU bus interface is parked behind a `HAS_EXTERNAL_387` parameter
  (default 0). It is not on the milestone-1 path.
- 486SX always raises **#NM (device-not-available, vector 7)** for FPU
  opcodes — matching real-silicon behavior with CR0.EM=1 / CR0.TS=1 set by
  the BIOS handler stub.

The decoder routes the F0–FF opcode prefix-D8..DF ranges through
`cpu386486_fpu_if` regardless of build mode; the interface itself decides
how to respond.

## 6. Module decomposition

```
cpu386486_top
├── cpu386486_pkg           (types, enums, parameters)
├── cpu386486_config        (personality -> feature table)
├── cpu386486_regs          (GPRs, segs, EIP, EFLAGS, CRn)
├── cpu386486_prefetch      (byte queue / linear address)
├── cpu386486_decode        (prefixes, ModRM/SIB, opcode → uop)
├── cpu386486_microcode     (sequencer for multi-step ops)
├── cpu386486_alu           (ALU + flag generation)
├── cpu386486_segment       (effective-address + descriptor checks)
├── cpu386486_paging        (CR3 + 4 KiB translation + TLB)
├── cpu386486_exceptions    (vector arbitration, fault/trap class)
├── cpu386486_bus_if        (external memory/IO bus master)
├── cpu386486_fpu_if        (handshake + status), optional
└── cpu386486_fpu_stub      (absent/#NM responder), optional
```

Module boundaries are stable; internal microarchitecture (single-cycle
vs pipelined) may evolve. Initial implementation is sequential/microcoded
for clarity.

## 7. External bus interface (provisional)

A simple synchronous master interface; tightened in Task 5 / 20.

```
output  [31:0] bus_addr
output         bus_read
output         bus_write
output  [3:0]  bus_byte_en
output  [31:0] bus_wdata
input          bus_ready
input   [31:0] bus_rdata
input          bus_fault     // bus error → #DF/#GP class fault
```

Memory and IO share the interface initially; an `bus_is_io` bit will be
added with the IN/OUT family.

## 8. Interrupt and exception interface

```
input          intr_req      // INTR pin
output         intr_ack      // single-cycle vector ack
input   [7:0]  intr_vec      // latched on ack
input          nmi_req       // edge-triggered
input          reset
```

Internally raised exceptions are arbitrated by `cpu386486_exceptions`.
Vectors and class (fault/trap/abort) match Intel 386 manual §9.8.

## 9. Toolchain & how to test

Install one of:

- **Icarus Verilog** (Windows: https://bleyer.org/icarus/, Linux: distro
  package `iverilog`). Primary simulator.
- **Verilator** (recommended for lint and faster sim). Optional.

Run:

```
python scripts/run_tests.py             # discovers and runs every test/*
python scripts/run_tests.py reset       # runs only matching tests
python scripts/run_tests.py --lint      # verilator --lint-only if available
```

The runner exits with a clear "simulator not found" diagnostic when neither
Icarus nor Verilator is on PATH. CI configuration is added with Task 3.

## 10. Coding rules

- All non-testbench `.sv` files must be synthesizable. No `initial`-side
  effects on RTL state, no `#delay`, no `$display` outside `tb/` or
  `// synthesis translate_off` blocks. Testbenches (`tb/`) and tests
  (`test/`) may use non-synthesizable constructs.
- No relying on undefined HDL behavior. All `case` statements either cover
  all values, have a `default`, or use `unique`/`priority` with explicit
  assertions.
- Reset is synchronous, active-high (`reset`), unless documented otherwise.
- Parameter names are `ALL_CAPS`; ports and signals `snake_case`; package
  types end in `_t`; enums end in `_e`.
- Each instruction-group implementation includes an Intel-manual citation
  in a header comment.

## 11. Legal / sourcing

- All code is to be implemented from the Intel architectural docs cited
  above, plus public knowledge of the x86 ISA.
- 86Box and ao486 are reference-only. No source is to be copied. Any
  *concept* or *test idea* borrowed from those projects must be cited in
  `docs/compatibility_notes.md` with a short justification.
- The repository LICENSE is MIT (Kevin Coleman 2026); contributions
  inherit that license unless explicitly noted.
