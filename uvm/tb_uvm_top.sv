// ============================================================================
// File: tb_uvm_top.sv
// Description: UVM Verification Top Module
// Instantiates System Interfaces, connects to SoC Interconnect, and runs UVM tests
// ============================================================================

`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "../vip/interfaces/wb_if.sv"
`include "../vip/interfaces/aes_if.sv"
`include "../vip/interfaces/spi_if.sv"
`include "../vip/interfaces/uart_if.sv"
`include "soc_base_test.sv"

module tb_uvm_top;

    logic clk;
    logic rst_n;

    // 50 MHz System Clock
    initial clk = 0;
    always #10 clk = ~clk;

    // Reset Generator
    initial begin
        rst_n = 0;
        #50 rst_n = 1;
    end

    // Interface Instantiations
    wb_if   bus_if  (.clk(clk), .rst_n(rst_n));
    aes_if  aes_vif (.clk(clk), .rst_n(rst_n));
    spi_if  spi_vif (.clk(clk), .rst_n(rst_n));
    uart_if uart_vif(.clk(clk), .rst_n(rst_n));

    // SoC Bus Interconnect and Subsystems
    bus_interconnect u_interconnect (
        .clk      (clk),
        .rst_n    (rst_n),

        .m_adr_i  (bus_if.adr),
        .m_dat_i  (bus_if.dat_m),
        .m_sel_i  (bus_if.sel),
        .m_we_i   (bus_if.we),
        .m_cyc_i  (bus_if.cyc),
        .m_stb_i  (bus_if.stb),
        .m_dat_o  (bus_if.dat_s),
        .m_ack_o  (bus_if.ack),

        // Connect slaves...
        .s0_adr_o(), .s0_dat_o(), .s0_sel_o(), .s0_we_o(), .s0_cyc_o(), .s0_stb_o(), .s0_dat_i(32'h0), .s0_ack_i(1'b1),
        .s1_adr_o(), .s1_dat_o(), .s1_sel_o(), .s1_we_o(), .s1_cyc_o(), .s1_stb_o(), .s1_dat_i(32'h0), .s1_ack_i(1'b1),
        .s2_adr_o(), .s2_dat_o(), .s2_sel_o(), .s2_we_o(), .s2_cyc_o(), .s2_stb_o(), .s2_dat_i(32'h0), .s2_ack_i(1'b1),
        .s3_adr_o(), .s3_dat_o(), .s3_sel_o(), .s3_we_o(), .s3_cyc_o(), .s3_stb_o(), .s3_dat_i(32'h0), .s3_ack_i(1'b1),
        .s4_adr_o(), .s4_dat_o(), .s4_sel_o(), .s4_we_o(), .s4_cyc_o(), .s4_stb_o(), .s4_dat_i(32'h0), .s4_ack_i(1'b1),
        .s5_adr_o(), .s5_dat_o(), .s5_sel_o(), .s5_we_o(), .s5_cyc_o(), .s5_stb_o(), .s5_dat_i(32'h0), .s5_ack_i(1'b1),
        .s6_adr_o(), .s6_dat_o(), .s6_sel_o(), .s6_we_o(), .s6_cyc_o(), .s6_stb_o(), .s6_dat_i(32'h0), .s6_ack_i(1'b1),
        .s7_adr_o(), .s7_dat_o(), .s7_sel_o(), .s7_we_o(), .s7_cyc_o(), .s7_stb_o(), .s7_dat_i(32'h0), .s7_ack_i(1'b1)
    );

    // Initial UVM Config and Test Launch
    initial begin
        uvm_config_db#(virtual wb_if)::set(null, "uvm_test_top.env.bus_agent*", "vif", bus_if);
        run_test();
    end

endmodule
