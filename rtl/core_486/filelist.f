# Compile order for the core_486 core. Used by scripts/run_tests.py and any
# external build flow. The package must come first.
rtl/core_486/core_486_pkg.sv
rtl/core_486/core_486_config.sv
rtl/core_486/core_486_regs.sv
rtl/core_486/core_486_prefetch.sv
rtl/core_486/core_486_decode.sv
rtl/core_486/core_486_alu.sv
rtl/core_486/core_486_segment.sv
rtl/core_486/core_486_paging.sv
rtl/core_486/core_486_exceptions.sv
rtl/core_486/core_486_microcode.sv
rtl/core_486/core_486_control.sv
rtl/core_486/core_486_bus_if.sv
rtl/core_486/core_486_fpu_if.sv
rtl/core_486/core_486_fpu_stub.sv
rtl/core_486/core_486_top.sv
