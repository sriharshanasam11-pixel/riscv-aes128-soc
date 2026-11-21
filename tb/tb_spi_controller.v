// ============================================================================
// File: tb_spi_controller.v
// Description: Unit Testbench for SPI Master Controller IP
// ============================================================================

`timescale 1ns / 1ps

module tb_spi_controller;

    reg         clk;
    reg         rst_n;
    reg         wb_cyc_i;
    reg         wb_stb_i;
    reg         wb_we_i;
    reg  [7:0]  wb_adr_i;
    reg  [31:0] wb_dat_i;
    reg  [3:0]  wb_sel_i;
    wire [31:0] wb_dat_o;
    wire        wb_ack_o;

    wire        spi_sck;
    wire        spi_mosi;
    reg         spi_miso;
    wire        spi_cs_n;

    spi_controller dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .wb_cyc_i   (wb_cyc_i),
        .wb_stb_i   (wb_stb_i),
        .wb_we_i    (wb_we_i),
        .wb_adr_i   (wb_adr_i),
        .wb_dat_i   (wb_dat_i),
        .wb_sel_i   (wb_sel_i),
        .wb_dat_o   (wb_dat_o),
        .wb_ack_o   (wb_ack_o),
        .spi_sck_o  (spi_sck),
        .spi_mosi_o (spi_mosi),
        .spi_miso_i (spi_miso),
        .spi_cs_n_o (spi_cs_n)
    );

    always #10 clk = ~clk;

    // Loopback MOSI to MISO
    always @(*) spi_miso = spi_mosi;

    task wb_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            wb_adr_i <= addr;
            wb_dat_i <= data;
            wb_we_i  <= 1'b1;
            wb_cyc_i <= 1'b1;
            wb_stb_i <= 1'b1;
            wb_sel_i <= 4'b1111;
            @(posedge clk);
            while (!wb_ack_o) @(posedge clk);
            wb_cyc_i <= 1'b0;
            wb_stb_i <= 1'b0;
            wb_we_i  <= 1'b0;
        end
    endtask

    task wb_read(input [7:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            wb_adr_i <= addr;
            wb_we_i  <= 1'b0;
            wb_cyc_i <= 1'b1;
            wb_stb_i <= 1'b1;
            wb_sel_i <= 4'b1111;
            @(posedge clk);
            while (!wb_ack_o) @(posedge clk);
            data = wb_dat_o;
            wb_cyc_i <= 1'b0;
            wb_stb_i <= 1'b0;
        end
    endtask

    reg [31:0] rdata;

    initial begin
        $display("=========================================================");
        $display("   TESTBENCH: SPI Master Controller IP                   ");
        $display("=========================================================");

        clk = 0; rst_n = 0;
        wb_cyc_i = 0; wb_stb_i = 0; wb_we_i = 0;
        wb_adr_i = 0; wb_dat_i = 0; wb_sel_i = 0;

        $dumpfile("spi_controller.vcd");
        $dumpvars(0, tb_spi_controller);

        #40;
        rst_n = 1;
        #20;

        // Set fast clock divider
        wb_write(8'h0C, 32'h00000002);
        // Assert CS_N (0)
        wb_write(8'h08, 32'h00000000);

        // Transmit test byte 0xA5
        $display("[INFO] Transmitting byte 0xA5 over SPI...");
        wb_write(8'h00, 32'h000000A5);

        // Wait until transfer completes
        rdata = 1;
        while (rdata & 32'h1) begin
            wb_read(8'h04, rdata);
        end

        // Read received byte via loopback
        wb_read(8'h00, rdata);
        $display("[INFO] Loopback received byte: 0x%02x (Expected: 0xA5)", rdata[7:0]);
        if (rdata[7:0] !== 8'hA5) $fatal(1, "[FAIL] Loopback mismatch!");

        // Deassert CS_N (1)
        wb_write(8'h08, 32'h00000002);

        $display(">> [PASS] SPI Controller verification passed!");
        $display("=========================================================");
        $finish;
    end

endmodule
