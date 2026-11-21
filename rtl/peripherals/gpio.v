// ============================================================================
// File: gpio.v
// Description: 32-Bit General Purpose Input/Output (GPIO) Controller IP
// Features: Software-configurable pin direction, atomic bit set/clear,
// input glitch sampling, Wishbone B4 slave interface.
// ============================================================================

`timescale 1ns / 1ps

module gpio (
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

    // External Physical GPIO Pins
    input  wire [31:0] gpio_in,
    output reg  [31:0] gpio_out,
    output reg  [31:0] gpio_dir     // 1 = Output, 0 = Input
);

    localparam ADDR_INPUT  = 8'h00;
    localparam ADDR_OUTPUT = 8'h04;
    localparam ADDR_DIR    = 8'h08;
    localparam ADDR_SET    = 8'h0C;
    localparam ADDR_CLEAR  = 8'h10;

    reg [31:0] sync_in_0, sync_in_1;
    wire bus_access = wb_cyc_i && wb_stb_i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o  <= 1'b0;
            wb_dat_o  <= 32'h0;
            gpio_out  <= 32'h0;
            gpio_dir  <= 32'h0;
            sync_in_0 <= 32'h0;
            sync_in_1 <= 32'h0;
        end else begin
            wb_ack_o <= bus_access && !wb_ack_o;

            // 2-stage input synchronizer
            sync_in_0 <= gpio_in;
            sync_in_1 <= sync_in_0;

            if (bus_access && !wb_ack_o) begin
                if (wb_we_i) begin
                    case (wb_adr_i[7:0])
                        ADDR_OUTPUT: gpio_out <= wb_dat_i;
                        ADDR_DIR:    gpio_dir <= wb_dat_i;
                        ADDR_SET:    gpio_out <= gpio_out | wb_dat_i;
                        ADDR_CLEAR:  gpio_out <= gpio_out & ~wb_dat_i;
                        default: ;
                    endcase
                end else begin
                    case (wb_adr_i[7:0])
                        ADDR_INPUT:  wb_dat_o <= sync_in_1;
                        ADDR_OUTPUT: wb_dat_o <= gpio_out;
                        ADDR_DIR:    wb_dat_o <= gpio_dir;
                        default:     wb_dat_o <= 32'h0;
                    endcase
                end
            end
        end
    end

endmodule
