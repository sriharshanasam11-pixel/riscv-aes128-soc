// ============================================================================
// File: soc_env.sv
// Description: Top-Level UVM Verification Environment
// Integrates Bus Agents, VIP Monitors, Scoreboard, and Coverage Collectors
// ============================================================================

`ifndef SOC_ENV_SV
`define SOC_ENV_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "wb_seq_item.sv"
`include "wb_driver.sv"
`include "wb_monitor.sv"
`include "wb_agent.sv"
`include "soc_scoreboard.sv"
`include "soc_coverage.sv"

class soc_env extends uvm_env;
    `uvm_component_utils(soc_env)

    wb_agent       bus_agent;
    soc_scoreboard scoreboard;
    soc_coverage   coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        bus_agent  = wb_agent::type_id::create("bus_agent", this);
        scoreboard = soc_scoreboard::type_id::create("scoreboard", this);
        coverage   = soc_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        bus_agent.item_collected_port.connect(scoreboard.item_collected_export);
        bus_agent.item_collected_port.connect(coverage.analysis_export);
    endfunction

endclass

`endif
