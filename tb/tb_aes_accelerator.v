// ============================================================================
// File: tb_aes_accelerator.v
// Description: Unit Testbench for AES-128 Hardware Accelerator
// Verifies NIST FIPS-197 Known Answer Tests (KAT) for Encryption & Decryption
// ============================================================================

`timescale 1ns / 1ps

module tb_aes_accelerator;

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
    wire        irq_o;

    // Instantiate DUT
    aes_accelerator dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .wb_cyc_i (wb_cyc_i),
        .wb_stb_i (wb_stb_i),
        .wb_we_i  (wb_we_i),
        .wb_adr_i (wb_adr_i),
        .wb_dat_i (wb_dat_i),
        .wb_sel_i (wb_sel_i),
        .wb_dat_o (wb_dat_o),
        .wb_ack_o (wb_ack_o),
        .irq_o    (irq_o)
    );

    // Clock generation (50 MHz, 20ns period)
    always #10 clk = ~clk;

    // Wishbone write task
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

    // Wishbone read task
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
    integer start_time, enc_time, dec_time;

    initial begin
        $display("=========================================================");
        $display("   TESTBENCH: AES-128 Accelerator (NIST FIPS-197 KAT)   ");
        $display("=========================================================");

        clk      = 0;
        rst_n    = 0;
        wb_cyc_i = 0;
        wb_stb_i = 0;
        wb_we_i  = 0;
        wb_adr_i = 0;
        wb_dat_i = 0;
        wb_sel_i = 0;

        $dumpfile("aes128_accelerator.vcd");
        $dumpvars(0, tb_aes_accelerator);

        #40;
        rst_n = 1;
        #20;

        // 1. Write NIST Test Key: 00010203 04050607 08090a0b 0c0d0e0f
        $display("[INFO] Writing NIST 128-bit Key...");
        wb_write(8'h08, 32'h00010203);
        wb_write(8'h0C, 32'h04050607);
        wb_write(8'h10, 32'h08090a0b);
        wb_write(8'h14, 32'h0c0d0e0f);

        // 2. Write NIST Plaintext: 00112233 44556677 8899aabb ccddeeff
        $display("[INFO] Writing NIST 128-bit Plaintext...");
        wb_write(8'h18, 32'h00112233);
        wb_write(8'h1C, 32'h44556677);
        wb_write(8'h20, 32'h8899aabb);
        wb_write(8'h24, 32'hccddeeff);

        // 3. Trigger Encryption (Mode = 0, Start = 1)
        $display("[INFO] Starting Hardware Encryption...");
        start_time = $time;
        wb_write(8'h00, 32'h00000001);

        // Poll status register
        rdata = 0;
        while ((rdata & 32'h2) == 0) begin
            wb_read(8'h04, rdata);
        end
        enc_time = ($time - start_time) / 20;
        $display("[INFO] Encryption completed in %0d clock cycles.", enc_time);

        // Read Ciphertext
        wb_read(8'h28, rdata);
        $display("  Ciphertext[0] = 0x%08x (Expected: 0x69c4e0d8)", rdata);
        if (rdata !== 32'h69c4e0d8) $fatal(1, "Ciphertext Word 0 mismatch!");

        wb_read(8'h2C, rdata);
        $display("  Ciphertext[1] = 0x%08x (Expected: 0x6a7b0430)", rdata);
        if (rdata !== 32'h6a7b0430) $fatal(1, "Ciphertext Word 1 mismatch!");

        wb_read(8'h30, rdata);
        $display("  Ciphertext[2] = 0x%08x (Expected: 0xd8cdb780)", rdata);
        if (rdata !== 32'hd8cdb780) $fatal(1, "Ciphertext Word 2 mismatch!");

        wb_read(8'h34, rdata);
        $display("  Ciphertext[3] = 0x%08x (Expected: 0x70b4c55a)", rdata);
        if (rdata !== 32'h70b4c55a) $fatal(1, "Ciphertext Word 3 mismatch!");

        $display(">> [PASS] AES-128 Encryption matches NIST FIPS-197 golden vector!");

        // 4. Test Decryption: Write Ciphertext into DIN
        $display("\n[INFO] Starting Hardware Decryption of Ciphertext...");
        wb_write(8'h18, 32'h69c4e0d8);
        wb_write(8'h1C, 32'h6a7b0430);
        wb_write(8'h20, 32'hd8cdb780);
        wb_write(8'h24, 32'h70b4c55a);

        // Trigger Decryption (Mode = 1, Start = 1 -> CTRL = 3)
        start_time = $time;
        wb_write(8'h00, 32'h00000003);

        rdata = 0;
        while ((rdata & 32'h2) == 0) begin
            wb_read(8'h04, rdata);
        end
        dec_time = ($time - start_time) / 20;
        $display("[INFO] Decryption completed in %0d clock cycles.", dec_time);

        // Read Recovered Plaintext
        wb_read(8'h28, rdata);
        $display("  Decrypted[0] = 0x%08x (Original: 0x00112233)", rdata);
        if (rdata !== 32'h00112233) $fatal(1, "Decrypted Word 0 mismatch!");

        wb_read(8'h2C, rdata);
        $display("  Decrypted[1] = 0x%08x (Original: 0x44556677)", rdata);
        if (rdata !== 32'h44556677) $fatal(1, "Decrypted Word 1 mismatch!");

        wb_read(8'h30, rdata);
        $display("  Decrypted[2] = 0x%08x (Original: 0x8899aabb)", rdata);
        if (rdata !== 32'h8899aabb) $fatal(1, "Decrypted Word 2 mismatch!");

        wb_read(8'h34, rdata);
        $display("  Decrypted[3] = 0x%08x (Original: 0xccddeeff)", rdata);
        if (rdata !== 32'hccddeeff) $fatal(1, "Decrypted Word 3 mismatch!");

        $display(">> [PASS] AES-128 Decryption restored original plaintext exactly!");
        $display("=========================================================");
        $display("   AES-128 ACCELERATOR UNIT VERIFICATION: PASSED        ");
        $display("=========================================================");
        $finish;
    end

endmodule
