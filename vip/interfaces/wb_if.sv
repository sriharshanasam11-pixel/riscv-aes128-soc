// ============================================================================
// File: wb_if.sv
// Description: Wishbone B4 SystemVerilog Interface for UVM VIP
// Includes Clocking Blocks, Modports, and Handshake Assertions
// ============================================================================

`timescale 1ns / 1ps

interface wb_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input wire clk,
    input wire rst_n
);

    // Bus Signals
    logic [ADDR_WIDTH-1:0] adr;
    logic [DATA_WIDTH-1:0] dat_m; // Master to Slave
    logic [DATA_WIDTH-1:0] dat_s; // Slave to Master
    logic [3:0]            sel;
    logic                  we;
    logic                  cyc;
    logic                  stb;
    logic                  ack;
    logic                  err;

    // Master Clocking Block
    clocking master_cb @(posedge clk);
        default input #1step output #1ns;
        output adr, dat_m, sel, we, cyc, stb;
        input  dat_s, ack, err;
    endclocking

    // Slave Clocking Block
    clocking slave_cb @(posedge clk);
        default input #1step output #1ns;
        input  adr, dat_m, sel, we, cyc, stb;
        output dat_s, ack, err;
    endclocking

    // Passive Monitor Clocking Block
    clocking monitor_cb @(posedge clk);
        default input #1step;
        input adr, dat_m, dat_s, sel, we, cyc, stb, ack, err;
    endclocking

    // Modports
    modport master (
        clocking master_cb,
        input    clk,
        input    rst_n
    );

    modport slave (
        clocking slave_cb,
        input    clk,
        input    rst_n
    );

    modport monitor (
        clocking monitor_cb,
        input    clk,
        input    rst_n
    );

    // Interface Assertions
    property p_ack_requires_cyc_stb;
        @(posedge clk) disable iff (!rst_n)
        ack |-> (cyc && stb);
    endproperty
    assert_ack_requires_cyc_stb: assert property (p_ack_requires_cyc_stb)
        else $error("[WB_IF ERROR] Slave asserted ACK without valid CYC and STB!");

endinterface
