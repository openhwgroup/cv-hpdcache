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
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //      Victim selection update interface
    input  logic                  updt_i,
    input  hpdcache_set_t         updt_set_i,
    input  hpdcache_way_vector_t  updt_way_i,

    //      Victim replacement interface
    input  logic                  repl_i,
    input  hpdcache_set_t         repl_set_i,
    input  hpdcache_way_vector_t  repl_dir_valid_i,
    input  logic                  repl_updt_i,

    output hpdcache_way_vector_t  victim_way_o
);

if (HPDCACHE_WAYS == 1) begin : single_way_victim_sel_gen
    assign victim_way_o = 1'b1;

end else if (HPDCACHE_VICTIM_SEL == HPDCACHE_VICTIM_RANDOM) begin : random_victim_sel_gen
    hpdcache_way_vector_t random_victim_way;
    hpdcache_way_vector_t unused_victim_way;
    logic [7:0] lfsr_val;
    logic sel_random;

    assign sel_random = ~(|unused_victim_way);

    hpdcache_lfsr #(
        .WIDTH               (8)
    ) lfsr_i(
        .clk_i,
        .rst_ni,
        .shift_i             (repl_i & sel_random),
        .val_o               (lfsr_val)
    );

    always_comb
    begin : random_way_encoder_comb
        random_victim_way = '0;
        for (int i = 0; i < HPDCACHE_WAYS; i++) begin
            random_victim_way[i] = (i == (lfsr_val % HPDCACHE_WAYS));
        end
    end

    hpdcache_prio_1hot_encoder #(
        .N(HPDCACHE_WAYS)
    ) unused_victim_select_i(
        .val_i     (~repl_dir_valid_i),
        .val_o     (unused_victim_way)
    );

    assign victim_way_o = sel_random ? random_victim_way : unused_victim_way;

end else if (HPDCACHE_VICTIM_SEL == HPDCACHE_VICTIM_PLRU) begin : plru_victim_sel_gen
    hpdcache_plru #(
        .SETS                (HPDCACHE_SETS),
        .WAYS                (HPDCACHE_WAYS)
    ) plru_i(
        .clk_i,
        .rst_ni,

        .updt_i,
        .updt_set_i,
        .updt_way_i,

        .repl_i,
        .repl_set_i,
        .repl_dir_valid_i,
        .repl_updt_plru_i    (repl_updt_i),

        .victim_way_o
    );
end

`ifndef HPDCACHE_ASSERT_OFF
    initial victim_sel_assert:
            assert (HPDCACHE_VICTIM_SEL inside {HPDCACHE_VICTIM_RANDOM, HPDCACHE_VICTIM_PLRU}) else
                    $fatal("unsupported victim selection policy");
`endif

endmodule
