import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles, Join, First
from cocotb.clock import Clock


@cocotb.test()
async def test_ppu(dut):
    dut.RST_N.value = 0
    dut.CLK.value = 0
    dut.ENABLE.value = 0
    dut.DIS_SHORTLINE.value = 0
    dut.PA.value = 0
    dut.PARD_N.value = 0
    dut.PAWR_N.value = 0
    dut.DI.value = 0
    dut.SYSCLK_CE.value = 0
    dut.VRAM_DAI.value = 0
    dut.VRAM_DBI.value = 0
    dut.EXTLATCH.value = 0
    dut.PAL.value = 0
    dut.BLEND.value = 0
    dut.BG_EN.value = 0

    cocotb.start_soon(Clock(dut.CLK, 46.5,'ns').start())

    await Timer(100,'ns')
    
    dut.RST_N.value = 1
    await Timer(100,'ns')
    dut.ENABLE.value = 1

    await Timer(200,'ms')