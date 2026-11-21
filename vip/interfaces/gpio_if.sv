// ============================================================================
// File: gpio_if.sv
// Description: GPIO Controller Verification Interface
// ============================================================================

`timescale 1ns / 1ps

interface gpio_if (
    input wire clk,
    input wire rst_n
);

    logic [31:0] pins_in;
    logic [31:0] pins_out;
    logic [31:0] pins_dir;

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input pins_in, pins_out, pins_dir;
    endclocking

    modport monitor (
        clocking monitor_cb,
        input    clk,
        input    rst_n
    );

endinterface
