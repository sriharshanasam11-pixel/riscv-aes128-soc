// ============================================================================
// File: aes_round.v
// Description: AES-128 Combined Encryption and Decryption Round Datapath
// Implements SubBytes/InvSubBytes, ShiftRows/InvShiftRows,
// MixColumns/InvMixColumns, and AddRoundKey
// Standard: NIST FIPS-197
// ============================================================================

`timescale 1ns / 1ps

module aes_round (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    input  wire         mode,           // 0 = Encrypt, 1 = Decrypt
    input  wire         is_final_round, // 1 = Final round (bypasses MixColumns)
    output reg  [127:0] state_out
);

    // Byte extraction (State matrix layout: 4x4 bytes, column-major)
    wire [7:0] s [0:15];
    assign s[0]  = state_in[127:120]; assign s[1]  = state_in[119:112];
    assign s[2]  = state_in[111:104]; assign s[3]  = state_in[103:96];
    assign s[4]  = state_in[95:88];   assign s[5]  = state_in[87:80];
    assign s[6]  = state_in[79:72];   assign s[7]  = state_in[71:64];
    assign s[8]  = state_in[63:56];   assign s[9]  = state_in[55:48];
    assign s[10] = state_in[47:40];   assign s[11] = state_in[39:32];
    assign s[12] = state_in[31:24];   assign s[13] = state_in[23:16];
    assign s[14] = state_in[15:8];    assign s[15] = state_in[7:0];

    // ========================================================================
    // ENCRYPTION PATH:
    // 1. SubBytes -> 2. ShiftRows -> 3. MixColumns (if not final) -> 4. AddRoundKey
    // ========================================================================
    wire [7:0] enc_sub [0:15];
    wire [7:0] dec_sub [0:15];

    // S-box inputs multiplexed by mode
    // Enc: S-box inputs are direct state bytes s[i]
    // Dec: S-box inputs are bytes after InvShiftRows
    wire [7:0] inv_sr [0:15];
    assign inv_sr[0]  = s[0];  assign inv_sr[1]  = s[13]; assign inv_sr[2]  = s[10]; assign inv_sr[3]  = s[7];
    assign inv_sr[4]  = s[4];  assign inv_sr[5]  = s[1];  assign inv_sr[6]  = s[14]; assign inv_sr[7]  = s[11];
    assign inv_sr[8]  = s[8];  assign inv_sr[9]  = s[5];  assign inv_sr[10] = s[2];  assign inv_sr[11] = s[15];
    assign inv_sr[12] = s[12]; assign inv_sr[13] = s[9];  assign inv_sr[14] = s[6];  assign inv_sr[15] = s[3];

    wire [7:0] sbox_in [0:15];
    wire [7:0] sbox_out [0:15];

    genvar g;
    generate
        for (g = 0; g < 16; g = g + 1) begin : gen_sbox
            assign sbox_in[g] = mode ? inv_sr[g] : s[g];
            aes_sbox u_sbox (
                .in_byte (sbox_in[g]),
                .inv     (mode),
                .out_byte(sbox_out[g])
            );
        end
    endgenerate

    // Enc ShiftRows applied on sbox_out
    wire [7:0] enc_sr [0:15];
    assign enc_sr[0]  = sbox_out[0];  assign enc_sr[1]  = sbox_out[5];  assign enc_sr[2]  = sbox_out[10]; assign enc_sr[3]  = sbox_out[15];
    assign enc_sr[4]  = sbox_out[4];  assign enc_sr[5]  = sbox_out[9];  assign enc_sr[6]  = sbox_out[14]; assign enc_sr[7]  = sbox_out[3];
    assign enc_sr[8]  = sbox_out[8];  assign enc_sr[9]  = sbox_out[13]; assign enc_sr[10] = sbox_out[2];  assign enc_sr[11] = sbox_out[7];
    assign enc_sr[12] = sbox_out[12]; assign enc_sr[13] = sbox_out[1];  assign enc_sr[14] = sbox_out[6];  assign enc_sr[15] = sbox_out[11];

    // Galois field xtime function
    function [7:0] xtime(input [7:0] a);
        xtime = a[7] ? ((a << 1) ^ 8'h1B) : (a << 1);
    endfunction

    // Galois field multiplication helpers
    function [7:0] mul2(input [7:0] a); mul2 = xtime(a); endfunction
    function [7:0] mul3(input [7:0] a); mul3 = xtime(a) ^ a; endfunction
    function [7:0] mul9(input [7:0] a); mul9 = xtime(xtime(xtime(a))) ^ a; endfunction
    function [7:0] mulb(input [7:0] a); mulb = xtime(xtime(xtime(a))) ^ xtime(a) ^ a; endfunction
    function [7:0] muld(input [7:0] a); muld = xtime(xtime(xtime(a))) ^ xtime(xtime(a)) ^ a; endfunction
    function [7:0] mule(input [7:0] a); mule = xtime(xtime(xtime(a))) ^ xtime(xtime(a)) ^ xtime(a); endfunction

    // MixColumns for 4 columns
    wire [7:0] enc_mc [0:15];
    generate
        for (g = 0; g < 4; g = g + 1) begin : gen_mix_cols
            assign enc_mc[4*g+0] = mul2(enc_sr[4*g+0]) ^ mul3(enc_sr[4*g+1]) ^ enc_sr[4*g+2]       ^ enc_sr[4*g+3];
            assign enc_mc[4*g+1] = enc_sr[4*g+0]       ^ mul2(enc_sr[4*g+1]) ^ mul3(enc_sr[4*g+2]) ^ enc_sr[4*g+3];
            assign enc_mc[4*g+2] = enc_sr[4*g+0]       ^ enc_sr[4*g+1]       ^ mul2(enc_sr[4*g+2]) ^ mul3(enc_sr[4*g+3]);
            assign enc_mc[4*g+3] = mul3(enc_sr[4*g+0]) ^ enc_sr[4*g+1]       ^ enc_sr[4*g+2]       ^ mul2(enc_sr[4*g+3]);
        end
    endgenerate

    // Encryption round state before AddRoundKey
    wire [127:0] enc_pre_rk = is_final_round ? 
        {enc_sr[0],  enc_sr[1],  enc_sr[2],  enc_sr[3],
         enc_sr[4],  enc_sr[5],  enc_sr[6],  enc_sr[7],
         enc_sr[8],  enc_sr[9],  enc_sr[10], enc_sr[11],
         enc_sr[12], enc_sr[13], enc_sr[14], enc_sr[15]} :
        {enc_mc[0],  enc_mc[1],  enc_mc[2],  enc_mc[3],
         enc_mc[4],  enc_mc[5],  enc_mc[6],  enc_mc[7],
         enc_mc[8],  enc_mc[9],  enc_mc[10], enc_mc[11],
         enc_mc[12], enc_mc[13], enc_mc[14], enc_mc[15]};

    wire [127:0] enc_round_out = enc_pre_rk ^ round_key;

    // ========================================================================
    // DECRYPTION PATH:
    // 1. InvShiftRows -> 2. InvSubBytes (sbox_out) -> 3. AddRoundKey -> 4. InvMixColumns (if not final)
    // ========================================================================
    wire [127:0] dec_sub_out = {
        sbox_out[0],  sbox_out[1],  sbox_out[2],  sbox_out[3],
        sbox_out[4],  sbox_out[5],  sbox_out[6],  sbox_out[7],
        sbox_out[8],  sbox_out[9],  sbox_out[10], sbox_out[11],
        sbox_out[12], sbox_out[13], sbox_out[14], sbox_out[15]
    };

    wire [127:0] dec_post_rk = dec_sub_out ^ round_key;

    wire [7:0] dec_ark_b [0:15];
    assign dec_ark_b[0]  = dec_post_rk[127:120]; assign dec_ark_b[1]  = dec_post_rk[119:112];
    assign dec_ark_b[2]  = dec_post_rk[111:104]; assign dec_ark_b[3]  = dec_post_rk[103:96];
    assign dec_ark_b[4]  = dec_post_rk[95:88];   assign dec_ark_b[5]  = dec_post_rk[87:80];
    assign dec_ark_b[6]  = dec_post_rk[79:72];   assign dec_ark_b[7]  = dec_post_rk[71:64];
    assign dec_ark_b[8]  = dec_post_rk[63:56];   assign dec_ark_b[9]  = dec_post_rk[55:48];
    assign dec_ark_b[10] = dec_post_rk[47:40];   assign dec_ark_b[11] = dec_post_rk[39:32];
    assign dec_ark_b[12] = dec_post_rk[31:24];   assign dec_ark_b[13] = dec_post_rk[23:16];
    assign dec_ark_b[14] = dec_post_rk[15:8];    assign dec_ark_b[15] = dec_post_rk[7:0];

    // InvMixColumns
    wire [7:0] dec_imc [0:15];
    generate
        for (g = 0; g < 4; g = g + 1) begin : gen_inv_mix_cols
            assign dec_imc[4*g+0] = mule(dec_ark_b[4*g+0]) ^ mulb(dec_ark_b[4*g+1]) ^ muld(dec_ark_b[4*g+2]) ^ mul9(dec_ark_b[4*g+3]);
            assign dec_imc[4*g+1] = mul9(dec_ark_b[4*g+0]) ^ mule(dec_ark_b[4*g+1]) ^ mulb(dec_ark_b[4*g+2]) ^ muld(dec_ark_b[4*g+3]);
            assign dec_imc[4*g+2] = muld(dec_ark_b[4*g+0]) ^ mul9(dec_ark_b[4*g+1]) ^ mule(dec_ark_b[4*g+2]) ^ mulb(dec_ark_b[4*g+3]);
            assign dec_imc[4*g+3] = mulb(dec_ark_b[4*g+0]) ^ muld(dec_ark_b[4*g+1]) ^ mul9(dec_ark_b[4*g+2]) ^ mule(dec_ark_b[4*g+3]);
        end
    endgenerate

    wire [127:0] dec_round_out = is_final_round ? dec_post_rk : {
        dec_imc[0],  dec_imc[1],  dec_imc[2],  dec_imc[3],
        dec_imc[4],  dec_imc[5],  dec_imc[6],  dec_imc[7],
        dec_imc[8],  dec_imc[9],  dec_imc[10], dec_imc[11],
        dec_imc[12], dec_imc[13], dec_imc[14], dec_imc[15]
    };

    always @(*) begin
        if (mode)
            state_out = dec_round_out;
        else
            state_out = enc_round_out;
    end

endmodule
