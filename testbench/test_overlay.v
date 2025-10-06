module test_overlay
(
    input clk,
    input lcd_clk,
    input resetn,

    // overlay inputs, synchronous with clk
    input [3:0] reg_char_we,
    input [31:0] reg_char_di,

    // snes display inputs, synchronous with clk
    input dotclk,
    input vde,
    input hde,
    input [8:0] xs,
    input [8:0] ys,
    // lcd inputs, async
    input overlay_on,

    // lcd outputs, synchronous with lcd_clk
    output lcd_vsync,
    output lcd_hsync,
    output lcd_de,
    output [23:0] lcd_data
);

wire [7:0] overlay_x;
wire [7:0] overlay_y;
wire [14:0] overlay_color;

snes2lcd u_lcd(
    .CLK(clk)
,   .RESETN(resetn)
,   .DOTCLK(dotclk)
,   .HDE(hde)
,   .VDE(vde)
,   .RGB5(15'b0)
,   .XS(xs)
,   .YS(ys)
,   .LCD_PIXELCLK(lcd_clk)
,   .LCD_VSYNC(lcd_vsync)
,   .LCD_HSYNC(lcd_hsync)
,   .LCD_DE(lcd_de)
,   .LCD_DATA(lcd_data)
,   .OVERLAY(overlay_on)
,   .OVERLAY_X(overlay_x)
,   .OVERLAY_Y(overlay_y)
,   .OVERLAY_COLOR(overlay_color)
);


textdisp_2cyc u_text(
    .clk(clk)
,   .hclk(lcd_clk)
,   .resetn(resetn)
,   .x(overlay_x)
,   .y(overlay_y)
,   .color(overlay_color)
,   .reg_char_we(reg_char_we)
,   .reg_char_di(reg_char_di)
);

endmodule
