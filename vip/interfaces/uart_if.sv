// ============================================================================
// File: uart_if.sv
// Description: UART Asynchronous Serial Interface for UVM VIP
// ============================================================================

`timescale 1ns / 1ps

interface uart_if (
    input wire clk,
    input wire rst_n
);

    logic tx;
    logic rx;
    logic irq;

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input tx, rx, irq;
    endclocking

    modport monitor (
        clocking monitor_cb,
        input    clk,
        input    rst_n
    );

    // TX Idle state must be logic 1
    property p_tx_idle_high;
        @(posedge clk) disable iff (!rst_n)
        $fell(rst_n) |=> tx == 1'b1;
    endproperty

endinterface
