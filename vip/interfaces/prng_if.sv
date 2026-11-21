// ============================================================================
// File: prng_if.sv
// Description: Hardware PRNG Verification Interface
// ============================================================================

`timescale 1ns / 1ps

interface prng_if (
    input wire clk,
    input wire rst_n
);

    logic [31:0] seed;
    logic [31:0] ctrl;
    logic [31:0] status;
    logic [31:0] data;
    logic        step_pulse;

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input seed, ctrl, status, data, step_pulse;
    endclocking

    modport monitor (
        clocking monitor_cb,
        input    clk,
        input    rst_n
    );

endinterface
