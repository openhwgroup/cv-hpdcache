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
 *  Creation Date : June, 2022
 *  Description   : CVA6 cache subsystem integrating standard CVA6's
 *                  instruction cache and the Core-V High-Performance L1
*                   data cache (CV-HPDcache).
 *  History       :
 */
module cva6_hpdcache_subsystem import ariane_pkg::*; import wt_cache_pkg::*; import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
  parameter ariane_pkg::ariane_cfg_t ArianeCfg = ariane_pkg::ArianeDefaultConfig,  // contains cacheable regions
  parameter int NrHwPrefetchers = 4,
  parameter int unsigned AxiAddrWidth = 0,
  parameter int unsigned AxiDataWidth = 0,
  parameter int unsigned AxiIdWidth = 0,
  parameter int unsigned AxiUserWidth = 0,
  parameter type axi_ar_chan_t = logic,
  parameter type axi_aw_chan_t = logic,
  parameter type axi_w_chan_t = logic,
  parameter type axi_req_t = logic,
  parameter type axi_rsp_t = logic,
  parameter type cmo_req_t = logic,
  parameter type cmo_rsp_t = logic
)
//  }}}

//  Ports
//  {{{
(
  input  logic                       clk_i,
  input  logic                       rst_ni,

  //  I$
  //  {{{
  input  logic                       icache_en_i,            // enable icache (or bypass e.g: in debug mode)
  input  logic                       icache_flush_i,         // flush the icache, flush and kill have to be asserted together
  output logic                       icache_miss_o,          // to performance counter
  // address translation requests
  input  ariane_pkg::icache_areq_i_t icache_areq_i,          // to/from frontend
  output ariane_pkg::icache_areq_o_t icache_areq_o,
  // data requests
  input  ariane_pkg::icache_dreq_i_t icache_dreq_i,          // to/from frontend
  output ariane_pkg::icache_dreq_o_t icache_dreq_o,
  //   }}}

  //  D$
  //  {{{
  //    Cache management
  input  logic                       dcache_enable_i,        // from CSR
  input  logic                       dcache_flush_i,         // high until acknowledged
  output logic                       dcache_flush_ack_o,     // send a single cycle acknowledge signal when the cache is flushed
  output logic                       dcache_miss_o,          // we missed on a ld/st

  //  AMO interface
  input  ariane_pkg::amo_req_t       dcache_amo_req_i,       // from LSU
  output ariane_pkg::amo_resp_t      dcache_amo_resp_o,      // to LSU
  //  CMO interface
  input  cmo_req_t                   dcache_cmo_req_i,       // from CMO FU
  output cmo_rsp_t                   dcache_cmo_resp_o,      // to CMO FU

  //  Request ports
  input  ariane_pkg::dcache_req_i_t [2:0] dcache_req_ports_i,     // from LSU
  output ariane_pkg::dcache_req_o_t [2:0] dcache_req_ports_o,     // to LSU
  //  Write Buffer status
  output logic                       wbuffer_empty_o,
  output logic                       wbuffer_not_ni_o,

  //  Hardware memory prefetcher configuration
  input  logic   [NrHwPrefetchers-1:0]       hwpf_base_set_i,
  input  logic   [NrHwPrefetchers-1:0][63:0] hwpf_base_i,
  output logic   [NrHwPrefetchers-1:0][63:0] hwpf_base_o,
  input  logic   [NrHwPrefetchers-1:0]       hwpf_param_set_i,
  input  logic   [NrHwPrefetchers-1:0][63:0] hwpf_param_i,
  output logic   [NrHwPrefetchers-1:0][63:0] hwpf_param_o,
  input  logic   [NrHwPrefetchers-1:0]       hwpf_throttle_set_i,
  input  logic   [NrHwPrefetchers-1:0][63:0] hwpf_throttle_i,
  output logic   [NrHwPrefetchers-1:0][63:0] hwpf_throttle_o,
  output logic                        [63:0] hwpf_status_o,
  //  }}}
  `ifdef PITON_ARIANE
  //  OpenPiton connection through L1.5
  // {{{
  output wt_cache_pkg::l15_req_t                       l15_req_o,
  input  wt_cache_pkg::l15_rtrn_t                      l15_rtrn_i
  // }}}
`else
  //  AXI port to upstream memory/peripherals
  //  {{{
  output axi_req_t                           axi_req_o,
  input  axi_rsp_t                           axi_resp_i
  //  }}}
`endif  
);
//  }}}

  //  I$ instantiation
  //  {{{
  logic icache_miss_valid, icache_miss_ready;
  wt_cache_pkg::icache_req_t  icache_miss;

  logic icache_miss_resp_valid;
  wt_cache_pkg::icache_rtrn_t icache_miss_resp;

  localparam int ICACHE_RDTXID = 1 << (ariane_pkg::MEM_TID_WIDTH - 1);

  cva6_icache #(
    // use ID 0 for icache reads
    .RdTxId             ('0), // As in OpenPiton
    .ArianeCfg          (ArianeCfg)
  ) i_cva6_icache (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    .flush_i            (icache_flush_i),
    .en_i               (icache_en_i),
    .miss_o             (icache_miss_o),
    .areq_i             (icache_areq_i),
    .areq_o             (icache_areq_o),
    .dreq_i             (icache_dreq_i),
    .dreq_o             (icache_dreq_o),
    .mem_rtrn_vld_i     (icache_miss_resp_valid),
    .mem_rtrn_i         (icache_miss_resp),
    .mem_data_req_o     (icache_miss_valid),
    .mem_data_ack_i     (icache_miss_ready),
    .mem_data_o         (icache_miss)
  );
  //  }}}

  //  D$ instantiation
  //  {{{
  `include "hpdcache_typedef.svh"

  localparam int HPDCACHE_NREQUESTERS = 5;

  `ifdef PITON_ARIANE
    typedef logic [riscv::PLEN-1:0]                       hpdcache_mem_addr_t;
    typedef logic [ariane_pkg::MEM_TID_WIDTH-1:0]         hpdcache_mem_id_t;
    typedef logic [ariane_pkg::DCACHE_LINE_WIDTH-1:0]     hpdcache_mem_data_t;
    typedef logic [ariane_pkg::DCACHE_LINE_WIDTH-1/8-1:0] hpdcache_mem_be_t;
  `else
    typedef logic [AxiAddrWidth-1:0]              hpdcache_mem_addr_t;
    typedef logic [ariane_pkg::MEM_TID_WIDTH-1:0] hpdcache_mem_id_t; 
    typedef logic [AxiDataWidth-1:0]              hpdcache_mem_data_t;
    typedef logic [AxiDataWidth/8-1:0]            hpdcache_mem_be_t;
  `endif
  `HPDCACHE_TYPEDEF_MEM_REQ_T(hpdcache_mem_req_t, hpdcache_mem_addr_t, hpdcache_mem_id_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_R_T(hpdcache_mem_resp_r_t, hpdcache_mem_id_t, hpdcache_mem_data_t);
  `HPDCACHE_TYPEDEF_MEM_REQ_W_T(hpdcache_mem_req_w_t, hpdcache_mem_data_t, hpdcache_mem_be_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_W_T(hpdcache_mem_resp_w_t, hpdcache_mem_id_t);

  typedef logic [63:0] hwpf_stride_param_t;

  logic                                     dcache_req_valid [HPDCACHE_NREQUESTERS-1:0];
  logic                                     dcache_req_ready [HPDCACHE_NREQUESTERS-1:0];
  hpdcache_pkg::hpdcache_req_t              dcache_req       [HPDCACHE_NREQUESTERS-1:0];
  logic                                     dcache_rsp_valid [HPDCACHE_NREQUESTERS-1:0];
  hpdcache_pkg::hpdcache_rsp_t              dcache_rsp       [HPDCACHE_NREQUESTERS-1:0];
  logic                                     dcache_read_miss, dcache_write_miss;

  logic [2:0]                               snoop_valid;
  hpdcache_pkg::hpdcache_req_addr_t [2:0]   snoop_addr;
  logic                                     dcache_cmo_req_is_prefetch;

  logic                                     dcache_miss_ready;
  logic                                     dcache_miss_valid;
  hpdcache_mem_req_t                        dcache_miss;

  logic                                     dcache_miss_resp_ready;
  logic                                     dcache_miss_resp_valid;
  hpdcache_mem_resp_r_t                     dcache_miss_resp;

  logic                                     dcache_wbuf_ready;
  logic                                     dcache_wbuf_valid;
  hpdcache_mem_req_t                        dcache_wbuf;

  logic                                     dcache_wbuf_data_ready;
  logic                                     dcache_wbuf_data_valid;
  hpdcache_mem_req_w_t                      dcache_wbuf_data;

  logic                                     dcache_wbuf_resp_ready;
  logic                                     dcache_wbuf_resp_valid;
  hpdcache_mem_resp_w_t                     dcache_wbuf_resp;

  logic                                     dcache_uc_read_ready;
  logic                                     dcache_uc_read_valid;
  hpdcache_mem_req_t                        dcache_uc_read;

  logic                                     dcache_uc_read_resp_ready;
  logic                                     dcache_uc_read_resp_valid;
  hpdcache_mem_resp_r_t                     dcache_uc_read_resp;

  logic                                     dcache_uc_write_ready;
  logic                                     dcache_uc_write_valid;
  hpdcache_mem_req_t                        dcache_uc_write;

  logic                                     dcache_uc_write_data_ready;
  logic                                     dcache_uc_write_data_valid;
  hpdcache_mem_req_w_t                      dcache_uc_write_data;

  logic                                     dcache_uc_write_resp_ready;
  logic                                     dcache_uc_write_resp_valid;
  hpdcache_mem_resp_w_t                     dcache_uc_write_resp;

  hwpf_stride_pkg::hwpf_stride_throttle_t [NrHwPrefetchers-1:0] hwpf_throttle_in;
  hwpf_stride_pkg::hwpf_stride_throttle_t [NrHwPrefetchers-1:0] hwpf_throttle_out;

  generate
    ariane_pkg::dcache_req_i_t   dcache_req_ports[HPDCACHE_NREQUESTERS-1:0];


    for (genvar r = 0; r < 2; r++) begin : cva6_hpdcache_load_if_adapter_gen
      assign dcache_req_ports[r] = dcache_req_ports_i[r];

      cva6_hpdcache_load_if_adapter #(
        .ArianeCfg                                   (ArianeCfg)
      ) i_cva6_hpdcache_load_if_adapter (
        .clk_i,
        .rst_ni,

        .dcache_req_sid_i                            (hpdcache_pkg::hpdcache_req_sid_t'(r)),

        .cva6_req_i                                  (dcache_req_ports[r]),
        .cva6_req_o                                  (dcache_req_ports_o[r]),

        .dcache_req_valid_o                          (dcache_req_valid[r]),
        .dcache_req_ready_i                          (dcache_req_ready[r]),
        .dcache_req_o                                (dcache_req[r]),

        .dcache_rsp_valid_i                          (dcache_rsp_valid[r]),
        .dcache_rsp_i                                (dcache_rsp[r])
      );
    end

     cva6_hpdcache_if_adapter #(
      .ArianeCfg                                   (ArianeCfg)
    ) i_cva6_hpdcache_store_if_adapter (
      .clk_i,
      .rst_ni,

      .dcache_req_sid_i                            (hpdcache_pkg::hpdcache_req_sid_t'(2)),

      .cva6_req_i                                  (dcache_req_ports_i[2]),
      .cva6_req_o                                  (dcache_req_ports_o[2]),
      .cva6_amo_req_i                              (dcache_amo_req_i),
      .cva6_amo_resp_o                             (dcache_amo_resp_o),

      .dcache_req_valid_o                          (dcache_req_valid[2]),
      .dcache_req_ready_i                          (dcache_req_ready[2]),
      .dcache_req_o                                (dcache_req[2]),

      .dcache_rsp_valid_i                          (dcache_rsp_valid[2]),
      .dcache_rsp_i                                (dcache_rsp[2])
    );

`ifdef HPDCACHE_ENABLE_CMO
  
    assign dcache_req_valid[3] = '0,
           dcache_req[3] = '0;
    cva6_hpdcache_cmo_if_adapter #(
      .ArianeCfg                                   (ArianeCfg),
      .cmo_req_t                                   (cmo_req_t),
      .cmo_rsp_t                                   (cmo_rsp_t)
    ) i_cva6_hpdcache_cmo_if_adapter (
      .clk_i,
      .rst_ni,

      .dcache_req_sid_i                            (hpdcache_pkg::hpdcache_req_sid_t'(3)),

      .cva6_cmo_req_i                              (dcache_cmo_req_i),
      .cva6_cmo_resp_o                             (dcache_cmo_resp_o),

      .dcache_req_valid_o                          (dcache_req_valid[3]),
      .dcache_req_ready_i                          (dcache_req_ready[3]),
      .dcache_req_o                                (dcache_req[3]),

      .dcache_rsp_valid_i                          (dcache_rsp_valid[3]),
      .dcache_rsp_i                                (dcache_rsp[3])
    );
`else
    assign dcache_req_valid[3] = 1'b0,
           dcache_req[3]       = '0;
`endif
  endgenerate

  //  Snoop load port
  assign snoop_valid[0] = dcache_req_valid[1] & dcache_req_ready[1],
          snoop_addr[0] = dcache_req[1].addr;

  //  Snoop Store/AMO port
  assign snoop_valid[1] = dcache_req_valid[2] & dcache_req_ready[2],
          snoop_addr[1] = dcache_req[2].addr;

`ifdef HPDCACHE_ENABLE_CMO
  //  Snoop CMO port (in case of read prefetch accesses)
  assign dcache_cmo_req_is_prefetch = hpdcache_pkg::is_cmo_prefetch(dcache_req[3].op, dcache_req[3].size);
  assign snoop_valid[2] = dcache_req_valid[3] & dcache_req_ready[3] & dcache_cmo_req_is_prefetch,
          snoop_addr[2] = dcache_req[3].addr;
`else
  assign snoop_valid[2] = 1'b0,
          snoop_addr[2] = '0;
`endif

  generate
    for (genvar h = 0; h < NrHwPrefetchers; h++) begin : hwpf_throttle_gen
      assign hwpf_throttle_in[h] = hwpf_stride_pkg::hwpf_stride_throttle_t'(hwpf_throttle_i[h]),
             hwpf_throttle_o[h]  = hwpf_stride_pkg::hwpf_stride_param_t'(hwpf_throttle_out[h]);
    end
  endgenerate

  hwpf_stride_wrapper #(
    .NUM_HW_PREFETCH (NrHwPrefetchers),
    .NUM_SNOOP_PORTS (3)
  ) i_hwpf_stride_wrapper (
    .clk_i,
    .rst_ni,

    .hwpf_stride_base_set_i     (hwpf_base_set_i),
    .hwpf_stride_base_i         (hwpf_base_i),
    .hwpf_stride_base_o         (hwpf_base_o),
    .hwpf_stride_param_set_i    (hwpf_param_set_i),
    .hwpf_stride_param_i        (hwpf_param_i),
    .hwpf_stride_param_o        (hwpf_param_o),
    .hwpf_stride_throttle_set_i (hwpf_throttle_set_i),
    .hwpf_stride_throttle_i     (hwpf_throttle_in),
    .hwpf_stride_throttle_o     (hwpf_throttle_out),
    .hwpf_stride_status_o       (hwpf_status_o),

    .snoop_valid_i              (snoop_valid),
    .snoop_addr_i               (snoop_addr),

    .dcache_req_sid_i           (hpdcache_pkg::hpdcache_req_sid_t'(4)),

    .dcache_req_valid_o         (dcache_req_valid[4]),
    .dcache_req_ready_i         (dcache_req_ready[4]),
    .dcache_req_o               (dcache_req[4]),
    .dcache_rsp_valid_i         (dcache_rsp_valid[4]),
    .dcache_rsp_i               (dcache_rsp[4])
  );

  hpdcache #(
    .NREQUESTERS                       (HPDCACHE_NREQUESTERS),
    .HPDcacheMemIdWidth                (ariane_pkg::MEM_TID_WIDTH),
    .HPDcacheMemDataWidth              (ariane_pkg::DCACHE_LINE_WIDTH),
    .hpdcache_mem_req_t                (hpdcache_mem_req_t),
    .hpdcache_mem_req_w_t              (hpdcache_mem_req_w_t),
    .hpdcache_mem_resp_r_t             (hpdcache_mem_resp_r_t),
    .hpdcache_mem_resp_w_t             (hpdcache_mem_resp_w_t)
  ) i_hpdcache(
    .clk_i,
    .rst_ni,

    .wbuf_flush_i                      (dcache_flush_i),

    .core_req_valid_i                  (dcache_req_valid),
    .core_req_ready_o                  (dcache_req_ready),
    .core_req_i                        (dcache_req),

    .core_rsp_valid_o                  (dcache_rsp_valid),
    .core_rsp_o                        (dcache_rsp),

    .mem_req_miss_read_ready_i         (dcache_miss_ready),
    .mem_req_miss_read_valid_o         (dcache_miss_valid),
    .mem_req_miss_read_o               (dcache_miss),

    .mem_resp_miss_read_ready_o        (dcache_miss_resp_ready),
    .mem_resp_miss_read_valid_i        (dcache_miss_resp_valid),
    .mem_resp_miss_read_i              (dcache_miss_resp),

    .mem_req_wbuf_write_ready_i        (dcache_wbuf_ready),
    .mem_req_wbuf_write_valid_o        (dcache_wbuf_valid),
    .mem_req_wbuf_write_o              (dcache_wbuf),

    .mem_req_wbuf_write_data_ready_i   (dcache_wbuf_data_ready),
    .mem_req_wbuf_write_data_valid_o   (dcache_wbuf_data_valid),
    .mem_req_wbuf_write_data_o         (dcache_wbuf_data),

    .mem_resp_wbuf_write_ready_o       (dcache_wbuf_resp_ready),
    .mem_resp_wbuf_write_valid_i       (dcache_wbuf_resp_valid),
    .mem_resp_wbuf_write_i             (dcache_wbuf_resp),

    .mem_req_uc_read_ready_i           (dcache_uc_read_ready),
    .mem_req_uc_read_valid_o           (dcache_uc_read_valid),
    .mem_req_uc_read_o                 (dcache_uc_read),

    .mem_resp_uc_read_ready_o          (dcache_uc_read_resp_ready),
    .mem_resp_uc_read_valid_i          (dcache_uc_read_resp_valid),
    .mem_resp_uc_read_i                (dcache_uc_read_resp),

    .mem_req_uc_write_ready_i          (dcache_uc_write_ready),
    .mem_req_uc_write_valid_o          (dcache_uc_write_valid),
    .mem_req_uc_write_o                (dcache_uc_write),

    .mem_req_uc_write_data_ready_i     (dcache_uc_write_data_ready),
    .mem_req_uc_write_data_valid_o     (dcache_uc_write_data_valid),
    .mem_req_uc_write_data_o           (dcache_uc_write_data),

    .mem_resp_uc_write_ready_o         (dcache_uc_write_resp_ready),
    .mem_resp_uc_write_valid_i         (dcache_uc_write_resp_valid),
    .mem_resp_uc_write_i               (dcache_uc_write_resp),

    .evt_cache_write_miss_o            (dcache_write_miss),
    .evt_cache_read_miss_o             (dcache_read_miss),
    .evt_uncached_req_o                (/* unused */),
    .evt_cmo_req_o                     (/* unused */),
    .evt_write_req_o                   (/* unused */),
    .evt_read_req_o                    (/* unused */),
    .evt_prefetch_req_o                (/* unused */),
    .evt_req_on_hold_o                 (/* unused */),
    .evt_rtab_rollback_o               (/* unused */),
    .evt_stall_refill_o                (/* unused */),
    .evt_stall_o                       (/* unused */),

    .wbuf_empty_o                      (wbuffer_empty_o),

    .cfg_enable_i                      (dcache_enable_i),
    .cfg_wbuf_threshold_i              (4'd0),
    .cfg_wbuf_reset_timecnt_on_write_i (1'b1),
    .cfg_wbuf_sequential_waw_i         (1'b0),
    .cfg_prefetch_updt_plru_i          (1'b1),
    .cfg_error_on_cacheable_amo_i      (1'b0),
    .cfg_rtab_single_entry_i           (1'b0)
  );

  assign dcache_miss_o    = dcache_read_miss,
         wbuffer_not_ni_o = wbuffer_empty_o;

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : dcache_flush_ff
    if (!rst_ni) dcache_flush_ack_o <= 1'b0;
    else         dcache_flush_ack_o <= ~dcache_flush_ack_o & dcache_flush_i;
  end
 //  }}}

///////////////////////////////////////////////////////
// memory plumbing, either use 64bit AXI port or native
// L15 cache interface (derived from OpenSPARC CCX).
///////////////////////////////////////////////////////

`ifdef PITON_ARIANE

//Adapter HPDC-L1.5 Request Ports type
typedef logic [$clog2(5)-1:0]               req_portid_t;  //NTODO: Optimize for more threads

  //L15 adapter instantiation
  //{{{
  cva6_hpdcache_subsystem_l15_adapter #(
    .ArianeCfg                                       (ArianeCfg),
    .HPDcacheMemDataWidth                            (ariane_pkg::DCACHE_LINE_WIDTH),
    .hpdcache_mem_req_t                              (hpdcache_mem_req_t),
    .hpdcache_mem_req_w_t                            (hpdcache_mem_req_w_t),
    .hpdcache_mem_resp_r_t                           (hpdcache_mem_resp_r_t),
    .hpdcache_mem_resp_w_t                           (hpdcache_mem_resp_w_t),
    .hpdcache_mem_id_t                               (hpdcache_mem_id_t),
    .hpdcache_mem_addr_t                             (hpdcache_mem_addr_t),
    .req_portid_t                                    (req_portid_t) //NTODO: Optimize for more threads
  ) i_l15_adapter (
    .clk_i,
    .rst_ni,

    .icache_miss_valid_i                             (icache_miss_valid),
    .icache_miss_ready_o                             (icache_miss_ready),
    .icache_miss_i                                   (icache_miss),
    .icache_miss_pid_i                               (3'b000), //Port 0 DEMUX

    .icache_miss_resp_valid_o                        (icache_miss_resp_valid),
    .icache_miss_resp_o                              (icache_miss_resp),

    .dcache_miss_ready_o                             (dcache_miss_ready),
    .dcache_miss_valid_i                             (dcache_miss_valid),
    .dcache_miss_i                                   (dcache_miss),
    .dcache_miss_pid_i                               (3'b001),

    .dcache_miss_resp_ready_i                        (dcache_miss_resp_ready),
    .dcache_miss_resp_valid_o                        (dcache_miss_resp_valid),
    .dcache_miss_resp_o                              (dcache_miss_resp),

    .dcache_wbuf_ready_o                             (dcache_wbuf_ready),
    .dcache_wbuf_valid_i                             (dcache_wbuf_valid),
    .dcache_wbuf_i                                   (dcache_wbuf),
    .dcache_wbuf_pid_i                               (3'b010),

    .dcache_wbuf_data_ready_o                        (dcache_wbuf_data_ready),
    .dcache_wbuf_data_valid_i                        (dcache_wbuf_data_valid),
    .dcache_wbuf_data_i                              (dcache_wbuf_data),

    .dcache_wbuf_resp_ready_i                        (dcache_wbuf_resp_ready),
    .dcache_wbuf_resp_valid_o                        (dcache_wbuf_resp_valid),
    .dcache_wbuf_resp_o                              (dcache_wbuf_resp),

    .dcache_uc_read_ready_o                          (dcache_uc_read_ready),
    .dcache_uc_read_valid_i                          (dcache_uc_read_valid),
    .dcache_uc_read_i                                (dcache_uc_read),
    .dcache_uc_read_pid_i                            (3'b011),

    .dcache_uc_read_resp_ready_i                     (dcache_uc_read_resp_ready),
    .dcache_uc_read_resp_valid_o                     (dcache_uc_read_resp_valid),
    .dcache_uc_read_resp_o                           (dcache_uc_read_resp),

    .dcache_uc_write_ready_o                         (dcache_uc_write_ready),
    .dcache_uc_write_valid_i                         (dcache_uc_write_valid),
    .dcache_uc_write_i                               (dcache_uc_write),
    .dcache_uc_write_pid_i                           (3'b100),

    .dcache_uc_write_data_ready_o                    (dcache_uc_write_data_ready),
    .dcache_uc_write_data_valid_i                    (dcache_uc_write_data_valid),
    .dcache_uc_write_data_i                          (dcache_uc_write_data),

    .dcache_uc_write_resp_ready_i                    (dcache_uc_write_resp_ready),
    .dcache_uc_write_resp_valid_o                    (dcache_uc_write_resp_valid),
    .dcache_uc_write_resp_o                          (dcache_uc_write_resp),

    .l15_req_o                                       (l15_req_o),
    .l15_rtrn_i                                      (l15_rtrn_i)
  );
  //}}}
`else
  //  AXI arbiter instantiation
  //  {{{
  cva6_hpdcache_subsystem_axi_arbiter #(
    .ArianeCfg                                       (ArianeCfg),
    .HPDcacheMemIdWidth                              (ariane_pkg::MEM_TID_WIDTH),
    .HPDcacheMemDataWidth                            (AxiDataWidth),
    .hpdcache_mem_req_t                              (hpdcache_mem_req_t),
    .hpdcache_mem_req_w_t                            (hpdcache_mem_req_w_t),
    .hpdcache_mem_resp_r_t                           (hpdcache_mem_resp_r_t),
    .hpdcache_mem_resp_w_t                           (hpdcache_mem_resp_w_t),

    .AxiAddrWidth                                    (AxiAddrWidth),
    .AxiDataWidth                                    (AxiDataWidth),
    .AxiIdWidth                                      (AxiIdWidth),
    .AxiUserWidth                                    (AxiUserWidth),
    .axi_ar_chan_t                                   (axi_ar_chan_t),
    .axi_aw_chan_t                                   (axi_aw_chan_t),
    .axi_w_chan_t                                    (axi_w_chan_t),
    .axi_req_t                                       (axi_req_t),
    .axi_rsp_t                                       (axi_rsp_t)
  ) i_axi_arbiter (
    .clk_i,
    .rst_ni,

    .icache_miss_valid_i                             (icache_miss_valid),
    .icache_miss_ready_o                             (icache_miss_ready),
    .icache_miss_i                                   (icache_miss),
    .icache_miss_id_i                                (hpdcache_mem_id_t'(ICACHE_RDTXID)),

    .icache_miss_resp_valid_o                        (icache_miss_resp_valid),
    .icache_miss_resp_o                              (icache_miss_resp),

    .dcache_miss_ready_o                             (dcache_miss_ready),
    .dcache_miss_valid_i                             (dcache_miss_valid),
    .dcache_miss_i                                   (dcache_miss),

    .dcache_miss_resp_ready_i                        (dcache_miss_resp_ready),
    .dcache_miss_resp_valid_o                        (dcache_miss_resp_valid),
    .dcache_miss_resp_o                              (dcache_miss_resp),

    .dcache_wbuf_ready_o                             (dcache_wbuf_ready),
    .dcache_wbuf_valid_i                             (dcache_wbuf_valid),
    .dcache_wbuf_i                                   (dcache_wbuf),

    .dcache_wbuf_data_ready_o                        (dcache_wbuf_data_ready),
    .dcache_wbuf_data_valid_i                        (dcache_wbuf_data_valid),
    .dcache_wbuf_data_i                              (dcache_wbuf_data),

    .dcache_wbuf_resp_ready_i                        (dcache_wbuf_resp_ready),
    .dcache_wbuf_resp_valid_o                        (dcache_wbuf_resp_valid),
    .dcache_wbuf_resp_o                              (dcache_wbuf_resp),

    .dcache_uc_read_ready_o                          (dcache_uc_read_ready),
    .dcache_uc_read_valid_i                          (dcache_uc_read_valid),
    .dcache_uc_read_i                                (dcache_uc_read),
    .dcache_uc_read_id_i                             ('1),

    .dcache_uc_read_resp_ready_i                     (dcache_uc_read_resp_ready),
    .dcache_uc_read_resp_valid_o                     (dcache_uc_read_resp_valid),
    .dcache_uc_read_resp_o                           (dcache_uc_read_resp),

    .dcache_uc_write_ready_o                         (dcache_uc_write_ready),
    .dcache_uc_write_valid_i                         (dcache_uc_write_valid),
    .dcache_uc_write_i                               (dcache_uc_write),
    .dcache_uc_write_id_i                            ('1),

    .dcache_uc_write_data_ready_o                    (dcache_uc_write_data_ready),
    .dcache_uc_write_data_valid_i                    (dcache_uc_write_data_valid),
    .dcache_uc_write_data_i                          (dcache_uc_write_data),

    .dcache_uc_write_resp_ready_i                    (dcache_uc_write_resp_ready),
    .dcache_uc_write_resp_valid_o                    (dcache_uc_write_resp_valid),
    .dcache_uc_write_resp_o                          (dcache_uc_write_resp),

    .axi_req_o                                       (axi_req_o),
    .axi_resp_i                                      (axi_resp_i)
  );
  //  }}}
`endif
  //  Assertions
  //  {{{
  //  pragma translate_off
  a_invalid_instruction_fetch: assert property (
    @(posedge clk_i) disable iff (!rst_ni) icache_dreq_o.valid |-> (|icache_dreq_o.data) !== 1'hX)
  else $warning(1,"[l1 dcache] reading invalid instructions: vaddr=%08X, data=%08X",
    icache_dreq_o.vaddr, icache_dreq_o.data);

  a_invalid_write_data: assert property (
    @(posedge clk_i) disable iff (!rst_ni) dcache_req_ports_i[2].data_req |-> |dcache_req_ports_i[2].data_be |-> (|dcache_req_ports_i[2].data_wdata) !== 1'hX)
  else $warning(1,"[l1 dcache] writing invalid data: paddr=%016X, be=%02X, data=%016X",
    {dcache_req_ports_i[2].address_tag, dcache_req_ports_i[2].address_index}, dcache_req_ports_i[2].data_be, dcache_req_ports_i[2].data_wdata);

  for (genvar j=0; j<2; j++) begin : gen_assertion
    a_invalid_read_data: assert property (
      @(posedge clk_i) disable iff (!rst_ni) dcache_req_ports_o[j].data_rvalid && ~dcache_req_ports_i[j].kill_req |-> (|dcache_req_ports_o[j].data_rdata) !== 1'hX)
    else $warning(1,"[l1 dcache] reading invalid data on port %01d: data=%016X",
      j, dcache_req_ports_o[j].data_rdata);
  end
  //  pragma translate_on
  //  }}}

endmodule : cva6_hpdcache_subsystem
