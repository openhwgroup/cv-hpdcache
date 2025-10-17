/*
 *  Copyright 2023,2024 CEA*
 *  *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *  Copyright 2025 Inria, Universite Grenoble-Alpes, TIMA
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
 *  Authors       : Shaoqian Zhou
 *  Creation Date : Oct 3, 2025
 *  Description   : HPDcache cyclic replacement policy
 *  History       :
 */
module hpdcache_victim_cyclic
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    localparam type set_t        = logic [$clog2(HPDcacheCfg.u.sets)-1:0],
    localparam type way_vector_t = logic [HPDcacheCfg.u.ways-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //      Update interface
    input  logic                  updt_i, /* unused */
    input  set_t                  updt_set_i, /* unused */
    input  way_vector_t           updt_way_i, /* unused */

    //      Victim selection interface
    input  logic                  sel_victim_i,
    input  way_vector_t           sel_dir_valid_i,
    input  way_vector_t           sel_dir_wback_i, /* unused */
    input  way_vector_t           sel_dir_dirty_i,
    input  way_vector_t           sel_dir_fetch_i,
    input  set_t                  sel_victim_set_i, /* unused */
    output way_vector_t           sel_victim_way_o
);
    //  }}}

    //  Internal signals and registers
    //  {{{
    logic         unused_available, clean_available, dirty_available;
    way_vector_t  unused_ways;
    way_vector_t  unused_victim_way;
    logic         [HPDcacheCfg.wayIndexWidth-1:0] cyclic_ptr;
    logic         cyclic_available;
    way_vector_t  cyclic_victim_way;
    way_vector_t  clean_ways, dirty_ways;
    way_vector_t  clean_victim_way, dirty_victim_way;
    //  }}}

    //  Victim way selection
    //  {{{
    assign unused_ways = ~sel_dir_fetch_i & ~sel_dir_valid_i;
    assign clean_ways  = ~sel_dir_fetch_i &  sel_dir_valid_i & ~sel_dir_dirty_i;
    assign dirty_ways  = ~sel_dir_fetch_i &  sel_dir_valid_i &  sel_dir_dirty_i;

    hpdcache_prio_1hot_encoder #(.N(HPDcacheCfg.u.ways))
        unused_victim_select_i(
            .val_i     (unused_ways),
            .val_o     (unused_victim_way)
        );


    hpdcache_prio_1hot_encoder #(.N(HPDcacheCfg.u.ways))
        clean_victim_select_i(
            .val_i     (clean_ways),
            .val_o     (clean_victim_way)
        );

    hpdcache_prio_1hot_encoder #(.N(HPDcacheCfg.u.ways))
        dirty_victim_select_i(
            .val_i     (dirty_ways),
            .val_o     (dirty_victim_way)
        );

    hpdcache_decoder #(.N(HPDcacheCfg.wayIndexWidth))
        cyclic_way_decoder_i(
            .en_i      (1'b1),
            .val_i     (cyclic_ptr),
            .val_o     (cyclic_victim_way)
        );

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : cyclic_pointer_seq
        if (!rst_ni)
        begin
            cyclic_ptr <= '0;
        end
        // Increment the pointer only when a victim is selected AND
        // there are no invalid ways to choose from. This prevents
        // the pointer from advancing unnecessarily.
        else if (sel_victim_i & ~unused_available)
        begin
            cyclic_ptr <= cyclic_ptr + 1'b1;
        end
    end


    assign unused_available = |unused_ways;
    assign clean_available  = |clean_ways;
    assign dirty_available  = |dirty_ways;
    assign cyclic_available = | (cyclic_victim_way & ~sel_dir_fetch_i & sel_dir_valid_i);

    always_comb
    begin : victim_way_selection_comb
        priority case (1'b1)
            unused_available: sel_victim_way_o = unused_victim_way;   // use invalid way if any
            cyclic_available: sel_victim_way_o = cyclic_victim_way;   // use cyclic way if available
            clean_available:  sel_victim_way_o = clean_victim_way;    // fallback to clean way if any
            dirty_available:  sel_victim_way_o = dirty_victim_way;
            default:          sel_victim_way_o = '0;
        endcase
    end
    //  }}}

endmodule
