// ============================================================================
// File: soc_coverage.sv
// Description: UVM Functional Coverage Model & Covergroups
// Tracks Memory Map Distribution, Peripheral Accesses, and Cryptographic Modes
// ============================================================================

`ifndef SOC_COVERAGE_SV
`define SOC_COVERAGE_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class soc_coverage extends uvm_subscriber #(wb_seq_item);
    `uvm_component_utils(soc_coverage)

    wb_seq_item cur_trans;

    // Covergroup 1: Address Map & Peripheral Space Coverage
    covergroup cg_address_map;
        option.per_instance = 1;
        option.name = "cg_address_map";

        cp_subsystem: coverpoint cur_trans.addr {
            bins rom_space    = {[32'h0000_0000 : 32'h0000_3FFF]};
            bins ram_space    = {[32'h2000_0000 : 32'h2000_3FFF]};
            bins uart_space   = {[32'h4000_0000 : 32'h4000_00FF]};
            bins timer_space  = {[32'h4000_1000 : 32'h4000_10FF]};
            bins gpio_space   = {[32'h4000_2000 : 32'h4000_20FF]};
            bins aes_space    = {[32'h4000_3000 : 32'h4000_30FF]};
            bins prng_space   = {[32'h4000_4000 : 32'h4000_40FF]};
            bins spi_space    = {[32'h4000_5000 : 32'h4000_50FF]};
        }

        cp_operation: coverpoint cur_trans.op {
            bins read_op  = {wb_seq_item::READ};
            bins write_op = {wb_seq_item::WRITE};
        }

        cp_byte_lanes: coverpoint cur_trans.sel {
            bins full_word = {4'b1111};
            bins half_word = {4'b0011, 4'b1100};
            bins byte_lane = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
        }

        // Cross coverage
        cross_subsystem_op: cross cp_subsystem, cp_operation;

    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_address_map = new();
    endfunction

    virtual function void write(wb_seq_item t);
        cur_trans = t;
        cg_address_map.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COVERAGE_REPORT", $sformatf("Address Map Functional Coverage: %0.2f%%", cg_address_map.get_coverage()), UVM_LOW)
    endfunction

endclass

`endif
