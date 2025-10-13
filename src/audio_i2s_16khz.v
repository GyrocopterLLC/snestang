
module audio_i2s #(
    parameter HDMI_CLK_FREQ_KHZ = 74250,
    parameter AUDIO_OUT_RATE_HZ = 32000,
    parameter AUDIO_CLK_DIVIDER = HDMI_CLK_FREQ_KHZ * 1000 / AUDIO_OUT_RATE_HZ / 2, // ends up begin 1160 after rounding
    parameter AUDIO_BITS_PER_SAMPLE = 16 // per channel
)
(
    input           HDMICLK,
    input           AUDIOCLK,
    input           RESETN,

    // snes audio output (re-timed by HDMI)
    input [15:0]    LEFT_SAMPLE_IN,
    input [15:0]    RIGHT_SAMPLE_IN,

    // i2s output
    output          PA_EN,
    output          I2S_BCLK,
    output          I2S_LRCLK,
    output          I2S_DOUT
);

// snes audio is roughly 32kHz
// but it's pushed a bit faster out of the dsp (~32.2kHz, or 536.33 samples per 60Hz frame)
// and has a few skipped samples for every frame

// snes2hdmi.v contains a short audio sample buffer which smoothes out the 
// sample rate. It holds enough samples to keep audio chugging during the
// frame pause period


// --- I2S clock generation ---
// manually setting the audio bit clock divider
// if the hdmi clock ever changes from the default of 74.25 MHz, need to redo the math

////////////////////////////////////////////////////////////////////////////////
// Audio Clock is 32 kHz, bit clock is 32x that, or 1024 kHz (1.024 MHz)      //
// The audio clock divider is 1160 (makes 64 kHz). That doesn't divide evenly //
// by 16.                                                                     //
// *** 1160 / 16 = 72.5 ***                                                   //
// So, we need to alternate between 72 cycle and 73 cycle long bits           //
// That way we have 16 bits of 72 cycles and 16 bits of 73 cycles             //
// 16*72 + 16*73 = 2320                                                       //
// Hopefully the MAX98357A doesn't care about the uneven BCLK timing!!        //
//                                                                            // 
//                      SPOILER                                               //
//                      it did.                                               //
//                                                                            //
// The minimum RMS jitter of the MAX98357A/B is 0.5ns for <40kHz, and 12ns    //
// for >40kHz. One cycle of 74.25 MHz is 13.47ns, waaay more than even LRCLK  //
// jitter tolerance, and ever more than the high frequency tolerance.         //
// Using a variable bclk divider resulted in frequent crackles and pops, and  //
// occassionally VERY LOUD pops.
//                                                                            //
// So instead, let's try using a constant BCLK divider of 145, resulting in   //
// a BLCK frequency of 512kHz and a audio clock of 16kHz.                     //
// We'll simply skip half the samples of the 32kHz source.                    //
// Audio quality will suffer, but no more pops.                               //
////////////////////////////////////////////////////////////////////////////////

localparam AUDIO_BIT_CLK_DIVIDER = 73;  // (72,73) for high, low periods. Resulting
                                        // in a total bit length of 145
reg audio_bit_clock;
reg audio_lr_clock;
reg [$clog2(AUDIO_BIT_CLK_DIVIDER)-1:0] audio_bitclk_div;
wire [$clog2(AUDIO_BIT_CLK_DIVIDER)-1:0] div_max_val = 
    audio_bit_clock ? AUDIO_BIT_CLK_DIVIDER - 2 : // on high periods, count to 72
    AUDIO_BIT_CLK_DIVIDER- 1; // on low periods, go to 73

reg [3:0] audio_lrclk_div;
reg saw_falling_edge;
reg audioclk_r;

always @(posedge HDMICLK) begin
    if(!RESETN) begin
        audio_bitclk_div <= 0;
        saw_falling_edge <= 0;
        audio_lrclk_div <= 0;
    end else begin
        audioclk_r <= AUDIOCLK;

        if(!saw_falling_edge) begin
            // wait for the first falling edge of audio_clock to 
            // synchronize the bit clock
            if(audioclk_r && ~AUDIOCLK) begin
                saw_falling_edge <= 1;
            end
        end

        if(saw_falling_edge) begin
            if(audio_bitclk_div == div_max_val) begin
                audio_bit_clock <= ~audio_bit_clock;
                audio_bitclk_div <= 0;
                if(audio_bit_clock) begin
                    // only perform LR clock changes on falling edge of bit clock
                    if(audio_lrclk_div == 15) begin
                        audio_lr_clock <= ~audio_lr_clock;
                        audio_lrclk_div <= 0;
                    end else begin
                        audio_lrclk_div <= audio_lrclk_div + 1;
                    end
                end
            end else begin
                audio_bitclk_div <= audio_bitclk_div + 1;
            end
        end
    end
end

// --- data sampling ---
// grab data on all falling edges of the input audio clock
// snes2hdmi loaded it on the rising edge
// 1/2 of the samples will end up getting skipped, but
// that's just how the 1/2 decimation ends up working anyway
reg [15:0] audio_sample;
always @(posedge HDMICLK) begin
    if(audioclk_r && ~AUDIOCLK) begin
        audio_sample <= LEFT_SAMPLE_IN;
    end
end

// --- I2S data bit generation ---
reg [15:0] audio_shift_reg;
reg audio_data_out;
reg lrclk_r;
reg bitclk_r;
always @(posedge HDMICLK) begin
    lrclk_r <= audio_lr_clock;
    bitclk_r <= audio_bit_clock;
    // first bit of I2S data is the **2nd cycle** after the change in LR clock
    // LEGEND: ------______ 
    //          high   low
    //
    // BCLK:  __--__--__--__--__--__--__--__--__--__--__--__--__--__--__--__--__--__--__--__--__--__--__--__-- ...
    // LRCLK: --------________________________________________________________________------------------------ ...
    // Data:  |R2 |R1 |R0 |L15|L14|L13|L12|L11|L10|L9 |L8 |L7 |L6 |L5 |L4 |L3 |L2 |L1 |L0 |R15|R14|R13|R12|R11 ...

    // load the shift reg on the LR clock change, and load the 
    // output data bit with the top bit of shift register
    // that way the data bit will be 2 bit clock cycles delayed
    if(bitclk_r && ~audio_bit_clock) begin
        // every falling edge of bit clock, move top of shift reg to output
        audio_data_out <= audio_shift_reg[15];        
        if(lrclk_r && ~audio_lr_clock) begin
            // on LRCLK falling edge, load shift register
            audio_shift_reg <= audio_sample;
        end else begin
            // otherwise, shift it one bit to the left
            audio_shift_reg <= {audio_shift_reg[14:0], 1'b0};
        end
    end
end

assign PA_EN = 1;
assign I2S_BCLK = audio_bit_clock;
assign I2S_LRCLK = audio_lr_clock;
assign I2S_DOUT = audio_data_out;

endmodule