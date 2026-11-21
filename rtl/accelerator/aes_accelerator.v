// ============================================================================
// File: aes_accelerator.v
// Description: Complete Memory-Mapped AES-128 Encryption/Decryption Accelerator
// Features: 32-bit Wishbone B4 slave interface, 10-round iterative pipeline,
// on-the-fly key expansion, deterministic 11-cycle execution per block.
// Standard: NIST FIPS-197
// ============================================================================

`timescale 1ns / 1ps

module aes_accelerator (
    input  wire        clk,
    input  wire        rst_n,

    // Wishbone Slave Interface
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [7:0]  wb_adr_i,    // Register offset [7:0]
    input  wire [31:0] wb_dat_i,
    input  wire [3:0]  wb_sel_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o,

    // Interrupt Request
    output wire        irq_o
);

    // Register Offsets
    localparam ADDR_CTRL   = 8'h00;
    localparam ADDR_STATUS = 8'h04;
    localparam ADDR_KEY0   = 8'h08;
    localparam ADDR_KEY1   = 8'h0C;
    localparam ADDR_KEY2   = 8'h10;
    localparam ADDR_KEY3   = 8'h14;
    localparam ADDR_DIN0   = 8'h18;
    localparam ADDR_DIN1   = 8'h1C;
    localparam ADDR_DIN2   = 8'h20;
    localparam ADDR_DIN3   = 8'h24;
    localparam ADDR_DOUT0  = 8'h28;
    localparam ADDR_DOUT1  = 8'h2C;
    localparam ADDR_DOUT2  = 8'h30;
    localparam ADDR_DOUT3  = 8'h34;

    // Registers
    reg [31:0] reg_ctrl;     // [0]=Start, [1]=Mode (0=Enc, 1=Dec), [2]=SoftReset, [3]=IRQ_EN
    reg [31:0] reg_status;   // [0]=Busy, [1]=Done, [2]=Valid
    reg [31:0] reg_key0, reg_key1, reg_key2, reg_key3;
    reg [31:0] reg_din0, reg_din1, reg_din2, reg_din3;
    reg [31:0] reg_dout0, reg_dout1, reg_dout2, reg_dout3;

    reg        key_dirty;    // Flag indicating key has changed and needs expansion
    wire [127:0] full_key = {reg_key0, reg_key1, reg_key2, reg_key3};
    wire [127:0] full_din = {reg_din0, reg_din1, reg_din2, reg_din3};

    // Key Expansion Instance
    reg         ke_start;
    wire        ke_ready;
    wire [127:0] rk [0:10];

    aes_key_expand u_key_expand (
        .clk        (clk),
        .rst_n      (rst_n && !reg_ctrl[2]),
        .start      (ke_start),
        .key_in     (full_key),
        .ready      (ke_ready),
        .rkey_0     (rk[0]),
        .rkey_1     (rk[1]),
        .rkey_2     (rk[2]),
        .rkey_3     (rk[3]),
        .rkey_4     (rk[4]),
        .rkey_5     (rk[5]),
        .rkey_6     (rk[6]),
        .rkey_7     (rk[7]),
        .rkey_8     (rk[8]),
        .rkey_9     (rk[9]),
        .rkey_10    (rk[10])
    );

    // Round Datapath
    reg  [127:0] round_state_in;
    reg  [127:0] current_round_key;
    reg          is_final_round;
    wire [127:0] round_state_out;

    aes_round u_aes_round (
        .state_in       (round_state_in),
        .round_key      (current_round_key),
        .mode           (reg_ctrl[1]), // 0 = Enc, 1 = Dec
        .is_final_round (is_final_round),
        .state_out      (round_state_out)
    );

    // FSM States
    localparam S_IDLE        = 3'd0;
    localparam S_KEY_EXPAND  = 3'd1;
    localparam S_ROUND_INIT  = 3'd2;
    localparam S_ROUND_LOOP  = 3'd3;
    localparam S_ROUND_FINAL = 3'd4;
    localparam S_DONE        = 3'd5;

    reg [2:0] state;
    reg [3:0] round_cnt;

    // Interrupt generation
    assign irq_o = reg_ctrl[3] && reg_status[1];

    // Wishbone Bus Read/Write Handling
    wire bus_access = wb_cyc_i && wb_stb_i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o   <= 1'b0;
            wb_dat_o   <= 32'h0;
            reg_ctrl   <= 32'h0;
            reg_key0   <= 32'h0;
            reg_key1   <= 32'h0;
            reg_key2   <= 32'h0;
            reg_key3   <= 32'h0;
            reg_din0   <= 32'h0;
            reg_din1   <= 32'h0;
            reg_din2   <= 32'h0;
            reg_din3   <= 32'h0;
            key_dirty  <= 1'b1;
        end else if (reg_ctrl[2]) begin // Soft Reset
            reg_ctrl   <= 32'h0;
            wb_ack_o   <= 1'b0;
            key_dirty  <= 1'b1;
        end else begin
            // Single cycle ACK handshake
            wb_ack_o <= bus_access && !wb_ack_o;

            // Auto-clear start pulse in next cycle
            if (reg_ctrl[0])
                reg_ctrl[0] <= 1'b0;

            if (bus_access && !wb_ack_o) begin
                if (wb_we_i) begin
                    // Write Transactions
                    case (wb_adr_i[7:0])
                        ADDR_CTRL:   reg_ctrl <= wb_dat_i;
                        ADDR_KEY0: begin reg_key0 <= wb_dat_i; key_dirty <= 1'b1; end
                        ADDR_KEY1: begin reg_key1 <= wb_dat_i; key_dirty <= 1'b1; end
                        ADDR_KEY2: begin reg_key2 <= wb_dat_i; key_dirty <= 1'b1; end
                        ADDR_KEY3: begin reg_key3 <= wb_dat_i; key_dirty <= 1'b1; end
                        ADDR_DIN0:   reg_din0 <= wb_dat_i;
                        ADDR_DIN1:   reg_din1 <= wb_dat_i;
                        ADDR_DIN2:   reg_din2 <= wb_dat_i;
                        ADDR_DIN3:   reg_din3 <= wb_dat_i;
                        default: ;
                    endcase
                end else begin
                    // Read Transactions
                    case (wb_adr_i[7:0])
                        ADDR_CTRL:   wb_dat_o <= reg_ctrl;
                        ADDR_STATUS: wb_dat_o <= reg_status;
                        ADDR_KEY0:   wb_dat_o <= reg_key0;
                        ADDR_KEY1:   wb_dat_o <= reg_key1;
                        ADDR_KEY2:   wb_dat_o <= reg_key2;
                        ADDR_KEY3:   wb_dat_o <= reg_key3;
                        ADDR_DIN0:   wb_dat_o <= reg_din0;
                        ADDR_DIN1:   wb_dat_o <= reg_din1;
                        ADDR_DIN2:   wb_dat_o <= reg_din2;
                        ADDR_DIN3:   wb_dat_o <= reg_din3;
                        ADDR_DOUT0:  wb_dat_o <= reg_dout0;
                        ADDR_DOUT1:  wb_dat_o <= reg_dout1;
                        ADDR_DOUT2:  wb_dat_o <= reg_dout2;
                        ADDR_DOUT3:  wb_dat_o <= reg_dout3;
                        default:     wb_dat_o <= 32'h0;
                    endcase
                end
            end
        end
    end

    // AES Execution Engine FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            reg_status     <= 32'h0;
            ke_start       <= 1'b0;
            round_cnt      <= 4'd0;
            round_state_in <= 128'h0;
            current_round_key <= 128'h0;
            is_final_round <= 1'b0;
            reg_dout0      <= 32'h0;
            reg_dout1      <= 32'h0;
            reg_dout2      <= 32'h0;
            reg_dout3      <= 32'h0;
        end else if (reg_ctrl[2]) begin
            state          <= S_IDLE;
            reg_status     <= 32'h0;
            ke_start       <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    is_final_round <= 1'b0;
                    if (reg_ctrl[0]) begin // Start triggered
                        reg_status[0] <= 1'b1; // Busy = 1
                        reg_status[1] <= 1'b0; // Done = 0
                        reg_status[2] <= 1'b0; // Valid = 0
                        if (key_dirty) begin
                            ke_start <= 1'b1;
                            state    <= S_KEY_EXPAND;
                        end else begin
                            state    <= S_ROUND_INIT;
                        end
                    end
                end

                S_KEY_EXPAND: begin
                    ke_start <= 1'b0;
                    if (ke_ready) begin
                        key_dirty <= 1'b0;
                        state     <= S_ROUND_INIT;
                    end
                end

                S_ROUND_INIT: begin
                    // Round 0: AddRoundKey
                    // For Encrypt: state = Plaintext ^ rk[0]
                    // For Decrypt: state = Ciphertext ^ rk[10]
                    if (!reg_ctrl[1])
                        round_state_in <= full_din ^ rk[0];
                    else
                        round_state_in <= full_din ^ rk[10];

                    round_cnt <= 4'd1;
                    state     <= S_ROUND_LOOP;
                end

                S_ROUND_LOOP: begin
                    // Select round key:
                    // Encrypt: rk[1] .. rk[9]
                    // Decrypt: rk[9] .. rk[1]
                    if (!reg_ctrl[1])
                        current_round_key = rk[round_cnt];
                    else
                        current_round_key = rk[4'd10 - round_cnt];

                    is_final_round <= 1'b0;
                    round_state_in <= round_state_out;

                    if (round_cnt == 4'd9) begin
                        state     <= S_ROUND_FINAL;
                        round_cnt <= 4'd10;
                    end else begin
                        round_cnt <= round_cnt + 1'b1;
                    end
                end

                S_ROUND_FINAL: begin
                    // Final round (round 10): MixColumns bypassed
                    is_final_round <= 1'b1;
                    if (!reg_ctrl[1])
                        current_round_key = rk[10];
                    else
                        current_round_key = rk[0];

                    // Output registration
                    reg_dout0 <= round_state_out[127:96];
                    reg_dout1 <= round_state_out[95:64];
                    reg_dout2 <= round_state_out[63:32];
                    reg_dout3 <= round_state_out[31:0];

                    state <= S_DONE;
                end

                S_DONE: begin
                    reg_status[0] <= 1'b0; // Busy = 0
                    reg_status[1] <= 1'b1; // Done = 1
                    reg_status[2] <= 1'b1; // Valid = 1
                    state         <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
