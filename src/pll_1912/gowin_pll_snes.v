module gowin_pll_snes(
    clkin,
    idsel,
    fbdsel,
    mdsel,
    mdsel_frac,
    odsel0,
    odsel0_frac,
    odsel1,
    odsel2,
    init_clk,
    clkout0,
    clkout1,
    clkout2
);


input clkin;
input [5:0] idsel;
input [5:0] fbdsel;
input [6:0] mdsel;
input [2:0] mdsel_frac;
input [6:0] odsel0;
input [2:0] odsel0_frac;
input [6:0] odsel1;
input [6:0] odsel2;
input init_clk;
output clkout0;
output clkout1;
output clkout2;
wire lock;
wire [5:0] icpsel;
wire [2:0] lpfres;
wire pll_lock;
wire pll_rst;


    gowin_pll_snes_MOD u_pll(
        .idsel(idsel),
        .fbdsel(fbdsel),
        .mdsel(mdsel),
        .mdsel_frac(mdsel_frac),
        .odsel0(odsel0),
        .odsel0_frac(odsel0_frac),
        .odsel1(odsel1),
        .odsel2(odsel2),
        .clkout1(clkout1),
        .clkout2(clkout2),
        .clkout0(clkout0),
        .lock(pll_lock),
        .clkin(clkin),
        .reset(pll_rst),
        .icpsel(icpsel),
        .lpfres(lpfres),
        .lpfcap(2'b00)
    );


    PLL_INIT u_pll_init(
        .CLKIN(init_clk),
        .I_RST(1'b0),
        .O_RST(pll_rst),
        .PLLLOCK(pll_lock),
        .O_LOCK(lock),
        .ICPSEL(icpsel),
        .LPFRES(lpfres)
    );
    defparam u_pll_init.CLK_PERIOD = 20;
    defparam u_pll_init.MULTI_FAC = 8;


endmodule
