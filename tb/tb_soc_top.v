// ============================================================================
// File: tb_soc_top.v
// Description: Full-Chip SoC Integration Testbench
// Exercises RISC-V CPU, Bus Interconnect, Memories, and All 6 IP Peripherals
// ============================================================================

`timescale 1ns / 1ps

module tb_soc_top;

    reg         clk;
    reg         rst_n;
    wire        uart_tx;
    reg         uart_rx;
    reg  [31:0] gpio_in;
    wire [31:0] gpio_out;
    wire [31:0] gpio_dir;
    wire        spi_sck;
    wire        spi_mosi;
    wire        spi_miso;
    wire        spi_cs_n;

    // Loopback SPI MOSI to MISO
    assign spi_miso = spi_mosi;

    // Instantiate Full SoC
    soc_top #(
        .BOOT_HEX_FILE ("rom.hex")
    ) u_soc (
        .clk      (clk),
        .rst_n    (rst_n),
        .uart_tx  (uart_tx),
        .uart_rx  (uart_rx),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out),
        .gpio_dir (gpio_dir),
        .spi_sck  (spi_sck),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso),
        .spi_cs_n (spi_cs_n)
    );

    // 50 MHz System Clock (20ns period)
    always #10 clk = ~clk;

    // UART Output Monitor: directly decodes characters when written into UART register
    always @(posedge clk) begin
        if (rst_n && u_soc.u_bus.sel_uart && u_soc.u_bus.s2_we_o && u_soc.u_bus.s2_stb_o && (u_soc.u_bus.s2_adr_o == 8'h00)) begin
            $write("%c", u_soc.u_bus.s2_dat_o[7:0]);
        end
    end

    // Simulation Execution Control
    integer cycles;
    initial begin
        $display("=================================================================");
        $display("   SYSTEM-ON-CHIP INTEGRATION SIMULATION: RISC-V + AES-128 SoC   ");
        $display("=================================================================");

        clk     = 0;
        rst_n   = 0;
        uart_rx = 1;
        gpio_in = 32'h0;
        cycles  = 0;

        // Apply Reset
        $dumpfile("soc_top_full.vcd");
        $dumpvars(0, tb_soc_top);
        #60;
        rst_n = 1;
        $display("[TB] SoC Reset released. CPU starting execution at PC 0x00000000...\n");

        // Wait for execution completion
        for (cycles = 0; cycles < 10000; cycles = cycles + 1) begin
            @(posedge clk);

            // Check if GPIO Pin 1 is set high (PASS signal from software)
            if (gpio_out[1]) begin
                #100;
                $display("\n=================================================================");
                $display("   [SUCCESS] FULL-CHIP SOC TEST PASSED!                         ");
                $display("   Total Simulation Cycles: %0d                                 ", cycles);
                $display("   AES-128 Encryption & Decryption Verified via RISC-V Firmware ");
                $display("=================================================================");
                $finish;
            end

            // Check if GPIO Pin 2 is set high (FAIL signal from software)
            if (gpio_out[2]) begin
                #100;
                $fatal(1, "\n[FATAL] SoC Firmware asserted GPIO Fail Pin 2!");
            end
        end

        $fatal(1, "\n[TIMEOUT] Simulation timed out after 10000 cycles!");
    end

endmodule
