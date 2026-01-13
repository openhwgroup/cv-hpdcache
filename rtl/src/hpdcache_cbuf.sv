// Copyright (c) 2025 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.1 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.1. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

//
// Authors       : Riccardo Tedeschi
// Creation Date : April, 2025
// Description   : Coalesce buffer
// History       :
//

module hpdcache_cbuf
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type hpdcache_req_data_t   = logic,
    parameter type hpdcache_req_be_t     = logic,
    parameter type cbuf_id_t             = logic
)
    //  }}}

    //  Ports
    //  {{{
(
    input  logic               clk_i,
    input  logic               rst_ni,
    input  logic               alloc_i,
    input  hpdcache_req_data_t alloc_wdata_i,
    input  hpdcache_req_be_t   alloc_be_i,
    output cbuf_id_t           alloc_id_o,
    output logic               alloc_full_o,
    input  logic               ack_i,
    input  cbuf_id_t           ack_id_i,
    output hpdcache_req_data_t ack_wdata_o,
    output hpdcache_req_be_t   ack_be_o
);
    //  }}}

    typedef struct packed {
        hpdcache_req_data_t wdata;
        hpdcache_req_be_t   be;
    } cbuf_entry_t;

    cbuf_entry_t [HPDcacheCfg.u.cbufEntries-1:0] entries_q, entries_d;
    logic        [HPDcacheCfg.u.cbufEntries-1:0] valid_q, valid_d;

    assign alloc_full_o = &valid_q;

    assign ack_wdata_o = entries_q[ack_id_i].wdata;
    assign ack_be_o    = entries_q[ack_id_i].be;

    always_comb begin
        valid_d   = valid_q;
        entries_d = entries_q;

        if (ack_i) begin
            valid_d[ack_id_i] = 1'b0;
        end

        if (alloc_i) begin
            valid_d  [alloc_id_o]       = 1'b1;
            entries_d[alloc_id_o].wdata = alloc_wdata_i;
            entries_d[alloc_id_o].be    = alloc_be_i;
        end
    end

    hpdcache_prio_bin_encoder #(
        .N (HPDcacheCfg.u.cbufEntries)
    ) cbuf_prio_bin_encoder_i (
        .val_i (~valid_q),
        .val_o (alloc_id_o)
    );

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            entries_q <= '0;
            valid_q <= '0;
        end else begin
            entries_q <= entries_d;
            valid_q <= valid_d;
        end
    end

endmodule
