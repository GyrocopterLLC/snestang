
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


// ---- I2S clock generation
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
////////////////////////////////////////////////////////////////////////////////

localparam AUDIO_BIT_CLK_DIVIDER = 36; // (36,36) half the time, and (36,37) the other half
// High cycle will always be 36 clocks, low cycle will alternate 36 and 37 clocks

reg audio_bit_clock;
reg [$clog2(AUDIO_BIT_CLK_DIVIDER)-1:0] audio_bitclk_div;
reg div_max_select;
wire [$clog2(AUDIO_BIT_CLK_DIVIDER)-1:0] div_max_val = 
    audio_bit_clock ? AUDIO_BIT_CLK_DIVIDER - 1 : // on high periods, always go to 36
    (div_max_select ? AUDIO_BIT_CLK_DIVIDER : AUDIO_BIT_CLK_DIVIDER - 1); // on low periods, alternate 36 and 37

reg saw_falling_edge;
reg audioclk_r;

always @(posedge HDMICLK) begin
    if(!RESETN) begin
        audio_bitclk_div <= 0;
        div_max_select <= 0;
        saw_falling_edge <= 0;
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
                if(audio_bit_clock)
                    div_max_select <= ~div_max_select; // alternate for each low period
                audio_bitclk_div <= 0;
            end else begin
                audio_bitclk_div <= audio_bitclk_div + 1;
            end
        end
    end
end

`ifndef fake_audio_path

// --- data sampling
// grab the new sample on the falling edge of LRCLK
// it was loaded by snes2hdmi on the rising edge
reg [15:0] audio_sample;
// wire [15:0] averaged_sample = LEFT_SAMPLE_IN[7:0] + RIGHT_SAMPLE_IN[7:0]; // sum and divide by 2

// wire [16:0] left_unsigned = LEFT_SAMPLE_IN + 17'h8000;
// wire [16:0] right_unsigned = RIGHT_SAMPLE_IN + 17'h8000;

// wire [15:0] averaged_sample = left_unsigned[8:0] + right_unsigned[8:0];
wire [15:0] averaged_sample = {LEFT_SAMPLE_IN[15], LEFT_SAMPLE_IN[15:1]}; // sign-extended divide by 2

reg [2:0] bclk_falling_lockout; // to prevent shifting right after LRCLK falling edge
reg bclk_r;
reg audio_data_out;
always @(posedge HDMICLK) begin
    bclk_r <= audio_bit_clock;

    if(audioclk_r && ~AUDIOCLK) begin
        audio_sample <= averaged_sample; 
        bclk_falling_lockout <= 3'd7;
    end else begin
        if(bclk_falling_lockout != 0) begin
            bclk_falling_lockout <= bclk_falling_lockout - 1;
        end else begin
            if(bclk_r && ~audio_bit_clock) begin
                // bclk falling edge when we're past the lockout period
                audio_sample <= {audio_sample[14:0], 1'b0}; // shift the holding register
                audio_data_out <= audio_sample[15]; // and load the output from the top
            end
        end
    end
end
        
`else

// send a sine wave
// 1kHz (so repeating 32 samples) 
// min -0.25, max +0.25
reg [15:0] sine_mem[0:31];
initial begin
    sine_mem[0] = 16'h0000;
    sine_mem[1] = 16'h063E;
    sine_mem[2] = 16'h0C3E;
    sine_mem[3] = 16'h11C7;
    sine_mem[4] = 16'h16A0;
    sine_mem[5] = 16'h1A9B;
    sine_mem[6] = 16'h1D90;
    sine_mem[7] = 16'h1F62;
    sine_mem[8] = 16'h2000;
    sine_mem[9] = 16'h1F62;
    sine_mem[10] = 16'h1D90;
    sine_mem[11] = 16'h1A9B;
    sine_mem[12] = 16'h16A0;
    sine_mem[13] = 16'h11C7;
    sine_mem[14] = 16'h0C3E;
    sine_mem[15] = 16'h063E;
    sine_mem[16] = 16'h0000;
    sine_mem[17] = 16'hF9C2;
    sine_mem[18] = 16'hF3C2;
    sine_mem[19] = 16'hEE39;
    sine_mem[20] = 16'hE960;
    sine_mem[21] = 16'hE565;
    sine_mem[22] = 16'hE270;
    sine_mem[23] = 16'hE09E;
    sine_mem[24] = 16'hE000;
    sine_mem[25] = 16'hE09E;
    sine_mem[26] = 16'hE270;
    sine_mem[27] = 16'hE565;
    sine_mem[28] = 16'hE960;
    sine_mem[29] = 16'hEE39;
    sine_mem[30] = 16'hF3C2;
    sine_mem[31] = 16'hF9C2;
end

reg [15:0] audio_sample;
reg [4:0] sample_count = 0;

