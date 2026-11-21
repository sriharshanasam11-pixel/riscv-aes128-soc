// ============================================================================
// File: prng.v
// Description: 32-Bit Hardware Pseudo-Random Number Generator (PRNG) IP
// Dual-Algorithm: Galois LFSR / Marsaglia Xorshift32 with Wishbone B4 interface
// ============================================================================

`timescale 1ns / 1ps

module prng (
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone Slave Interface
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [7:0]  wb_adr_i,
    input  wire [31:0] wb_dat_i,
    input  wire [3:0]  wb_sel_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o
);

    localparam ADDR_SEED   = 8'h00;
    localparam ADDR_CTRL   = 8'h04;
    localparam ADDR_STATUS = 8'h08;
    localparam ADDR_DATA   = 8'h0C;

    reg [31:0] reg_seed;
    reg [31:0] reg_ctrl;     // [0]=Enable, [1]=Load Seed, [2]=Algo (0=LFSR, 1=Xorshift)
    reg [31:0] reg_status;   // [0]=Ready
    reg [31:0] lfsr_state;
    reg [31:0] xorshift_state;

    wire bus_access = wb_cyc_i && wb_stb_i;

    // Xorshift32 next state logic
    wire [31:0] xs_step1 = xorshift_state ^ (xorshift_state << 13);
    wire [31:0] xs_step2 = xs_step1 ^ (xs_step1 >> 17);
    wire [31:0] xs_next  = xs_step2 ^ (xs_step2 << 5);

    // 32-bit Galois LFSR next state logic (polynomial: taps 32, 22, 2, 1)
    wire [31:0] lfsr_next = lfsr_state[0] ? ((lfsr_state >> 1) ^ 32'h80200003) : (lfsr_state >> 1);

    wire [31:0] current_random = reg_ctrl[2] ? xorshift_state : lfsr_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o       <= 1'b0;
            wb_dat_o       <= 32'h0;
            reg_seed       <= 32'hACE1_2468;
            reg_ctrl       <= 32'h0000_0005; // Enabled, Xorshift32 mode default
            reg_status     <= 32'h0000_0001; // Ready
            lfsr_state     <= 32'hACE1_2468;
            xorshift_state <= 32'h2468_ACE1;
        end else begin
            wb_ack_o <= bus_access && !wb_ack_o;

            // Seed reload pulse auto-clear
            if (reg_ctrl[1]) begin
                reg_ctrl[1]    <= 1'b0;
                lfsr_state     <= (reg_seed != 32'h0) ? reg_seed : 32'hACE1_2468;
                xorshift_state <= (reg_seed != 32'h0) ? reg_seed : 32'h2468_ACE1;
            end

            if (bus_access && !wb_ack_o) begin
                if (wb_we_i) begin
                    case (wb_adr_i[7:0])
                        ADDR_SEED: begin
                            reg_seed       <= wb_dat_i;
                            lfsr_state     <= (wb_dat_i != 32'h0) ? wb_dat_i : 32'hACE1_2468;
                            xorshift_state <= (wb_dat_i != 32'h0) ? wb_dat_i : 32'h2468_ACE1;
                        end
                        ADDR_CTRL: reg_ctrl <= wb_dat_i;
                        default: ;
                    endcase
                end else begin
                    case (wb_adr_i[7:0])
                        ADDR_SEED:   wb_dat_o <= reg_seed;
                        ADDR_CTRL:   wb_dat_o <= reg_ctrl;
                        ADDR_STATUS: wb_dat_o <= reg_status;
                        ADDR_DATA: begin
                            wb_dat_o <= current_random;
                            // Step PRNG on reading data
                            if (reg_ctrl[0]) begin
                                lfsr_state     <= lfsr_next;
                                xorshift_state <= xs_next;
                            end
                        end
                        default: wb_dat_o <= 32'h0;
                    endcase
                end
            end
        end
    end

endmodule
