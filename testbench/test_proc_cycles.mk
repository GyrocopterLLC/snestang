# Makefile for cocotb

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES ?= $(PWD)/../src/65C816/common.sv
VERILOG_SOURCES += $(PWD)/../src/cpu.v
VERILOG_SOURCES += $(PWD)/../src/65C816/P65C816.v
VERILOG_SOURCES += $(PWD)/../src/65C816/mcode.sv
VERILOG_SOURCES += $(PWD)/../src/65C816/bit_adder.v
VERILOG_SOURCES += $(PWD)/../src/65C816/BCDAdder.v
VERILOG_SOURCES += $(PWD)/../src/65C816/ALU.v
VERILOG_SOURCES += $(PWD)/../src/65C816/AddSubBCD.v
VERILOG_SOURCES += $(PWD)/../src/65C816/AddrGen.v
VERILOG_SOURCES += $(PWD)/../src/65C816/adder4.v


VERILOG_INCLUDE_DIRS ?= $(PWD)/../src/65C816

# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = SCPU

# MODULE is the basename of the Python test file
MODULE = test_proc_cycles

# Example of how to add a verilog define
# this is equivalent to `define INSERT_ERROR in the .v file
# COMPILE_ARGS ?= -DINSERT_ERROR 
# and this is how you'd do something like `define NUM_BITS 12
# COMPILE_ARGS ?= -DNUM_BITS=12

# COMPILE_ARGS ?= -DSIM
EXTRA_ARGS += --trace --trace-structs --trace-fst

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim