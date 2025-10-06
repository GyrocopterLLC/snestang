/*
 * bsram_interface
 * Accesses the BSRAM through the "RV" port on the SDRAM
 * Used to load or save the battery backed RAM to an SD card
 *
 * External processor sends UART commands to start reading or writing
 * the BSRAM.
 * Any kind of physical storage is taken care of by the external processor,
 * this module just gets or returns bytes from the proper SDRAM addresses.
 */

module bsram_interface
(
    input             CLK,
    input             RESETN,
    // input [3:0]       RAM_SIZE, // Maximum value is usually 0x07 which means 1MB of RAM
                                // Although in reality not usually larger than 256kB (0x05)

    // Processor port
    input             START_READ,
    input     [10:0]  BSRAM_BLOCK_NUM, // reads/writes are in 512 Byte blocks, up to 1MB
    output     [7:0]  DATA_OUT, 
    output            DATA_OUT_READY,
    input             DATA_OUT_ACK,
    input             START_WRITE,
    input      [7:0]  DATA_IN,
    input             DATA_IN_READY,
    output            DATA_IN_ACK, // probably unnecessary since we can load much faster than UART sends

    // SDRAM port
    output     [22:1] RV_ADDR,      // 8MB RV memory space (top 1MB is for BSRAM)    
    output     [15:0] RV_DIN,       // 16-bit accesses
    output     [1:0]  RV_DS,
    input      [15:0] RV_DOUT,
    output            RV_REQ,
    input             RV_REQ_ACK,   // ready for new requests. read data available on NEXT mclk
    output            RV_WE
);

parameter   PACKET_SIZE = 512;
parameter   PACKET_MAX = PACKET_SIZE-2;

// generate all 1's for the highest possible RAM address based on input size
// wire [6:0] upper_ram_limit = {{(7-RAM_SIZE[2:0]){1'b0}}, {(RAM_SIZE[2:0]){1'b1}}};
// wire [19:0] bsram_max_addr = RAM_SIZE == 0 ? 0 : {upper_ram_limit, 13'b0};

// Read / Write state machine, states and signals
localparam  BI_IDLE = 3'd0;
localparam  BI_START_READ = 3'd1;
localparam  BI_READING = 3'd2;
localparam  BI_READ_DATA0 = 3'd3;
localparam  BI_READ_DATA1 = 3'd4;
// localparam   BI_START_WRITE = 3'd4;
// localparam   BI_WRITING = 3'd5;
// localparam   BI_DONE_WRITE = 3'd6;
// localparam   BI_ERROR = 3'd7;
reg  [2:0]  state;
reg  [8:0]  bsram_count; // which byte are we on?
wire [19:0] read_addr = {BSRAM_BLOCK_NUM, bsram_count};
reg         rv_req; // not sent out directly, goes to sdram state machine
reg         rv_we;
reg         data_out_ready;
reg  [7:0]  data_out;

// SDRAM interface state machine
localparam  RV_IDLE = 3'd0;
localparam  RV_WAIT_ACK = 3'd1;
localparam  RV_WAIT_DATA = 3'd2;
reg  [2:0]  rvst;
reg         rv_req_o;
reg         rv_data_done;
reg [15:0]  data16_out;

always @(posedge CLK or negedge RESETN) begin
    if(~RESETN) begin
        state <= BI_IDLE;
        bsram_count <= 9'd0;
        rv_req <= 1'b0;
        rv_we <= 1'b0;
        data_out_ready <= 1'b0;
    end else begin
        rv_req <= 1'b0;
        rv_we <= 1'b0;
        data_out_ready <= 1'b0;

        case(state)
        BI_IDLE: begin
            if(START_READ) begin
                state <= BI_START_READ;
                // read_addr <= {BSRAM_BLOCK_NUM, 9'b0}; // multiply by 512
                bsram_count <= 9'd0;
            end
        end
        BI_START_READ: begin
            rv_req <= 1'b1;
            rv_we <= 1'b0;
            if(rvst == RV_WAIT_ACK)
                state <= BI_READING;
        end
        BI_READING: begin
            if(rv_data_done) begin
                state <= BI_READ_DATA0;
                data_out <= data16_out[7:0];
                data_out_ready <= 1'b1;
            end
        end
        BI_READ_DATA0: begin
            data_out_ready <= 1'b1;
            if(DATA_OUT_ACK) begin
                state <= BI_READ_DATA1;
                data_out <= data16_out[15:8];
            end
        end
        BI_READ_DATA1: begin
            data_out_ready <= 1'b1;
            if(DATA_OUT_ACK) begin
                data_out_ready <= 1'b0;
                if(bsram_count == (PACKET_MAX[8:0])) begin
                    state <= BI_IDLE;
                end else begin
                    state <= BI_START_READ;
                    bsram_count <= bsram_count + 9'd2;
                end              
            end
        end
        default: state <= BI_IDLE;
        endcase
    end
