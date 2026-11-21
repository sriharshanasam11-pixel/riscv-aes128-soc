// ============================================================================
// File: soc_top.v
// Description: Top-Level System-on-Chip (SoC) Integration
// Subsystems:
//   1. RISC-V RV32I Processor Core
//   2. Synchronous Crossbar Bus Interconnect
//   3. 16 KB Instruction ROM
//   4. 16 KB Data SRAM
//   5. Universal Asynchronous Receiver/Transmitter (UART)
//   6. 32-Bit System Timer
//   7. 32-Bit General-Purpose Input/Output (GPIO)
//   8. AES-128 Encryption/Decryption Accelerator (Custom IP)
//   9. Hardware Pseudo-Random Number Generator (PRNG, Custom IP)
//  10. Serial Peripheral Interface (SPI Master, Integrated IP)
// ============================================================================

`timescale 1ns / 1ps

module soc_top #(
    parameter BOOT_HEX_FILE = "rom.hex"
)(
    input  wire        clk,
    input  wire        rst_n,

    // External UART Interface
    output wire        uart_tx,
    input  wire        uart_rx,

    // External GPIO Pins
    input  wire [31:0] gpio_in,
    output wire [31:0] gpio_out,
    output wire [31:0] gpio_dir,

    // External SPI Interface
    output wire        spi_sck,
    output wire        spi_mosi,
    input  wire        spi_miso,
    output wire        spi_cs_n
);

    // ========================================================================
    // CPU Master Wishbone Bus
    // ========================================================================
    wire [31:0] cpu_wb_adr;
    wire [31:0] cpu_wb_dat_m;
    wire [31:0] cpu_wb_dat_s;
    wire [3:0]  cpu_wb_sel;
    wire        cpu_wb_we;
    wire        cpu_wb_cyc;
    wire        cpu_wb_stb;
    wire        cpu_wb_ack;

    // Interrupt signals
    wire uart_irq;
    wire timer_irq;
    wire aes_irq;
    wire combined_irq = uart_irq || timer_irq || aes_irq;

    // ========================================================================
    // CPU Core Instance
    // ========================================================================
    riscv_core u_riscv_core (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_adr_o (cpu_wb_adr),
        .wb_dat_o (cpu_wb_dat_m),
        .wb_sel_o (cpu_wb_sel),
        .wb_we_o  (cpu_wb_we),
        .wb_cyc_o (cpu_wb_cyc),
        .wb_stb_o (cpu_wb_stb),
        .wb_dat_i (cpu_wb_dat_s),
        .wb_ack_i (cpu_wb_ack),
        .irq_i    (combined_irq)
    );

    // ========================================================================
    // Slave Wishbone Interconnect Buses
    // ========================================================================
    // Slave 0: ROM
    wire [31:0] s0_adr, s0_dat_m, s0_dat_s;
    wire [3:0]  s0_sel;
    wire        s0_we, s0_cyc, s0_stb, s0_ack;

    // Slave 1: RAM
    wire [31:0] s1_adr, s1_dat_m, s1_dat_s;
    wire [3:0]  s1_sel;
    wire        s1_we, s1_cyc, s1_stb, s1_ack;

    // Slave 2: UART
    wire [7:0]  s2_adr;
    wire [31:0] s2_dat_m, s2_dat_s;
    wire [3:0]  s2_sel;
    wire        s2_we, s2_cyc, s2_stb, s2_ack;

    // Slave 3: Timer
    wire [7:0]  s3_adr;
    wire [31:0] s3_dat_m, s3_dat_s;
    wire [3:0]  s3_sel;
    wire        s3_we, s3_cyc, s3_stb, s3_ack;

    // Slave 4: GPIO
    wire [7:0]  s4_adr;
    wire [31:0] s4_dat_m, s4_dat_s;
    wire [3:0]  s4_sel;
    wire        s4_we, s4_cyc, s4_stb, s4_ack;

    // Slave 5: AES Accelerator
    wire [7:0]  s5_adr;
    wire [31:0] s5_dat_m, s5_dat_s;
    wire [3:0]  s5_sel;
    wire        s5_we, s5_cyc, s5_stb, s5_ack;

    // Slave 6: PRNG
    wire [7:0]  s6_adr;
    wire [31:0] s6_dat_m, s6_dat_s;
    wire [3:0]  s6_sel;
    wire        s6_we, s6_cyc, s6_stb, s6_ack;

    // Slave 7: SPI Controller
    wire [7:0]  s7_adr;
    wire [31:0] s7_dat_m, s7_dat_s;
    wire [3:0]  s7_sel;
    wire        s7_we, s7_cyc, s7_stb, s7_ack;

    // ========================================================================
    // Bus Interconnect Instance
    // ========================================================================
    bus_interconnect u_bus (
        .clk      (clk),
        .rst_n    (rst_n),

        // Master
        .m_adr_i  (cpu_wb_adr),
        .m_dat_i  (cpu_wb_dat_m),
        .m_sel_i  (cpu_wb_sel),
        .m_we_i   (cpu_wb_we),
        .m_cyc_i  (cpu_wb_cyc),
        .m_stb_i  (cpu_wb_stb),
        .m_dat_o  (cpu_wb_dat_s),
        .m_ack_o  (cpu_wb_ack),

        // Slaves
        .s0_adr_o (s0_adr), .s0_dat_o (s0_dat_m), .s0_sel_o (s0_sel), .s0_we_o (s0_we), .s0_cyc_o (s0_cyc), .s0_stb_o (s0_stb), .s0_dat_i (s0_dat_s), .s0_ack_i (s0_ack),
        .s1_adr_o (s1_adr), .s1_dat_o (s1_dat_m), .s1_sel_o (s1_sel), .s1_we_o (s1_we), .s1_cyc_o (s1_cyc), .s1_stb_o (s1_stb), .s1_dat_i (s1_dat_s), .s1_ack_i (s1_ack),
        .s2_adr_o (s2_adr), .s2_dat_o (s2_dat_m), .s2_sel_o (s2_sel), .s2_we_o (s2_we), .s2_cyc_o (s2_cyc), .s2_stb_o (s2_stb), .s2_dat_i (s2_dat_s), .s2_ack_i (s2_ack),
        .s3_adr_o (s3_adr), .s3_dat_o (s3_dat_m), .s3_sel_o (s3_sel), .s3_we_o (s3_we), .s3_cyc_o (s3_cyc), .s3_stb_o (s3_stb), .s3_dat_i (s3_dat_s), .s3_ack_i (s3_ack),
        .s4_adr_o (s4_adr), .s4_dat_o (s4_dat_m), .s4_sel_o (s4_sel), .s4_we_o (s4_we), .s4_cyc_o (s4_cyc), .s4_stb_o (s4_stb), .s4_dat_i (s4_dat_s), .s4_ack_i (s4_ack),
        .s5_adr_o (s5_adr), .s5_dat_o (s5_dat_m), .s5_sel_o (s5_sel), .s5_we_o (s5_we), .s5_cyc_o (s5_cyc), .s5_stb_o (s5_stb), .s5_dat_i (s5_dat_s), .s5_ack_i (s5_ack),
        .s6_adr_o (s6_adr), .s6_dat_o (s6_dat_m), .s6_sel_o (s6_sel), .s6_we_o (s6_we), .s6_cyc_o (s6_cyc), .s6_stb_o (s6_stb), .s6_dat_i (s6_dat_s), .s6_ack_i (s6_ack),
        .s7_adr_o (s7_adr), .s7_dat_o (s7_dat_m), .s7_sel_o (s7_sel), .s7_we_o (s7_we), .s7_cyc_o (s7_cyc), .s7_stb_o (s7_stb), .s7_dat_i (s7_dat_s), .s7_ack_i (s7_ack)
    );

    // ========================================================================
    // Slave 0: Instruction ROM (16 KB)
    // ========================================================================
    rom_imem #(
        .MEM_SIZE_WORDS (4096),
        .INIT_FILE      (BOOT_HEX_FILE)
    ) u_rom (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_cyc_i (s0_cyc),
        .wb_stb_i (s0_stb),
        .wb_we_i  (s0_we),
        .wb_adr_i (s0_adr),
        .wb_dat_i (s0_dat_m),
        .wb_sel_i (s0_sel),
        .wb_dat_o (s0_dat_s),
        .wb_ack_o (s0_ack)
    );

    // ========================================================================
    // Slave 1: Data RAM (16 KB)
    // ========================================================================
    ram_dmem #(
        .MEM_SIZE_WORDS (4096)
    ) u_ram (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_cyc_i (s1_cyc),
        .wb_stb_i (s1_stb),
        .wb_we_i  (s1_we),
        .wb_adr_i (s1_adr),
        .wb_dat_i (s1_dat_m),
        .wb_sel_i (s1_sel),
        .wb_dat_o (s1_dat_s),
        .wb_ack_o (s1_ack)
    );

    // ========================================================================
    // Slave 2: UART Controller
    // ========================================================================
    uart u_uart (
        .clk       (clk),
        .rst_n     (rst_n),
        .wb_cyc_i  (s2_cyc),
        .wb_stb_i  (s2_stb),
        .wb_we_i   (s2_we),
        .wb_adr_i  (s2_adr),
        .wb_dat_i  (s2_dat_m),
        .wb_sel_i  (s2_sel),
        .wb_dat_o  (s2_dat_s),
        .wb_ack_o  (s2_ack),
        .uart_tx_o (uart_tx),
        .uart_rx_i (uart_rx),
        .irq_o     (uart_irq)
    );

    // ========================================================================
    // Slave 3: 32-Bit System Timer
    // ========================================================================
    timer u_timer (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_cyc_i (s3_cyc),
        .wb_stb_i (s3_stb),
        .wb_we_i  (s3_we),
        .wb_adr_i (s3_adr),
        .wb_dat_i (s3_dat_m),
        .wb_sel_i (s3_sel),
        .wb_dat_o (s3_dat_s),
        .wb_ack_o (s3_ack),
        .irq_o    (timer_irq)
    );

    // ========================================================================
    // Slave 4: 32-Bit GPIO Controller
    // ========================================================================
    gpio u_gpio (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_cyc_i (s4_cyc),
        .wb_stb_i (s4_stb),
        .wb_we_i  (s4_we),
        .wb_adr_i (s4_adr),
        .wb_dat_i (s4_dat_m),
        .wb_sel_i (s4_sel),
        .wb_dat_o (s4_dat_s),
        .wb_ack_o (s4_ack),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out),
        .gpio_dir (gpio_dir)
    );

    // ========================================================================
    // Slave 5: AES-128 Encryption/Decryption Accelerator (Custom IP)
    // ========================================================================
    aes_accelerator u_aes (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_cyc_i (s5_cyc),
        .wb_stb_i (s5_stb),
        .wb_we_i  (s5_we),
        .wb_adr_i (s5_adr),
        .wb_dat_i (s5_dat_m),
        .wb_sel_i (s5_sel),
        .wb_dat_o (s5_dat_s),
        .wb_ack_o (s5_ack),
        .irq_o    (aes_irq)
    );

    // ========================================================================
    // Slave 6: Hardware PRNG (Custom IP)
    // ========================================================================
    prng u_prng (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_cyc_i (s6_cyc),
        .wb_stb_i (s6_stb),
        .wb_we_i  (s6_we),
        .wb_adr_i (s6_adr),
        .wb_dat_i (s6_dat_m),
        .wb_sel_i (s6_sel),
        .wb_dat_o (s6_dat_s),
        .wb_ack_o (s6_ack)
    );

    // ========================================================================
    // Slave 7: SPI Master Controller (Integrated IP)
    // ========================================================================
    spi_controller u_spi (
        .clk        (clk),
        .rst_n      (rst_n),
        .wb_cyc_i   (s7_cyc),
        .wb_stb_i   (s7_stb),
        .wb_we_i    (s7_we),
        .wb_adr_i   (s7_adr),
        .wb_dat_i   (s7_dat_m),
        .wb_sel_i   (s7_sel),
        .wb_dat_o   (s7_dat_s),
        .wb_ack_o   (s7_ack),
        .spi_sck_o  (spi_sck),
        .spi_mosi_o (spi_mosi),
        .spi_miso_i (spi_miso),
        .spi_cs_n_o (spi_cs_n)
    );

endmodule
