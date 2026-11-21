// ============================================================================
// File: assertions.sv
// Description: SystemVerilog Assertions (SVA) and Protocol Verification Bindings
// Verifies Wishbone Handshake Integrity, AES Accelerator FSM, and Bus Liveness
// ============================================================================

`timescale 1ns / 1ps

module soc_assertions (
    input wire clk,
    input wire rst_n,

    // Bus signals
    input wire [31:0] wb_adr,
    input wire [31:0] wb_dat_w,
    input wire [31:0] wb_dat_r,
    input wire        wb_cyc,
    input wire        wb_stb,
    input wire        wb_we,
    input wire        wb_ack,

    // AES status
    input wire        aes_start,
    input wire        aes_busy,
    input wire        aes_done,
    input wire        aes_valid
);

`ifndef SYNTHESIS

    // ========================================================================
    // SVA 1: Wishbone Handshake Liveness (No Hanging Transactions)
    // ========================================================================
    property p_wb_ack_bounded;
        @(posedge clk) disable iff (!rst_n)
        (wb_cyc && wb_stb) |-> ##[1:64] wb_ack;
    endproperty
    assert_wb_ack_bounded: assert property (p_wb_ack_bounded)
        else $error("[SVA FAIL] Wishbone bus hung: no ACK within 64 clock cycles!");

    // ========================================================================
    // SVA 2: Bus Stability During Wait States
    // ========================================================================
    property p_wb_addr_stable;
        @(posedge clk) disable iff (!rst_n)
        (wb_cyc && wb_stb && !wb_ack) |=> ($stable(wb_adr) && $stable(wb_we));
    endproperty
    assert_wb_addr_stable: assert property (p_wb_addr_stable)
        else $error("[SVA FAIL] Bus address or control changed while awaiting ACK!");

    // ========================================================================
    // SVA 3: AES Accelerator Start-Busy Handshake
    // ========================================================================
    property p_aes_start_causes_busy;
        @(posedge clk) disable iff (!rst_n)
        aes_start |=> ##[1:2] aes_busy;
    endproperty
    assert_aes_start_causes_busy: assert property (p_aes_start_causes_busy)
        else $error("[SVA FAIL] AES accelerator did not enter BUSY state after START pulse!");

    // ========================================================================
    // SVA 4: AES Accelerator Done Implies Valid Output
    // ========================================================================
    property p_aes_done_implies_valid;
        @(posedge clk) disable iff (!rst_n)
        $rose(aes_done) |-> aes_valid;
    endproperty
    assert_aes_done_implies_valid: assert property (p_aes_done_implies_valid)
        else $error("[SVA FAIL] AES DONE asserted but VALID signal is low!");

    // ========================================================================
    // SVA 5: AES Busy Must Eventually Complete (Deterministic Bounded Latency)
    // ========================================================================
    property p_aes_busy_bounded;
        @(posedge clk) disable iff (!rst_n)
        $rose(aes_busy) |-> ##[1:32] aes_done;
    endproperty
    assert_aes_busy_bounded: assert property (p_aes_busy_bounded)
        else $error("[SVA FAIL] AES accelerator exceeded maximum 32-cycle execution bound!");

`endif

endmodule
