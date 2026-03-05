// Lightweight load/store unit with simple memory and basic I/O mapping.
// Supports byte/half/word accesses, signed or unsigned loads, and memory‑mapped I/O:
//   0x1000_0000 : LEDR
//   0x1000_1000 : LEDG
//   0x1000_2000 : HEX0-HEX3 (one word write latches all)
//   0x1000_3000 : HEX4-HEX7 (one word write latches all)
//   0x1000_4000 : LCD
//   0x1001_0000 : SW (read)
module lsu (
    input  logic        i_clk,
    input  logic        i_reset,       // active-high
    input  logic [31:0] i_lsu_addr,
    input  logic [31:0] i_st_data,
    input  logic        i_lsu_wren,    // store enable
    input  logic [1:0]  i_lsu_size,    // 00:byte, 01:half, 10:word
    input  logic        i_lsu_unsigned,
    input  logic [31:0] i_io_sw,

    output logic [31:0] o_ld_data,
    output logic [31:0] o_io_ledr,
    output logic [31:0] o_io_ledg,
    output logic [31:0] o_io_lcd,
    output logic [6:0]  o_io_hex0, o_io_hex1, o_io_hex2, o_io_hex3,
    output logic [6:0]  o_io_hex4, o_io_hex5, o_io_hex6, o_io_hex7
);

    // Address map
    localparam logic [31:0] ADDR_LED_R  = 32'h1000_0000;
    localparam logic [31:0] ADDR_LED_G  = 32'h1000_1000;
    localparam logic [31:0] ADDR_HEX0_3 = 32'h1000_2000;
    localparam logic [31:0] ADDR_HEX4_7 = 32'h1000_3000;
    localparam logic [31:0] ADDR_LCD    = 32'h1000_4000;
    localparam logic [31:0] ADDR_SW     = 32'h1001_0000;

    // Simple data memory (64KB, word-addressable)
    logic [31:0] data_mem [0:16383];

    // Khởi tạo RAM dữ liệu về 0 để tách biệt với instruction memory
    integer i;
    initial begin
        for (i = 0; i < 16384; i = i + 1) data_mem[i] = 32'b0;
    end

    // Asynchronous read
    logic [31:0] mem_rdata;
    assign mem_rdata = data_mem[i_lsu_addr[15:2]];

    // Byte-enable decode and shifted store data
    logic [3:0]  wmask;
    logic [31:0] st_shifted;
    always_comb begin
        wmask      = 4'b0000;
        st_shifted = i_st_data;
        unique case (i_lsu_size)
            2'b00: begin // byte
                case (i_lsu_addr[1:0])
                    2'b00: begin wmask = 4'b0001; st_shifted = i_st_data;          end
                    2'b01: begin wmask = 4'b0010; st_shifted = i_st_data << 8;    end
                    2'b10: begin wmask = 4'b0100; st_shifted = i_st_data << 16;   end
                    2'b11: begin wmask = 4'b1000; st_shifted = i_st_data << 24;   end
                endcase
            end
            2'b01: begin // half
                if (i_lsu_addr[1] == 1'b0) begin
                    wmask      = 4'b0011;
                    st_shifted = i_st_data;
                end else begin
                    wmask      = 4'b1100;
                    st_shifted = i_st_data << 16;
                end
            end
            default: begin // word
                wmask      = 4'b1111;
                st_shifted = i_st_data;
            end
        endcase
    end

    // Memory and I/O writes
    always_ff @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            o_io_ledr <= 32'b0;
            o_io_ledg <= 32'b0;
            o_io_lcd  <= 32'b0;
            o_io_hex0 <= 7'b0; o_io_hex1 <= 7'b0; o_io_hex2 <= 7'b0; o_io_hex3 <= 7'b0;
            o_io_hex4 <= 7'b0; o_io_hex5 <= 7'b0; o_io_hex6 <= 7'b0; o_io_hex7 <= 7'b0;
        end else if (i_lsu_wren) begin
            if (i_lsu_addr < 32'h0001_0000) begin
                // Data memory region
                if (wmask[0]) data_mem[i_lsu_addr[15:2]][7:0]   <= st_shifted[7:0];
                if (wmask[1]) data_mem[i_lsu_addr[15:2]][15:8]  <= st_shifted[15:8];
                if (wmask[2]) data_mem[i_lsu_addr[15:2]][23:16] <= st_shifted[23:16];
                if (wmask[3]) data_mem[i_lsu_addr[15:2]][31:24] <= st_shifted[31:24];
            end else begin
                // Memory-mapped outputs
                case (i_lsu_addr)
                    ADDR_LED_R:  o_io_ledr <= i_st_data;
                    ADDR_LED_G:  o_io_ledg <= i_st_data;
                    ADDR_HEX0_3: begin
                        o_io_hex0 <= i_st_data[6:0];
                        o_io_hex1 <= i_st_data[14:8];
                        o_io_hex2 <= i_st_data[22:16];
                        o_io_hex3 <= i_st_data[30:24];
                    end
                    ADDR_HEX4_7: begin
                        o_io_hex4 <= i_st_data[6:0];
                        o_io_hex5 <= i_st_data[14:8];
                        o_io_hex6 <= i_st_data[22:16];
                        o_io_hex7 <= i_st_data[30:24];
                    end
                    ADDR_LCD:    o_io_lcd  <= i_st_data;
                    default: ; // ignore unmapped stores
                endcase
            end
        end
    end

    // Load data alignment and sign/zero extension
    logic [7:0]  ld_byte;
    logic [15:0] ld_half;
    always_comb begin
        case (i_lsu_addr[1:0])
            2'b00: ld_byte = mem_rdata[7:0];
            2'b01: ld_byte = mem_rdata[15:8];
            2'b10: ld_byte = mem_rdata[23:16];
            default: ld_byte = mem_rdata[31:24];
        endcase
        ld_half = (i_lsu_addr[1] == 1'b0) ? mem_rdata[15:0] : mem_rdata[31:16];
    end

    always_comb begin
        if (i_lsu_addr == ADDR_SW) begin
            o_ld_data = i_io_sw;
        end else if (i_lsu_addr < 32'h0001_0000) begin
            unique case (i_lsu_size)
                2'b00: o_ld_data = i_lsu_unsigned ? {24'b0, ld_byte}  : {{24{ld_byte[7]}}, ld_byte};
                2'b01: o_ld_data = i_lsu_unsigned ? {16'b0, ld_half}  : {{16{ld_half[15]}}, ld_half};
                default: o_ld_data = mem_rdata;
            endcase
        end else begin
            o_ld_data = 32'hdeadbeef; // unmapped region
        end
    end

endmodule
