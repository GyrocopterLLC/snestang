import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles, Join, First
from cocotb.clock import Clock


@cocotb.test()
async def test_startup(dut):
    # clock is 21.477 MHz

    cocotb.start_soon(Clock(dut.CLK, round(1/21.477,5), 'us').start())

    dut.RST_N.value = 0
    dut.ENABLE.value = 0

    dut.DI.value = 0xEA # (NOP)

    # ???
    dut.HBLANK.value=0
    dut.VBLANK.value=0
    dut.IRQ_N.value=1
    dut.JOY1_DI.value=0
    dut.JOY2_DI.value=0
    dut.TURBO.value=0
    dut.DBG_REG.value=0
    dut.DBG_DAT_IN.value=0
    dut.DBG_CPU_WR.value=0

    await ClockCycles(dut.CLK, 40)
    dut.RST_N.value = 1
    await ClockCycles(dut.CLK, 40)
    dut.ENABLE.value = 1

    await ClockCycles(dut.CLK, 4000)
