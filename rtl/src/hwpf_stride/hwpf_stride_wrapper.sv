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
 *  Authors       : Riccardo Alidori, Cesar Fuguet
 *  Creation Date : June, 2021
 *  Description   : Linear Hardware Memory Prefetcher wrapper.
 *  History       :
 */
module hwpf_stride_wrapper
import hwpf_stride_pkg::*;
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter NUM_HW_PREFETCH = 4,
    parameter NUM_SNOOP_PORTS = 1
)
//  }}}

//  Ports
//  {{{
(
    input  logic                                       clk_i,
    input  logic                                       rst_ni,

    //  CSR
    //  {{{
    input  logic                  [NUM_HW_PREFETCH-1:0] hwpf_stride_base_set_i,
    input  hwpf_stride_base_t     [NUM_HW_PREFETCH-1:0] hwpf_stride_base_i,
    output hwpf_stride_base_t     [NUM_HW_PREFETCH-1:0] hwpf_stride_base_o,

    input  logic                  [NUM_HW_PREFETCH-1:0] hwpf_stride_param_set_i,
    input  hwpf_stride_param_t    [NUM_HW_PREFETCH-1:0] hwpf_stride_param_i,
    output hwpf_stride_param_t    [NUM_HW_PREFETCH-1:0] hwpf_stride_param_o,

    input  logic                  [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_set_i,
    input  hwpf_stride_throttle_t [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_i,
    output hwpf_stride_throttle_t [NUM_HW_PREFETCH-1:0] hwpf_stride_throttle_o,

    output hwpf_stride_status_t                         hwpf_stride_status_o,
    //  }}}

    // Snooping
    //  {{{
    input  logic               [NUM_SNOOP_PORTS-1:0]   snoop_valid_i,
    input  hpdcache_req_addr_t [NUM_SNOOP_PORTS-1:0]   snoop_addr_i,
    //  }}}

    //  DCache interface
    //  {{{
    input  hpdcache_req_sid_t                          dcache_req_sid_i,
    output logic                                       dcache_req_valid_o,
    input  logic                                       dcache_req_ready_i,
    output hpdcache_req_t                              dcache_req_o,
    input  logic                                       dcache_rsp_valid_i,
    input  hpdcache_rsp_t                              dcache_rsp_i
    //  }}}
);
//  }}}

    //  Internal signals
    //  {{{
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_enable;
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_free;
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_status_busy;
    logic            [3:0]                 hwpf_stride_status_free_idx;

    hpdcache_nline_t [NUM_HW_PREFETCH-1:0] snoop_addr;
    logic            [NUM_HW_PREFETCH-1:0] snoop_match;

    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_req_valid;
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_req_ready;
    hpdcache_req_t   [NUM_HW_PREFETCH-1:0] hwpf_stride_req;
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_arb_in_req_valid;
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_arb_in_req_ready;
    hpdcache_req_t   [NUM_HW_PREFETCH-1:0] hwpf_stride_arb_in_req;
    logic            [NUM_HW_PREFETCH-1:0] hwpf_stride_arb_in_rsp_valid;
    hpdcache_rsp_t   [NUM_HW_PREFETCH-1:0] hwpf_stride_arb_in_rsp;
    //  }}}

    //  Assertions
    //  {{{
    //  pragma translate_off
    initial
    begin
        max_hwpf_stride_assert: assert (NUM_HW_PREFETCH <= 16) else
                $error("hwpf_stride: maximum number of HW prefetchers is 16");
    end
    //  pragma translate_on
    //  }}}

    //  Compute the status information
    //  {{{
    always_comb begin: hwpf_stride_priority_encoder
        hwpf_stride_status_free_idx = '0;
        for (int unsigned i = 0; i < NUM_HW_PREFETCH; i++) begin
            if (hwpf_stride_free[i]) begin
                hwpf_stride_status_free_idx = i;
                break;
            end
        end
    end

    assign  hwpf_stride_free = ~(hwpf_stride_enable | hwpf_stride_status_busy);

    assign  hwpf_stride_status_o[63:32] = {{32-NUM_HW_PREFETCH{1'b0}}, hwpf_stride_status_busy}, // Busy flags
            hwpf_stride_status_o[31]    = |hwpf_stride_free,                                     // Global free flag
            hwpf_stride_status_o[30:16] = {11'b0, hwpf_stride_status_free_idx},                  // Free Index
            hwpf_stride_status_o[15:0]  = {{16-NUM_HW_PREFETCH{1'b0}}, hwpf_stride_enable};      // Enable flags
    //  }}}

    //  Hardware prefetcher engines
    //  {{{
    generate
        for (genvar i = 0; i < NUM_HW_PREFETCH; i++) begin
            assign hwpf_stride_enable[i] = hwpf_stride_base_o[i].enable;

            //  Compute snoop match signals
            //  {{{
            always_comb
            begin : snoop_comb
                snoop_match[i] = 1'b0;
                for (int j = 0; j < NUM_SNOOP_PORTS; j++) begin
                    automatic hpdcache_nline_t [NUM_SNOOP_PORTS-1:0] snoop_nline;
                    snoop_nline = snoop_addr_i[j][HPDCACHE_OFFSET_WIDTH +: HPDCACHE_NLINE_WIDTH];
                    snoop_match[i] |= (snoop_valid_i[j] && (snoop_nline == snoop_addr[i]));
                end
            end
            //  }}}

            hwpf_stride #(
                .CACHE_LINE_BYTES   ( HPDCACHE_CL_WIDTH/8 )
            ) hwpf_stride_i (
                .clk_i,
                .rst_ni,

                .csr_base_set_i     ( hwpf_stride_base_set_i[i] ),
                .csr_base_i         ( hwpf_stride_base_i[i] ),
                .csr_param_set_i    ( hwpf_stride_param_set_i[i] ),
                .csr_param_i        ( hwpf_stride_param_i[i] ),
                .csr_throttle_set_i ( hwpf_stride_throttle_set_i[i] ),
                .csr_throttle_i     ( hwpf_stride_throttle_i[i] ),

                .csr_base_o         ( hwpf_stride_base_o[i] ),
                .csr_param_o        ( hwpf_stride_param_o[i] ),
                .csr_throttle_o     ( hwpf_stride_throttle_o[i] ),

                .busy_o             ( hwpf_stride_status_busy[i] ),

                .snoop_addr_o       ( snoop_addr[i] ),
                .snoop_match_i      ( snoop_match[i] ),

                .dcache_req_valid_o ( hwpf_stride_req_valid[i] ),
                .dcache_req_ready_i ( hwpf_stride_req_ready[i] ),
                .dcache_req_o       ( hwpf_stride_req[i] ),
                .dcache_rsp_valid_i ( hwpf_stride_arb_in_rsp_valid[i]  ),
                .dcache_rsp_i       ( hwpf_stride_arb_in_rsp[i] )
            );

            assign hwpf_stride_req_ready[i]              = hwpf_stride_arb_in_req_ready[i],
                   hwpf_stride_arb_in_req_valid[i]       = hwpf_stride_req_valid[i],
                   hwpf_stride_arb_in_req[i].addr        = hwpf_stride_req[i].addr,
                   hwpf_stride_arb_in_req[i].wdata       = hwpf_stride_req[i].wdata,
                   hwpf_stride_arb_in_req[i].op          = hwpf_stride_req[i].op,
                   hwpf_stride_arb_in_req[i].be          = hwpf_stride_req[i].be,
                   hwpf_stride_arb_in_req[i].size        = hwpf_stride_req[i].size,
                   hwpf_stride_arb_in_req[i].uncacheable = hwpf_stride_req[i].uncacheable,
                   hwpf_stride_arb_in_req[i].sid         = dcache_req_sid_i,
                   hwpf_stride_arb_in_req[i].tid         = hpdcache_req_tid_t'(i),
                   hwpf_stride_arb_in_req[i].need_rsp    = hwpf_stride_req[i].need_rsp;
        end
    endgenerate
    //  }}}

    //  Hardware prefetcher arbiter betweem engines
    //  {{{
    hwpf_stride_arb #(
        .NUM_HW_PREFETCH          ( NUM_HW_PREFETCH )
    ) hwpf_stride_arb_i (
        .clk_i,
        .rst_ni,

        // DCache input interface
        .hwpf_stride_req_valid_i  ( hwpf_stride_arb_in_req_valid ),
        .hwpf_stride_req_ready_o  ( hwpf_stride_arb_in_req_ready ),
        .hwpf_stride_req_i        ( hwpf_stride_arb_in_req ),
        .hwpf_stride_rsp_valid_o  ( hwpf_stride_arb_in_rsp_valid ),
        .hwpf_stride_rsp_o        ( hwpf_stride_arb_in_rsp ),

        // DCache output interface
        .dcache_req_valid_o,
        .dcache_req_ready_i,
        .dcache_req_o,
        .dcache_rsp_valid_i,
        .dcache_rsp_i
    );
    //  }}}

endmodule
