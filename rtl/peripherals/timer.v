// ============================================================================
// File: timer.v
// Description: 32-Bit Real-Time System Timer IP
// Features: Programmable 16-bit prescaler, 32-bit comparator, auto-reload,
// match interrupt generation, Wishbone B4 slave interface.
// ============================================================================

`timescale 1ns / 1ps

module timer (
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

    // Interrupt Request
    output wire        irq_o
);

    localparam ADDR_COUNT    = 8'h00;
    localparam ADDR_COMPARE  = 8'h04;
    localparam ADDR_CTRL     = 8'h08;
    localparam ADDR_PRESCALE = 8'h0C;

    reg [31:0] reg_count;
    reg [31:0] reg_compare;
    reg [31:0] reg_ctrl;     // [0]=ENABLE, [1]=AUTO_RELOAD, [2]=IRQ_EN, [3]=MATCH_FLAG
    reg [31:0] reg_prescale;

    reg [15:0] prescale_cnt;

    wire bus_access = wb_cyc_i && wb_stb_i;

    assign irq_o = reg_ctrl[2] && reg_ctrl[3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o     <= 1'b0;
            wb_dat_o     <= 32'h0;
            reg_count    <= 32'h0;
            reg_compare  <= 32'hFFFF_FFFF;
            reg_ctrl     <= 32'h0;
            reg_prescale <= 32'h0;
            prescale_cnt <= 16'h0;
        end else begin
            wb_ack_o <= bus_access && !wb_ack_o;

            // Bus Operations
            if (bus_access && !wb_ack_o) begin
                if (wb_we_i) begin
                    case (wb_adr_i[7:0])
                        ADDR_COUNT:    reg_count   <= wb_dat_i;
                        ADDR_COMPARE:  reg_compare <= wb_dat_i;
                        ADDR_CTRL: begin
                            reg_ctrl[2:0] <= wb_dat_i[2:0];
                            if (wb_dat_i[3]) reg_ctrl[3] <= 1'b0; // W1C
                        end
                        ADDR_PRESCALE: reg_prescale <= wb_dat_i;
                        default: ;
                    endcase
                end else begin
                    case (wb_adr_i[7:0])
                        ADDR_COUNT:    wb_dat_o <= reg_count;
                        ADDR_COMPARE:  wb_dat_o <= reg_compare;
                        ADDR_CTRL:     wb_dat_o <= reg_ctrl;
                        ADDR_PRESCALE: wb_dat_o <= reg_prescale;
                        default:       wb_dat_o <= 32'h0;
                    endcase
                end
            end

            // Timer Counting Logic
            if (reg_ctrl[0]) begin // Enable
                if (prescale_cnt >= reg_prescale[15:0]) begin
                    prescale_cnt <= 16'h0;
                    if (reg_count == reg_compare) begin
                        reg_ctrl[3] <= 1'b1; // Set match flag
                        if (reg_ctrl[1]) begin
                            reg_count <= 32'h0; // Auto-reload
                        end else begin
                            reg_count <= reg_count + 1'b1;
                        end
                    end else begin
                        reg_count <= reg_count + 1'b1;
                    end
                end else begin
                    prescale_cnt <= prescale_cnt + 1'b1;
                end
            end
        end
    end

endmodule
