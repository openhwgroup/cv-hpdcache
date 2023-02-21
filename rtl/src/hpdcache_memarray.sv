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
 *  Creation Date : April, 2021
 *  Description   : HPDcache Directory and Data Memory Arrays
 *  History       :
 */
module hpdcache_memarray
import hpdcache_pkg::*;
    //  Ports
    //  {{{
(
    input  wire logic                                    clk_i,
    input  wire logic                                    rst_ni,

    input  wire hpdcache_dir_addr_t                      dir_addr_i,
    input  wire hpdcache_way_vector_t                    dir_cs_i,
    input  wire hpdcache_way_vector_t                    dir_we_i,
    input  wire hpdcache_dir_entry_t [HPDCACHE_WAYS-1:0] dir_wmask_i,
    input  wire hpdcache_dir_entry_t [HPDCACHE_WAYS-1:0] dir_wentry_i,
    output wire hpdcache_dir_entry_t [HPDCACHE_WAYS-1:0] dir_rentry_o,

    input  wire hpdcache_data_addr_t                     data_addr_i,
    input  wire hpdcache_data_enable_t                   data_cs_i,
    input  wire hpdcache_data_enable_t                   data_we_i,
    input  wire hpdcache_data_entry_t                    data_wmask_i,
    input  wire hpdcache_data_entry_t                    data_wentry_i,
    output wire hpdcache_data_entry_t                    data_rentry_o
);
    //  }}}

    //  Memory arrays
    //  {{{
    generate
        genvar x, y, w;

        //  Directory
        //
        for (w = 0; w < int'(HPDCACHE_WAYS); w++) begin
            hpdcache_sram_wmask #(
                .DATA_SIZE (HPDCACHE_DIR_RAM_WIDTH),
                .ADDR_SIZE (HPDCACHE_DIR_RAM_ADDR_WIDTH)
            ) dir_sram (
                .clk       (clk_i),
                .rst_n     (rst_ni),
                .cs        (dir_cs_i[w]),
                .we        (dir_we_i[w]),
                .addr      (dir_addr_i),
                .wdata     (dir_wentry_i[w]),
                .wmask     (dir_wmask_i[w]),
                .rdata     (dir_rentry_o[w])
            );
        end

        //  Data
        //
        for (y = 0; y < int'(HPDCACHE_DATA_RAM_Y_CUTS); y++) begin
            for (x = 0; x < int'(HPDCACHE_DATA_RAM_X_CUTS); x++) begin
                hpdcache_sram_wmask #(
                    .DATA_SIZE (HPDCACHE_DATA_RAM_WIDTH),
                    .ADDR_SIZE (HPDCACHE_DATA_RAM_ADDR_WIDTH)
                ) data_sram (
                    .clk       (clk_i),
                    .rst_n     (rst_ni),
                    .cs        (data_cs_i[y][x]),
                    .we        (data_we_i[y][x]),
                    .addr      (data_addr_i[y][x]),
                    .wdata     (data_wentry_i[y][x]),
                    .wmask     (data_wmask_i[y][x]),
                    .rdata     (data_rentry_o[y][x])
                );
            end
        end
    endgenerate
    //  }}}
endmodule
