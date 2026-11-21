// ============================================================================
// File: riscv_alu.v
// Description: RV32I Arithmetic Logic Unit (ALU)
// ============================================================================

`timescale 1ns / 1ps

module riscv_alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] alu_out,
    output wire        zero
);

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
        case (alu_ctrl)
            ALU_ADD:  alu_out = a + b;
            ALU_SUB:  alu_out = a - b;
            ALU_SLL:  alu_out = a << b[4:0];
            ALU_SLT:  alu_out = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: alu_out = (a < b) ? 32'd1 : 32'd0;
            ALU_XOR:  alu_out = a ^ b;
            ALU_SRL:  alu_out = a >> b[4:0];
            ALU_SRA:  alu_out = $signed(a) >>> b[4:0];
            ALU_OR:   alu_out = a | b;
            ALU_AND:  alu_out = a & b;
            default:  alu_out = 32'd0;
        endcase
    end

    assign zero = (alu_out == 32'd0);

endmodule
