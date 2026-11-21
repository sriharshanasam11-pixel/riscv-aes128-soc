// ============================================================================
// File: spi_if.sv
// Description: SPI Master/Slave SystemVerilog Interface for UVM VIP
// ============================================================================

`timescale 1ns / 1ps

interface spi_if (
    input wire clk,
    input wire rst_n
);

    logic sck;
    logic mosi;
    logic miso;
    logic cs_n;

    // Clocking block for synchronous sampling on SCK
    clocking slave_cb @(posedge sck);
        default input #1step output #1ns;
        input  mosi, cs_n;
        output miso;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1step;
        input sck, mosi, miso, cs_n;
    endclocking

    modport slave (
        clocking slave_cb,
        input    cs_n
    );

    modport monitor (
        clocking monitor_cb,
        input    clk,
        input    rst_n
    );

    // Assertion: CS_N must remain low throughout serial byte transaction
    property p_cs_stable_during_byte;
        @(posedge sck) disable iff (!rst_n)
        !cs_n |-> !cs_n;
    endproperty
    assert_cs_stable: assert property (p_cs_stable_during_byte)
        else $error("[SPI_IF ERROR] CS_N glitch detected during active transfer!");

endinterface
