// ============================================================================
// File: wb_monitor.sv
// Description: Passive Wishbone Bus Monitor for UVM VIP
// Samples transactions and broadcasts them to analysis ports
// ============================================================================

`ifndef WB_MONITOR_SV
`define WB_MONITOR_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class wb_monitor extends uvm_monitor;
    `uvm_component_utils(wb_monitor)

    virtual wb_if vif;
    uvm_analysis_port #(wb_seq_item) item_collected_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual wb_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("WB_MON_NOVIF", "Virtual interface wb_if not found in config_db!")
        end
    endfunction

    task run_phase(uvm_phase phase);
        wb_seq_item trans;
        forever begin
            @(vif.monitor_cb);
            if (vif.monitor_cb.cyc && vif.monitor_cb.stb && vif.monitor_cb.ack) begin
                trans = wb_seq_item::type_id::create("trans");
                trans.addr     = vif.monitor_cb.adr;
                trans.sel      = vif.monitor_cb.sel;
                trans.op       = vif.monitor_cb.we ? wb_seq_item::WRITE : wb_seq_item::READ;
                trans.data     = vif.monitor_cb.we ? vif.monitor_cb.dat_m : vif.monitor_cb.dat_s;
                trans.rsp_data = vif.monitor_cb.dat_s;
                item_collected_port.write(trans);
            end
        end
    endtask

endclass

`endif
