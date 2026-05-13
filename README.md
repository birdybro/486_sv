# 486_sv

Synthesizable 386/486-class x86 CPU core in SystemVerilog, configurable for
the personalities below. Long-term defaults for DOS gaming workloads are
**486DX2/66** and **486DX4/100**; the first functional milestone is a 386DX
real-mode integer core.

| Personality   | Family | FPU on die | Notes                                |
| ------------- | ------ | ---------- | ------------------------------------ |
| 386DX-25 / 40 | 386DX  | external   | First-milestone target               |
| 486SX-25 / 33 | 486SX  | absent     | FPU opcodes raise #NM                |
| 486DX-33      | 486DX  | optional   |                                      |
| 486DX2-66     | 486DX2 | optional   | **Long-term DOS-gaming default**     |
| 486DX4-100    | 486DX4 | optional   | High-end 486 DOS-gaming target       |

The FPU is **optional** — built only when both `parameter bit ENABLE_FPU`
and the synthesis define `CPU386486_ENABLE_FPU` are set. See
[`docs/386_486_cpu_core_spec.md`](docs/386_486_cpu_core_spec.md) §5.

## Layout

```
rtl/cpu386486/   SystemVerilog RTL (synthesizable)
tb/              Testbenches (non-synthesizable allowed)
test/            Directed test descriptions (tests.json)
docs/            Specification and notes
scripts/         Build/test helpers
```

## Running tests

Install [Icarus Verilog](https://bleyer.org/icarus/) (and optionally
[Verilator](https://www.veripool.org/verilator/) for lint), then:

```
python scripts/run_tests.py            # run every known test
python scripts/run_tests.py reset      # run tests matching "reset"
python scripts/run_tests.py --lint     # verilator --lint-only
python scripts/run_tests.py --fpu      # build with CPU386486_ENABLE_FPU
```

The runner exits with code 2 if no simulator is on PATH, so CI can
distinguish missing tooling from real failures.

## Task plan

Living plan: [`TASKS_386_486_CPU_CORE.md`](TASKS_386_486_CPU_CORE.md).

## References

This core is implemented from the Intel architectural documents:

- Intel 80386 Programmer's Reference Manual (1986)
- Intel i486 Programmer's Reference Manual (1990)
- Intel i486 Hardware Reference Manual

[86Box](https://86box.net/) and [ao486](https://github.com/MiSTer-devel/ao486_MiSTer)
are consulted as behavioral and FPGA-implementation references only — no
source from either project is used here.

## License

MIT — see [`LICENSE`](LICENSE).

