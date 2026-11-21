// ============================================================================
// File: aes_if.sv
// Description: AES-128 Accelerator Verification Interface
// Connects to register and round datapath signals for UVM Scoreboarding
// ============================================================================

`timescale 1ns / 1ps

interface aes_if (
    input wire clk,
    input wire rst_n
);

    logic [31:0]  ctrl;
    logic [31:0]  status;
    logic [127:0] key;
    logic [127:0] din;
    logic [127:0] dout;
    logic         start;
    logic         busy;
    logic         done;
    logic         valid;
    logic         mode; // 0 = Enc, 1 = Dec
    logic         irq;

    // Monitor Clocking Block
    clocking monitor_cb @(posedge clk);
        default input #1step;
        input ctrl, status, key, din, dout, start, busy, done, valid, mode, irq;
    endclocking

    modport monitor (
        clocking monitor_cb,
        input    clk,
        input    rst_n
    );

    // Cryptographic Protocol Assertions
    property p_busy_rises_on_start;
        @(posedge clk) disable iff (!rst_n)
        start |=> ##[1:2] busy;
    endproperty
    assert_busy_rises: assert property (p_busy_rises_on_start)
        else $error("[AES_IF ERROR] BUSY did not assert following START trigger!");

    property p_valid_matches_done;
        @(posedge clk) disable iff (!rst_n)
        $rose(done) |-> valid;
    endproperty
    assert_valid_on_done: assert property (p_valid_matches_done)
        else $error("[AES_IF ERROR] VALID is not high when DONE rises!");

endinterface
