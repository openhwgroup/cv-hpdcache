/*
 *  Copyright 2023 CEA*
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
 *  Creation Date : Mars, 2024
 *  Description   : HPDcache Victim Selection
 *  History       :
 */
module hpdcache_victim_sel
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_way_vector_t = logic
)
//  }}}

//  Ports
//  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //      Victim policy update interface
    input  logic                  updt_i,
    input  hpdcache_set_t         updt_set_i,
    input  hpdcache_way_vector_t  updt_way_i,

    //      Victim policy replacement interface
    input  logic                  repl_i,
    input  hpdcache_set_t         repl_set_i,
    input  hpdcache_way_vector_t  repl_way_i,

    //      Victim selection interface
    input  logic                  sel_victim_i,
    input  hpdcache_way_vector_t  sel_dir_valid_i,
    input  hpdcache_way_vector_t  sel_dir_wback_i,
    input  hpdcache_way_vector_t  sel_dir_dirty_i,
    input  hpdcache_way_vector_t  sel_dir_fetch_i,
    output hpdcache_way_vector_t  sel_victim_way_o
);
//  }}}

    //  -----------------------------------------------------------------------
    //  Direct mapped cache (one way)
    if (HPDcacheCfg.u.ways == 1)
    begin : gen_single_way_victim_sel
        assign sel_victim_way_o = 1'b1;
    end

    //  -----------------------------------------------------------------------
    //  Set-associative cache with pseudo random victim selection
    else if (HPDcacheCfg.u.victimSel == HPDCACHE_VICTIM_RANDOM)
    begin : gen_random_victim_sel
        hpdcache_way_vector_t unused_victim_way;
        hpdcache_way_vector_t random_victim_way;
        hpdcache_way_vector_t unused_ways;

        logic [7:0] lfsr_val;
        logic sel_random;

        assign unused_ways = ~sel_dir_valid_i;
        assign sel_random = ~|unused_ways;

        always_comb
        begin : random_way_comb
            for (int i = 0; i < HPDcacheCfg.u.ways; i++) begin
                random_victim_way[i] = (i == (lfsr_val % HPDcacheCfg.u.ways));
            end
        end

        always_comb
        begin : victim_way_comb
            unique case (1'b1)
                sel_random: sel_victim_way_o = random_victim_way;
                default:    sel_victim_way_o = unused_victim_way;
            endcase
        end

        hpdcache_lfsr #(
            .WIDTH               (8)
        ) lfsr_i(
            .clk_i,
            .rst_ni,
            .shift_i             (sel_victim_i & sel_random),
            .val_o               (lfsr_val)
        );

        hpdcache_prio_1hot_encoder #(
            .N                   (HPDcacheCfg.u.ways)
        ) unused_victim_select_i(
            .val_i               (unused_ways),
            .val_o               (unused_victim_way)
        );
    end

    //  -----------------------------------------------------------------------
    //  Set-associative cache with pseudo least-recently-used victim selection
    else if (HPDcacheCfg.u.victimSel == HPDCACHE_VICTIM_PLRU)
    begin : gen_plru_victim_sel
        hpdcache_plru #(
            .SETS                (HPDcacheCfg.u.sets),
            .WAYS                (HPDcacheCfg.u.ways)
        ) plru_i(
            .clk_i,
            .rst_ni,

            .updt_i,
            .updt_set_i,
            .updt_way_i,

            .repl_i,
            .repl_set_i,
            .repl_way_i,

            .sel_dir_valid_i,
            .sel_dir_wback_i,
            .sel_dir_dirty_i,
            .sel_dir_fetch_i,
            .sel_victim_way_o
        );
    end

`ifndef HPDCACHE_ASSERT_OFF
    initial victim_sel_assert:
            assert (HPDcacheCfg.u.victimSel inside {HPDCACHE_VICTIM_RANDOM, HPDCACHE_VICTIM_PLRU})
                    else $fatal("unsupported victim selection policy");
`endif

endmodule
