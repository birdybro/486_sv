# 386/486 CPU Core — Task Plan

Living plan for the 386/486-class x86 CPU core targeting DOS-era FPGA gaming
systems. Long-term defaults: **486DX2/66** and **486DX4/100** behavioral
personalities. First functional milestone: **386DX real-mode integer core**.

Maintained alongside `docs/386_486_cpu_core_spec.md` (architectural spec),
`docs/compatibility_notes.md` (known deltas from real silicon), and
`docs/fpu_implementation_plan.md` (x87 roadmap).

## Status legend

- `[ ]` not started
- `[~]` in progress
- `[x]` complete
- `[!]` blocked (see notes)
- `[s]` skipped / superseded

## Repository conventions (locked in Task 0)

| Concern         | Choice                                                        |
| --------------- | ------------------------------------------------------------- |
| HDL language    | SystemVerilog (`.sv`, `.svh`)                                 |
| RTL location    | `rtl/cpu386486/`                                              |
| Testbench loc.  | `tb/` (non-synthesizable allowed)                             |
| Tests location  | `test/` (directed assembly + sv test programs)                |
| Docs            | `docs/`                                                       |
| Simulator       | **Icarus Verilog** primary; **Verilator** secondary (lint+sim)|
| Lint            | `verilator --lint-only` when available                        |
| Test runner     | `scripts/run_tests.py` (Python 3, no Make required)           |
| Naming          | `cpu386486_<unit>.sv`, snake_case signals, ALL_CAPS params    |
| FPU gating      | `parameter bit ENABLE_FPU` + ``CPU386486_ENABLE_FPU`` define  |
| Personalities   | `cpu_personality_e` enum in `cpu386486_pkg.sv`                |

## Tasks

### Task 0 — Repository inspection [x]

- Empty repo aside from `LICENSE` (MIT, Kevin Coleman 2026) and `README.md`.
- No prior HDL, build files, lint config, or tests.
- Host has Python 3; no `iverilog`/`verilator`/`make` on PATH.
- Decisions captured above. No code changes required for this task — the
  deliverable is this plan file plus the inventory above.

### Task 1 — CPU core specification document [x]

- `docs/386_486_cpu_core_spec.md` landed.
- Personalities, milestones, FPU build matrix, module decomposition, bus
  interface sketch, coding rules, and legal/sourcing posture all captured.

### Task 2 — Skeleton RTL [ ]

- `rtl/cpu386486/cpu386486_pkg.sv` (types, enums, parameters).
- `rtl/cpu386486/cpu386486_config.sv` (personality → feature table).
- `rtl/cpu386486/cpu386486_top.sv` (clock, reset, bus, intr, params).
- Stub modules: regs, decode, alu, control, bus_if, segment, paging,
  exceptions, prefetch, microcode, fpu_if, fpu_stub.
- Synthesizable (lint-clean) even though logic is empty.

### Task 3 — Simulation harness [ ]

- `tb/tb_cpu386486_reset.sv` resets the CPU and checks reset state.
- `tb/mem_model.sv` simple byte-addressable async memory.
- `scripts/run_tests.py` discovers tests under `test/` and runs Icarus Verilog.
- README/spec section documenting how to run tests.

### Task 4 — Architectural register file [ ]

- GPRs EAX..EDI with 8/16/32-bit views (AL/AH/AX/EAX...).
- Segment registers CS, DS, ES, SS, FS, GS plus hidden descriptor cache.
- EIP, EFLAGS.
- CR0/CR2/CR3/CR4 placeholders.
- Directed tests for each access path.

### Task 5 — Reset and real-mode fetch [ ]

- 486-style reset vector (CS:F000 selector / EIP=FFF0 / base=FFFF0000) with
  CS base initialization compatible with both 386 and 486 personalities.
- Simple sequential fetch over the bus interface.
- Real-mode CS:EIP linear address calculation.
- Tests that step a few NOPs from a ROM image.

### Task 6 — Instruction decoder framework [ ]

