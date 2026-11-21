// ============================================================================
// File: wb_sequencer.sv & wb_agent.sv
// Description: Wishbone Sequencer and Agent for UVM Verification
// ============================================================================

`ifndef WB_AGENT_SV
`define WB_AGENT_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

typedef uvm_sequencer #(wb_seq_item) wb_sequencer;

class wb_agent extends uvm_agent;
    `uvm_component_utils(wb_agent)

    wb_driver                        driver;
    wb_monitor                       monitor;
    wb_sequencer                     sequencer;
    uvm_analysis_port #(wb_seq_item) item_collected_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = wb_monitor::type_id::create("monitor", this);
        if (get_is_active() == UVM_ACTIVE) begin
            driver    = wb_driver::type_id::create("driver", this);
            sequencer = wb_sequencer::type_id::create("sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        item_collected_port = monitor.item_collected_port;
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass

`endif
