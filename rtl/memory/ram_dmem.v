// ============================================================================
// File: ram_dmem.v
// Description: 16 KB Synchronous Byte-Addressable Data SRAM (4096 x 32-bit words)
// Supports byte, half-word, and word reads and writes via wb_sel_i[3:0]
// ============================================================================

`timescale 1ns / 1ps

module ram_dmem #(
    parameter MEM_SIZE_WORDS = 4096
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
            mem[i] = 32'h0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 1'b0;
            wb_dat_o <= 32'h0;
        end else begin
            wb_ack_o <= bus_access && !wb_ack_o;
            if (bus_access && !wb_ack_o) begin
                if (wb_we_i) begin
                    if (wb_sel_i[0]) mem[word_addr][7:0]   <= wb_dat_i[7:0];
                    if (wb_sel_i[1]) mem[word_addr][15:8]  <= wb_dat_i[15:8];
                    if (wb_sel_i[2]) mem[word_addr][23:16] <= wb_dat_i[23:16];
                    if (wb_sel_i[3]) mem[word_addr][31:24] <= wb_dat_i[31:24];
                end else begin
                    wb_dat_o <= mem[word_addr];
                end
            end
        end
    end

endmodule