- Prefix bytes: operand-size, address-size, segment override, REP/REPE/REPNE,
  LOCK (latches only; semantics later).
- ModRM/SIB parser.
- x87/FPU opcode-range detection → routes to `cpu386486_fpu_if`.
- Decoder-only unit tests independent of execute.

### Task 7 — Basic ALU [ ]

- MOV (reg/imm/mem foundation), ADD, SUB, AND, OR, XOR, CMP.
- INC, DEC, NEG, NOT.
- Full EFLAGS (CF/PF/AF/ZF/SF/OF) per Intel spec.
- Directed tests.

### Task 8 — Stack and branches [ ]

- PUSH/POP, CALL/RET near, JMP short/near, Jcc.
- SP vs ESP under 16-bit and 32-bit operand-size.
- Tests.

### Task 9 — Real-mode addressing modes [ ]

- All 16-bit and 32-bit ModRM/SIB forms.
- Segment default selection + override.
- Tests.

### Task 10 — Interrupts/exceptions foundation [ ]

- INT n, IRET (real mode).
- #DE, #UD, #NM (no-FPU) plumbing.
- Real-mode IVT lookups.
- Tests.

### Task 11 — Expand 386 integer coverage [ ]

- MUL/IMUL/DIV/IDIV.
- SHL/SHR/SAR/ROL/ROR/RCL/RCR.
- String ops MOVS/STOS/LODS/CMPS/SCAS with REP.
- Tests.

### Task 12 — Protected-mode scaffolding [ ]

- GDT/IDT parsing, CR0.PE switch, segment descriptor cache.
- Privilege checks (initially minimal).
- Hand-crafted PM test programs.

### Task 13 — Paging scaffolding [ ]

- CR3, 4 KiB translation, #PF generation, simple TLB.
- Tests.

### Task 14 — DOS compatibility test programs [ ]

- Tiny assembly programs (real mode, INT, VGA-text-style writes to a stub
  framebuffer, stack, branches, arithmetic).
- Compare traces against **86Box** where feasible.

### Task 15 — 486SX personality [ ]

- `ENABLE_FPU=0` default. FPU opcodes route to no-FPU behavior (#NM).
- Cache-control instructions as functional stubs.

### Task 16 — 486DX/DX2/DX4 personalities [ ]

- 486DX-33, 486DX2-66, 486DX4-100 configs.
- Clock-multiplier metadata.
- FPU exposure only when compiled+enabled.

### Task 17 — Timing/personality model [ ]

- Configurable throttle (not cycle-exact initially).
- Presets per personality.
- Doc note on why DOS games need throttling.

### Task 18 — FPU interface, stub, synthesis exclusion [ ]

- Clean `cpu386486_fpu_if` boundary.
- Stub: absent / #NM / opt. ack-unimplemented for test only.
- Build matrix: FPU-out, FPU-iface-in/stub, FPU-iface-in/real (future).

### Task 19 — Real x87/FPU planning [ ]

- `docs/fpu_implementation_plan.md` with x87 stack, tag/status/control words,
  exception model, and instruction milestones (FLD/FST, FADD..FDIV, FCOM,
  FSAVE/FRSTOR, FINIT, 80-bit extended).

### Task 20 — Integration notes for DOS gaming platform [ ]

- Document required surrounding devices (BIOS ROM, PIT, PIC, DMA, KBC, VGA,
  AdLib/OPL2-3, Sound Blaster DSP+DMA, IDE/ATA, CMOS/RTC).
- Clarify CPU-core boundary.
- Note 86Box preference over DOSBox for system-level reference.

## Notes & blockers

- **No simulator pre-installed on dev host.** Tests can be authored and
  committed; running them requires installing Icarus Verilog
  (`https://bleyer.org/icarus/` on Windows). Test runner will exit cleanly
  with a "simulator not found" diagnostic so CI/contributors get a clear
  message. Tracked: install instructions land in spec doc (Task 1).
- **No 86Box on host either.** Behavioral comparison will be staged as the
  integer core stabilizes; trace ingestion will be added with Task 14.
