// ============================================================================
// File: timer_if.sv
// Description: System Timer Verification Interface
// ============================================================================

`timescale 1ns / 1ps

interface timer_if (
    input wire clk,
    input wire rst_n
);

    logic [31:0] count;
    logic [31:0] compare;
    logic [31:0] ctrl;
    logic [15:0] prescale;
    logic        irq;

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input count, compare, ctrl, prescale, irq;
    endclocking

    modport monitor (
        clocking monitor_cb,
        input    clk,
        input    rst_n
    );

endinterface
