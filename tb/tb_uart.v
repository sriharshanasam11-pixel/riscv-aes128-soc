// ============================================================================
// File: tb_uart.v
// Description: Unit Testbench for UART Peripheral
// ============================================================================

`timescale 1ns / 1ps

module tb_uart;

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

    wire        uart_tx;
    reg         uart_rx;
    wire        irq_o;

    uart dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .wb_cyc_i  (wb_cyc_i),
        .wb_stb_i  (wb_stb_i),
        .wb_we_i   (wb_we_i),
        .wb_adr_i  (wb_adr_i),
        .wb_dat_i  (wb_dat_i),
        .wb_sel_i  (wb_sel_i),
        .wb_dat_o  (wb_dat_o),
        .wb_ack_o  (wb_ack_o),
        .uart_tx_o (uart_tx),
        .uart_rx_i (uart_rx),
        .irq_o     (irq_o)
    );

    always #10 clk = ~clk;

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
        $display("   TESTBENCH: UART Peripheral IP                         ");
        $display("=========================================================");

        clk = 0; rst_n = 0;
        wb_cyc_i = 0; wb_stb_i = 0; wb_we_i = 0;
        wb_adr_i = 0; wb_dat_i = 0; wb_sel_i = 0;
        uart_rx = 1'b1;

        $dumpfile("uart_controller.vcd");
        $dumpvars(0, tb_uart);

        #40;
        rst_n = 1;
        #20;

        // Set fast baud divisor for simulation speed
        wb_write(8'h0C, 32'd8);

        // Send character 'K'
        $display("[INFO] Transmitting ASCII 'K' (0x4B)...");
        wb_write(8'h00, 32'h0000004B);

        // Wait until TX is ready again
        rdata = 0;
        while ((rdata & 32'h2) == 0) begin
            wb_read(8'h04, rdata);
        end

        $display(">> [PASS] UART byte transmission completed successfully!");
        $display("=========================================================");
        $finish;
    end

endmodule
