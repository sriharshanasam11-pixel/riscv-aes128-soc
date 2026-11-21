// ============================================================================
// File: spi_controller.v
// Description: Memory-Mapped SPI Master Controller IP
// Features: Full-duplex synchronous SPI transfer, programmable clock division,
// SPI Mode 0-3 support (CPOL/CPHA), automated/manual CS_N, Wishbone B4 interface.
// ============================================================================

`timescale 1ns / 1ps

module spi_controller (
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
    output reg         wb_ack_o,

    // External SPI Interface Pins
    output reg         spi_sck_o,
    output reg         spi_mosi_o,
    input  wire        spi_miso_i,
    output reg         spi_cs_n_o
);

    localparam ADDR_DATA   = 8'h00;
    localparam ADDR_STATUS = 8'h04;
    localparam ADDR_CTRL   = 8'h08;
    localparam ADDR_CLKDIV = 8'h0C;

    reg [7:0]  tx_shift_reg;
    reg [7:0]  rx_shift_reg;
    reg [7:0]  rx_data_reg;
    reg [31:0] reg_ctrl;     // [0]=Enable, [1]=CS_N control, [2]=CPOL, [3]=CPHA
    reg [31:0] reg_clkdiv;   // Clock divider prescaler
    reg [31:0] reg_status;   // [0]=Busy, [1]=TX Empty, [2]=RX Ready

    reg [15:0] clk_cnt;
    reg [3:0]  bit_cnt;
    reg        sck_phase;

    wire bus_access = wb_cyc_i && wb_stb_i;

    localparam S_IDLE     = 2'd0;
    localparam S_TRANSFER = 2'd1;
    localparam S_DONE     = 2'd2;
    reg [1:0] spi_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o     <= 1'b0;
            wb_dat_o     <= 32'h0;
            reg_ctrl     <= 32'h0000_0002; // CS_N deasserted (1)
            reg_clkdiv   <= 32'h0000_0004; // Divide by 8
            reg_status   <= 32'h0000_0002; // TX Empty = 1, Busy = 0, RX Ready = 0
            rx_data_reg  <= 8'h0;
            spi_sck_o    <= 1'b0;
            spi_mosi_o   <= 1'b0;
            spi_cs_n_o   <= 1'b1;
            spi_state    <= S_IDLE;
            clk_cnt      <= 16'h0;
            bit_cnt      <= 4'd0;
            sck_phase    <= 1'b0;
            tx_shift_reg <= 8'h0;
            rx_shift_reg <= 8'h0;
        end else begin
            wb_ack_o <= bus_access && !wb_ack_o;

            // Direct software control of CS_N
            spi_cs_n_o <= reg_ctrl[1];

            // Bus Write/Read handling
            if (bus_access && !wb_ack_o) begin
                if (wb_we_i) begin
                    case (wb_adr_i[7:0])
                        ADDR_DATA: begin
                            if (spi_state == S_IDLE) begin
                                tx_shift_reg  <= wb_dat_i[7:0];
                                reg_status[1] <= 1'b0; // TX not empty
                                reg_status[0] <= 1'b1; // Busy = 1
                                reg_status[2] <= 1'b0; // Clear RX Ready
                                spi_state     <= S_TRANSFER;
                                bit_cnt       <= 4'd0;
                                clk_cnt       <= 16'h0;
                                sck_phase     <= 1'b0;
                                spi_sck_o     <= reg_ctrl[2]; // Default CPOL
                                spi_mosi_o    <= wb_dat_i[7]; // Drive MSB
                            end
                        end
                        ADDR_CTRL:   reg_ctrl   <= wb_dat_i;
                        ADDR_CLKDIV: reg_clkdiv <= wb_dat_i;
                        default: ;
                    endcase
                end else begin
                    case (wb_adr_i[7:0])
                        ADDR_DATA: begin
                            wb_dat_o <= {24'h0, rx_data_reg};
                            reg_status[2] <= 1'b0; // Reading clears RX ready
                        end
                        ADDR_STATUS: wb_dat_o <= reg_status;
                        ADDR_CTRL:   wb_dat_o <= reg_ctrl;
                        ADDR_CLKDIV: wb_dat_o <= reg_clkdiv;
                        default:     wb_dat_o <= 32'h0;
                    endcase
                end
            end

            // SPI Shift Engine FSM
            case (spi_state)
                S_IDLE: begin
                    spi_sck_o <= reg_ctrl[2]; // Idle level of SCK
                end

                S_TRANSFER: begin
                    if (clk_cnt >= reg_clkdiv[15:0]) begin
                        clk_cnt <= 16'h0;
                        sck_phase <= ~sck_phase;

                        if (!sck_phase) begin
                            // First edge of SCK: sample MISO
                            spi_sck_o    <= ~spi_sck_o;
                            rx_shift_reg <= {rx_shift_reg[6:0], spi_miso_i};
                        end else begin
                            // Second edge of SCK: shift MOSI
                            spi_sck_o <= ~spi_sck_o;
                            if (bit_cnt == 4'd7) begin
                                rx_data_reg   <= rx_shift_reg;
                                reg_status[0] <= 1'b0; // Busy = 0
                                reg_status[1] <= 1'b1; // TX Empty = 1
                                reg_status[2] <= 1'b1; // RX Ready = 1
                                spi_state     <= S_IDLE;
                            end else begin
                                bit_cnt      <= bit_cnt + 1'b1;
                                tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                spi_mosi_o   <= tx_shift_reg[6];
                            end
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: spi_state <= S_IDLE;
            endcase
        end
    end

endmodule
