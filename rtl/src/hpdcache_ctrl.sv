/*
 *  Copyright 2023,2024 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *  Copyright 2025 Univ. Grenoble Alpes, Inria, TIMA Laboratory
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : HPDcache controller
 *  History       :
 */
module hpdcache_ctrl
    // Package imports
    // {{{
import hpdcache_pkg::*;
    // }}}

    // Parameters
    // {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_word_t = logic,
    parameter type hpdcache_data_word_t = logic,
    parameter type hpdcache_data_be_t = logic,
    parameter type hpdcache_dir_entry_t = logic,
    parameter type hpdcache_way_vector_t = logic,
    parameter type hpdcache_way_t = logic,

    parameter type wbuf_addr_t = logic,
    parameter type wbuf_data_t = logic,
    parameter type wbuf_be_t = logic,

    parameter type hpdcache_access_data_t = logic,
    parameter type hpdcache_access_be_t = logic,

    parameter type hpdcache_req_addr_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,

    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic
)
    // }}}

    // Ports
    // {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //      Core request interface
    input  logic                  core_req_valid_i,
    output logic                  core_req_ready_o,
    input  hpdcache_req_t         core_req_i,
    input  logic                  core_req_abort_i,
    input  hpdcache_tag_t         core_req_tag_i,
    input  hpdcache_pma_t         core_req_pma_i,

    //      Core response interface
    output logic                  core_rsp_valid_o,
    output hpdcache_rsp_t         core_rsp_o,

    //      Force the write buffer to send all pending writes
    input  logic                  wbuf_flush_i,

    //      Global control signals
    output logic                  cachedir_hit_o,

    //      Miss handler interface
    output logic                  st0_mshr_check_o,
    output hpdcache_req_offset_t  st0_mshr_check_offset_o,
    output hpdcache_nline_t       st1_mshr_check_nline_o,
    input  logic                  st1_mshr_hit_i,
    input  logic                  st1_mshr_alloc_ready_i,
    input  logic                  st1_mshr_alloc_full_i,
    input  logic                  st1_mshr_alloc_cbuf_full_i,
    output logic                  st2_mshr_alloc_o,
    output logic                  st2_mshr_alloc_cs_o,
    output hpdcache_nline_t       st2_mshr_alloc_nline_o,
    output hpdcache_req_tid_t     st2_mshr_alloc_tid_o,
    output hpdcache_req_sid_t     st2_mshr_alloc_sid_o,
    output hpdcache_word_t        st2_mshr_alloc_word_o,
    output hpdcache_req_data_t    st2_mshr_alloc_wdata_o,
    output hpdcache_req_be_t      st2_mshr_alloc_be_o,
    output hpdcache_way_vector_t  st2_mshr_alloc_victim_way_o,
    output logic                  st2_mshr_alloc_need_rsp_o,
    output logic                  st2_mshr_alloc_is_prefetch_o,
    output logic                  st2_mshr_alloc_wback_o,
    output logic                  st2_mshr_alloc_dirty_o,

    //      Refill interface
    input  logic                  refill_req_valid_i,
    output logic                  refill_req_ready_o,
    input  logic                  refill_is_error_i,
    input  logic                  refill_busy_i,
    input  logic                  refill_updt_sel_victim_i,
    input  hpdcache_set_t         refill_set_i,
    input  hpdcache_way_vector_t  refill_way_i,
    input  hpdcache_dir_entry_t   refill_dir_entry_i,
    input  logic                  refill_write_dir_i,
    input  logic                  refill_write_data_i,
    input  hpdcache_word_t        refill_word_i,
    input  hpdcache_access_data_t refill_data_i,
    input  logic                  refill_core_rsp_valid_i,
    input  hpdcache_rsp_t         refill_core_rsp_i,
    input  hpdcache_nline_t       refill_nline_i,
    input  logic                  refill_updt_rtab_i,

    //      Flush interface
    input  logic                  flush_busy_i,
    output hpdcache_nline_t       flush_check_nline_o,
    input  logic                  flush_check_hit_i,
    output logic                  flush_alloc_o,
    input  logic                  flush_alloc_ready_i,
    output hpdcache_nline_t       flush_alloc_nline_o,
    output hpdcache_way_vector_t  flush_alloc_way_o,
    input  logic                  flush_data_read_i,
    input  hpdcache_set_t         flush_data_read_set_i,
    input  hpdcache_word_t        flush_data_read_word_i,
    input  hpdcache_way_vector_t  flush_data_read_way_i,
    output hpdcache_access_data_t flush_data_read_data_o,
    input  logic                  flush_ack_i,
    input  hpdcache_nline_t       flush_ack_nline_i,

    //      Invalidate interface
    input  logic                  inval_check_dir_i,
    input  logic                  inval_write_dir_i,
    input  hpdcache_nline_t       inval_nline_i,
    output logic                  inval_hit_o,

    //      Write buffer interface
    input  logic                  wbuf_empty_i,
    output logic                  wbuf_flush_all_o,
    output logic                  wbuf_write_o,
    input  logic                  wbuf_write_ready_i,
    output wbuf_addr_t            wbuf_write_addr_o,
    output wbuf_data_t            wbuf_write_data_o,
    output wbuf_be_t              wbuf_write_be_o,
    output logic                  wbuf_write_uncacheable_o,
    input  logic                  wbuf_read_hit_i,
    output logic                  wbuf_read_flush_hit_o,
    output hpdcache_req_addr_t    wbuf_rtab_addr_o,
    output logic                  wbuf_rtab_is_read_o,
    input  logic                  wbuf_rtab_hit_open_i,
    input  logic                  wbuf_rtab_hit_pend_i,
    input  logic                  wbuf_rtab_hit_sent_i,
    input  logic                  wbuf_rtab_not_ready_i,

    //      Uncacheable request handler
    input  logic                  uc_busy_i,
    output logic                  uc_lrsc_snoop_o,
    output hpdcache_req_addr_t    uc_lrsc_snoop_addr_o,
    output hpdcache_req_size_t    uc_lrsc_snoop_size_o,
    output logic                  uc_req_valid_o,
    output hpdcache_uc_op_t       uc_req_op_o,
    output hpdcache_req_addr_t    uc_req_addr_o,
    output hpdcache_req_size_t    uc_req_size_o,
    output hpdcache_req_data_t    uc_req_data_o,
    output hpdcache_req_be_t      uc_req_be_o,
    output logic                  uc_req_uc_o,
    output hpdcache_req_sid_t     uc_req_sid_o,
    output hpdcache_req_tid_t     uc_req_tid_o,
    output logic                  uc_req_need_rsp_o,
    output hpdcache_way_vector_t  uc_req_dir_hit_way_o,
    output hpdcache_req_data_t    uc_req_old_data_o,
    input  logic                  uc_wbuf_flush_all_i,
    input  logic                  uc_data_amo_write_i,
    input  logic                  uc_data_amo_write_enable_i,
    input  hpdcache_set_t         uc_data_amo_write_set_i,
    input  hpdcache_req_size_t    uc_data_amo_write_size_i,
    input  hpdcache_word_t        uc_data_amo_write_word_i,
    input  hpdcache_way_vector_t  uc_data_amo_write_way_i,
    input  hpdcache_req_data_t    uc_data_amo_write_data_i,
    input  hpdcache_req_be_t      uc_data_amo_write_be_i,
    output logic                  uc_core_rsp_ready_o,
    input  logic                  uc_core_rsp_valid_i,
    input  hpdcache_rsp_t         uc_core_rsp_i,

    //      Cache Management Operation (CMO)
    input  logic                  cmo_busy_i,
    input  logic                  cmo_wait_i,
    output logic                  cmo_req_valid_o,
    output hpdcache_cmoh_op_t     cmo_req_op_o,
    output hpdcache_req_addr_t    cmo_req_addr_o,
    output hpdcache_req_data_t    cmo_req_wdata_o,
    output hpdcache_req_sid_t     cmo_req_sid_o,
    output hpdcache_req_tid_t     cmo_req_tid_o,
    output logic                  cmo_req_need_rsp_o,
    output logic                  cmo_dirty_set_en_o,
    output hpdcache_set_t         cmo_dirty_min_set_o,
    output hpdcache_set_t         cmo_dirty_max_set_o,
    output logic                  cmo_valid_set_en_o,
    output hpdcache_set_t         cmo_valid_min_set_o,
    output hpdcache_set_t         cmo_valid_max_set_o,
    input  logic                  cmo_wbuf_flush_all_i,
    input  logic                  cmo_flush_all_i,
    input  logic                  cmo_inval_all_i,
    input  logic                  cmo_dir_check_nline_i,
    input  hpdcache_set_t         cmo_dir_check_nline_set_i,
    input  hpdcache_tag_t         cmo_dir_check_nline_tag_i,
    output hpdcache_way_vector_t  cmo_dir_check_nline_hit_way_o,
    output logic                  cmo_dir_check_nline_wback_o,
    output logic                  cmo_dir_check_nline_dirty_o,
    input  logic                  cmo_dir_check_entry_i,
    input  hpdcache_set_t         cmo_dir_check_entry_set_i,
    input  hpdcache_way_vector_t  cmo_dir_check_entry_way_i,
    output logic                  cmo_dir_check_entry_valid_o,
    output logic                  cmo_dir_check_entry_wback_o,
    output logic                  cmo_dir_check_entry_dirty_o,
    output hpdcache_tag_t         cmo_dir_check_entry_tag_o,
    input  logic                  cmo_dir_updt_i,
    input  hpdcache_set_t         cmo_dir_updt_set_i,
    input  hpdcache_way_vector_t  cmo_dir_updt_way_i,
    input  logic                  cmo_dir_updt_valid_i,
    input  logic                  cmo_dir_updt_wback_i,
    input  logic                  cmo_dir_updt_dirty_i,
    input  logic                  cmo_dir_updt_fetch_i,
    input  hpdcache_tag_t         cmo_dir_updt_tag_i,
    output logic                  cmo_core_rsp_ready_o,
    input  logic                  cmo_core_rsp_valid_i,
    input  hpdcache_rsp_t         cmo_core_rsp_i,

    input  logic                  mshr_empty_i,
    input  logic                  flush_empty_i,

    output logic                  rtab_empty_o,
    output logic                  ctrl_empty_o,

    //   Configuration signals
    input  logic                  cfg_enable_i,
    input  logic                  cfg_prefetch_updt_plru_i,
    input  logic                  cfg_rtab_single_entry_i,
    input  logic                  cfg_default_wb_i,

    //   Performance events
    output logic                  evt_cache_write_miss_o,
    output logic                  evt_cache_read_miss_o,
    output logic                  evt_cache_dir_unc_err_o,
    output logic                  evt_cache_dir_cor_err_o,
    output logic                  evt_cache_dat_unc_err_o,
    output logic                  evt_cache_dat_cor_err_o,
    output logic                  evt_uncached_req_o,
    output logic                  evt_cmo_req_o,
    output logic                  evt_write_req_o,
    output logic                  evt_read_req_o,
    output logic                  evt_prefetch_req_o,
    output logic                  evt_req_on_hold_o,
    output logic                  evt_rtab_rollback_o,
    output logic                  evt_stall_refill_o,
    output logic                  evt_stall_o
);
    // }}}

    //  Definition of types
    //  {{{
    typedef logic [$clog2(HPDcacheCfg.u.rtabEntries)-1:0] rtab_ptr_t;
    typedef logic [$clog2(HPDcacheCfg.u.rtabEntries):0]   rtab_cnt_t;

    //    Extended request type
    typedef struct packed {
        hpdcache_req_t req;

        // Replayed from the RTAB
        logic from_rtab;

        // Error tag: Used for replayed requests that has been tagged as an error
        // (e.g. write miss with allocation whose read response was an error)
        logic is_error;

        // Error scrubbing request
        //   - Do not trigger miss request to the memory in case of miss
        //   - Do not update the access state (e.g. LRU bits)
        //   - Address contains the indexes of the way, set and word
        logic err_scrubbing;
    } hpdcache_req_x_t;

    //    RTAB entry definition
    typedef struct packed {
        hpdcache_req_x_t req;
        hpdcache_way_t   way_fetch;
    } rtab_entry_t;
    //  }}}

    //  Definition of internal registers
    //  {{{
    logic                    st1_req_valid_q, st1_req_valid_d;
    hpdcache_req_x_t         st1_req_q;
    rtab_ptr_t               st1_rtab_pop_try_ptr_q;

    logic                    st2_mshr_alloc_q, st2_mshr_alloc_d;
    logic                    st2_mshr_alloc_is_prefetch_q;
    logic                    st2_mshr_alloc_wback_q, st2_mshr_alloc_wback_d;
    logic                    st2_mshr_alloc_dirty_q, st2_mshr_alloc_dirty_d;
    logic                    st2_mshr_alloc_need_rsp_q, st2_mshr_alloc_need_rsp_d;
    hpdcache_req_addr_t      st2_mshr_alloc_addr_q;
    hpdcache_req_sid_t       st2_mshr_alloc_sid_q;
    hpdcache_req_tid_t       st2_mshr_alloc_tid_q;
    hpdcache_req_data_t      st2_mshr_alloc_wdata_q;
    hpdcache_req_be_t        st2_mshr_alloc_be_q;
    hpdcache_way_vector_t    st2_mshr_alloc_victim_way_q;

    logic                    st2_flush_alloc_q, st2_flush_alloc_d;
    hpdcache_nline_t         st2_flush_alloc_nline_q;
    hpdcache_way_vector_t    st2_flush_alloc_way_q;

    logic                    st2_dir_updt_q, st2_dir_updt_d;
    hpdcache_set_t           st2_dir_updt_set_q;
    hpdcache_way_vector_t    st2_dir_updt_way_q;
    hpdcache_tag_t           st2_dir_updt_tag_q;
    logic                    st2_dir_updt_valid_q, st2_dir_updt_valid_d;
    logic                    st2_dir_updt_wback_q, st2_dir_updt_wback_d;
    logic                    st2_dir_updt_dirty_q, st2_dir_updt_dirty_d;
    logic                    st2_dir_updt_fetch_q, st2_dir_updt_fetch_d;
    //  }}}

    //  Definition of internal signals
    //  {{{
    // Pipeline Stage 0
    hpdcache_req_x_t         st0_req;
    hpdcache_pma_t           st0_req_pma;
    logic                    st0_req_is_uncacheable;
    logic                    st0_req_is_load;
    logic                    st0_req_is_store;
    logic                    st0_req_is_amo;
    logic                    st0_req_is_cmo_fence;
    logic                    st0_req_is_cmo_inval;
    logic                    st0_req_is_cmo_prefetch;
    logic                    st0_req_is_partial;
    logic                    st0_req_cachedir_read;
    hpdcache_set_t           st0_req_set;
    hpdcache_word_t          st0_req_word;
    logic                    st0_rtab_pop_try_valid;
    logic                    st0_rtab_pop_try_ready;
    rtab_entry_t             st0_rtab_pop_try_req;
    rtab_ptr_t               st0_rtab_pop_try_ptr;

    // Pipeline Stage 1
    logic                    st1_rsp_valid;
    logic                    st1_rsp_error;
    logic                    st1_rsp_aborted;
    hpdcache_req_x_t         st1_req;
    logic                    st1_req_abort;
    logic                    st1_req_cachedata_write;
    logic                    st1_req_cachedata_write_enable;
    logic                    st1_req_cachedata_write_merge;
    hpdcache_pma_t           st1_req_pma;
    hpdcache_tag_t           st1_req_tag;
    hpdcache_set_t           st1_req_set;
    hpdcache_word_t          st1_req_word;
    hpdcache_nline_t         st1_req_nline;
    hpdcache_req_addr_t      st1_req_addr;
    logic                    st1_victim_sel;
    logic                    st1_req_updt_sel_victim;
    logic                    st1_req_is_uncacheable;
    logic                    st1_req_is_load;
    logic                    st1_req_is_store;
    logic                    st1_req_is_amo;
    logic                    st1_req_is_amo_lr;
    logic                    st1_req_is_amo_sc;
    logic                    st1_req_is_amo_swap;
    logic                    st1_req_is_amo_add;
    logic                    st1_req_is_amo_and;
    logic                    st1_req_is_amo_or;
    logic                    st1_req_is_amo_xor;
    logic                    st1_req_is_amo_max;
    logic                    st1_req_is_amo_maxu;
    logic                    st1_req_is_amo_min;
    logic                    st1_req_is_amo_minu;
    logic                    st1_req_is_cmo_inval;
    logic                    st1_req_is_cmo_flush;
    logic                    st1_req_is_cmo_fence;
    logic                    st1_req_is_cmo_prefetch;
    logic                    st1_req_is_partial;
    logic                    st1_req_wr_wt;
    logic                    st1_req_wr_wb;
    logic                    st1_req_wr_auto;
    logic                    st1_dir_hit;
    logic                    st1_dir_hit_wback;
    logic                    st1_dir_hit_dirty;
    logic                    st1_dir_hit_fetch;
    hpdcache_way_vector_t    st1_dir_hit_way;
    hpdcache_way_t           st1_dir_hit_way_index;
    hpdcache_tag_t           st1_dir_hit_tag;
    logic                    st1_dir_victim_unavailable;
    logic                    st1_dir_victim_valid;
    logic                    st1_dir_victim_wback;
    logic                    st1_dir_victim_dirty;
    hpdcache_tag_t           st1_dir_victim_tag;
    hpdcache_way_vector_t    st1_dir_victim_way;
    hpdcache_way_vector_t    st1_dir_err_cor;
    hpdcache_way_vector_t    st1_dir_err_unc;
    hpdcache_way_vector_t    st1_dir_err_valid;
    hpdcache_way_vector_t    st1_dir_err_dirty;
    hpdcache_way_vector_t    st1_dat_err_cor;
    hpdcache_way_vector_t    st1_dat_err_unc;
    hpdcache_way_vector_t    st1_dat_err_unc_dirty;
    logic                    st1_err_trigger;
    logic                    err_busy;
    hpdcache_nline_t         st1_victim_nline;
    logic                    st1_rtab_alloc;
    logic                    st1_rtab_alloc_and_link;
    logic                    st1_rtab_pop_try_commit;
    logic                    st1_rtab_pop_try_rback;
    hpdcache_rtab_deps_t     st1_rtab_deps;
    logic                    st1_rtab_check;
    logic                    st1_rtab_check_hit;
    logic                    st1_no_pend_trans;

    // Pipeline Stage 1/2 (depending on lowLatency setting)
    logic                    core_rsp_valid;
    logic                    core_rsp_error;
    logic                    core_rsp_aborted;
    hpdcache_req_tid_t       core_rsp_tid;
    hpdcache_req_sid_t       core_rsp_sid;

    hpdcache_way_t           refill_way_index;

    logic                    rtab_full;
    logic                    rtab_fence;
    logic                    rtab_no_pend_trans;

    logic                    st1_empty;
    logic                    st2_empty;

    logic                    hpdcache_init_ready;

    logic                    data_req_read;
    hpdcache_set_t           data_req_read_set;
    hpdcache_req_size_t      data_req_read_size;
    hpdcache_word_t          data_req_read_word;
    hpdcache_way_vector_t    data_req_read_way;
    hpdcache_req_data_t      data_req_read_data;

    logic                    rd_wr_conflict;
    //  }}}

    //  Decoding of the request in stage 0
    //  {{{
    always_comb
    begin : st0_req_pma_comb
        st0_req_pma = core_req_i.pma;

        //  force uncacheable requests if the cache is disabled
        if (!cfg_enable_i) begin
            st0_req_pma.uncacheable = 1'b1;
        end

        //  if either WB or WT is not supported, force write-policy
        if (!HPDcacheCfg.u.wtEn) begin
            st0_req_pma.wr_policy_hint = HPDCACHE_WR_POLICY_WB;
        end
        if (!HPDcacheCfg.u.wbEn) begin
            st0_req_pma.wr_policy_hint = HPDCACHE_WR_POLICY_WT;
        end
    end

    //     Select between request in the replay table or a new core requests
    always_comb
    begin : st0_req_comb
        st0_req = '0;
        if (st0_rtab_pop_try_valid) begin
            //  Grant RTAB request
            st0_req = st0_rtab_pop_try_req.req;

            //  Requests in the RTAB have their address translated at allocation time
            st0_req.req.phys_indexed = 1'b1;

            //  Indicate that this request is being replayed
            st0_req.from_rtab = 1'b1;
        end else begin
            //  Grant core request
            st0_req.req = core_req_i;
        end
    end

    //     Decode operation in stage 0
    assign st0_req_is_uncacheable  =     st0_req.req.pma.uncacheable;
    assign st0_req_is_load         =         is_load(st0_req.req.op);
    assign st0_req_is_store        =        is_store(st0_req.req.op);
    assign st0_req_is_amo          =          is_amo(st0_req.req.op);
    assign st0_req_is_cmo_fence    =    is_cmo_fence(st0_req.req.op);
    assign st0_req_is_cmo_inval    =    is_cmo_inval(st0_req.req.op);
    assign st0_req_is_cmo_prefetch = is_cmo_prefetch(st0_req.req.op);

    assign st0_req_is_partial = (hpdcache_uint'(st0_req.req.size) < HPDcacheCfg.wordByteIdxWidth);
    //  }}}

    //  Decode operation in stage 1
    //  {{{
    always_comb
    begin : st1_req_pma_comb
        st1_req_pma = st1_req_q.req.phys_indexed ? st1_req_q.req.pma : core_req_pma_i;

        //  force uncacheable requests if the cache is disabled
        if (!cfg_enable_i) begin
            st1_req_pma.uncacheable = 1'b1;
        end

        //  if either WB or WT is not supported, force write-policy
        if (!HPDcacheCfg.u.wtEn) begin
            st1_req_pma.wr_policy_hint = HPDCACHE_WR_POLICY_WB;
        end
        if (!HPDcacheCfg.u.wbEn) begin
            st1_req_pma.wr_policy_hint = HPDCACHE_WR_POLICY_WT;
        end
    end

    //         In case of replay or physically-indexed cache, the tag and PMA come
    //         from stage 0. Otherwise, this information come directly from the
    //         requester in stage 1
    assign st1_req_tag = st1_req_q.req.phys_indexed ? st1_req_q.req.addr_tag : core_req_tag_i;

    always_comb
    begin : st1_req_comb
        st1_req = st1_req_q;
        if (!st1_req_q.from_rtab) begin
            st1_req.req.addr_tag = st1_req_tag;
            st1_req.req.pma      = st1_req_pma;
        end
    end

    //         A requester can ask to abort a request it initiated on the
    //         previous cycle (stage 0). Useful in case of TLB miss for example
    assign st1_req_abort           = core_req_abort_i & ~st1_req.req.phys_indexed;

    assign st1_req_is_uncacheable  = ~cfg_enable_i | st1_req.req.pma.uncacheable;
    assign st1_req_is_load         =         is_load(st1_req.req.op);
    assign st1_req_is_store        =        is_store(st1_req.req.op);
    assign st1_req_is_amo          =          is_amo(st1_req.req.op);
    assign st1_req_is_amo_lr       =       is_amo_lr(st1_req.req.op);
    assign st1_req_is_amo_sc       =       is_amo_sc(st1_req.req.op);
    assign st1_req_is_amo_swap     =     is_amo_swap(st1_req.req.op);
    assign st1_req_is_amo_add      =      is_amo_add(st1_req.req.op);
    assign st1_req_is_amo_and      =      is_amo_and(st1_req.req.op);
    assign st1_req_is_amo_or       =       is_amo_or(st1_req.req.op);
    assign st1_req_is_amo_xor      =      is_amo_xor(st1_req.req.op);
    assign st1_req_is_amo_max      =      is_amo_max(st1_req.req.op);
    assign st1_req_is_amo_maxu     =     is_amo_maxu(st1_req.req.op);
    assign st1_req_is_amo_min      =      is_amo_min(st1_req.req.op);
    assign st1_req_is_amo_minu     =     is_amo_minu(st1_req.req.op);
    assign st1_req_is_cmo_inval    =    is_cmo_inval(st1_req.req.op);
    assign st1_req_is_cmo_flush    =    is_cmo_flush(st1_req.req.op);
    assign st1_req_is_cmo_fence    =    is_cmo_fence(st1_req.req.op);
    assign st1_req_is_cmo_prefetch = is_cmo_prefetch(st1_req.req.op);

    assign st1_req_is_partial = (hpdcache_uint'(st1_req.req.size) < HPDcacheCfg.wordByteIdxWidth);

    //  Decode write-policy hint
    assign st1_req_wr_wt           = (st1_req.req.pma.wr_policy_hint == HPDCACHE_WR_POLICY_WT);
    assign st1_req_wr_wb           = (st1_req.req.pma.wr_policy_hint == HPDCACHE_WR_POLICY_WB);
    assign st1_req_wr_auto         = (st1_req.req.pma.wr_policy_hint == HPDCACHE_WR_POLICY_AUTO);
    //  }}}

    //  Cache controller protocol engine
    //  {{{
    assign st1_dat_err_unc_dirty = st1_dir_err_valid & st1_dir_err_dirty & st1_dat_err_unc;

    hpdcache_ctrl_pe #(
        .HPDcacheCfg(HPDcacheCfg)
    ) hpdcache_ctrl_pe_i(
        .core_req_valid_i,
        .core_req_ready_o,
        .rtab_req_valid_i                   (st0_rtab_pop_try_valid),
        .rtab_req_ready_o                   (st0_rtab_pop_try_ready),
        .refill_req_valid_i,
        .refill_req_ready_o,

        .st0_req_is_error_i                 (st0_req.is_error),
        .st0_req_is_uncacheable_i           (st0_req_is_uncacheable),
        .st0_req_need_rsp_i                 (st0_req.req.need_rsp),
        .st0_req_is_load_i                  (st0_req_is_load),
        .st0_req_is_store_i                 (st0_req_is_store),
        .st0_req_is_amo_i                   (st0_req_is_amo),
        .st0_req_is_cmo_fence_i             (st0_req_is_cmo_fence),
        .st0_req_is_cmo_inval_i             (st0_req_is_cmo_inval),
        .st0_req_is_cmo_prefetch_i          (st0_req_is_cmo_prefetch),
        .st0_req_is_partial_i               (st0_req_is_partial),
        .st0_req_mshr_check_o               (st0_mshr_check_o),
        .st0_req_cachedir_read_o            (st0_req_cachedir_read),

        .st1_req_valid_i                    (st1_req_valid_q),
        .st1_req_abort_i                    (st1_req_abort),
        .st1_req_rtab_i                     (st1_req.from_rtab),
        .st1_req_is_error_i                 (st1_req.is_error),
        .st1_req_is_uncacheable_i           (st1_req_is_uncacheable),
        .st1_req_need_rsp_i                 (st1_req.req.need_rsp),
        .st1_req_is_load_i                  (st1_req_is_load),
        .st1_req_is_store_i                 (st1_req_is_store),
        .st1_req_is_amo_i                   (st1_req_is_amo),
        .st1_req_is_cmo_inval_i             (st1_req_is_cmo_inval),
        .st1_req_is_cmo_flush_i             (st1_req_is_cmo_flush),
        .st1_req_is_cmo_fence_i             (st1_req_is_cmo_fence),
        .st1_req_is_cmo_prefetch_i          (st1_req_is_cmo_prefetch),
        .st1_req_is_partial_i               (st1_req_is_partial),
        .st1_req_wr_wt_i                    (st1_req_wr_wt),
        .st1_req_wr_wb_i                    (st1_req_wr_wb),
        .st1_req_wr_auto_i                  (st1_req_wr_auto),
        .st1_dir_hit_wback_i                (st1_dir_hit_wback),
        .st1_dir_hit_dirty_i                (st1_dir_hit_dirty),
        .st1_dir_hit_fetch_i                (st1_dir_hit_fetch),
        .st1_dir_victim_unavailable_i       (st1_dir_victim_unavailable),
        .st1_dir_victim_valid_i             (st1_dir_victim_valid),
        .st1_dir_victim_wback_i             (st1_dir_victim_wback),
        .st1_dir_victim_dirty_i             (st1_dir_victim_dirty),
        .st1_dir_err_cor_i                  (|st1_dir_err_cor),
        .st1_dir_err_unc_i                  (|st1_dir_err_unc),
        .st1_dat_err_cor_i                  (|st1_dat_err_cor),
        .st1_dat_err_unc_i                  (|st1_dat_err_unc),
        .st1_dat_err_unc_dirty_i            (|st1_dat_err_unc_dirty),
        .st1_err_o                          (st1_err_trigger),
        .err_busy_i                         (err_busy),
        .st1_req_valid_o                    (st1_req_valid_d),
        .st1_rsp_valid_o                    (st1_rsp_valid),
        .st1_rsp_error_o                    (st1_rsp_error),
        .st1_rsp_aborted_o                  (st1_rsp_aborted),
        .st1_req_cachedir_sel_victim_o      (st1_victim_sel),
        .st1_req_cachedir_updt_sel_victim_o (st1_req_updt_sel_victim),
        .st1_req_cachedata_write_o          (st1_req_cachedata_write),
        .st1_req_cachedata_write_enable_o   (st1_req_cachedata_write_enable),
        .st1_req_cachedata_write_merge_o    (st1_req_cachedata_write_merge),
        .st1_no_pend_trans_i                (st1_no_pend_trans),

        .st2_mshr_alloc_i                   (st2_mshr_alloc_q),
        .st2_mshr_alloc_is_prefetch_i       (st2_mshr_alloc_is_prefetch_q),
        .st2_mshr_alloc_wback_i             (st2_mshr_alloc_wback_q),
        .st2_mshr_alloc_dirty_i             (st2_mshr_alloc_dirty_q),
        .st2_mshr_alloc_o                   (st2_mshr_alloc_d),
        .st2_mshr_alloc_cs_o                (st2_mshr_alloc_cs_o),
        .st2_mshr_alloc_need_rsp_o          (st2_mshr_alloc_need_rsp_d),
        .st2_mshr_alloc_wback_o             (st2_mshr_alloc_wback_d),
        .st2_mshr_alloc_dirty_o             (st2_mshr_alloc_dirty_d),

        .st2_dir_updt_i                     (st2_dir_updt_q),
        .st2_dir_updt_valid_i               (st2_dir_updt_valid_q),
        .st2_dir_updt_wback_i               (st2_dir_updt_wback_q),
        .st2_dir_updt_dirty_i               (st2_dir_updt_dirty_q),
        .st2_dir_updt_fetch_i               (st2_dir_updt_fetch_q),
        .st2_dir_updt_o                     (st2_dir_updt_d),
        .st2_dir_updt_valid_o               (st2_dir_updt_valid_d),
        .st2_dir_updt_wback_o               (st2_dir_updt_wback_d),
        .st2_dir_updt_dirty_o               (st2_dir_updt_dirty_d),
        .st2_dir_updt_fetch_o               (st2_dir_updt_fetch_d),

        .req_cachedata_read_o               (data_req_read),
        .rd_wr_conflict_i                   (rd_wr_conflict),

        .flush_busy_i,
        .st1_flush_check_hit_i              (flush_check_hit_i),
        .st1_flush_alloc_ready_i            (flush_alloc_ready_i),
        .st2_flush_alloc_i                  (st2_flush_alloc_q),
        .st2_flush_alloc_o                  (st2_flush_alloc_d),

        .rtab_full_i                        (rtab_full),
        .rtab_fence_i                       (rtab_fence),
        .rtab_check_o                       (st1_rtab_check),
        .rtab_check_hit_i                   (st1_rtab_check_hit),
        .st1_rtab_alloc_o                   (st1_rtab_alloc),
        .st1_rtab_alloc_and_link_o          (st1_rtab_alloc_and_link),
        .st1_rtab_commit_o                  (st1_rtab_pop_try_commit),
        .st1_rtab_rback_o                   (st1_rtab_pop_try_rback),
        .st1_rtab_mshr_hit_o                (st1_rtab_deps.mshr_hit),
        .st1_rtab_mshr_full_o               (st1_rtab_deps.mshr_full),
        .st1_rtab_mshr_ready_o              (st1_rtab_deps.mshr_ready),
        .st1_rtab_write_miss_o              (st1_rtab_deps.write_miss),
        .st1_rtab_wbuf_hit_o                (st1_rtab_deps.wbuf_hit),
        .st1_rtab_wbuf_not_ready_o          (st1_rtab_deps.wbuf_not_ready),
        .st1_rtab_dir_unavailable_o         (st1_rtab_deps.dir_unavailable),
        .st1_rtab_dir_fetch_o               (st1_rtab_deps.dir_fetch),
        .st1_rtab_flush_hit_o               (st1_rtab_deps.flush_hit),
        .st1_rtab_flush_not_ready_o         (st1_rtab_deps.flush_not_ready),
        .st1_rtab_pend_trans_o              (st1_rtab_deps.pend_trans),

        .cachedir_hit_i                     (cachedir_hit_o),
        .cachedir_init_ready_i              (hpdcache_init_ready),

        .st1_mshr_alloc_ready_i             (st1_mshr_alloc_ready_i),
        .st1_mshr_hit_i                     (st1_mshr_hit_i),
        .st1_mshr_full_i                    (st1_mshr_alloc_full_i),
        .st1_mshr_cbuf_full_i               (st1_mshr_alloc_cbuf_full_i),

        .refill_busy_i,
        .refill_core_rsp_valid_i,

        .wbuf_write_valid_o                 (wbuf_write_o),
        .wbuf_write_ready_i,
        .wbuf_read_hit_i,
        .wbuf_write_uncacheable_o,
        .wbuf_read_flush_hit_o,

        .uc_busy_i,
        .uc_req_valid_o,
        .uc_core_rsp_ready_o,

        .cmo_busy_i,
        .cmo_wait_i,
        .cmo_req_valid_o,
        .cmo_core_rsp_ready_o,

        .cfg_prefetch_updt_plru_i,
        .cfg_default_wb_i,

        .evt_cache_write_miss_o,
        .evt_cache_read_miss_o,
        .evt_cache_dir_unc_err_o,
        .evt_cache_dir_cor_err_o,
        .evt_cache_dat_unc_err_o,
        .evt_cache_dat_cor_err_o,
        .evt_uncached_req_o,
        .evt_cmo_req_o,
        .evt_write_req_o,
        .evt_read_req_o,
        .evt_prefetch_req_o,
        .evt_req_on_hold_o,
        .evt_rtab_rollback_o,
        .evt_stall_refill_o,
        .evt_stall_o
    );

    // No pending transaction across different handlers
    assign st1_no_pend_trans = st2_empty
                               & rtab_empty_o
                               & wbuf_empty_i
                               & mshr_empty_i
                               & flush_empty_i;
    assign rtab_no_pend_trans = ctrl_empty_o
                               & wbuf_empty_i
                               & mshr_empty_i
                               & flush_empty_i;

    //  pipeline is empty
    always_comb
    begin : pipeline_empty_comb
        st1_empty = ~st1_req_valid_q;
        st2_empty = ~(st2_mshr_alloc_q | st2_dir_updt_q | st2_flush_alloc_q);
        ctrl_empty_o = st1_empty & st2_empty;
    end

    //  no available victim cacheline (all pre-allocated for replacement)
    assign st1_dir_victim_unavailable = ~(|st1_dir_victim_way);
    //  }}}

    //  Replay table
    //  {{{
    rtab_entry_t st1_alloc_rtab;

    hpdcache_1hot_to_binary #(
        .N     (HPDcacheCfg.u.ways)
    ) dir_hit_way_encoder_i(
        .val_i (st1_dir_hit_way),
        .val_o (st1_dir_hit_way_index)
    );

    hpdcache_1hot_to_binary #(
        .N     (HPDcacheCfg.u.ways)
    ) refill_way_encoder_i(
        .val_i (refill_way_i),
        .val_o (refill_way_index)
    );

    assign st1_alloc_rtab = '{
        req       : st1_req,
        way_fetch : st1_dir_hit_way_index
    };

    hpdcache_rtab #(
        .HPDcacheCfg                        (HPDcacheCfg),
        .hpdcache_nline_t                   (hpdcache_nline_t),
        .hpdcache_way_t                     (hpdcache_way_t),
        .hpdcache_req_addr_t                (hpdcache_req_addr_t),
        .rtab_ptr_t                         (rtab_ptr_t),
        .rtab_cnt_t                         (rtab_cnt_t),
        .rtab_entry_t                       (rtab_entry_t)
    ) hpdcache_rtab_i(
        .clk_i,
        .rst_ni,

        .empty_o                            (rtab_empty_o),
        .full_o                             (rtab_full),
        .fence_o                            (rtab_fence),

        .check_i                            (st1_rtab_check),
        .check_nline_i                      (st1_req_nline),
        .check_hit_o                        (st1_rtab_check_hit),

        .alloc_i                            (st1_rtab_alloc),
        .alloc_and_link_i                   (st1_rtab_alloc_and_link),
        .alloc_req_i                        (st1_alloc_rtab),
        .alloc_deps_i                       (st1_rtab_deps),

        .pop_try_valid_o                    (st0_rtab_pop_try_valid),
        .pop_try_i                          (st0_rtab_pop_try_ready),
        .pop_try_req_o                      (st0_rtab_pop_try_req),
        .pop_try_ptr_o                      (st0_rtab_pop_try_ptr),

        .pop_commit_i                       (st1_rtab_pop_try_commit),
        .pop_commit_ptr_i                   (st1_rtab_pop_try_ptr_q),

        .pop_rback_i                        (st1_rtab_pop_try_rback),
        .pop_rback_ptr_i                    (st1_rtab_pop_try_ptr_q),

        .wbuf_addr_o                        (wbuf_rtab_addr_o),
        .wbuf_is_read_o                     (wbuf_rtab_is_read_o),
        .wbuf_hit_open_i                    (wbuf_rtab_hit_open_i),
        .wbuf_hit_pend_i                    (wbuf_rtab_hit_pend_i),
        .wbuf_hit_sent_i                    (wbuf_rtab_hit_sent_i),
        .wbuf_not_ready_i                   (wbuf_rtab_not_ready_i),

        .miss_ready_i                       (st1_mshr_alloc_ready_i),

        .refill_i                           (refill_updt_rtab_i),
        .refill_is_error_i,
        .refill_nline_i,
        .refill_way_index_i                 (refill_way_index),

        .flush_ack_i                        (flush_ack_i),
        .flush_ack_nline_i                  (flush_ack_nline_i),
        .flush_ready_i                      (flush_alloc_ready_i),

        .cfg_single_entry_i                 (cfg_rtab_single_entry_i),

        .no_pend_trans_i                    (rtab_no_pend_trans)
    );
    //  }}}

    //  Pipeline stage 1 registers
    //  {{{
    always_ff @(posedge clk_i)
    begin : st1_req_payload_ff
        if (core_req_ready_o | st0_rtab_pop_try_ready) begin
            st1_req_q <= st0_req;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : st1_req_valid_ff
        if (!rst_ni) begin
            st1_req_valid_q        <= 1'b0;
            st1_rtab_pop_try_ptr_q <= '0;
        end else begin
            st1_req_valid_q <= st1_req_valid_d;
            if (st0_rtab_pop_try_ready) begin
                st1_rtab_pop_try_ptr_q <= st0_rtab_pop_try_ptr;
            end
        end
    end
    //  }}}

    //  Pipeline stage 2 registers
    //  {{{
    always_ff @(posedge clk_i)
    begin : st2_metadata_ff
        if (st2_mshr_alloc_d) begin
            st2_mshr_alloc_need_rsp_q    <= st2_mshr_alloc_need_rsp_d;
            st2_mshr_alloc_addr_q        <= st1_req_addr;
            st2_mshr_alloc_sid_q         <= st1_req.req.sid;
            st2_mshr_alloc_tid_q         <= st1_req.req.tid;
            st2_mshr_alloc_wdata_q       <= st1_req.req.wdata;
            st2_mshr_alloc_be_q          <= st1_req.req.be;
            st2_mshr_alloc_is_prefetch_q <= st1_req_is_cmo_prefetch;
            st2_mshr_alloc_wback_q       <= st2_mshr_alloc_wback_d;
            st2_mshr_alloc_dirty_q       <= st2_mshr_alloc_dirty_d;
            st2_mshr_alloc_victim_way_q  <= st1_dir_victim_way;
        end

        if (st2_flush_alloc_d) begin
            st2_flush_alloc_nline_q <= st1_dir_hit ? st1_req_nline   : st1_victim_nline;
            st2_flush_alloc_way_q   <= st1_dir_hit ? st1_dir_hit_way : st1_dir_victim_way;
        end

        if (st2_dir_updt_d) begin
            st2_dir_updt_tag_q   <= st1_dir_hit ? st1_dir_hit_tag : st1_dir_victim_tag;
            st2_dir_updt_set_q   <= st1_req_set;
            st2_dir_updt_way_q   <= st1_dir_hit ? st1_dir_hit_way : st1_dir_victim_way;
            st2_dir_updt_valid_q <= st2_dir_updt_valid_d;
            st2_dir_updt_wback_q <= st2_dir_updt_wback_d;
            st2_dir_updt_dirty_q <= st2_dir_updt_dirty_d;
            st2_dir_updt_fetch_q <= st2_dir_updt_fetch_d;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : st2_valid_ff
        if (!rst_ni) begin
            st2_mshr_alloc_q  <= 1'b0;
            st2_flush_alloc_q <= 1'b0;
            st2_dir_updt_q    <= 1'b0;
        end else begin
            st2_mshr_alloc_q  <= st2_mshr_alloc_d;
            st2_flush_alloc_q <= st2_flush_alloc_d;
            st2_dir_updt_q    <= st2_dir_updt_d;
        end
    end
    //  }}}

    //  Controller for the HPDcache directory and data memory arrays
    //  {{{
    assign st0_req_set = st0_req.req.addr_offset[HPDcacheCfg.clOffsetWidth +:
                                                 HPDcacheCfg.setWidth];
    assign st0_req_word = st0_req.req.addr_offset[HPDcacheCfg.wordByteIdxWidth +:
                                                  HPDcacheCfg.clWordIdxWidth];

    assign st1_req_set = st1_req.req.addr_offset[HPDcacheCfg.clOffsetWidth +:
                                                 HPDcacheCfg.setWidth];
    assign st1_req_word = st1_req.req.addr_offset[HPDcacheCfg.wordByteIdxWidth +:
                                                  HPDcacheCfg.clWordIdxWidth];
    assign st1_req_addr = {st1_req.req.addr_tag, st1_req.req.addr_offset};
    assign st1_req_nline = st1_req_addr[HPDcacheCfg.clOffsetWidth +: HPDcacheCfg.nlineWidth];

    assign st1_victim_nline = {st1_dir_victim_tag, st1_req_set};

    //  When lowLatency, data SRAM is read at stage 0 but way selection is done at stage 1
    if (HPDcacheCfg.u.lowLatency) begin : gen_st0_data_sram_read
        assign data_req_read_set = st0_req_set;
        assign data_req_read_size = st0_req.req.size;
        assign data_req_read_word = st0_req_word;
        assign data_req_read_way = st1_dir_hit_way;
    end
    //  When not lowLatency, data SRAM is read at stage 1 but way selection is done at stage 2
    else begin : gen_st1_data_sram_read
        assign data_req_read_set = st1_req_set;
        assign data_req_read_size = st1_req.req.size;
        assign data_req_read_word = st1_req_word;
        always_ff @(posedge clk_i)
        begin : data_req_read_way_ff
            data_req_read_way <= st1_dir_hit_way;
        end
    end

    hpdcache_memctrl #(
        .HPDcacheCfg                   (HPDcacheCfg),
        .hpdcache_nline_t              (hpdcache_nline_t),
        .hpdcache_tag_t                (hpdcache_tag_t),
        .hpdcache_set_t                (hpdcache_set_t),
        .hpdcache_word_t               (hpdcache_word_t),
        .hpdcache_way_vector_t         (hpdcache_way_vector_t),
        .hpdcache_dir_entry_t          (hpdcache_dir_entry_t),
        .hpdcache_data_word_t          (hpdcache_data_word_t),
        .hpdcache_data_be_t            (hpdcache_data_be_t),
        .hpdcache_req_data_t           (hpdcache_req_data_t),
        .hpdcache_req_be_t             (hpdcache_req_be_t),
        .hpdcache_access_data_t        (hpdcache_access_data_t),
        .hpdcache_access_be_t          (hpdcache_access_be_t)
    ) hpdcache_memctrl_i(
        .clk_i,
        .rst_ni,

        .ready_o                       (hpdcache_init_ready),
        .rd_wr_conflict_o              (rd_wr_conflict),

        .dir_match_i                   (st0_req_cachedir_read),
        .dir_match_set_i               (st0_req_set),
        .dir_match_tag_i               (st1_req.req.addr_tag),
        .dir_updt_sel_victim_i         (st1_req_updt_sel_victim),
        .dir_hit_way_o                 (st1_dir_hit_way),
        .dir_hit_tag_o                 (st1_dir_hit_tag),
        .dir_hit_wback_o               (st1_dir_hit_wback),
        .dir_hit_dirty_o               (st1_dir_hit_dirty),
        .dir_hit_fetch_o               (st1_dir_hit_fetch),

        .dir_updt_i                    (st2_dir_updt_q),
        .dir_updt_set_i                (st2_dir_updt_set_q),
        .dir_updt_way_i                (st2_dir_updt_way_q),
        .dir_updt_tag_i                (st2_dir_updt_tag_q),
        .dir_updt_valid_i              (st2_dir_updt_valid_q),
        .dir_updt_wback_i              (st2_dir_updt_wback_q),
        .dir_updt_dirty_i              (st2_dir_updt_dirty_q),
        .dir_updt_fetch_i              (st2_dir_updt_fetch_q),

        .dir_refill_i                  (refill_write_dir_i),
        .dir_refill_set_i              (refill_set_i),
        .dir_refill_way_i              (refill_way_i),
        .dir_refill_entry_i            (refill_dir_entry_i),
        .dir_refill_updt_sel_victim_i  (refill_updt_sel_victim_i),

        .dir_victim_sel_i              (st1_victim_sel),
        .dir_victim_set_i              (st1_req_set),
        .dir_victim_valid_o            (st1_dir_victim_valid),
        .dir_victim_wback_o            (st1_dir_victim_wback),
        .dir_victim_dirty_o            (st1_dir_victim_dirty),
        .dir_victim_tag_o              (st1_dir_victim_tag),
        .dir_victim_way_o              (st1_dir_victim_way),

        .dir_inval_check_i             (inval_check_dir_i),
        .dir_inval_nline_i             (inval_nline_i),
        .dir_inval_write_i             (inval_write_dir_i),
        .dir_inval_hit_o               (inval_hit_o),

        .dir_cmo_check_nline_i         (cmo_dir_check_nline_i),
        .dir_cmo_check_nline_set_i     (cmo_dir_check_nline_set_i),
        .dir_cmo_check_nline_tag_i     (cmo_dir_check_nline_tag_i),
        .dir_cmo_check_nline_hit_way_o (cmo_dir_check_nline_hit_way_o),
        .dir_cmo_check_nline_wback_o   (cmo_dir_check_nline_wback_o),
        .dir_cmo_check_nline_dirty_o   (cmo_dir_check_nline_dirty_o),

        .dir_cmo_check_entry_i         (cmo_dir_check_entry_i),
        .dir_cmo_check_entry_set_i     (cmo_dir_check_entry_set_i),
        .dir_cmo_check_entry_way_i     (cmo_dir_check_entry_way_i),
        .dir_cmo_check_entry_valid_o   (cmo_dir_check_entry_valid_o),
        .dir_cmo_check_entry_wback_o   (cmo_dir_check_entry_wback_o),
        .dir_cmo_check_entry_dirty_o   (cmo_dir_check_entry_dirty_o),
        .dir_cmo_check_entry_tag_o     (cmo_dir_check_entry_tag_o),

        .dir_cmo_updt_i                (cmo_dir_updt_i),
        .dir_cmo_updt_set_i            (cmo_dir_updt_set_i),
        .dir_cmo_updt_way_i            (cmo_dir_updt_way_i),
        .dir_cmo_updt_tag_i            (cmo_dir_updt_tag_i),
        .dir_cmo_updt_valid_i          (cmo_dir_updt_valid_i),
        .dir_cmo_updt_wback_i          (cmo_dir_updt_wback_i),
        .dir_cmo_updt_dirty_i          (cmo_dir_updt_dirty_i),
        .dir_cmo_updt_fetch_i          (cmo_dir_updt_fetch_i),

        .dir_err_cor_o                 (st1_dir_err_cor),
        .dir_err_unc_o                 (st1_dir_err_unc),
        .dir_err_valid_o               (st1_dir_err_valid),
        .dir_err_dirty_o               (st1_dir_err_dirty),

        .dir_err_set_i                 (err_set_q),
        .dir_err_way_i                 (err_way_q),
        .dir_err_read_i                (err_dir_read),
        .dir_err_rdata_o               (err_dir_rdata_d),
        .dir_err_write_i               (err_dir_write),
        .dir_err_wdata_i               (err_dir_wdata),

        .data_req_read_i               (data_req_read),
        .data_req_read_set_i           (data_req_read_set),
        .data_req_read_size_i          (data_req_read_size),
        .data_req_read_word_i          (data_req_read_word),
        .data_req_read_way_i           (data_req_read_way),
        .data_req_read_data_o          (data_req_read_data),

        .data_req_write_i              (st1_req_cachedata_write),
        .data_req_write_enable_i       (st1_req_cachedata_write_enable),
        .data_req_write_merge_i        (st1_req_cachedata_write_merge),
        .data_req_write_set_i          (st1_req_set),
        .data_req_write_way_i          (st1_dir_hit_way),
        .data_req_write_size_i         (st1_req.req.size),
        .data_req_write_word_i         (st1_req_word),
        .data_req_write_data_i         (st1_req.req.wdata),
        .data_req_write_be_i           (st1_req.req.be),

        .data_amo_write_i              (uc_data_amo_write_i),
        .data_amo_write_enable_i       (uc_data_amo_write_enable_i),
        .data_amo_write_set_i          (uc_data_amo_write_set_i),
        .data_amo_write_size_i         (uc_data_amo_write_size_i),
        .data_amo_write_word_i         (uc_data_amo_write_word_i),
        .data_amo_write_way_i          (uc_data_amo_write_way_i),
        .data_amo_write_data_i         (uc_data_amo_write_data_i),
        .data_amo_write_be_i           (uc_data_amo_write_be_i),

        .data_flush_read_i             (flush_data_read_i),
        .data_flush_read_set_i         (flush_data_read_set_i),
        .data_flush_read_way_i         (flush_data_read_way_i),
        .data_flush_read_word_i        (flush_data_read_word_i),
        .data_flush_read_data_o        (flush_data_read_data_o),

        .data_refill_i                 (refill_write_data_i),
        .data_refill_set_i             (refill_set_i),
        .data_refill_way_i             (refill_way_i),
        .data_refill_word_i            (refill_word_i),
        .data_refill_data_i            (refill_data_i),

        .data_err_cor_o                (st1_dat_err_cor),
        .data_err_unc_o                (st1_dat_err_unc),
        .data_err_set_i                (err_set_q),
        .data_err_way_i                (err_way_q),
        .data_err_word_i               (err_dat_word_q),
        .data_err_read_i               (err_dat_read),
        .data_err_rdata_o              (err_dat_rdata_d),
        .data_err_write_i              (err_dat_write),
        .data_err_wdata_i              (err_dat_wdata)
    );

    assign st1_dir_hit           = |st1_dir_hit_way;

    assign cachedir_hit_o = st1_dir_hit;
    //  }}}

    //  Write buffer outputs
    //  {{{
    assign wbuf_write_addr_o = st1_req_addr;
    assign wbuf_write_data_o = st1_req.req.wdata;
    assign wbuf_write_be_o   = st1_req.req.be;
    assign wbuf_flush_all_o  = cmo_wbuf_flush_all_i | uc_wbuf_flush_all_i | wbuf_flush_i;
    //  }}}

    //  Miss handler outputs
    //  {{{
    assign st0_mshr_check_offset_o      = st0_req.req.addr_offset;
    assign st1_mshr_check_nline_o       = st1_req_nline;
    assign st2_mshr_alloc_o             = st2_mshr_alloc_q;
    assign st2_mshr_alloc_nline_o       = st2_mshr_alloc_addr_q[HPDcacheCfg.clOffsetWidth +:
                                                                HPDcacheCfg.nlineWidth];
    assign st2_mshr_alloc_tid_o         = st2_mshr_alloc_tid_q;
    assign st2_mshr_alloc_sid_o         = st2_mshr_alloc_sid_q;
    assign st2_mshr_alloc_word_o        = st2_mshr_alloc_addr_q[HPDcacheCfg.wordByteIdxWidth +:
                                                                HPDcacheCfg.clWordIdxWidth];
    assign st2_mshr_alloc_wdata_o       = st2_mshr_alloc_wdata_q;
    assign st2_mshr_alloc_be_o          = st2_mshr_alloc_be_q;
    assign st2_mshr_alloc_victim_way_o  = st2_mshr_alloc_victim_way_q;
    assign st2_mshr_alloc_need_rsp_o    = st2_mshr_alloc_need_rsp_q;
    assign st2_mshr_alloc_is_prefetch_o = st2_mshr_alloc_is_prefetch_q;
    assign st2_mshr_alloc_wback_o       = st2_mshr_alloc_wback_q;
    assign st2_mshr_alloc_dirty_o       = st2_mshr_alloc_dirty_q;
    //  }}}

    //  Uncacheable request handler outputs
    //  {{{
    assign uc_lrsc_snoop_o           = st1_req_valid_q & st1_req_is_store;
    assign uc_lrsc_snoop_addr_o      = st1_req_addr;
    assign uc_lrsc_snoop_size_o      = st1_req.req.size;
    assign uc_req_addr_o             = st1_req_addr;
    assign uc_req_size_o             = st1_req.req.size;
    assign uc_req_data_o             = st1_req.req.wdata;
    assign uc_req_be_o               = st1_req.req.be;
    assign uc_req_uc_o               = st1_req_is_uncacheable;
    assign uc_req_sid_o              = st1_req.req.sid;
    assign uc_req_tid_o              = st1_req.req.tid;
    assign uc_req_need_rsp_o         = st1_req.req.need_rsp;
    assign uc_req_dir_hit_way_o      = st1_dir_hit_way;
    assign uc_req_old_data_o         = data_req_read_data;
    assign uc_req_op_o.is_ld         = st1_req_is_load;
    assign uc_req_op_o.is_st         = st1_req_is_store;
    assign uc_req_op_o.is_amo_lr     = st1_req_is_amo_lr;
    assign uc_req_op_o.is_amo_sc     = st1_req_is_amo_sc;
    assign uc_req_op_o.is_amo_swap   = st1_req_is_amo_swap;
    assign uc_req_op_o.is_amo_add    = st1_req_is_amo_add;
    assign uc_req_op_o.is_amo_and    = st1_req_is_amo_and;
    assign uc_req_op_o.is_amo_or     = st1_req_is_amo_or;
    assign uc_req_op_o.is_amo_xor    = st1_req_is_amo_xor;
    assign uc_req_op_o.is_amo_max    = st1_req_is_amo_max;
    assign uc_req_op_o.is_amo_maxu   = st1_req_is_amo_maxu;
    assign uc_req_op_o.is_amo_min    = st1_req_is_amo_min;
    assign uc_req_op_o.is_amo_minu   = st1_req_is_amo_minu;
    //  }}}

    //  CMO request handler outputs
    //  {{{
    assign cmo_req_addr_o                       = st1_req_addr;
    assign cmo_req_wdata_o                      = st1_req.req.wdata;
    assign cmo_req_sid_o                        = st1_req.req.sid;
    assign cmo_req_tid_o                        = st1_req.req.tid;
    assign cmo_req_need_rsp_o                   = st1_req.req.need_rsp;
    assign cmo_req_op_o.is_fence                = st1_req_is_cmo_fence;
    assign cmo_req_op_o.is_inval_by_nline       = st1_req_is_cmo_inval &
                                                  is_cmo_inval_by_nline(st1_req.req.op);
    assign cmo_req_op_o.is_inval_all            = st1_req_is_cmo_inval &
                                                  is_cmo_inval_all(st1_req.req.op);
    assign cmo_req_op_o.is_flush_by_nline       = st1_req_is_cmo_flush &
                                                  is_cmo_flush_by_nline(st1_req.req.op);
    assign cmo_req_op_o.is_flush_all            = st1_req_is_cmo_flush &
                                                  is_cmo_flush_all(st1_req.req.op);
    assign cmo_req_op_o.is_flush_inval_by_nline = st1_req_is_cmo_flush &
                                                  is_cmo_flush_inval_by_nline(st1_req.req.op);
    assign cmo_req_op_o.is_flush_inval_all      = st1_req_is_cmo_flush &
                                                  is_cmo_flush_inval_all(st1_req.req.op);
    //  }}}

    //  ECC recovery handler
    //  {{{
    typedef enum {
        ERR_IDLE,
        ERR_CHECK,
        ERR_INVAL,
        ERR_LATCH,
        ERR_CORRECT
    } hpdcache_err_fsm_t;

    hpdcache_err_fsm_t    err_fsm_q, err_fsm_d;
    hpdcache_way_vector_t err_dir_unc_q;
    hpdcache_way_vector_t err_dir_cor_q;
    hpdcache_way_vector_t err_dat_unc_q;
    hpdcache_way_vector_t err_dat_cor_q;

    hpdcache_set_t         err_set_q;
    hpdcache_way_vector_t  err_way_q, err_way_d;

    logic                  err_dir_read, err_dir_write;
    logic                  err_dir_rdata_we;
    hpdcache_dir_entry_t   err_dir_rdata_q, err_dir_rdata_d;
    hpdcache_dir_entry_t   err_dir_wdata;

    logic                  err_dat_read, err_dat_write;
    logic                  err_dat_rdata_we;
    hpdcache_access_data_t err_dat_rdata_q, err_dat_rdata_d;
    hpdcache_word_t        err_dat_word_q;
    hpdcache_access_data_t err_dat_wdata;

    always_comb
    begin : err_fsm_comb
        automatic hpdcache_way_vector_t err_way_next;
        automatic logic err_dir_unc_msk, err_dir_cor_msk;
        automatic logic err_dat_unc_msk, err_dat_cor_msk;

        err_fsm_d = err_fsm_q;
        err_way_d = err_way_q;

        err_dir_unc_msk = |(err_dir_unc_q & err_way_q);
        err_dir_cor_msk = |(err_dir_cor_q & err_way_q);
        err_dat_unc_msk = |(err_dat_unc_q & err_way_q);
        err_dat_cor_msk = |(err_dat_cor_q & err_way_q);

        err_way_next  = {err_way_q[0 +: HPDcacheCfg.u.ways-1], 1'b0};
        err_dir_read  = 1'b0;
        err_dir_write = 1'b0;
        err_dir_wdata = '0;
        err_dat_read  = 1'b0;
        err_dat_write = 1'b0;
        err_dat_wdata = '0;

        err_dir_rdata_we = 1'b0;
        err_dat_rdata_we = 1'b0;

        err_busy = 1'b1;

        case (err_fsm_q)
            ERR_IDLE: begin
                err_busy = 1'b0;

                //  Start checking all ways to correct/invalidate wrong entries
                if (st1_err_trigger) begin
                    err_fsm_d = ERR_CHECK;
                    err_way_d = {{HPDcacheCfg.u.ways-1{1'b0}}, 1'b1};
                end
            end
            ERR_CHECK: begin
                if (err_dir_unc_msk | err_dat_unc_msk) begin
                    err_fsm_d = ERR_INVAL;
                end else if (err_dir_cor_msk | err_dat_cor_msk) begin
                    err_dir_read = err_dir_cor_msk;
                    err_dat_read = err_dat_cor_msk;
                    err_fsm_d = ERR_LATCH;
                end else if (err_way_q[HPDcacheCfg.u.ways - 1]) begin
                    err_fsm_d = ERR_IDLE;
                end else begin
                    err_way_d = err_way_next;
                end
            end
            ERR_INVAL: begin
                //  Invalidate the uncorrectable cacheline
                err_dir_write = 1'b1;
                err_dir_wdata = '0;
                //  Zero data words to put them in a correct state
                err_dat_write = err_dat_unc_msk;
                err_dat_wdata = '0;

                //  Check next way or go to IDLE after the last one
                if (err_way_q[HPDcacheCfg.u.ways - 1]) begin
                    err_fsm_d = ERR_IDLE;
                end else begin
                    err_way_d = err_way_next;
                    err_fsm_d = ERR_CHECK;
                end
            end
            ERR_LATCH: begin
                //  Latch corrected dir and data entries
                err_dir_rdata_we = err_dir_cor_msk;
                err_dat_rdata_we = err_dat_cor_msk;
                err_fsm_d = ERR_CORRECT;
            end
            ERR_CORRECT: begin
                //  Correct the directory entry
                err_dir_write = err_dir_cor_msk;
                err_dir_wdata = err_dir_rdata_q;
                //  Correct data words
                err_dat_write = err_dat_cor_msk;
                err_dat_wdata = err_dat_rdata_q;

                //  Check next way or go to IDLE after the last one
                if (err_way_q[HPDcacheCfg.u.ways - 1]) begin
                    err_fsm_d = ERR_IDLE;
                end else begin
                    err_way_d = err_way_next;
                    err_fsm_d = ERR_CHECK;
                end
            end
            default: begin
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : err_fsm_ff
        if (!rst_ni) begin
            err_fsm_q      <= ERR_IDLE;
            err_way_q      <= '0;
            err_set_q      <= '0;
            err_dir_unc_q  <= '0;
            err_dir_cor_q  <= '0;
            err_dat_unc_q  <= '0;
            err_dat_cor_q  <= '0;
            err_dat_word_q <= '0;
        end else begin
            err_fsm_q      <= err_fsm_d;
            err_way_q      <= err_way_d;
            if (st1_err_trigger && !err_busy) begin
                err_set_q  <= st1_req_set;

                err_dir_unc_q <= st1_dir_err_unc;
                err_dir_cor_q <= st1_dir_err_cor;
                err_dat_unc_q <= st1_dat_err_unc;
                err_dat_cor_q <= st1_dat_err_cor;

                //  Align request word to the number of access words
                //  The error recovery handler checks and corrects "access words" per cycle
                err_dat_word_q <= hpdcache_word_t'(
                    (hpdcache_uint'(st1_req_word) / HPDcacheCfg.u.accessWords) *
                    HPDcacheCfg.u.accessWords);
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : err_fsm_data_ff
        if (err_dir_rdata_we) begin
            err_dir_rdata_q <= err_dir_rdata_d;
        end
        if (err_dat_rdata_we) begin
            err_dat_rdata_q <= err_dat_rdata_d;
        end
    end
    //  }}}

    //  Dirty/valid cachelines tracking to accelerate flushes and invalidations triggered by CMOs
    //  {{{
    if (HPDcacheCfg.u.wbEn) begin : gen_cmo_dirty_set
        hpdcache_set_t cmo_dirty_min_set_q, cmo_dirty_min_set_d;
        hpdcache_set_t cmo_dirty_max_set_q, cmo_dirty_max_set_d;
        logic cmo_dirty_set_en_q, cmo_dirty_set_en_d;

        always_comb
        begin : cmo_dirty_min_max_set_comb
            automatic hpdcache_uint32 v_min;
            automatic hpdcache_uint32 v_max;
            unique if (st2_dir_updt_q && st2_dir_updt_dirty_q) begin
                //  Cacheline updated by the pipeline
                if (cmo_dirty_set_en_q) begin
                    v_min = hpdcache_min(hpdcache_uint32'(st2_dir_updt_set_q),
                        hpdcache_uint32'(cmo_dirty_min_set_q));
                    v_max = hpdcache_max(hpdcache_uint32'(st2_dir_updt_set_q),
                        hpdcache_uint32'(cmo_dirty_max_set_q));
                end else begin
                    v_min = hpdcache_uint32'(st2_dir_updt_set_q);
                    v_max = hpdcache_uint32'(st2_dir_updt_set_q);
                end
            end else if (refill_write_dir_i && refill_dir_entry_i.dirty) begin
                //  Cacheline directly written during refill
                if (cmo_dirty_set_en_q) begin
                    v_min = hpdcache_min(hpdcache_uint32'(refill_set_i),
                        hpdcache_uint32'(cmo_dirty_min_set_q));
                    v_max = hpdcache_max(hpdcache_uint32'(refill_set_i),
                        hpdcache_uint32'(cmo_dirty_max_set_q));
                end else begin
                    v_min = hpdcache_uint32'(refill_set_i);
                    v_max = hpdcache_uint32'(refill_set_i);
                end
            end else begin
                v_min = hpdcache_uint32'(cmo_dirty_min_set_q);
                v_max = hpdcache_uint32'(cmo_dirty_max_set_q);
            end
            cmo_dirty_min_set_d = hpdcache_set_t'(v_min);
            cmo_dirty_max_set_d = hpdcache_set_t'(v_max);
        end

        always_comb
        begin : cmo_dirty_set_en_comb
            unique if (
                (st2_dir_updt_q && st2_dir_updt_dirty_q) ||
                (refill_write_dir_i && refill_dir_entry_i.dirty))
            begin
                cmo_dirty_set_en_d = 1'b1;
            end else if (cmo_flush_all_i) begin
                cmo_dirty_set_en_d = 1'b0;
            end else begin
                cmo_dirty_set_en_d = cmo_dirty_set_en_q;
            end
        end

        always_ff @(posedge clk_i or negedge rst_ni)
        begin : cmo_dirty_ff
            if (!rst_ni) begin
                cmo_dirty_set_en_q <= 1'b0;
                cmo_dirty_min_set_q <= 0;
                cmo_dirty_max_set_q <= 0;
            end else begin
                cmo_dirty_set_en_q <= cmo_dirty_set_en_d;
                cmo_dirty_min_set_q <= cmo_dirty_min_set_d;
                cmo_dirty_max_set_q <= cmo_dirty_max_set_d;
            end
        end

        assign cmo_dirty_set_en_o = cmo_dirty_set_en_q;
        assign cmo_dirty_min_set_o = cmo_dirty_min_set_q;
        assign cmo_dirty_max_set_o = cmo_dirty_max_set_q;
    end else begin : gen_no_cmo_dirty_set
        assign cmo_dirty_set_en_o = 1'b0;
        assign cmo_dirty_min_set_o = '0;
        assign cmo_dirty_max_set_o = '0;
    end

    hpdcache_set_t cmo_valid_min_set_q, cmo_valid_min_set_d;
    hpdcache_set_t cmo_valid_max_set_q, cmo_valid_max_set_d;
    logic cmo_valid_set_en_q, cmo_valid_set_en_d;

    always_comb
    begin : cmo_valid_min_max_set_comb
        automatic hpdcache_uint32 v_min;
        automatic hpdcache_uint32 v_max;
        unique if (refill_write_dir_i && refill_dir_entry_i.valid) begin
            if (cmo_valid_set_en_q) begin
                v_min = hpdcache_min(hpdcache_uint32'(refill_set_i),
                    hpdcache_uint32'(cmo_valid_min_set_q));
                v_max = hpdcache_max(hpdcache_uint32'(refill_set_i),
                    hpdcache_uint32'(cmo_valid_max_set_q));
            end else begin
                v_min = hpdcache_uint32'(refill_set_i);
                v_max = hpdcache_uint32'(refill_set_i);
            end
        end else begin
            v_min = hpdcache_uint32'(cmo_valid_min_set_q);
            v_max = hpdcache_uint32'(cmo_valid_max_set_q);
        end
        cmo_valid_min_set_d = hpdcache_set_t'(v_min);
        cmo_valid_max_set_d = hpdcache_set_t'(v_max);
    end

    always_comb
    begin : cmo_valid_set_en_comb
        unique if (refill_write_dir_i && refill_dir_entry_i.valid) begin
            cmo_valid_set_en_d = 1'b1;
        end else if (cmo_inval_all_i) begin
            cmo_valid_set_en_d = 1'b0;
        end else begin
            cmo_valid_set_en_d = cmo_valid_set_en_q;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : cmo_valid_ff
        if (!rst_ni) begin
            cmo_valid_set_en_q <= 1'b0;
            cmo_valid_min_set_q <= 0;
            cmo_valid_max_set_q <= 0;
        end else begin
            cmo_valid_set_en_q <= cmo_valid_set_en_d;
            cmo_valid_min_set_q <= cmo_valid_min_set_d;
            cmo_valid_max_set_q <= cmo_valid_max_set_d;
        end
    end

    assign cmo_valid_set_en_o = cmo_valid_set_en_q;
    assign cmo_valid_min_set_o = cmo_valid_min_set_q;
    assign cmo_valid_max_set_o = cmo_valid_max_set_q;
    //  }}}

    //  Flush controller outputs
    //  {{{
    assign flush_check_nline_o = st1_req_nline;
    assign flush_alloc_o       = st2_flush_alloc_q;
    assign flush_alloc_nline_o = st2_flush_alloc_nline_q;
    assign flush_alloc_way_o   = st2_flush_alloc_way_q;
    //  }}}

    //  Control of the response to the core
    //  {{{
    if (HPDcacheCfg.u.lowLatency) begin : gen_st2_core_rsp_comb
        //  When lowLatency, all responses to the core are sent on stage 1
        assign core_rsp_valid = st1_rsp_valid;
        assign core_rsp_aborted = st1_rsp_aborted;
        assign core_rsp_error = st1_rsp_error;
        assign core_rsp_sid = st1_req.req.sid;
        assign core_rsp_tid = st1_req.req.tid;
    end else begin : gen_st2_core_rsp_ff
        //  When not lowLatency, delay all responses to the core by one cycle (stage 2)
        always_ff @(posedge clk_i or negedge rst_ni)
        begin : st2_core_rsp_ff
            if (!rst_ni) begin
                core_rsp_valid <= 1'b0;
                core_rsp_aborted <= 1'b0;
                core_rsp_error <= 1'b0;
                core_rsp_sid <= 'h0;
                core_rsp_tid <= 'h0;
            end else begin
                core_rsp_valid <= st1_rsp_valid;
                core_rsp_aborted <= st1_rsp_aborted;
                core_rsp_error <= st1_rsp_error;
                core_rsp_sid <= st1_req.req.sid;
                core_rsp_tid <= st1_req.req.tid;
            end
        end
    end

    assign core_rsp_valid_o   = refill_core_rsp_valid_i |
                                (uc_core_rsp_valid_i & uc_core_rsp_ready_o) |
                                (cmo_core_rsp_valid_i & cmo_core_rsp_ready_o) |
                                core_rsp_valid;
    assign core_rsp_o.rdata   = (refill_core_rsp_valid_i ? refill_core_rsp_i.rdata :
                                (cmo_core_rsp_valid_i    ? cmo_core_rsp_i.rdata :
                                (uc_core_rsp_valid_i     ? uc_core_rsp_i.rdata :
                                                           data_req_read_data)));
    assign core_rsp_o.sid     = (refill_core_rsp_valid_i ? refill_core_rsp_i.sid :
                                (cmo_core_rsp_valid_i    ? cmo_core_rsp_i.sid :
                                (uc_core_rsp_valid_i     ? uc_core_rsp_i.sid :
                                                           core_rsp_sid)));
    assign core_rsp_o.tid     = (refill_core_rsp_valid_i ? refill_core_rsp_i.tid :
                                (cmo_core_rsp_valid_i    ? cmo_core_rsp_i.tid :
                                (uc_core_rsp_valid_i     ? uc_core_rsp_i.tid :
                                                           core_rsp_tid)));
    assign core_rsp_o.error   = (refill_core_rsp_valid_i ? refill_core_rsp_i.error :
                                (cmo_core_rsp_valid_i    ? cmo_core_rsp_i.error :
                                (uc_core_rsp_valid_i     ? uc_core_rsp_i.error :
                                                           core_rsp_error)));
    assign core_rsp_o.aborted = core_rsp_aborted;
    //  }}}

    //  Assertions
    //  {{{
`ifndef HPDCACHE_ASSERT_OFF
    //  Check that the cache controller is being used by one and only one among a core request, the
    //  RTAB or the miss handler.
    assert property (@(posedge clk_i) disable iff (rst_ni !== 1'b1)
            $onehot0({core_req_ready_o, st0_rtab_pop_try_ready, refill_req_ready_o})) else
                    $error("ctrl: only one request can be served per cycle");

    //  Check that requests have a valid size field. The check is not necessary for the fence,
    //  invalidation and flush CMOs because these requests do not use the size field.
    property prop_core_req_size_max;
        @(posedge clk_i) disable iff (rst_ni !== 1'b1) (
            core_req_valid_i && core_req_ready_o &&
            !(is_cmo_fence(core_req_i.op) ||
              is_cmo_inval(core_req_i.op) ||
              is_cmo_flush(core_req_i.op))
        ) |-> (
            (2**core_req_i.size) <= HPDcacheCfg.reqDataBytes
        );
    endproperty

    assert property (prop_core_req_size_max) else
            $error("ctrl: bad SIZE for request");

    //  Check that stores and AMOs requests have a valid Byte Enable field. In particular, check
    //  that it is aligned with respect to the address
    function automatic bit check_is_be_aligned(
      input hpdcache_req_offset_t req_offset,
      input hpdcache_req_be_t req_be
    );
        int offset = int'(req_offset) % HPDcacheCfg.reqDataBytes;
        return (((req_be >> offset) << offset) == req_be);
    endfunction

    property prop_core_req_be_align;
        @(posedge clk_i) disable iff (rst_ni !== 1'b1) (
            core_req_valid_i && core_req_ready_o &&
            (is_store(core_req_i.op) || is_amo(core_req_i.op))
        ) |-> (
            check_is_be_aligned(core_req_i.addr_offset, core_req_i.be)
        );
    endproperty

    assert property (prop_core_req_be_align) else
            $error("ctrl: bad BE alignment for request");

    //  Check that only one cache victim way is required when reserving a slot in the MSHR
    assert property (@(posedge clk_i) disable iff (rst_ni !== 1'b1)
        st2_mshr_alloc_q |-> $onehot(st2_mshr_alloc_victim_way_q)) else
            $error("ctrl: no victim way selected during MSHR allocation");
`endif
    //  }}}
endmodule
// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en : fdm=marker
