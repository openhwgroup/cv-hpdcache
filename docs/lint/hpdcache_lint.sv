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
 *  Creation Date : April, 2024
 *  Description   : HPDcache Wrapper for Code Linting Check
 *  History       :
 */
`include "hpdcache_typedef.svh"

module hpdcache_lint
  import hpdcache_pkg::*;
();
  localparam int unsigned HPDCACHE_NREQUESTERS = 1;

  localparam hpdcache_pkg::hpdcache_user_cfg_t HPDcacheUserCfg = '{
      nRequesters: HPDCACHE_NREQUESTERS,
      paWidth: 56,
      wordWidth: 64,
      sets: 64,
      ways: 8,
      clWords: 8,
      reqWords: 1,
      reqTransIdWidth: 6,
      reqSrcIdWidth: 3,
      victimSel: hpdcache_pkg::HPDCACHE_VICTIM_RANDOM,
      dataWaysPerRamWord: 2,
      dataSetsPerRam: 64,
      dataRamByteEnable: 1'b1,
      accessWords: 8,
      mshrSets: 32,
      mshrWays: 2,
      mshrWaysPerRamWord: 2,
      mshrSetsPerRam: 32,
      mshrRamByteEnable: 1'b1,
      mshrUseRegbank: 1,
      refillCoreRspFeedthrough: 1'b1,
      refillFifoDepth: 2,
      wbufDirEntries: 16,
      wbufDataEntries: 8,
      wbufWords: 4,
      wbufTimecntWidth: 3,
      wbufSendFeedThrough: 1'b0,
      rtabEntries: 4,
      memAddrWidth: 56,
      memIdWidth: 6,
      memDataWidth: 512
  };

  localparam hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = hpdcache_pkg::hpdcacheBuildConfig(
      HPDcacheUserCfg
  );

  `HPDCACHE_TYPEDEF_MEM_ATTR_T(hpdcache_mem_addr_t, hpdcache_mem_id_t, hpdcache_mem_data_t,
                               hpdcache_mem_be_t, HPDcacheCfg);
  `HPDCACHE_TYPEDEF_MEM_REQ_T(hpdcache_mem_req_t, hpdcache_mem_addr_t, hpdcache_mem_id_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_R_T(hpdcache_mem_resp_r_t, hpdcache_mem_id_t, hpdcache_mem_data_t);
  `HPDCACHE_TYPEDEF_MEM_REQ_W_T(hpdcache_mem_req_w_t, hpdcache_mem_data_t, hpdcache_mem_be_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_W_T(hpdcache_mem_resp_w_t, hpdcache_mem_id_t);

  `HPDCACHE_TYPEDEF_REQ_ATTR_T(hpdcache_req_offset_t, hpdcache_data_word_t, hpdcache_data_be_t,
                               hpdcache_req_data_t, hpdcache_req_be_t, hpdcache_req_sid_t,
                               hpdcache_req_tid_t, hpdcache_tag_t, HPDcacheCfg);
  `HPDCACHE_TYPEDEF_REQ_T(hpdcache_req_t, hpdcache_req_offset_t, hpdcache_req_data_t,
                          hpdcache_req_be_t, hpdcache_req_sid_t, hpdcache_req_tid_t,
                          hpdcache_tag_t);
  `HPDCACHE_TYPEDEF_RSP_T(hpdcache_rsp_t, hpdcache_req_data_t, hpdcache_req_sid_t,
                          hpdcache_req_tid_t);

  typedef logic [HPDcacheCfg.u.wbufTimecntWidth-1:0] hpdcache_wbuf_timecnt_t;

  logic                        clk;
  logic                        rst_n;

  logic                        wbuf_flush;
  logic                        wbuf_empty;

  logic                        dcache_req_valid           [HPDCACHE_NREQUESTERS-1];
  logic                        dcache_req_ready           [HPDCACHE_NREQUESTERS-1];
  hpdcache_req_t               dcache_req                 [HPDCACHE_NREQUESTERS-1];
  logic                        dcache_req_abort           [HPDCACHE_NREQUESTERS-1];
  hpdcache_tag_t               dcache_req_tag             [HPDCACHE_NREQUESTERS-1];
  hpdcache_pkg::hpdcache_pma_t dcache_req_pma             [HPDCACHE_NREQUESTERS-1];
  logic                        dcache_rsp_valid           [HPDCACHE_NREQUESTERS-1];
  hpdcache_rsp_t               dcache_rsp                 [HPDCACHE_NREQUESTERS-1];

  logic                        dcache_miss_ready;
  logic                        dcache_miss_valid;
  hpdcache_mem_req_t           dcache_miss;

  logic                        dcache_miss_resp_ready;
  logic                        dcache_miss_resp_valid;
  hpdcache_mem_resp_r_t        dcache_miss_resp;

  logic                        dcache_wbuf_ready;
  logic                        dcache_wbuf_valid;
  hpdcache_mem_req_t           dcache_wbuf;

  logic                        dcache_wbuf_data_ready;
  logic                        dcache_wbuf_data_valid;
  hpdcache_mem_req_w_t         dcache_wbuf_data;

  logic                        dcache_wbuf_resp_ready;
  logic                        dcache_wbuf_resp_valid;
  hpdcache_mem_resp_w_t        dcache_wbuf_resp;

  logic                        dcache_uc_read_ready;
  logic                        dcache_uc_read_valid;
  hpdcache_mem_req_t           dcache_uc_read;

  logic                        dcache_uc_read_resp_ready;
  logic                        dcache_uc_read_resp_valid;
  hpdcache_mem_resp_r_t        dcache_uc_read_resp;

  logic                        dcache_uc_write_ready;
  logic                        dcache_uc_write_valid;
  hpdcache_mem_req_t           dcache_uc_write;

  logic                        dcache_uc_write_data_ready;
  logic                        dcache_uc_write_data_valid;
  hpdcache_mem_req_w_t         dcache_uc_write_data;

  logic                        dcache_uc_write_resp_ready;
  logic                        dcache_uc_write_resp_valid;
  hpdcache_mem_resp_w_t        dcache_uc_write_resp;

  hpdcache #(
      .HPDcacheCfg          (HPDcacheCfg),
      .wbuf_timecnt_t       (hpdcache_wbuf_timecnt_t),
      .hpdcache_tag_t       (hpdcache_tag_t),
      .hpdcache_data_word_t (hpdcache_data_word_t),
      .hpdcache_data_be_t   (hpdcache_data_be_t),
      .hpdcache_req_offset_t(hpdcache_req_offset_t),
      .hpdcache_req_data_t  (hpdcache_req_data_t),
      .hpdcache_req_be_t    (hpdcache_req_be_t),
      .hpdcache_req_sid_t   (hpdcache_req_sid_t),
      .hpdcache_req_tid_t   (hpdcache_req_tid_t),
      .hpdcache_req_t       (hpdcache_req_t),
      .hpdcache_rsp_t       (hpdcache_rsp_t),
      .hpdcache_mem_addr_t  (hpdcache_mem_addr_t),
      .hpdcache_mem_id_t    (hpdcache_mem_id_t),
      .hpdcache_mem_data_t  (hpdcache_mem_data_t),
      .hpdcache_mem_be_t    (hpdcache_mem_be_t),
      .hpdcache_mem_req_t   (hpdcache_mem_req_t),
      .hpdcache_mem_req_w_t (hpdcache_mem_req_w_t),
      .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
      .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t)
  ) i_hpdcache (
      .clk_i (clk),
      .rst_ni(rst_n),

      .wbuf_flush_i(wbuf_flush),

      .core_req_valid_i(dcache_req_valid),
      .core_req_ready_o(dcache_req_ready),
      .core_req_i      (dcache_req),
      .core_req_abort_i(dcache_req_abort),
      .core_req_tag_i  (dcache_req_tag),
      .core_req_pma_i  (dcache_req_pma),

      .core_rsp_valid_o(dcache_rsp_valid),
      .core_rsp_o      (dcache_rsp),

      .mem_req_miss_read_ready_i(dcache_miss_ready),
      .mem_req_miss_read_valid_o(dcache_miss_valid),
      .mem_req_miss_read_o      (dcache_miss),

      .mem_resp_miss_read_ready_o(dcache_miss_resp_ready),
      .mem_resp_miss_read_valid_i(dcache_miss_resp_valid),
      .mem_resp_miss_read_i      (dcache_miss_resp),

      .mem_req_wbuf_write_ready_i(dcache_wbuf_ready),
      .mem_req_wbuf_write_valid_o(dcache_wbuf_valid),
      .mem_req_wbuf_write_o      (dcache_wbuf),

      .mem_req_wbuf_write_data_ready_i(dcache_wbuf_data_ready),
      .mem_req_wbuf_write_data_valid_o(dcache_wbuf_data_valid),
      .mem_req_wbuf_write_data_o      (dcache_wbuf_data),

      .mem_resp_wbuf_write_ready_o(dcache_wbuf_resp_ready),
      .mem_resp_wbuf_write_valid_i(dcache_wbuf_resp_valid),
      .mem_resp_wbuf_write_i      (dcache_wbuf_resp),

      .mem_req_uc_read_ready_i(dcache_uc_read_ready),
      .mem_req_uc_read_valid_o(dcache_uc_read_valid),
      .mem_req_uc_read_o      (dcache_uc_read),

      .mem_resp_uc_read_ready_o(dcache_uc_read_resp_ready),
      .mem_resp_uc_read_valid_i(dcache_uc_read_resp_valid),
      .mem_resp_uc_read_i      (dcache_uc_read_resp),

      .mem_req_uc_write_ready_i(dcache_uc_write_ready),
      .mem_req_uc_write_valid_o(dcache_uc_write_valid),
      .mem_req_uc_write_o      (dcache_uc_write),

      .mem_req_uc_write_data_ready_i(dcache_uc_write_data_ready),
      .mem_req_uc_write_data_valid_o(dcache_uc_write_data_valid),
      .mem_req_uc_write_data_o      (dcache_uc_write_data),

      .mem_resp_uc_write_ready_o(dcache_uc_write_resp_ready),
      .mem_resp_uc_write_valid_i(dcache_uc_write_resp_valid),
      .mem_resp_uc_write_i      (dcache_uc_write_resp),

      .evt_cache_write_miss_o(  /* unused */),
      .evt_cache_read_miss_o (  /* unused */),
      .evt_uncached_req_o    (  /* unused */),
      .evt_cmo_req_o         (  /* unused */),
      .evt_write_req_o       (  /* unused */),
      .evt_read_req_o        (  /* unused */),
      .evt_prefetch_req_o    (  /* unused */),
      .evt_req_on_hold_o     (  /* unused */),
      .evt_rtab_rollback_o   (  /* unused */),
      .evt_stall_refill_o    (  /* unused */),
      .evt_stall_o           (  /* unused */),

      .wbuf_empty_o(wbuf_empty),

      .cfg_enable_i                       (1'b1),
      .cfg_wbuf_threshold_i               (3'd2),
      .cfg_wbuf_reset_timecnt_on_write_i  (1'b1),
      .cfg_wbuf_sequential_waw_i          (1'b0),
      .cfg_wbuf_inhibit_write_coalescing_i(1'b0),
      .cfg_prefetch_updt_plru_i           (1'b1),
      .cfg_error_on_cacheable_amo_i       (1'b0),
      .cfg_rtab_single_entry_i            (1'b0)
  );

endmodule  /* hpdcache_lint */
