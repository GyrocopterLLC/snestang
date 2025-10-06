//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12 (64-bit)
//Part Number: GW5AST-LV138PG484AC1/I0
//Device: GW5AST-138
//Device Version: C
//Created Time: Wed Oct  1 04:39:12 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    gowin_pll_snes_MOD your_instance_name(
        .lock(lock), //output lock
        .clkout0(clkout0), //output clkout0
        .clkout1(clkout1), //output clkout1
        .clkout2(clkout2), //output clkout2
        .clkin(clkin), //input clkin
        .reset(reset), //input reset
        .fbdsel(fbdsel), //input [5:0] fbdsel
        .idsel(idsel), //input [5:0] idsel
        .mdsel(mdsel), //input [6:0] mdsel
        .mdsel_frac(mdsel_frac), //input [2:0] mdsel_frac
        .odsel0(odsel0), //input [6:0] odsel0
        .odsel0_frac(odsel0_frac), //input [2:0] odsel0_frac
        .odsel1(odsel1), //input [6:0] odsel1
        .odsel2(odsel2), //input [6:0] odsel2
        .icpsel(icpsel), //input [5:0] icpsel
        .lpfres(lpfres), //input [2:0] lpfres
        .lpfcap(lpfcap) //input [1:0] lpfcap
    );

//--------Copy end-------------------
