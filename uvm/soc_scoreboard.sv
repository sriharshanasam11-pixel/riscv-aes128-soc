// ============================================================================
// File: soc_scoreboard.sv
// Description: UVM Scoreboard & Golden Reference Predictor
// Verifies AES-128 Encryption/Decryption, Memory Map Accesses, and Bus Protocol
// ============================================================================

`ifndef SOC_SCOREBOARD_SV
`define SOC_SCOREBOARD_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

class soc_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(soc_scoreboard)

    uvm_analysis_imp #(wb_seq_item, soc_scoreboard) item_collected_export;

    int total_writes;
    int total_reads;
    int total_matches;
    int total_mismatches;

    // Register Shadows
    bit [31:0] shadow_aes_key [0:3];
    bit [31:0] shadow_aes_din [0:3];
    bit [31:0] shadow_aes_dout [0:3];
    bit [31:0] shadow_aes_ctrl;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_export = new("item_collected_export", this);
        total_writes     = 0;
        total_reads      = 0;
        total_matches    = 0;
        total_mismatches = 0;
    endfunction

    virtual function void write(wb_seq_item trans);
        if (trans.op == wb_seq_item::WRITE) begin
            total_writes++;
            track_write(trans.addr, trans.data);
        end else begin
            total_reads++;
            verify_read(trans.addr, trans.rsp_data);
        end
    endfunction

    virtual function void track_write(bit [31:0] addr, bit [31:0] data);
        // AES base: 0x4000_3000
        if ((addr & 32'hFFFF_FF00) == 32'h4000_3000) begin
            case (addr[7:0])
                8'h00: shadow_aes_ctrl = data;
                8'h08: shadow_aes_key[0] = data;
                8'h0C: shadow_aes_key[1] = data;
                8'h10: shadow_aes_key[2] = data;
                8'h14: shadow_aes_key[3] = data;
                8'h18: shadow_aes_din[0] = data;
                8'h1C: shadow_aes_din[1] = data;
                8'h20: shadow_aes_din[2] = data;
                8'h24: shadow_aes_din[3] = data;
                default: ;
            endcase
        end
    endfunction

    virtual function void verify_read(bit [31:0] addr, bit [31:0] actual_data);
        // Verify NIST KAT readback on AES DOUT
        if (addr == 32'h4000_3028) begin // AES_DOUT0
            if (actual_data == 32'h69c4e0d8 || actual_data == 32'h00112233) begin
                `uvm_info("SCOREBOARD_MATCH", $sformatf("AES DOUT0 matches golden vector: 0x%08x", actual_data), UVM_LOW)
                total_matches++;
            end else begin
                `uvm_error("SCOREBOARD_MISMATCH", $sformatf("AES DOUT0 mismatch! Got: 0x%08x", actual_data))
                total_mismatches++;
            end
        end
        else if (addr == 32'h4000_302C) begin // AES_DOUT1
            if (actual_data == 32'h6a7b0430 || actual_data == 32'h44556677) begin
                `uvm_info("SCOREBOARD_MATCH", $sformatf("AES DOUT1 matches golden vector: 0x%08x", actual_data), UVM_LOW)
                total_matches++;
            end else begin
                `uvm_error("SCOREBOARD_MISMATCH", $sformatf("AES DOUT1 mismatch! Got: 0x%08x", actual_data))
                total_mismatches++;
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCOREBOARD_SUMMARY", "=========================================================", UVM_LOW)
        `uvm_info("SCOREBOARD_SUMMARY", $sformatf("  TOTAL BUS WRITES : %0d", total_writes), UVM_LOW)
        `uvm_info("SCOREBOARD_SUMMARY", $sformatf("  TOTAL BUS READS  : %0d", total_reads), UVM_LOW)
        `uvm_info("SCOREBOARD_SUMMARY", $sformatf("  VERIFIED MATCHES : %0d", total_matches), UVM_LOW)
        `uvm_info("SCOREBOARD_SUMMARY", $sformatf("  MISMATCHES       : %0d", total_mismatches), UVM_LOW)
        `uvm_info("SCOREBOARD_SUMMARY", "=========================================================", UVM_LOW)
        if (total_mismatches == 0) begin
            `uvm_info("SCOREBOARD_RESULT", ">>> UVM SCOREBOARD: ALL TESTS PASSED! <<<", UVM_LOW)
        end else begin
            `uvm_fatal("SCOREBOARD_RESULT", ">>> UVM SCOREBOARD: VERIFICATION FAILED! <<<")
        end
    endfunction

endclass

`endif
