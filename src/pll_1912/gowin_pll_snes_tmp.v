//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Part Number: GW5AST-LV138PG484AC1/I0
//Device: GW5AST-138
//Device Version: C


//Change the instance name and port connections to the signal names
//--------Copy here to design--------
    gowin_pll_snes your_instance_name(
        .clkin(clkin), //input  clkin
        .idsel(idsel), //input [5:0] idsel
        .fbdsel(fbdsel), //input [5:0] fbdsel
        .mdsel(mdsel), //input [6:0] mdsel
        .mdsel_frac(mdsel_frac), //input [2:0] mdsel_frac
        .odsel0(odsel0), //input [6:0] odsel0
        .odsel0_frac(odsel0_frac), //input [2:0] odsel0_frac
        .odsel1(odsel1), //input [6:0] odsel1
        .odsel2(odsel2), //input [6:0] odsel2
        .init_clk(init_clk), //input  init_clk
        .clkout0(clkout0), //output  clkout0
        .clkout1(clkout1), //output  clkout1
        .clkout2(clkout2) //output  clkout2
);


//--------Copy end-------------------
