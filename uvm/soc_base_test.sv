// ============================================================================
// File: soc_base_test.sv & aes_kat_test.sv
// Description: UVM Test Cases for System-on-Chip Verification
// ============================================================================

`ifndef SOC_TESTS_SV
`define SOC_TESTS_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "soc_env.sv"

// ----------------------------------------------------------------------------
// Base Test
// ----------------------------------------------------------------------------
class soc_base_test extends uvm_test;
    `uvm_component_utils(soc_base_test)

    soc_env env;

    function new(string name = "soc_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

endclass

// ----------------------------------------------------------------------------
// AES NIST KAT Directed Test
// ----------------------------------------------------------------------------
class aes_kat_test extends soc_base_test;
    `uvm_component_utils(aes_kat_test)

    function new(string name = "aes_kat_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        wb_seq_item item;
        phase.raise_objection(this);

        `uvm_info("AES_KAT_TEST", ">>> Starting NIST FIPS-197 Known Answer Test via UVM <<<", UVM_LOW)

        // 1. Program NIST Key (00010203 04050607 08090a0b 0c0d0e0f)
        write_reg(32'h4000_3008, 32'h00010203);
        write_reg(32'h4000_300C, 32'h04050607);
        write_reg(32'h4000_3010, 32'h08090a0b);
        write_reg(32'h4000_3014, 32'h0c0d0e0f);

        // 2. Program NIST Plaintext (00112233 44556677 8899aabb ccddeeff)
        write_reg(32'h4000_3018, 32'h00112233);
        write_reg(32'h4000_301C, 32'h44556677);
        write_reg(32'h4000_3020, 32'h8899aabb);
        write_reg(32'h4000_3024, 32'hccddeeff);

        // 3. Trigger Encryption (AES_CTRL = 1)
        write_reg(32'h4000_3000, 32'h00000001);

        // 4. Poll AES_STATUS until DONE
        poll_status(32'h4000_3004, 32'h2);

        // 5. Read back Ciphertext (Scoreboard automatically verifies)
        read_reg(32'h4000_3028);
        read_reg(32'h4000_302C);
        read_reg(32'h4000_3030);
        read_reg(32'h4000_3034);

        #100ns;
        phase.drop_objection(this);
    endtask

    task write_reg(bit [31:0] addr, bit [31:0] data);
        wb_seq_item item = wb_seq_item::type_id::create("item");
        item.addr = addr;
        item.data = data;
        item.sel  = 4'b1111;
        item.op   = wb_seq_item::WRITE;
        item.wait_cycles = 1;
        env.bus_agent.driver.drive_transaction(item);
    endtask

    task read_reg(bit [31:0] addr);
        wb_seq_item item = wb_seq_item::type_id::create("item");
        item.addr = addr;
        item.sel  = 4'b1111;
        item.op   = wb_seq_item::READ;
        item.wait_cycles = 1;
        env.bus_agent.driver.drive_transaction(item);
    endtask

    task poll_status(bit [31:0] addr, bit [31:0] bitmask);
        wb_seq_item item;
        bit done = 0;
        while (!done) begin
            item = wb_seq_item::type_id::create("poll_item");
            item.addr = addr;
            item.sel  = 4'b1111;
            item.op   = wb_seq_item::READ;
            env.bus_agent.driver.drive_transaction(item);
            if ((item.rsp_data & bitmask) != 0) done = 1;
        end
    endtask

endclass

`endif