reg [3:0] bclk_falling_lockout; // to prevent shifting right after LRCLK falling edge
reg bclk_r;
reg audio_data_out;
always @(posedge HDMICLK) begin
    bclk_r <= audio_bit_clock;

    if(audioclk_r && ~AUDIOCLK) begin
        audio_sample <= sine_mem[sample_count]; 
        sample_count <= sample_count + 1;
        bclk_falling_lockout <= 4'd15;
    end else begin
        if(bclk_falling_lockout != 0) begin
            bclk_falling_lockout <= bclk_falling_lockout - 1;
        end else begin
            if(bclk_r && ~audio_bit_clock) begin
                // bclk falling edge when we're past the lockout period
                audio_sample <= {audio_sample[14:0], 1'b0}; // shift the holding register
                audio_data_out <= audio_sample[15]; // and load the output from the top
            end
        end
    end
end

`endif

/*
        audio_bitclk_div <= audio_bitclk_div + 1;
        if(audio_bitclk_div == AUDIO_BIT_CLOCK_DELAY - 1) begin
            audio_bitclk_div <= 0; 
            audio_bit_clock <= ~audio_bit_clock;
            if(audio_bit_clock) begin
                // change LRCLK or data on bit clock falling edge only
                audio_lrclk_div <= audio_lrclk_div + 1;
                if(audio_lrclk_div == AUDIO_BITS_PER_SAMPLE - 1) begin
                    audio_lrclk_div <= 0;
                    audio_lr_clock <= ~audio_lr_clock;
                end
            end
        end
    end
*/

// --- Data output selection
`ifdef COMMENTED_OUT
reg fetch_next_sample;
reg double_fetch;
reg [AUDIO_BITS_PER_SAMPLE-1:0] sample_buf;
reg audio_data_out;

wire bitclk_fall = (audio_bitclk_div == AUDIO_BIT_CLOCK_DELAY - 1) && audio_bit_clock;
wire lrclk_fall = bitclk_fall && (audio_lrclk_div == AUDIO_BITS_PER_SAMPLE - 1) && audio_lr_clock;

wire [$clog2(FIFO_DEPTH):0] samples_available;
wire [AUDIO_BITS_PER_SAMPLE-1:0] fifo_data_out;

always @(posedge AUDIOCLK) begin
    // we get new samples when LR clock transitions low
    // that is the beginning of the last right channel bit
    // and the first left channel bit begins one clock later

    fetch_next_sample <= 1'b0;
    if(double_fetch) begin
        // remove a fifo element but data is not latched
        fetch_next_sample <= 1'b1; 
        double_fetch <= 1'b0;
    end

    if( lrclk_fall ) begin
        if(samples_available > SKIP_THRESH) begin
            // too many samples from SNES, so we skip one by double-triggering the RdEn
            fetch_next_sample <= 1'b1;
            double_fetch <= 1'b1;
        end else if(samples_available >= INSERT_THRESH) begin
            fetch_next_sample <= 1'b1;
        end
        // if too few samples available, we insert by not triggering RdEn, making us
        // send the same sample twice in a row
        sample_buf <= fifo_data_out;
    end

    if( bitclk_fall ) begin
        // set output bit and shift 
        audio_data_out <= sample_buf[AUDIO_BITS_PER_SAMPLE-1];
        if(~lrclk_fall)
            sample_buf <= {sample_buf[AUDIO_BITS_PER_SAMPLE-2:0], 1'b0};
    end
end

// --- output enable state machine
localparam  AUDIO_OUT_DISABLED = 1'b0,
            AUDIO_OUT_ENABLED = 1'b1;

reg audio_out_state;
reg [7:0] missed_sample_count;
always @(posedge AUDIOCLK) begin
    if(!RESETN) begin
        audio_out_state <= AUDIO_OUT_DISABLED;
        missed_sample_count <= 8'd0;
    end else begin
        case(audio_out_state)
        AUDIO_OUT_DISABLED: begin
            if(samples_available > AUDIO_ENABLE_THRESH) begin
                audio_out_state <= AUDIO_OUT_ENABLED;
                missed_sample_count <= 8'd0;
            end
        end
        AUDIO_OUT_ENABLED: begin
            if(lrclk_fall) begin
                if (samples_available < INSERT_THRESH) begin
                    missed_sample_count <= missed_sample_count + 1;
                end else begin
                    missed_sample_count <= 0;
                end
            end
            if(missed_sample_count > AUDIO_DISABLE_THRESH) begin
                audio_out_state <= AUDIO_OUT_DISABLED;
            end
        end
        endcase
    end
end



wire [16:0] audio_sum = LEFT_SAMPLE_IN + RIGHT_SAMPLE_IN;
wire [15:0] combined_audio_sample_in = audio_sum[16:1]; // L+R / 2

gowin_fifo_audio u_audio(
    .Reset(~RESETN), //input Reset

    .WrClk(MCLK), //input WrClk
    .WrEn(AUDIO_SAMPLE_READY), //input WrEn
    .Data(combined_audio_sample_in), //input [15:0] Data

    .RdClk(AUDIOCLK), //input RdClk
    .RdEn(fetch_next_sample && audio_out_state), //input RdEn
    .Rnum(samples_available), //output [6:0] Rnum
    .Q(fifo_data_out), //output [15:0] Q
    .Empty(), //output Empty
    .Full() //output Full
);

assign PA_EN = audio_out_state;
assign I2S_BCLK = audio_bit_clock;
assign I2S_LRCLK = audio_lr_clock;
assign I2S_DOUT = audio_data_out;

`endif 
assign PA_EN = 1;
assign I2S_BCLK = audio_bit_clock;
assign I2S_LRCLK = AUDIOCLK;
assign I2S_DOUT = audio_data_out;

endmodule
