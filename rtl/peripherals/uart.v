// ============================================================================
// File: uart.v
// Description: Full-Duplex Universal Asynchronous Receiver Transmitter (UART)
// Features: 8-N-1 framing, programmable 16-bit baud-rate divider, status flags,
// Wishbone B4 slave interface.
// ============================================================================

`timescale 1ns / 1ps

module uart (
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

    // External UART Pins
    output reg         uart_tx_o,
    input  wire        uart_rx_i,

    // Interrupt Request
    output wire        irq_o
);

    localparam ADDR_DATA    = 8'h00;
    localparam ADDR_STATUS  = 8'h04;
    localparam ADDR_CTRL    = 8'h08;
    localparam ADDR_BAUDDIV = 8'h0C;

    reg [31:0] reg_ctrl;     // [0]=TX_EN, [1]=RX_EN, [2]=RX_IRQ_EN, [3]=TX_IRQ_EN
    reg [31:0] reg_bauddiv;  // 16-bit baud divisor
    reg [7:0]  rx_buffer;
    reg        rx_valid;
    reg        tx_busy;

    wire bus_access = wb_cyc_i && wb_stb_i;

    // Transmitter logic
    reg [9:0]  tx_shift_reg;
    reg [15:0] tx_baud_cnt;
    reg [3:0]  tx_bit_idx;

    // Receiver logic
    reg [1:0]  rx_sync;
    reg [9:0]  rx_shift_reg;
    reg [15:0] rx_baud_cnt;
    reg [3:0]  rx_bit_idx;
    reg        rx_active;

    assign irq_o = (reg_ctrl[2] && rx_valid) || (reg_ctrl[3] && !tx_busy);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o     <= 1'b0;
            wb_dat_o     <= 32'h0;
            reg_ctrl     <= 32'h0000_0003; // TX_EN and RX_EN enabled
            reg_bauddiv  <= 32'd434;       // Default ~115200 at 50MHz
            rx_buffer    <= 8'h0;
            rx_valid     <= 1'b0;
            tx_busy      <= 1'b0;
            uart_tx_o    <= 1'b1;          // Idle high
            tx_shift_reg <= 10'h3FF;
            tx_baud_cnt  <= 16'h0;
            tx_bit_idx   <= 4'd0;
            rx_sync      <= 2'b11;
            rx_shift_reg <= 10'h0;
            rx_baud_cnt  <= 16'h0;
            rx_bit_idx   <= 4'd0;
            rx_active    <= 1'b0;
        end else begin
            wb_ack_o <= bus_access && !wb_ack_o;

            // Bus Reads / Writes
            if (bus_access && !wb_ack_o) begin
                if (wb_we_i) begin
                    case (wb_adr_i[7:0])
                        ADDR_DATA: begin
                            if (!tx_busy && reg_ctrl[0]) begin
                                // Frame: Start bit (0) + 8 data bits + Stop bit (1)
                                tx_shift_reg <= {1'b1, wb_dat_i[7:0], 1'b0};
                                tx_busy      <= 1'b1;
                                tx_bit_idx   <= 4'd0;
                                tx_baud_cnt  <= 16'h0;
                            end
                        end
                        ADDR_CTRL:    reg_ctrl    <= wb_dat_i;
                        ADDR_BAUDDIV: reg_bauddiv <= wb_dat_i;
                        default: ;
                    endcase
                end else begin
                    case (wb_adr_i[7:0])
                        ADDR_DATA: begin
                            wb_dat_o <= {24'h0, rx_buffer};
                            rx_valid <= 1'b0; // Reading clears RX valid
                        end
                        ADDR_STATUS:  wb_dat_o <= {30'h0, !tx_busy, rx_valid};
                        ADDR_CTRL:    wb_dat_o <= reg_ctrl;
                        ADDR_BAUDDIV: wb_dat_o <= reg_bauddiv;
                        default:      wb_dat_o <= 32'h0;
                    endcase
                end
            end

            // TX State Machine
            if (tx_busy) begin
                if (tx_baud_cnt >= reg_bauddiv[15:0]) begin
                    tx_baud_cnt  <= 16'h0;
                    uart_tx_o    <= tx_shift_reg[0];
                    tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};
                    if (tx_bit_idx == 4'd9) begin
                        tx_busy   <= 1'b0;
                        uart_tx_o <= 1'b1;
                    end else begin
                        tx_bit_idx <= tx_bit_idx + 1'b1;
                    end
                end else begin
                    tx_baud_cnt <= tx_baud_cnt + 1'b1;
                end
            end

            // RX Synchronizer & Sampling Logic
            rx_sync <= {rx_sync[0], uart_rx_i};
            if (!rx_active) begin
                // Falling edge detected (Start bit)
                if (reg_ctrl[1] && rx_sync[1] == 1'b1 && rx_sync[0] == 1'b0) begin
                    rx_active   <= 1'b1;
                    rx_baud_cnt <= {1'b0, reg_bauddiv[15:1]}; // Sample middle of bit
                    rx_bit_idx  <= 4'd0;
                end
            end else begin
                if (rx_baud_cnt >= reg_bauddiv[15:0]) begin
                    rx_baud_cnt <= 16'h0;
                    rx_shift_reg <= {rx_sync[1], rx_shift_reg[9:1]};
                    if (rx_bit_idx == 4'd9) begin
                        rx_active <= 1'b0;
                        if (rx_sync[1] == 1'b1) begin // Valid stop bit
                            rx_buffer <= rx_shift_reg[8:1];
                            rx_valid  <= 1'b1;
                        end
                    end else begin
                        rx_bit_idx <= rx_bit_idx + 1'b1;
                    end
                end else begin
                    rx_baud_cnt <= rx_baud_cnt + 1'b1;
                end
            end
        end
    end

endmodule
