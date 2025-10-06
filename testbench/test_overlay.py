import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ClockCycles, Join, First
from cocotb.clock import Clock
import numpy as np
import cv2

async def overlay_print(dut, inchars:str, linenum:int):
    # available space: 32x28
    await RisingEdge(dut.clk)
    if(linenum < 28):
        y = linenum
        if(len(inchars) > 32):
            inchars = inchars[:32]
        for x, c in enumerate(inchars):
            dut.reg_char_we.value = 1
            dut.reg_char_di.value = (x << 16) + (y << 8) + ord(c)
            await RisingEdge(dut.clk)
    dut.reg_char_we.value = 0
async def create_frame(dut) -> np.ndarray:
    fullimg = np.zeros((480,800,3)).astype(np.uint8)

    xval = 0
    yval = 0

    await FallingEdge(dut.lcd_vsync)
    await FallingEdge(dut.lcd_hsync)

    while yval < 480:
        active_line = False
        while dut.lcd_hsync.value == 0:
            if(dut.lcd_de.value == 1):
                active_line = True
                fullimg[yval, xval, 0] = (dut.lcd_data.value >> 16) & 0xFF
                fullimg[yval, xval, 1] = (dut.lcd_data.value >> 8) & 0xFF
                fullimg[yval, xval, 2] = (dut.lcd_data.value >> 0) & 0xFF
                xval = xval + 1
            await RisingEdge(dut.lcd_clk)
        await FallingEdge(dut.lcd_hsync)
        xval = 0
        if active_line:
            yval = yval + 1

    return fullimg

class snes_display:
    def __init__(self):
        self.xcnt = 0
        self.ycnt = 0

    async def fake_snes_xs_ys_generator(self, dut):
        while True:
            if self.ycnt < 1:
                dut.ys.value = 0
            elif self.ycnt < 226:
                dut.ys.value = self.ycnt - 1
            else:
                dut.ys.value = 224

            if self.xcnt < 19:
                dut.xs.value = 0
            elif self.xcnt < 275:
                dut.xs.value = (self.xcnt - 19) << 1
            else:
                dut.xs.value = 255 << 1
            await RisingEdge(dut.clk)

    async def fake_snes_dotclk(self, dut):
        while True:
            await ClockCycles(dut.clk, 2)
            dut.dotclk.value = 1
            await ClockCycles(dut.clk, 2)
            dut.dotclk.value = 0

    async def fake_snes_display(self, dut):
        cocotb.start_soon(self.fake_snes_dotclk(dut))
        cocotb.start_soon(self.fake_snes_xs_ys_generator(dut))
        while True:
            self.xcnt = 0
            self.ycnt = 0
            dut.hde.value = 0
            dut.vde.value = 0
            while self.ycnt < 262:
                while self.xcnt < 340:
                    await RisingEdge(dut.dotclk)
                    self.xcnt = self.xcnt + 1
                    if(self.xcnt == 19):
                        dut.hde.value = 1
                    if(self.xcnt == 275):
                        dut.hde.value = 0
                self.xcnt = 0
                if self.ycnt % 10 == 0:
                    dut._log.info(f'line {self.ycnt} done')
                self.ycnt = self.ycnt + 1
                if(self.ycnt == 1):
                    dut.vde.value = 1
                if(self.ycnt == 225):
                    dut.vde.value = 0
            self.ycnt = 0
        

@cocotb.test()
async def test_overlay(dut):
    # create two clocks, main clock (21.5MHz) and lcd clock (31.2MHz)
    cocotb.start_soon(Clock(dut.clk, 46.5, "ns").start())
    cocotb.start_soon(Clock(dut.lcd_clk, 32.04, "ns").start())

    dut.resetn.value = 0
    dut.reg_char_we.value = 0
    dut.reg_char_di.value = 0
    dut.overlay_on.value = 0

    my_fake_snes = snes_display()

    cocotb.start_soon(my_fake_snes.fake_snes_display(dut))
    await Timer(10, 'us')

    dut.resetn.value = 1

    await Timer(1, 'us')
    await overlay_print(dut, "    Hello SNES!", 12)

    dut.overlay_on.value = 1

    frame_vals = await create_frame(dut)

    cv2.imshow('frame',frame_vals)
    cv2.waitKey(0)
    cv2.destroyAllWindows()

    frame_vals = await create_frame(dut)

    cv2.imshow('frame',frame_vals)
    cv2.waitKey(0)
    cv2.destroyAllWindows()