# Makefile for cocotb

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES ?= $(PWD)/../src/bsram_interface.v
# VERILOG_SOURCES += $(PWD)/prim_sim_dpb.v
# VERILOG_SOURCES += $(PWD)/../src/snes2lcd.v
# VERILOG_SOURCES += $(PWD)/../src/iosys/textdisp_2cyc.v
# VERILOG_SOURCES += $(PWD)/../src/iosys/gowin_dpb_menu.v

# VERILOG_INCLUDE_DIRS ?= $(PWD)/../src/65C816

# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = bsram_interface

# MODULE is the basename of the Python test file
MODULE = test_bsram

# Example of how to add a verilog define
# this is equivalent to `define INSERT_ERROR in the .v file
# COMPILE_ARGS ?= -DINSERT_ERROR 
# and this is how you'd do something like `define NUM_BITS 12
# COMPILE_ARGS ?= -DNUM_BITS=12

# COMPILE_ARGS ?= -DSIM
EXTRA_ARGS += --trace --trace-structs --trace-fst

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim