// ============================================================================
// File: wb_driver.sv
// Description: Wishbone Master Driver for UVM VIP
// Drives bus transactions onto the physical wb_if interface
// ============================================================================

`ifndef WB_DRIVER_SV
`define WB_DRIVER_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class wb_driver extends uvm_driver #(wb_seq_item);
    `uvm_component_utils(wb_driver)

    virtual wb_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual wb_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("WB_DRV_NOVIF", "Virtual interface wb_if not found in config_db!")
        end
    endfunction

    task run_phase(uvm_phase phase);
        reset_signals();
        forever begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask

    task reset_signals();
        @(posedge vif.clk);
        vif.master_cb.adr   <= 32'h0;
        vif.master_cb.dat_m <= 32'h0;
        vif.master_cb.sel   <= 4'h0;
        vif.master_cb.we    <= 1'b0;
        vif.master_cb.cyc   <= 1'b0;
        vif.master_cb.stb   <= 1'b0;
    endtask

    task drive_transaction(wb_seq_item item);
        // Inter-transaction wait states
        repeat (item.wait_cycles) @(vif.master_cb);

        vif.master_cb.adr   <= item.addr;
        vif.master_cb.sel   <= item.sel;
        vif.master_cb.cyc   <= 1'b1;
        vif.master_cb.stb   <= 1'b1;

        if (item.op == wb_seq_item::WRITE) begin
            vif.master_cb.we    <= 1'b1;
            vif.master_cb.dat_m <= item.data;
        end else begin
            vif.master_cb.we    <= 1'b0;
        end

        // Wait for ACK
        @(vif.master_cb);
        while (!vif.master_cb.ack) begin
            @(vif.master_cb);
        end

        if (item.op == wb_seq_item::READ) begin
            item.rsp_data = vif.master_cb.dat_s;
        end

        // End bus cycle
        vif.master_cb.cyc <= 1'b0;
        vif.master_cb.stb <= 1'b0;
        vif.master_cb.we  <= 1'b0;
    endtask

endclass

`endif