end


// Figure out when data is ready from the SDRAM interface, or when next write is allowed

always @(posedge CLK or negedge RESETN) begin
    if(~RESETN) begin
        rvst <= RV_IDLE;
        rv_req_o <= 1'b0;
        rv_data_done <= 1'b0;
    end else begin
        rv_data_done <= 1'b0;
        case(rvst) 
        RV_IDLE: begin
            if(rv_req) begin
                rvst <= RV_WAIT_ACK;
                rv_req_o <= 1'b1;
            end
        end
        RV_WAIT_ACK: begin
            if(RV_REQ_ACK) begin
                rv_req_o <= 1'b0;
                if(rv_we) begin
                    rvst <= RV_IDLE;
                end else begin
                    rvst <= RV_WAIT_DATA;
                end
            end
        end
        RV_WAIT_DATA: begin
            rvst <= RV_IDLE;
            data16_out <= RV_DOUT;
            rv_data_done <= 1'b1;
        end
        default: rvst <= RV_IDLE;
        endcase
    end
end


`ifdef OLDSTUFF
wire        rv_valid;
reg         rv_ready;
wire [22:0] rv_addr;
wire [31:0] rv_wdata;
wire [3:0]  rv_wstrb;
reg  [15:0] rv_dout0;
wire [31:0] rv_rdata = {rv_dout, rv_dout0};
reg         rv_valid_r;
reg         rv_word;           // which word
reg         rv_req;
wire        rv_req_ack;
wire [15:0] rv_dout;
reg [1:0]   rv_ds;
reg         rv_new_req;

always @(posedge mclk) begin            // RV
    if (~resetn) begin
        rvst <= RV_IDLE_REQ0;
        rv_ready <= 0;
    end else begin
        reg write = /*rv_wstrb != 0;*/ rv_write;
        reg rv_new_req_t = rv_valid & ~rv_valid_r;
        if (rv_new_req_t) rv_new_req <= 1;

        rv_ready <= 0;
        rv_valid_r <= rv_valid;

        case (rvst)
        RV_IDLE_REQ0: if (rv_new_req || rv_new_req_t) begin
            rv_new_req <= 0;
            rv_req <= ~rv_req;
            if (write && rv_wstrb[1:0] == 2'b0) begin
                // shortcut for only writing the upper word
                rv_word <= 1;
                rv_ds <= rv_wstrb[3:2];
                rvst <= RV_WAIT1;
            end else begin
                rv_word <= 0;
                if (write)
                    rv_ds <= rv_wstrb[1:0];
                else
                    rv_ds <= 2'b11;
                rvst <= RV_WAIT0_REQ1;
            end
        end

        RV_WAIT0_REQ1: begin
            if (rv_req == rv_req_ack) begin
                rv_req <= ~rv_req;      // request 1
                rv_word <= 1;
                if (write) begin
                    rvst <= RV_WAIT1;
                    if (rv_wstrb[3:2] == 2'b0) begin
                        // shortcut for only writing the lower word
                        rv_req <= rv_req;
                        rv_ready <= 1;
                        rvst <= RV_IDLE_REQ0;
                    end
                    rv_ds <= rv_wstrb[3:2];
                end else begin
                    rv_ds <= 2'b11;
                    rvst <= RV_DATA0;
                end
            end
        end

        RV_DATA0: begin
            rv_dout0 <= rv_dout;
            rvst <= RV_WAIT1;
        end
            
        RV_WAIT1: 
            if (rv_req == rv_req_ack) begin
                if (write)  begin
                    rv_ready <= 1;
                    rvst <= RV_IDLE_REQ0;
                end else
                    rvst <= RV_DATA1;
            end

        RV_DATA1: begin
            rv_ready <= 1;
            rvst <= RV_IDLE_REQ0;
        end

        default:;
        endcase
    end
end
`endif

assign DATA_OUT = data_out;
assign DATA_OUT_READY = data_out_ready;
assign RV_ADDR = {3'b111, read_addr[19:1]};
assign RV_DIN = 16'b0;
assign RV_DS = 2'b0; // ????
assign RV_REQ = rv_req_o;
assign RV_WE = 1'b0;

endmodule


