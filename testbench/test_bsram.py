import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles, Join, First
from cocotb.clock import Clock
from random import getrandbits, randint

async def mock_sdram(dut):
    # // SDRAM port
    # output     [22:1] RV_ADDR,      // 8MB RV memory space (top 1MB is for BSRAM)    
    # output     [15:0] RV_DIN,       // 16-bit accesses
    # output     [1:0]  RV_DS,
    # input      [15:0] RV_DOUT,
    # output            RV_REQ,
    # input             RV_REQ_ACK,   // ready for new requests. read data available on NEXT mclk
    # output            RV_WE

    sdram_mem = [getrandbits(8) for _ in range(1024*16)] # 16kB of random data
    dut.RV_REQ_ACK.value = 0
    dut.RV_DOUT.value = 0

    while True:
        if dut.RV_REQ.value == 1:
            sdram_addr = dut.RV_ADDR.value * 2
            assert sdram_addr >= 0x700000 and sdram_addr < 0x704000, "SDRAM out of range"
            phys_addr = sdram_addr - 0x700000
            if dut.RV_WE.value == 1:
                await RisingEdge(dut.CLK)
                dut.RV_REQ_ACK.value = 1
                sdram_mem[phys_addr] = dut.RV_DIN.value & 0xFF
                sdram_mem[phys_addr + 1] = (dut.RV_DIN.value >> 8) & 0xFF
                await RisingEdge(dut.CLK)
                dut.RV_REQ_ACK.value = 0
            else:
                await RisingEdge(dut.CLK)
                dut.RV_REQ_ACK.value = 1
                await RisingEdge(dut.CLK)
                dut.RV_REQ_ACK.value = 0
                dut.RV_DOUT.value = sdram_mem[phys_addr] + (sdram_mem[phys_addr + 1] << 8)
        await RisingEdge(dut.CLK)

async def mock_bl616(dut, block_num = 0, is_write=False, write_data=None) -> list | None:
    # // Processor port
    # input             START_READ,
    # input     [15:0]  BSRAM_BLOCK_NUM, // reads/writes are in 512 Byte blocks
    # output     [7:0]  DATA_OUT, 
    # output            DATA_OUT_READY,
    # input             DATA_OUT_ACK,
    # input             START_WRITE,
    # input      [7:0]  DATA_IN,
    # input             DATA_IN_READY,
    # output            DATA_IN_ACK, // probably unnecessary since we can load much faster than UART sends

    dut.START_READ.value = 0
    dut.BSRAM_BLOCK_NUM.value = 0
    dut.DATA_OUT_ACK.value = 0
    dut.START_WRITE.value = 0
    dut.DATA_IN.value = 0
    dut.DATA_IN_READY.value = 0

    if is_write:
        assert len(write_data) == 512, "incorrect write data length"
        dut.START_WRITE.value = 1
        dut.BSRAM_BLOCK_NUM.value = block_num

        for bb in write_data:
            while dut.DATA_IN_ACK.value == 0:
                await RisingEdge(dut.CLK)
                dut.START_WRITE.value = 0
                dut.DATA_IN_READY.value = 1
                dut.DATA_IN.value = bb
            dut.DATA_IN_READY.value = 0
            await ClockCycles(dut.CLK, randint(10,15))
        
        return None
            
    else:
        # is read
        dat_out = []
        dut.START_READ.value = 1
        dut.BSRAM_BLOCK_NUM.value = block_num
        
        while len(dat_out) < 512:
            await RisingEdge(dut.CLK)
            dut.START_READ.value = 0
            dut.DATA_OUT_ACK.value = 0
            if dut.DATA_OUT_READY.value == 1:
                await ClockCycles(dut.CLK, randint(10,15))
                dut.DATA_OUT_ACK.value = 1
                dat_out.append(dut.DATA_OUT.value)
            
        await RisingEdge(dut.CLK)
        dut.START_READ.value = 0
        dut.BSRAM_BLOCK_NUM.value = 0
        dut.DATA_OUT_ACK.value = 0
        dut.START_WRITE.value = 0
        dut.DATA_IN.value = 0
        dut.DATA_IN_READY.value = 0
        return dat_out
    
@cocotb.test()
async def test_bsram(dut):
    cocotb.start_soon(Clock(dut.CLK, 10, 'ps').start())
    cocotb.start_soon(mock_sdram(dut))
    dut.RESETN.value = 0

    await ClockCycles(dut.CLK, 30)
    dut.RESETN.value = 1
    await ClockCycles(dut.CLK, 30)


    await mock_bl616(dut, 0)
    await ClockCycles(dut.CLK, 30)

    await mock_bl616(dut, 0, True, [0x00 for _ in range(512)])
    await ClockCycles(dut.CLK, 30)

    await mock_bl616(dut, 0)
    await ClockCycles(dut.CLK, 30)

    await mock_bl616(dut, 3)
    await ClockCycles(dut.CLK, 30)

    await mock_bl616(dut, 3, True, [0xAA for _ in range(512)])
    await ClockCycles(dut.CLK, 30)

    await mock_bl616(dut, 3)
    await ClockCycles(dut.CLK, 30)

    await mock_bl616(dut, 0)
    await ClockCycles(dut.CLK, 30)