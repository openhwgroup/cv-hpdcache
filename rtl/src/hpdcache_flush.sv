/*
 *  Copyright 2024 CEA*
 *  *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 *  Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 *  may not use this file except in compliance with the License, or, at your
 *  option, the Apache License version 2.0. You may obtain a copy of the
 *  License at
 *
 *  https://solderpad.org/licenses/SHL-2.1/
 *
 *  Unless required by applicable law or agreed to in writing, any work
 *  distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 *  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 *  License for the specific language governing permissions and limitations
 *  under the License.
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : September, 2024
 *  Description   : HPDcache Flush Controller
 *  History       :
 */
module hpdcache_flush_controller
//  {{{
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0

    parameter type hpdcache_nline_t = logic,

    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,
)
//  }}}

//  Ports
//  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //      Global control signals
    //      {{{
    output logic                  flush_empty_o,
    output logic                  flush_full_o,
    output logic                  flush_busy_o,
    //      }}}

    //      CHECK interface
    //      {{{
    input  logic                  flush_check_i,
    input  hpdcache_nline_t       flush_check_nline_i,
    output logic                  flush_check_hit_o,
    //      }}}

    //      ALLOC interface
    //      {{{
    input  logic                  flush_alloc_i,
    input  hpdcache_nline_t       flush_alloc_nline_i,
    //      }}}

    //      MEMORY interface
    //      {{{
    input  logic                  mem_req_write_ready_i,
    output logic                  mem_req_write_valid_o,
    output hpdcache_mem_req_t     mem_req_write_o,

    input  logic                  mem_req_write_data_ready_i,
    output logic                  mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t   mem_req_write_data_o,

    output logic                  mem_resp_write_ready_o,
    input  logic                  mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t  mem_resp_write_i
    //      }}}
);

    //  Definition of constants and types
    //  {{{
    localparam int unsigned N = HPDcacheCfg.u.flushEntries;

    typedef struct packed {
        hpdcache_nline_t nline;
    } flush_entry_t;

    typedef flush_entry_t [N-1:0] flush_directory_t;

    typedef enum logic {
        FLUSH_IDLE = 1'b0,
        FLUSH_SEND = 1'b1
    } flush_fsm_e;
    //  }}}

    //  Definition of internal signals and registers
    //  {{{
    logic [N-1:0]     flush_dir_valid_q;
    flush_directory_t flush_dir_q;
    logic [N-1:0]     flush_dir_free_ptr_bv;
    logic [N-1:0]     flush_dir_free_ptr;
    flush_fsm_e       flush_fsm_q, flush_fsm_d;

    logic flush_eop;
    logic flush_alloc;
    logic flush_resizer_ready;
    //  }}}

    //  Flush FSM
    //  {{{
    always_comb
    begin : flush_fsm_comb
        flush_fsm_d = flush_fsm_q;

        unique case (flush_fsm_q)
            FLUSH_IDLE: begin
                if (flush_alloc_i && !flush_full_o) begin
                    flush_fsm_d = FLUSH_SEND;
                end
            end
            FLUSH_SEND: begin
                if (flush_resizer_ready && mem_req_write_ready_i && flush_eop) begin
                    flush_fsm_d = FLUSH_IDLE;
                end
            end
        endcase
    end
    //  }}}

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : flush_fsm_ff
        if (!rst_ni) begin
            flush_fsm_q <= FLUSH_IDLE;
        end else begin
            flush_fsm_q <= flush_fsm_d;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : flush_dir_ff
        if (!rst_ni) begin
            flush_dir_q <= '0;
        end else begin
            if (flush_alloc) begin
                flush_dir_q[flush_dir_free_ptr] <= '{
                    nline: flush_alloc_nline_i
                };
            end
        end
    end

    //  Select a free entry in the flush directory
    hpdcache_fxarb #(.N(N)) flush_dir_free_arb_i(
        .clk_i,
        .rst_ni,
        .req_i   (flush_dir_valid_q),
        .gnt_o   (flush_dir_free_ptr_bv),
        .ready_i (flush_alloc)
    );
    hpdcache_1hot_to_binary #(.N (N)) flush_dir_free_ptr_bin_i(
        .val_i   (flush_dir_free_ptr_bv),
        .val_o   (flush_dir_free_ptr)
    );

endmodule
