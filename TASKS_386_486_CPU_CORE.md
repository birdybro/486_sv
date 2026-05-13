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
| RTL location    | `rtl/core_486/`                                              |
| Testbench loc.  | `tb/` (non-synthesizable allowed)                             |
| Tests location  | `test/` (directed assembly + sv test programs)                |
| Docs            | `docs/`                                                       |
| Simulator       | **Icarus Verilog** primary; **Verilator** secondary (lint+sim)|
| Lint            | `verilator --lint-only` when available                        |
| Test runner     | `scripts/run_tests.py` (Python 3, no Make required)           |
| Naming          | `core_486_<unit>.sv`, snake_case signals, ALL_CAPS params     |
| FPU gating      | `parameter bit ENABLE_FPU` + ``CORE_486_ENABLE_FPU`` define  |
| Personalities   | `cpu_personality_e` enum in `core_486_pkg.sv`                |

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

### Task 2 — Skeleton RTL [x]

- Package, config, top, and all stub modules landed under `rtl/core_486/`.
- `rtl/core_486/filelist.f` records the compile order for tooling.
- Top module exposes clock/reset, 32-bit bus master, INTR/NMI, and debug
  observability (EIP/EFLAGS). All stubs are lint-friendly (every output is
  driven; unused inputs are gathered into `_unused` sinks).
- FPU is gated by both `parameter bit ENABLE_FPU` and the
  ``CORE_486_ENABLE_FPU`` define; default build excludes the FPU
  interface from elaboration.
- Lint not yet run on the dev host (no `verilator`/`iverilog` on PATH; the
  test runner in Task 3 will execute lint when those tools are present).

### Task 3 — Simulation harness [x]

- `tb/mem_model.sv` byte-addressable sim memory with configurable latency.
- `tb/tb_core_486_reset.sv` testbench verifying reset state.
- `test/tests.json` test catalog (extensible).
- `scripts/run_tests.py` discovers tests, runs Icarus Verilog, exits with
  code 2 when no simulator is found (so CI distinguishes "no tooling"
  from "broken").
- `.github/workflows/ci.yml` installs iverilog+verilator on Ubuntu and runs
  lint and tests in both FPU-out and FPU-compiled configurations.
- README rewritten with personality table and run instructions.
- **Local run:** runner exits 2 (no-sim) on the dev host as expected;
  CI will execute the reset testbench. Reset test is also a Task 5
  acceptance gate.

### Task 4 — Architectural register file [x]

- Real `core_486_regs` implementation: two GPR read ports + one write
  port with 8/16/32-bit sizing, AH/BH/CH/DH high-byte addressing; segment
  file (selector + base + limit + access bits); EIP with arbitrary-set
  and increment; EFLAGS with caller mask + personality mask (AC dropped on
  386) + reserved-1; CR0/CR2/CR3/CR4 with CR4 gated on 486 personalities.
- Package extended with `op_size_e`, `gpr_e`, `seg_e`, `seg_reg_t`, and
  EFLAGS supported-mask localparam.
- `tb_core_486_regs.sv` exercises all access paths (20 assertions).
  Reset test extended (10 assertions). Both pass under Icarus Verilog 12.
- Iverilog 12 compatibility issues encountered and worked around:
  no `automatic` lifetime overrides, no unpacked-array function args,
  no struct-field access via unpacked-array index in continuous assigns.
  These are sim-tool nuisances; the RTL stays synthesizable.

### Task 5 — Reset and real-mode fetch [x]

- Real `core_486_prefetch` implementation: dword-aligned bus reads with the
  byte-select picked from `linear_addr[1:0]`; single-byte handshake to the
  decoder; one-cycle EIP increment pulse on consume.
- Bus master `core_486_bus_if` wired to a sequenced request port from the
  prefetcher, so `cpu_top` now issues real reads at linear(CS:EIP).
- `core_486_control` upgraded from idle stub to a NOP-streamer: consumes
  0x90 bytes and halts (latches `dbg_halted`) on the first non-NOP, giving
  the test something definitive to assert.
- `tb_core_486_fetch.sv` preloads a 16-byte NOP slide at the wrap-aliased
  reset address (0xFFFFFFF0 → 0xFFF0 in a 64 KiB model) plus an HLT
  sentinel and verifies retire-count, halted, and EIP after 400 cycles.
  All three checks pass.
- Memory model now wraps modulo BYTES so the reset linear address aliases
  into a tiny ROM mirror — same trick a real PC BIOS uses.

### Rename pass (concurrent with Task 5)

- Renamed every module/file/dir from `cpu386486_*` to `core_486_*`
  (`rtl/cpu386486/` → `rtl/core_486/`). Macro `CPU386486_ENABLE_FPU` →
  `CORE_486_ENABLE_FPU`. Docs, tests, scripts, CI all updated. Reset/regs/
  fetch all pass on the renamed code.

### Task 6 — Instruction decoder framework [ ]

- Prefix bytes: operand-size, address-size, segment override, REP/REPE/REPNE,
  LOCK (latches only; semantics later).
- ModRM/SIB parser.
- x87/FPU opcode-range detection → routes to `core_486_fpu_if`.
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

- Clean `core_486_fpu_if` boundary.
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
