// ============================================================================
// File: aes_key_expand.v
// Description: AES-128 Iterative Key Expansion Module
// Computes 11 round keys (K0 - K10) using 4 shared S-boxes
// Standard: NIST FIPS-197
// ============================================================================

`timescale 1ns / 1ps

module aes_key_expand (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] key_in,
    output reg          ready,
    output wire [127:0] rkey_0,
    output wire [127:0] rkey_1,
    output wire [127:0] rkey_2,
    output wire [127:0] rkey_3,
    output wire [127:0] rkey_4,
    output wire [127:0] rkey_5,
    output wire [127:0] rkey_6,
    output wire [127:0] rkey_7,
    output wire [127:0] rkey_8,
    output wire [127:0] rkey_9,
    output wire [127:0] rkey_10
);

    reg [127:0] round_keys [0:10];
    reg [3:0]   round_idx;
    reg         busy;

    assign rkey_0  = round_keys[0];
    assign rkey_1  = round_keys[1];
    assign rkey_2  = round_keys[2];
    assign rkey_3  = round_keys[3];
    assign rkey_4  = round_keys[4];
    assign rkey_5  = round_keys[5];
    assign rkey_6  = round_keys[6];
    assign rkey_7  = round_keys[7];
    assign rkey_8  = round_keys[8];
    assign rkey_9  = round_keys[9];
    assign rkey_10 = round_keys[10];

    // Rcon lookup table
    function [7:0] get_rcon(input [3:0] r);
        case (r)
            4'd1:  get_rcon = 8'h01;
            4'd2:  get_rcon = 8'h02;
            4'd3:  get_rcon = 8'h04;
            4'd4:  get_rcon = 8'h08;
            4'd5:  get_rcon = 8'h10;
            4'd6:  get_rcon = 8'h20;
            4'd7:  get_rcon = 8'h40;
            4'd8:  get_rcon = 8'h80;
            4'd9:  get_rcon = 8'h1B;
            4'd10: get_rcon = 8'h36;
            default: get_rcon = 8'h00;
        endcase
    endfunction

    // 4 S-boxes for SubWord
    wire [31:0] prev_w3 = round_keys[round_idx - 1][31:0];
    // RotWord: shift left circular 1 byte: [23:16], [15:8], [7:0], [31:24]
    wire [7:0]  rot_b0 = prev_w3[23:16];
    wire [7:0]  rot_b1 = prev_w3[15:8];
    wire [7:0]  rot_b2 = prev_w3[7:0];
    wire [7:0]  rot_b3 = prev_w3[31:24];

    wire [7:0]  sub_b0, sub_b1, sub_b2, sub_b3;
    aes_sbox sbox_k0 (.in_byte(rot_b0), .inv(1'b0), .out_byte(sub_b0));
    aes_sbox sbox_k1 (.in_byte(rot_b1), .inv(1'b0), .out_byte(sub_b1));
    aes_sbox sbox_k2 (.in_byte(rot_b2), .inv(1'b0), .out_byte(sub_b2));
    aes_sbox sbox_k3 (.in_byte(rot_b3), .inv(1'b0), .out_byte(sub_b3));

    wire [31:0] sub_rot_rcon = {sub_b0 ^ get_rcon(round_idx), sub_b1, sub_b2, sub_b3};

    // Words from previous key
    wire [31:0] prev_w0 = round_keys[round_idx - 1][127:96];
    wire [31:0] prev_w1 = round_keys[round_idx - 1][95:64];
    wire [31:0] prev_w2 = round_keys[round_idx - 1][63:32];

    wire [31:0] next_w0 = prev_w0 ^ sub_rot_rcon;
    wire [31:0] next_w1 = prev_w1 ^ next_w0;
    wire [31:0] next_w2 = prev_w2 ^ next_w1;
    wire [31:0] next_w3 = prev_w3 ^ next_w2;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready     <= 1'b0;
            busy      <= 1'b0;
            round_idx <= 4'd0;
            for (i = 0; i <= 10; i = i + 1)
                round_keys[i] <= 128'h0;
        end else begin
            if (start && !busy) begin
                round_keys[0] <= key_in;
                round_idx     <= 4'd1;
                busy          <= 1'b1;
                ready         <= 1'b0;
            end else if (busy) begin
                round_keys[round_idx] <= {next_w0, next_w1, next_w2, next_w3};
                if (round_idx == 4'd10) begin
                    busy      <= 1'b0;
                    ready     <= 1'b1;
                    round_idx <= 4'd0;
                end else begin
                    round_idx <= round_idx + 1'b1;
                end
            end
        end
    end

endmodule
