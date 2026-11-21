// ============================================================================
// File: rom_imem.v
// Description: 16 KB Synchronous Instruction ROM (4096 x 32-bit words)
// Pre-loadable via $readmemh with default NOP padding
// ============================================================================

`timescale 1ns / 1ps

module rom_imem #(
    parameter MEM_SIZE_WORDS = 4096,
    parameter INIT_FILE      = "rom.hex"
)(
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone Slave Interface
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [31:0] wb_adr_i,    // Byte address
    input  wire [31:0] wb_dat_i,
    input  wire [3:0]  wb_sel_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o
);

    reg [31:0] mem [0:MEM_SIZE_WORDS-1];
    wire [11:0] word_addr = wb_adr_i[13:2];
    wire bus_access = wb_cyc_i && wb_stb_i;

    integer i;
    initial begin
        for (i = 0; i < MEM_SIZE_WORDS; i = i + 1)
            mem[i] = 32'h0000_0013; // RISC-V NOP (addi x0, x0, 0)
        $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'h0;
        end else begin
            wb_ack_o <= bus_access && !wb_ack_o;
            if (bus_access && !wb_ack_o) begin
                wb_dat_o <= mem[word_addr];
            end
        end
    end

endmodule
