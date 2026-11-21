// ============================================================================
// File: wb_seq_item.sv
// Description: Wishbone Transaction Sequence Item for UVM VIP
// ============================================================================

`ifndef WB_SEQ_ITEM_SV
`define WB_SEQ_ITEM_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class wb_seq_item extends uvm_sequence_item;

    typedef enum { READ, WRITE } op_type_e;

    rand bit [31:0]   addr;
    rand bit [31:0]   data;
    rand bit [3:0]    sel;
    rand op_type_e    op;
    rand int unsigned wait_cycles;

    // Response fields
    bit [31:0]        rsp_data;
    bit               error;

    `uvm_object_utils_begin(wb_seq_item)
        `uvm_field_int(addr, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(data, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(sel, UVM_ALL_ON | UVM_BIN)
        `uvm_field_enum(op_type_e, op, UVM_ALL_ON)
        `uvm_field_int(wait_cycles, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(rsp_data, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(error, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_align {
        addr[1:0] == 2'b00; // Word aligned by default
    }

    constraint c_sel {
        sel inside {4'b1111, 4'b0011, 4'b1100, 4'b0001, 4'b0010, 4'b0100, 4'b1000};
    }

    constraint c_wait {
        wait_cycles inside {[0:4]};
    }

    function new(string name = "wb_seq_item");
        super.new(name);
    endfunction

endclass

`endif
