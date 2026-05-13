#!/usr/bin/env python3
"""Test runner for the cpu386486 core.

Discovers tests from test/tests.json, compiles them with Icarus Verilog,
and reports pass/fail. Exits 0 only when every selected test passes; exits
2 when no simulator is available (so CI can distinguish missing tooling
from real failures).

Usage:
    python scripts/run_tests.py                # run all tests
    python scripts/run_tests.py reset alu      # run tests whose names match
    python scripts/run_tests.py --lint         # only run verilator --lint
    python scripts/run_tests.py --list         # list known tests and exit
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
FILELIST = REPO_ROOT / "rtl" / "cpu386486" / "filelist.f"
BUILD_DIR = REPO_ROOT / "build"
TESTS_JSON = REPO_ROOT / "test" / "tests.json"

# Exit codes: 0=pass, 1=fail, 2=no-simulator, 3=user error.
EXIT_PASS = 0
EXIT_FAIL = 1
EXIT_NO_SIM = 2
EXIT_USAGE = 3


def read_filelist() -> list[Path]:
    files: list[Path] = []
    for line in FILELIST.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        files.append(REPO_ROOT / line)
    return files


def load_tests() -> list[dict]:
    return json.loads(TESTS_JSON.read_text())


def have(tool: str) -> bool:
    return shutil.which(tool) is not None


def run_lint(define_fpu: bool) -> int:
    """Run verilator --lint-only over the RTL filelist."""
    if not have("verilator"):
        print("verilator: not found on PATH; skipping lint.")
        return EXIT_NO_SIM
    cmd = [
        "verilator", "--lint-only", "-Wall", "-Wno-fatal",
        "--top-module", "cpu386486_top",
    ]
    if define_fpu:
        cmd.append("-DCPU386486_ENABLE_FPU")
    cmd.extend(str(p) for p in read_filelist())
    print("$", " ".join(cmd))
    return subprocess.run(cmd, cwd=REPO_ROOT).returncode


def run_test(test: dict, define_fpu: bool) -> int:
    if not have("iverilog") or not have("vvp"):
        print(f"iverilog/vvp: not found on PATH; cannot run '{test['name']}'.")
        return EXIT_NO_SIM
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    vvp_path = BUILD_DIR / f"{test['name']}.vvp"
    sources = [*read_filelist(), *[REPO_ROOT / f for f in test["tb_files"]]]
    compile_cmd = [
        "iverilog", "-g2012", "-Wall",
        "-s", test["tb_top"],
        "-o", str(vvp_path),
    ]
    if define_fpu:
        compile_cmd.extend(["-D", "CPU386486_ENABLE_FPU"])
    compile_cmd.extend(str(p) for p in sources)
    print("$", " ".join(compile_cmd))
    rc = subprocess.run(compile_cmd, cwd=REPO_ROOT).returncode
    if rc != 0:
        return EXIT_FAIL
    rc = subprocess.run(["vvp", str(vvp_path)], cwd=REPO_ROOT).returncode
    return EXIT_PASS if rc == 0 else EXIT_FAIL


def select_tests(tests: list[dict], patterns: list[str]) -> list[dict]:
    if not patterns:
        return tests
    selected = []
    for t in tests:
        if any(p in t["name"] for p in patterns):
            selected.append(t)
    return selected


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("patterns", nargs="*",
                    help="substring filters; runs all tests if omitted")
    ap.add_argument("--lint", action="store_true",
                    help="run verilator --lint-only and exit")
    ap.add_argument("--list", action="store_true",
                    help="list known tests and exit")
    ap.add_argument("--fpu", action="store_true",
                    help="define CPU386486_ENABLE_FPU for this build")
    args = ap.parse_args()

    if args.list:
        for t in load_tests():
            print(f"{t['name']:20s} {t['description']}")
        return EXIT_PASS

    if args.lint:
        return run_lint(define_fpu=args.fpu)

    tests = select_tests(load_tests(), args.patterns)
    if not tests:
        print("No matching tests.")
        return EXIT_USAGE

    no_sim = False
    fail = 0
    for t in tests:
        print(f"\n--- {t['name']} ---")
        rc = run_test(t, define_fpu=args.fpu)
        if rc == EXIT_NO_SIM:
            no_sim = True
            break
        if rc != EXIT_PASS:
            fail += 1

    if no_sim:
        print("\nSimulator (iverilog/vvp) not installed; tests not executed.")
        print("Install Icarus Verilog from https://bleyer.org/icarus/ (Windows)")
        print("or 'apt install iverilog' / 'brew install icarus-verilog'.")
        return EXIT_NO_SIM

    if fail:
        print(f"\n{fail} test(s) failed.")
        return EXIT_FAIL
    print(f"\nAll {len(tests)} test(s) passed.")
    return EXIT_PASS


if __name__ == "__main__":
    sys.exit(main())
