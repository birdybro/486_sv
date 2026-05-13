# Compile order for the cpu386486 core. Used by scripts/run_tests.py and any
# external build flow. The package must come first.
rtl/cpu386486/cpu386486_pkg.sv
rtl/cpu386486/cpu386486_config.sv
rtl/cpu386486/cpu386486_regs.sv
rtl/cpu386486/cpu386486_prefetch.sv
rtl/cpu386486/cpu386486_decode.sv
rtl/cpu386486/cpu386486_alu.sv
rtl/cpu386486/cpu386486_segment.sv
rtl/cpu386486/cpu386486_paging.sv
rtl/cpu386486/cpu386486_exceptions.sv
rtl/cpu386486/cpu386486_microcode.sv
rtl/cpu386486/cpu386486_control.sv
rtl/cpu386486/cpu386486_bus_if.sv
rtl/cpu386486/cpu386486_fpu_if.sv
rtl/cpu386486/cpu386486_fpu_stub.sv
rtl/cpu386486/cpu386486_top.sv
