// ============================================================================
// File: tb_prng.v
// Description: Unit Testbench for Hardware PRNG IP
// ============================================================================

`timescale 1ns / 1ps

module tb_prng;

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

    prng dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_cyc_i (wb_cyc_i),
        .wb_stb_i (wb_stb_i),
        .wb_we_i  (wb_we_i),
        .wb_adr_i (wb_adr_i),
        .wb_dat_i (wb_dat_i),
        .wb_sel_i (wb_sel_i),
        .wb_dat_o (wb_dat_o),
        .wb_ack_o (wb_ack_o)
    );

    always #10 clk = ~clk;

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

    reg [31:0] val1, val2, val3;

    initial begin
        $display("=========================================================");
        $display("   TESTBENCH: Hardware PRNG IP                           ");
        $display("=========================================================");

        clk = 0; rst_n = 0;
        wb_cyc_i = 0; wb_stb_i = 0; wb_we_i = 0;
        wb_adr_i = 0; wb_dat_i = 0; wb_sel_i = 0;

        $dumpfile("prng_module.vcd");
        $dumpvars(0, tb_prng);

        #40;
        rst_n = 1;
        #20;

        // Read 3 successive random values
        wb_read(8'h0C, val1);
        wb_read(8'h0C, val2);
        wb_read(8'h0C, val3);

        $display("[PRNG] Sampled Word 1: 0x%08x", val1);
        $display("[PRNG] Sampled Word 2: 0x%08x", val2);
        $display("[PRNG] Sampled Word 3: 0x%08x", val3);

        if (val1 === val2 || val2 === val3) begin
            $fatal(1, "[FAIL] PRNG generated repeating consecutive words!");
        end

        // Reseed PRNG
        $display("[INFO] Testing PRNG Reseeding...");
        wb_write(8'h00, 32'h12345678);
        wb_read(8'h0C, val1);
        $display("[PRNG] Post-Reseed Word: 0x%08x", val1);

        $display(">> [PASS] PRNG verification passed!");
        $display("=========================================================");
        $finish;
    end

endmodule
