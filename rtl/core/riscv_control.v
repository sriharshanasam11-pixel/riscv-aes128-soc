// ============================================================================
// File: riscv_control.v
// Description: RV32I Instruction Decoder & Main Control Logic
// ============================================================================

`timescale 1ns / 1ps

module riscv_control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg  [3:0] alu_ctrl,
    output reg        alu_src_b,    // 0 = reg2, 1 = immediate
    output reg        reg_write,
    output reg        mem_to_reg,   // 1 = load from mem to reg
    output reg        mem_write,
    output reg        mem_read,
    output reg        branch,
    output reg        jump,
    output reg        jalr,
    output reg        lui,
    output reg        auipc
);

    localparam OPCODE_OP     = 7'b0110011; // R-type
    localparam OPCODE_OP_IMM = 7'b0010011; // I-type ALU
    localparam OPCODE_LOAD   = 7'b0000011; // Loads
    localparam OPCODE_STORE  = 7'b0100011; // Stores
    localparam OPCODE_BRANCH = 7'b1100011; // Branches
    localparam OPCODE_JAL    = 7'b1101111; // JAL
    localparam OPCODE_JALR   = 7'b1100111; // JALR
    localparam OPCODE_LUI    = 7'b0110111; // LUI
    localparam OPCODE_AUIPC  = 7'b0010111; // AUIPC

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLL  = 4'b0010;
    localparam ALU_SLT  = 4'b0011;
    localparam ALU_SLTU = 4'b0100;
    localparam ALU_XOR  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_OR   = 4'b1000;
    localparam ALU_AND  = 4'b1001;

    always @(*) begin
        alu_ctrl   = ALU_ADD;
        alu_src_b  = 1'b0;
        reg_write  = 1'b0;
        mem_to_reg = 1'b0;
        mem_write  = 1'b0;
        mem_read   = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        lui        = 1'b0;
        auipc      = 1'b0;

        case (opcode)
            OPCODE_OP: begin
                reg_write = 1'b1;
                case (funct3)
                    3'b000: alu_ctrl = (funct7[5]) ? ALU_SUB : ALU_ADD;
                    3'b001: alu_ctrl = ALU_SLL;
                    3'b010: alu_ctrl = ALU_SLT;
                    3'b011: alu_ctrl = ALU_SLTU;
                    3'b100: alu_ctrl = ALU_XOR;
                    3'b101: alu_ctrl = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: alu_ctrl = ALU_OR;
                    3'b111: alu_ctrl = ALU_AND;
                endcase
            end

            OPCODE_OP_IMM: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1;
                case (funct3)
                    3'b000: alu_ctrl = ALU_ADD;
                    3'b001: alu_ctrl = ALU_SLL;
                    3'b010: alu_ctrl = ALU_SLT;
                    3'b011: alu_ctrl = ALU_SLTU;
                    3'b100: alu_ctrl = ALU_XOR;
                    3'b101: alu_ctrl = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: alu_ctrl = ALU_OR;
                    3'b111: alu_ctrl = ALU_AND;
                endcase
            end

            OPCODE_LOAD: begin
                reg_write  = 1'b1;
                alu_src_b  = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                alu_ctrl   = ALU_ADD;
            end

            OPCODE_STORE: begin
                alu_src_b = 1'b1;
                mem_write = 1'b1;
                alu_ctrl  = ALU_ADD;
            end

            OPCODE_BRANCH: begin
                branch = 1'b1;
                case (funct3)
                    3'b000, 3'b001: alu_ctrl = ALU_SUB;  // BEQ, BNE
                    3'b100, 3'b101: alu_ctrl = ALU_SLT;  // BLT, BGE
                    3'b110, 3'b111: alu_ctrl = ALU_SLTU; // BLTU, BGEU
                    default: alu_ctrl = ALU_SUB;
                endcase
            end

            OPCODE_JAL: begin
                jump      = 1'b1;
                reg_write = 1'b1;
            end

            OPCODE_JALR: begin
                jalr      = 1'b1;
                reg_write = 1'b1;
                alu_src_b = 1'b1;
                alu_ctrl  = ALU_ADD;
            end

            OPCODE_LUI: begin
                lui       = 1'b1;
                reg_write = 1'b1;
            end

            OPCODE_AUIPC: begin
                auipc     = 1'b1;
                reg_write = 1'b1;
            end

            default: ;
        endcase
    end

endmodule
