// ============================================================================
// File: riscv_core.v
// Description: RV32I Processor Core with Wishbone B4 Master Interface
// Handles Instruction Fetch, Decode, Execution, Memory Access, and Writeback
// ============================================================================

`timescale 1ns / 1ps

module riscv_core (
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone Master Interface
    output reg  [31:0] wb_adr_o,
    output reg  [31:0] wb_dat_o,
    output reg  [3:0]  wb_sel_o,
    output reg         wb_we_o,
    output reg         wb_cyc_o,
    output reg         wb_stb_o,
    input  wire [31:0] wb_dat_i,
    input  wire        wb_ack_i,

    // External Interrupt Input
    input  wire        irq_i
);

    // Core States
    localparam S_FETCH      = 2'd0;
    localparam S_DECODE     = 2'd1;
    localparam S_MEM_ACCESS = 2'd2;
    localparam S_WRITEBACK  = 2'd3;

    reg [1:0]  state;
    reg [31:0] pc;
    reg [31:0] instr;
    reg [31:0] reg_wdata;
    reg        reg_we;

    // Instruction Fields
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    // Immediate Decoding
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'h0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // Register File
    wire [31:0] rdata1, rdata2;
    riscv_regfile u_regfile (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (reg_we),
        .raddr1 (rs1),
        .raddr2 (rs2),
        .waddr  (rd),
        .wdata  (reg_wdata),
        .rdata1 (rdata1),
        .rdata2 (rdata2)
    );

    // Control Unit
    wire [3:0] alu_ctrl;
    wire       alu_src_b, reg_write_ctrl, mem_to_reg, mem_write, mem_read;
    wire       branch, jump, jalr, lui, auipc;

    riscv_control u_control (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .alu_ctrl   (alu_ctrl),
        .alu_src_b  (alu_src_b),
        .reg_write  (reg_write_ctrl),
        .mem_to_reg (mem_to_reg),
        .mem_write  (mem_write),
        .mem_read   (mem_read),
        .branch     (branch),
        .jump       (jump),
        .jalr       (jalr),
        .lui        (lui),
        .auipc      (auipc)
    );

    // ALU Operand Selection
    wire [31:0] alu_a = auipc ? pc : rdata1;
    wire [31:0] alu_b = alu_src_b ? (
        (opcode == 7'b0100011) ? imm_s : // Store
        (opcode == 7'b0010111) ? imm_u : // AUIPC
        imm_i                             // Load / I-type
    ) : rdata2;

    wire [31:0] alu_out;
    wire        alu_zero;
    riscv_alu u_alu (
        .a        (alu_a),
        .b        (alu_b),
        .alu_ctrl (alu_ctrl),
        .alu_out  (alu_out),
        .zero     (alu_zero)
    );

    // Branch condition evaluation
    reg take_branch;
    always @(*) begin
        case (funct3)
            3'b000:  take_branch = (rdata1 == rdata2);                    // BEQ
            3'b001:  take_branch = (rdata1 != rdata2);                    // BNE
            3'b100:  take_branch = ($signed(rdata1) < $signed(rdata2));   // BLT
            3'b101:  take_branch = ($signed(rdata1) >= $signed(rdata2));  // BGE
            3'b110:  take_branch = (rdata1 < rdata2);                     // BLTU
            3'b111:  take_branch = (rdata1 >= rdata2);                    // BGEU
            default: take_branch = 1'b0;
        endcase
    end

    // Load Data Formatter
    reg [31:0] load_data_formatted;
    always @(*) begin
        case (funct3)
            3'b000: begin // LB
                case (alu_out[1:0])
                    2'b00: load_data_formatted = {{24{wb_dat_i[7]}},  wb_dat_i[7:0]};
                    2'b01: load_data_formatted = {{24{wb_dat_i[15]}}, wb_dat_i[15:8]};
                    2'b10: load_data_formatted = {{24{wb_dat_i[23]}}, wb_dat_i[23:16]};
                    2'b11: load_data_formatted = {{24{wb_dat_i[31]}}, wb_dat_i[31:24]};
                endcase
            end
            3'b001: begin // LH
                case (alu_out[1])
                    1'b0: load_data_formatted = {{16{wb_dat_i[15]}}, wb_dat_i[15:0]};
                    1'b1: load_data_formatted = {{16{wb_dat_i[31]}}, wb_dat_i[31:16]};
                endcase
            end
            3'b010: load_data_formatted = wb_dat_i; // LW
            3'b100: begin // LBU
                case (alu_out[1:0])
                    2'b00: load_data_formatted = {24'h0, wb_dat_i[7:0]};
                    2'b01: load_data_formatted = {24'h0, wb_dat_i[15:8]};
                    2'b10: load_data_formatted = {24'h0, wb_dat_i[23:16]};
                    2'b11: load_data_formatted = {24'h0, wb_dat_i[31:24]};
                endcase
            end
            3'b101: begin // LHU
                case (alu_out[1])
                    1'b0: load_data_formatted = {16'h0, wb_dat_i[15:0]};
                    1'b1: load_data_formatted = {16'h0, wb_dat_i[31:16]};
                endcase
            end
            default: load_data_formatted = wb_dat_i;
        endcase
    end

    // Store Data and Select Byte Lane Formatter
    reg [31:0] store_data_formatted;
    reg [3:0]  store_sel_formatted;
    always @(*) begin
        case (funct3)
            3'b000: begin // SB
                store_data_formatted = {4{rdata2[7:0]}};
                case (alu_out[1:0])
                    2'b00: store_sel_formatted = 4'b0001;
                    2'b01: store_sel_formatted = 4'b0010;
                    2'b10: store_sel_formatted = 4'b0100;
                    2'b11: store_sel_formatted = 4'b1000;
                endcase
            end
            3'b001: begin // SH
                store_data_formatted = {2{rdata2[15:0]}};
                case (alu_out[1])
                    1'b0: store_sel_formatted = 4'b0011;
                    1'b1: store_sel_formatted = 4'b1100;
                endcase
            end
            3'b010: begin // SW
                store_data_formatted = rdata2;
                store_sel_formatted  = 4'b1111;
            end
            default: begin
                store_data_formatted = rdata2;
                store_sel_formatted  = 4'b1111;
            end
        endcase
    end

    // Main CPU State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_FETCH;
            pc         <= 32'h0000_0000;
            instr      <= 32'h0000_0013; // NOP
            wb_adr_o   <= 32'h0;
            wb_dat_o   <= 32'h0;
            wb_sel_o   <= 4'b1111;
            wb_we_o    <= 1'b0;
            wb_cyc_o   <= 1'b0;
            wb_stb_o   <= 1'b0;
            reg_we     <= 1'b0;
            reg_wdata  <= 32'h0;
        end else begin
            case (state)
                S_FETCH: begin
                    reg_we   <= 1'b0;
                    wb_adr_o <= pc;
                    wb_sel_o <= 4'b1111;
                    wb_we_o  <= 1'b0;
                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;

                    if (wb_ack_i) begin
                        instr    <= wb_dat_i;
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        state    <= S_DECODE;
                    end
                end

                S_DECODE: begin
                    if (mem_read || mem_write) begin
                        // Memory Load/Store Access
                        wb_adr_o <= alu_out;
                        wb_dat_o <= store_data_formatted;
                        wb_sel_o <= store_sel_formatted;
                        wb_we_o  <= mem_write;
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        state    <= S_MEM_ACCESS;
                    end else begin
                        // Register / Branch / Jump execution
                        if (reg_write_ctrl) begin
                            reg_we <= 1'b1;
                            if (jump || jalr)
                                reg_wdata <= pc + 32'd4;
                            else if (lui)
                                reg_wdata <= imm_u;
                            else
                                reg_wdata <= alu_out;
                        end

                        // Program Counter update
                        if (jump)
                            pc <= pc + imm_j;
                        else if (jalr)
                            pc <= (rdata1 + imm_i) & ~32'd1;
                        else if (branch && take_branch)
                            pc <= pc + imm_b;
                        else
                            pc <= pc + 32'd4;

                        state <= S_FETCH;
                    end
                end

                S_MEM_ACCESS: begin
                    if (wb_ack_i) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        if (mem_read) begin
                            reg_we    <= 1'b1;
                            reg_wdata <= load_data_formatted;
                        end
                        pc    <= pc + 32'd4;
                        state <= S_FETCH;
                    end
                end

                default: state <= S_FETCH;
            endcase
        end
    end

endmodule
