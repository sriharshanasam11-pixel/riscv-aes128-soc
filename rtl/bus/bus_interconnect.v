// ============================================================================
// File: bus_interconnect.v
// Description: Synchronous Memory-Mapped Crossbar Interconnect & Address Decoder
// Connects 1 Wishbone Master to 8 Wishbone Slaves (ROM, RAM, UART, Timer, GPIO,
// AES-128 Accelerator, PRNG, and SPI Controller)
// ============================================================================

`timescale 1ns / 1ps

module bus_interconnect (
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone Master Interface (CPU)
    input  wire [31:0] m_adr_i,
    input  wire [31:0] m_dat_i,
    input  wire [3:0]  m_sel_i,
    input  wire        m_we_i,
    input  wire        m_cyc_i,
    input  wire        m_stb_i,
    output reg  [31:0] m_dat_o,
    output reg         m_ack_o,

    // Slave 0: ROM (0x0000_0000 - 0x0000_3FFF)
    output wire [31:0] s0_adr_o,
    output wire [31:0] s0_dat_o,
    output wire [3:0]  s0_sel_o,
    output wire        s0_we_o,
    output wire        s0_cyc_o,
    output wire        s0_stb_o,
    input  wire [31:0] s0_dat_i,
    input  wire        s0_ack_i,

    // Slave 1: RAM (0x2000_0000 - 0x2000_3FFF)
    output wire [31:0] s1_adr_o,
    output wire [31:0] s1_dat_o,
    output wire [3:0]  s1_sel_o,
    output wire        s1_we_o,
    output wire        s1_cyc_o,
    output wire        s1_stb_o,
    input  wire [31:0] s1_dat_i,
    input  wire        s1_ack_i,

    // Slave 2: UART (0x4000_0000 - 0x4000_00FF)
    output wire [7:0]  s2_adr_o,
    output wire [31:0] s2_dat_o,
    output wire [3:0]  s2_sel_o,
    output wire        s2_we_o,
    output wire        s2_cyc_o,
    output wire        s2_stb_o,
    input  wire [31:0] s2_dat_i,
    input  wire        s2_ack_i,

    // Slave 3: Timer (0x4000_1000 - 0x4000_10FF)
    output wire [7:0]  s3_adr_o,
    output wire [31:0] s3_dat_o,
    output wire [3:0]  s3_sel_o,
    output wire        s3_we_o,
    output wire        s3_cyc_o,
    output wire        s3_stb_o,
    input  wire [31:0] s3_dat_i,
    input  wire        s3_ack_i,

    // Slave 4: GPIO (0x4000_2000 - 0x4000_20FF)
    output wire [7:0]  s4_adr_o,
    output wire [31:0] s4_dat_o,
    output wire [3:0]  s4_sel_o,
    output wire        s4_we_o,
    output wire        s4_cyc_o,
    output wire        s4_stb_o,
    input  wire [31:0] s4_dat_i,
    input  wire        s4_ack_i,

    // Slave 5: AES Accelerator (0x4000_3000 - 0x4000_30FF)
    output wire [7:0]  s5_adr_o,
    output wire [31:0] s5_dat_o,
    output wire [3:0]  s5_sel_o,
    output wire        s5_we_o,
    output wire        s5_cyc_o,
    output wire        s5_stb_o,
    input  wire [31:0] s5_dat_i,
    input  wire        s5_ack_i,

    // Slave 6: PRNG (0x4000_4000 - 0x4000_40FF)
    output wire [7:0]  s6_adr_o,
    output wire [31:0] s6_dat_o,
    output wire [3:0]  s6_sel_o,
    output wire        s6_we_o,
    output wire        s6_cyc_o,
    output wire        s6_stb_o,
    input  wire [31:0] s6_dat_i,
    input  wire        s6_ack_i,

    // Slave 7: SPI Controller (0x4000_5000 - 0x4000_50FF)
    output wire [7:0]  s7_adr_o,
    output wire [31:0] s7_dat_o,
    output wire [3:0]  s7_sel_o,
    output wire        s7_we_o,
    output wire        s7_cyc_o,
    output wire        s7_stb_o,
    input  wire [31:0] s7_dat_i,
    input  wire        s7_ack_i
);

    // Address Decoding
    wire sel_rom   = (m_adr_i[31:16] == 16'h0000);
    wire sel_ram   = (m_adr_i[31:16] == 16'h2000);
    wire sel_periph= (m_adr_i[31:16] == 16'h4000);
    wire sel_uart  = sel_periph && (m_adr_i[15:8] == 8'h00);
    wire sel_timer = sel_periph && (m_adr_i[15:8] == 8'h10);
    wire sel_gpio  = sel_periph && (m_adr_i[15:8] == 8'h20);
    wire sel_aes   = sel_periph && (m_adr_i[15:8] == 8'h30);
    wire sel_prng  = sel_periph && (m_adr_i[15:8] == 8'h40);
    wire sel_spi   = sel_periph && (m_adr_i[15:8] == 8'h50);

    wire unmapped  = m_cyc_i && m_stb_i && !(sel_rom || sel_ram || sel_uart || 
                                             sel_timer || sel_gpio || sel_aes || 
                                             sel_prng || sel_spi);

    // Common Master Bus Broadcast
    assign s0_adr_o = m_adr_i;
    assign s0_dat_o = m_dat_i;
    assign s0_sel_o = m_sel_i;
    assign s0_we_o  = m_we_i;
    assign s0_cyc_o = m_cyc_i && sel_rom;
    assign s0_stb_o = m_stb_i && sel_rom;

    assign s1_adr_o = m_adr_i;
    assign s1_dat_o = m_dat_i;
    assign s1_sel_o = m_sel_i;
    assign s1_we_o  = m_we_i;
    assign s1_cyc_o = m_cyc_i && sel_ram;
    assign s1_stb_o = m_stb_i && sel_ram;

    assign s2_adr_o = m_adr_i[7:0];
    assign s2_dat_o = m_dat_i;
    assign s2_sel_o = m_sel_i;
    assign s2_we_o  = m_we_i;
    assign s2_cyc_o = m_cyc_i && sel_uart;
    assign s2_stb_o = m_stb_i && sel_uart;

    assign s3_adr_o = m_adr_i[7:0];
    assign s3_dat_o = m_dat_i;
    assign s3_sel_o = m_sel_i;
    assign s3_we_o  = m_we_i;
    assign s3_cyc_o = m_cyc_i && sel_timer;
    assign s3_stb_o = m_stb_i && sel_timer;

    assign s4_adr_o = m_adr_i[7:0];
    assign s4_dat_o = m_dat_i;
    assign s4_sel_o = m_sel_i;
    assign s4_we_o  = m_we_i;
    assign s4_cyc_o = m_cyc_i && sel_gpio;
    assign s4_stb_o = m_stb_i && sel_gpio;

    assign s5_adr_o = m_adr_i[7:0];
    assign s5_dat_o = m_dat_i;
    assign s5_sel_o = m_sel_i;
    assign s5_we_o  = m_we_i;
    assign s5_cyc_o = m_cyc_i && sel_aes;
    assign s5_stb_o = m_stb_i && sel_aes;

    assign s6_adr_o = m_adr_i[7:0];
    assign s6_dat_o = m_dat_i;
    assign s6_sel_o = m_sel_i;
    assign s6_we_o  = m_we_i;
    assign s6_cyc_o = m_cyc_i && sel_prng;
    assign s6_stb_o = m_stb_i && sel_prng;

    assign s7_adr_o = m_adr_i[7:0];
    assign s7_dat_o = m_dat_i;
    assign s7_sel_o = m_sel_i;
    assign s7_we_o  = m_we_i;
    assign s7_cyc_o = m_cyc_i && sel_spi;
    assign s7_stb_o = m_stb_i && sel_spi;

    // Unmapped address single-cycle termination
    reg unmapped_ack;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) unmapped_ack <= 1'b0;
        else unmapped_ack <= unmapped && !unmapped_ack;
    end

    // Master Read Multiplexer
    always @(*) begin
        if (sel_rom)        m_dat_o = s0_dat_i;
        else if (sel_ram)   m_dat_o = s1_dat_i;
        else if (sel_uart)  m_dat_o = s2_dat_i;
        else if (sel_timer) m_dat_o = s3_dat_i;
        else if (sel_gpio)  m_dat_o = s4_dat_i;
        else if (sel_aes)   m_dat_o = s5_dat_i;
        else if (sel_prng)  m_dat_o = s6_dat_i;
        else if (sel_spi)   m_dat_o = s7_dat_i;
        else                m_dat_o = 32'hDEAD_BEEF;
    end

    // Master ACK Multiplexer
    always @(*) begin
        if (sel_rom)        m_ack_o = s0_ack_i;
        else if (sel_ram)   m_ack_o = s1_ack_i;
        else if (sel_uart)  m_ack_o = s2_ack_i;
        else if (sel_timer) m_ack_o = s3_ack_i;
        else if (sel_gpio)  m_ack_o = s4_ack_i;
        else if (sel_aes)   m_ack_o = s5_ack_i;
        else if (sel_prng)  m_ack_o = s6_ack_i;
        else if (sel_spi)   m_ack_o = s7_ack_i;
        else                m_ack_o = unmapped_ack;
    end

endmodule
