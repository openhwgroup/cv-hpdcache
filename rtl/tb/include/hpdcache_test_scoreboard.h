/**
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
/**
 *  Author     : Cesar Fuguet
 *  Date       : October, 2024
 *  Description: Class definition of the hpdcache_test_scoreboard
 */
#ifndef __HPDCACHE_TEST_SCOREBOARD_H__
#define __HPDCACHE_TEST_SCOREBOARD_H__

#include <iostream>
#include <map>
#include <memory>
#include <sstream>
#include <systemc>
#include <verilated.h>

#include "generic_cache_directory_plru.h"
#include "hpdcache_test_amo.h"
#include "hpdcache_test_defs.h"
#include "hpdcache_test_driver.h"
#include "hpdcache_test_mem_resp_model_base.h"
#include "hpdcache_test_sequence.h"
#include "logger.h"
#include "ram_model.h"

// FIXME currently this cannot be set because there are some race conditions
// badly handled. The race conditions are when there is a refill on a given
// set and at the same time a request on the same set (but different tag). In
// that case, the LRU bits are updated in a undefined order (it depends on the
// internal arbiter of the hpdcache that decides whether to handle the request
// or the refill first).
//
// #define ENABLE_CACHE_DIR_VERIF 1

class hpdcache_test_scoreboard : public sc_module
{
public:
    sc_in<bool> clk_i;

    sc_fifo_in<hpdcache_test_transaction_req> core_req_i;
    sc_fifo_in<hpdcache_test_transaction_resp> core_resp_i;

    sc_fifo_in<hpdcache_test_transaction_mem_read_req> mem_read_req_i;
    sc_fifo_in<hpdcache_test_transaction_mem_read_resp> mem_read_resp_i;

    sc_fifo_in<hpdcache_test_transaction_mem_write_req> mem_write_req_i;
    sc_fifo_in<hpdcache_test_transaction_mem_write_resp> mem_write_resp_i;

    sc_in<bool> evt_cache_write_miss_i;
    sc_in<bool> evt_cache_read_miss_i;
    sc_in<bool> evt_uncached_req_i;
    sc_in<bool> evt_cmo_req_i;
    sc_in<bool> evt_write_req_i;
    sc_in<bool> evt_read_req_i;
    sc_in<bool> evt_prefetch_req_i;
    sc_in<bool> evt_req_on_hold_i;
    sc_in<bool> evt_rtab_rollback_i;
    sc_in<bool> evt_stall_refill_i;
    sc_in<bool> evt_stall_i;

    hpdcache_test_scoreboard(sc_core::sc_module_name nm)
      : sc_module(nm)
      , core_req_i("core_req_i")
      , core_resp_i("core_resp_i")
      , mem_read_req_i("mem_read_req_i")
      , mem_read_resp_i("mem_read_resp_i")
      , mem_write_req_i("mem_write_req_i")
      , mem_write_resp_i("mem_write_resp_i")
      , nb_cycles(0)
      , nb_cycles_effective(0)
      , nb_core_req(0)
      , nb_core_req_need_rsp(0)
      , nb_core_resp(0)
      , nb_mem_read_req(0)
      , nb_mem_read_resp(0)
      , nb_mem_write_req(0)
      , nb_mem_write_resp(0)
      , nb_error(0)
      , sb_error_limit_m(0)
      , evt_cache_write_miss(0)
      , evt_cache_read_miss(0)
      , evt_uncached_req(0)
      , evt_cmo_req(0)
      , evt_write_req(0)
      , evt_read_req(0)
      , evt_prefetch_req(0)
      , evt_req_on_hold(0)
      , evt_rtab_rollback(0)
      , evt_stall_refill(0)
      , evt_stall(0)
      , seq(nullptr)
      , mem_resp_model(nullptr)
      ,
#if ENABLE_CACHE_DIR_VERIF
      cache_dir_m(std::make_shared<GenericCacheDirectoryPlru>("hpdcache_dir",
                                                              HPDCACHE_NWAYS,
                                                              HPDCACHE_NSETS,
                                                              HPDCACHE_NWORDS * 8))
      ,
#endif
      ram_m(std::make_shared<ram_t>("ram"))
    {
        SC_THREAD(core_req_process);
        SC_THREAD(core_resp_process);
        SC_THREAD(mem_read_req_process);
        SC_THREAD(mem_read_resp_process);
        SC_THREAD(mem_write_req_process);
        SC_THREAD(mem_write_resp_process);

        SC_METHOD(perf_events_process);
        sensitive << clk_i.pos();
    }

    ~hpdcache_test_scoreboard()
    {
        std::stringstream ss;
        if (nb_core_resp != nb_core_req_need_rsp) {
            ss.str("");
            ss << "number of responses (" << nb_core_resp
               << ") is different than the number of requests (" << nb_core_req_need_rsp << ")";
            print_error(ss.str());
        }
        if (evt_cache_write_miss > evt_write_req) {
            ss.str("");
            ss << "number of write misses (" << evt_cache_write_miss
               << ") is bigger than the number of write requests (" << evt_write_req << ")";
            print_error(ss.str());
        }
        if (evt_cache_read_miss > evt_read_req) {
            ss.str("");
            ss << "number of read misses (" << evt_cache_read_miss
               << ") is bigger than the number of read requests (" << evt_read_req << ")";
            print_error(ss.str());
        }
        if (seq->ids_size() > 0) {
            ss.str("");
            ss << "unresponded ids:";
            for (auto it : seq->get_ids()) {
                ss << " 0x" << std::hex << it << std::dec;
            }
            print_error(ss.str());
        }

        if (check_verbosity(sc_core::SC_LOW)) {
            ss.str("");
            ss << "SCOREBOARD STATISTICS" << std::endl
               << "Status" << std::endl
               << "--------------------------------------------------" << std::endl
               << "SB.NB_ERROR             : " << nb_error << std::endl
               << std::endl

               << "Instrumentation" << std::endl
               << "--------------------------------------------------" << std::endl
               << "SB.NB_CYCLES            : " << nb_cycles_effective << std::endl
               << "SB.NB_CORE_REQ          : " << nb_core_req << std::endl
               << "SB.NB_CORE_RESP         : " << nb_core_resp << std::endl
               << "SB.NB_MEM_READ_REQ      : " << nb_mem_read_req << std::endl
               << "SB.NB_MEM_READ_RESP     : " << nb_mem_read_resp << std::endl
               << "SB.NB_MEM_WRITE_REQ     : " << nb_mem_write_req << std::endl
               << "SB.NB_MEM_WRITE_RESP    : " << nb_mem_write_resp << std::endl
               << "CACHE.WRITE_MISSES      : " << evt_cache_write_miss << std::endl
               << "CACHE.READ_MISSES       : " << evt_cache_read_miss << std::endl
               << "CACHE.UNCACHED_REQUESTS : " << evt_uncached_req << std::endl
               << "CACHE.CMO_REQUESTS      : " << evt_cmo_req << std::endl
               << "CACHE.WRITE_REQUESTS    : " << evt_write_req << std::endl
               << "CACHE.READ_REQUESTS     : " << evt_read_req << std::endl
               << "CACHE.PREFETCH_REQUESTS : " << evt_prefetch_req << std::endl
               << "CACHE.ON_HOLD_REQUESTS  : " << evt_req_on_hold << std::endl
               << "CACHE.RTAB_ROLLBACK     : " << evt_rtab_rollback << std::endl
               << "CACHE.STALL_REFILL      : " << evt_stall_refill << std::endl
               << "CACHE.STALL             : " << evt_stall << std::endl
               << std::endl

               << "Computed values" << std::endl
               << "---------------" << std::endl
               << "Cycles per request      : "
               << (nb_core_req > 0 ? (double)nb_cycles_effective / nb_core_req : 0) << std::endl
               << "Read miss rate          : "
               << (evt_read_req > 0 ? (double)evt_cache_read_miss / evt_read_req : 0) << std::endl
               << "Write miss rate         : "
               << (evt_write_req > 0 ? (double)evt_cache_write_miss / evt_write_req : 0)
               << std::endl;

            std::cout << ss.str() << std::endl;
        }
    }

    void set_sequence(std::shared_ptr<hpdcache_test_sequence> p) { seq = p; }

    void set_mem_resp_model(std::shared_ptr<hpdcache_test_mem_resp_model_base> p)
    {
        mem_resp_model = p;
    }

    void set_error_limit(size_t error_limit) { sb_error_limit_m = error_limit; }

private:
    uint64_t nb_cycles;
    uint64_t nb_cycles_effective;
    uint64_t nb_core_req;
    uint64_t nb_core_req_need_rsp;
    uint64_t nb_core_resp;
    uint64_t nb_mem_read_req;
    uint64_t nb_mem_read_resp;
    uint64_t nb_mem_write_req;
    uint64_t nb_mem_write_resp;

    size_t nb_error;
    size_t sb_error_limit_m;

    uint64_t evt_cache_write_miss;
    uint64_t evt_cache_read_miss;
    uint64_t evt_uncached_req;
    uint64_t evt_cmo_req;
    uint64_t evt_write_req;
    uint64_t evt_read_req;
    uint64_t evt_prefetch_req;
    uint64_t evt_req_on_hold;
    uint64_t evt_rtab_rollback;
    uint64_t evt_stall_refill;
    uint64_t evt_stall;

    std::shared_ptr<hpdcache_test_sequence> seq;
    std::shared_ptr<hpdcache_test_mem_resp_model_base> mem_resp_model;

    static constexpr unsigned int CORE_REQ_WORDS = HPDCACHE_REQ_WORDS;
    static constexpr unsigned int CORE_REQ_WORD_BYTES = HPDCACHE_WORD_WIDTH / 8;
    static constexpr unsigned int CORE_REQ_BYTES = CORE_REQ_WORDS * CORE_REQ_WORD_BYTES;

    struct inflight_entry_t
    {
        uint64_t time;
        uint32_t tid;
        uint64_t addr;
        bool need_rsp;
        bool hit;
        bool is_read;
        bool is_write;
        bool is_amo;
        bool is_amo_sc;
        bool is_amo_lr;
        bool is_atomic;
        bool is_error;
        unsigned op;
        bool is_uncacheable;
        uint8_t bytes;
        uint64_t wdata[CORE_REQ_WORDS];
        uint8_t be[CORE_REQ_WORDS];
        uint64_t rdata[CORE_REQ_WORDS];
        uint8_t rv[CORE_REQ_WORDS];

        const std::string to_string() const
        {
            std::stringstream ss;
            ss << "@0x" << std::hex << addr << std::dec << (hit ? " / hit" : " / miss")
               << (is_read     ? " / read"
                   : is_write  ? " / write"
                   : is_amo    ? " / amo"
                   : is_amo_sc ? " / sc"
                   : is_amo_lr ? " / lr"
                               : "")
               << " / " << hpdcache_test_transaction_req::op_to_string(op)
               << (is_uncacheable ? " / uncacheable" : "") << " / bytes = " << (unsigned)bytes;

            return ss.str();
        }

        friend std::ostream& operator<<(std::ostream& os, const inflight_entry_t& req)
        {
            os << req.to_string();
            return os;
        }
    };

    struct inflight_mem_entry_t
    {
        uint64_t addr;
        uint8_t bytes;
        bool is_uncacheable;
        bool is_error;
        bool is_stex;
        const inflight_entry_t* core_req_ptr;
    };

    struct lrsc_reservation_buf_t
    {
        bool valid;
        uint64_t base_addr;
        uint64_t end_addr;
        bool is_atomic;
    };

    static inline bool within_region(uint64_t addr, uint64_t base, uint64_t end)
    {
        if (addr < base) return false;
        if (addr > end) return false;
        return true;
    }

    static inline uint64_t get_nline(uint64_t addr) { return addr >> HPDCACHE_CL_OFFSET_WIDTH; }

    static inline uint64_t get_offset(uint64_t addr)
    {
        return addr & ((1ULL << HPDCACHE_CL_OFFSET_WIDTH) - 1);
    }

    typedef std::map<uint32_t, inflight_entry_t> inflight_map_t;
    typedef std::pair<uint32_t, inflight_entry_t> inflight_map_pair_t;
    typedef std::map<uint64_t, inflight_mem_entry_t> inflight_mem_map_t;
    typedef std::pair<uint32_t, inflight_mem_entry_t> inflight_mem_map_pair_t;
    typedef ram_model<SCOREBOARD_RAM_SIZE> ram_t;

#if ENABLE_CACHE_DIR_VERIF
    std::shared_ptr<GenericCacheDirectoryPlru> cache_dir_m;
#endif

    inflight_map_t inflight_m;
    inflight_mem_map_t inflight_mem_read_m;
    inflight_mem_map_t inflight_mem_write_m;
    lrsc_reservation_buf_t lrsc_buf_m;
    std::shared_ptr<ram_t> ram_m;

    sc_fifo<inflight_entry_t> inflight_amo_req_m;
    std::map<uint32_t, bool> sc_is_atomic_m;

#if SC_VERSION_MAJOR < 3
    SC_HAS_PROCESS(hpdcache_test_scoreboard);
#endif

    void perf_events_process()
    {
        nb_cycles++;
        if (evt_cache_write_miss_i.read()) evt_cache_write_miss++;
        if (evt_cache_read_miss_i.read()) evt_cache_read_miss++;
        if (evt_uncached_req_i.read()) evt_uncached_req++;
        if (evt_cmo_req_i.read()) evt_cmo_req++;
        if (evt_write_req_i.read()) evt_write_req++;
        if (evt_read_req_i.read()) evt_read_req++;
        if (evt_prefetch_req_i.read()) evt_prefetch_req++;
        if (evt_req_on_hold_i.read()) evt_req_on_hold++;
        if (evt_rtab_rollback_i.read()) evt_rtab_rollback++;
        if (evt_stall_refill_i.read()) evt_stall_refill++;
        if (evt_stall_i.read()) evt_stall++;
    }

    static uint64_t align_to(uint64_t val, uint64_t align) { return (val / align) * align; }

    bool check_verbosity(sc_core::sc_verbosity verbosity)
    {
        return (sc_core::sc_report_handler::get_verbosity_level() >= verbosity);
    }

    void print_error(const std::string& msg)
    {
        std::cout << sc_time_stamp().to_string() << " / SB_ERROR: " << msg << std::endl;

        nb_error++;
        if (sb_error_limit_m > 0 && (nb_error >= sb_error_limit_m)) {
            std::cout << "SB_ERROR: number of errors exceeded the limit (" << sb_error_limit_m
                      << ")" << std::endl;

            std::exit(1);
        }
    }

    void print_debug(const std::string& msg)
    {
        std::cout << sc_time_stamp().to_string() << " / SB_DEBUG: " << msg << std::endl;
    }

    void core_req_process()
    {
        hpdcache_test_transaction_req req;
        for (;;) {
            req = core_req_i.read();
            nb_core_req++;

            if (check_verbosity(sc_core::SC_MEDIUM)) {
                std::cout << sc_time_stamp().to_string() << " / " << req << std::endl;
            }

            //  count the number of requests that need a response
            if (req.req_need_rsp) nb_core_req_need_rsp++;

            uint32_t req_id = req.req_tid.to_uint();
            uint64_t req_addr = req.req_addr.to_uint64();

            inflight_map_t::const_iterator it = inflight_m.find(req_id);
            if (it != inflight_m.end()) {
                std::stringstream ss;
                ss << "core request ID "
                   << "0x" << std::hex << req_id << std::dec << " matches an inflight request";
                print_error(ss.str());
                continue;
            }

            if (req.is_cmo()) {
#if ENABLE_CACHE_DIR_VERIF
                switch (req.req_size.to_uint()) {
                    case hpdcache_test_transaction_req::HPDCACHE_CMO_INVAL_NLINE: {
                        cache_dir_m->inval(req_addr);
                        break;
                    }
                    case hpdcache_test_transaction_req::HPDCACHE_CMO_INVAL_SET_WAY: {
                        uint64_t wdata = req.req_wdata.range(HPDCACHE_NWAYS - 1, 0).to_uint64();
                        if (wdata == 0) break;
                        for (int way = 0; way < HPDCACHE_NWAYS; way++) {
                            if ((wdata & (1 << way)) != 0) {
                                cache_dir_m->inval(way, cache_dir_m->getAddrSet(req_addr));
                            }
                        }
                        break;
                    }
                    case hpdcache_test_transaction_req::HPDCACHE_CMO_INVAL_ALL: {
                        for (int way = 0; way < HPDCACHE_NWAYS; way++) {
                            for (int set = 0; set < HPDCACHE_NSETS; set++) {
                                cache_dir_m->inval(way, set);
                            }
                        }
                        break;
                    }
                }
#endif
                if (!req.req_need_rsp) {
                    //  release response ID on the sequence
                    seq->deallocate_id(req_id);
                    continue;
                }
            }

            bool hit = false;

#if ENABLE_CACHE_DIR_VERIF
            size_t hit_way;
            size_t hit_set;
            if ((req.is_load() || req.is_store() || req.is_amo_lr() || req.is_amo_sc()
                 || req.is_amo())
                && !req.is_uncacheable()) {
                hit = cache_dir_m->access(req_addr, &hit_way, &hit_set);
            }
#endif

            inflight_entry_t e;
            e.time = nb_cycles;
            e.tid = req_id;
            e.addr = req_addr;
            e.need_rsp = req.req_need_rsp;
            e.hit = hit;
            e.is_read = req.is_load();
            e.is_write = req.is_store();
            e.is_amo = req.is_amo();
            e.is_amo_lr = req.is_amo_lr();
            e.is_amo_sc = req.is_amo_sc();
            e.is_uncacheable = req.req_uncacheable;
            e.is_error = false;
            e.bytes = 1 << req.req_size.to_uint();
            e.op = req.req_op.to_uint();
            if (req.is_store() || req.is_amo_sc() || req.is_amo()) {
                for (int i = 0; i < CORE_REQ_WORDS; i++) {
                    e.wdata[i] =
                        req.req_wdata
                            .range((i + 1) * HPDCACHE_WORD_WIDTH - 1, i * HPDCACHE_WORD_WIDTH)
                            .to_uint64();
                    e.be[i] =
                        req.req_be.range((i + 1) * CORE_REQ_WORD_BYTES - 1, i * CORE_REQ_WORD_BYTES)
                            .to_uint();
                }
            }

            //  Look for the request address into the error memory segments
            if (mem_resp_model && (!req.is_cmo() || req.is_cmo_prefetch())) {
                e.is_error = mem_resp_model->within_error_region(e.addr, e.addr + e.bytes);
            }

            uint64_t aligned_addr = align_to(req_addr, HPDCACHE_REQ_DATA_WIDTH / 8);
            if (!e.is_error && (req.is_load() || req.is_amo_lr() || req.is_amo())) {
                ram_m->read(reinterpret_cast<uint8_t*>(e.rdata),
                            HPDCACHE_REQ_DATA_WIDTH / 8,
                            aligned_addr,
                            e.rv);

#if DEBUG_HPDCACHE_TEST_SCOREBOARD
                if (check_verbosity(sc_core::SC_DEBUG)) {
                    for (int i = 0; i < CORE_REQ_WORDS; i++) {
                        if (e.rv[i]) {
                            std::stringstream ss;
                            ss << "check response for @0x" << std::hex
                               << aligned_addr + i * CORE_REQ_WORD_BYTES << std::dec
                               << " / expected = 0x" << std::hex << e.rdata[i] << std::dec
                               << " / valid = 0x" << std::hex << (unsigned)e.rv[i] << std::dec;

                            print_debug(ss.str());
                        }
                    }
                }
#endif
            }

            //  Compute if the SC address matches the one of a previous LR reservation
            if (req.is_amo_lr()) {
                if (!e.is_error) {
                    if (check_verbosity(sc_core::SC_DEBUG)) {
                        print_debug("making LR reservation");
                    }
                    lrsc_buf_m.valid = true;
                    lrsc_buf_m.base_addr = e.addr;
                    lrsc_buf_m.end_addr = e.addr + 8;
                    lrsc_buf_m.is_atomic = false; // initialization
                } else {
                    if (check_verbosity(sc_core::SC_DEBUG)) {
                        print_debug("invalidating previous LR reservation");
                    }
                    lrsc_buf_m.valid = false;
                }
            }

            //  Manage invalidation of the LR/SC reservation buffer
            if (req.is_amo() || req.is_amo_sc() || req.is_store()) {
                uint64_t lrsc_rsrv_nline;
                uint64_t lrsc_rsrv_word;
                uint64_t lrsc_entry_nline;
                uint64_t lrsc_entry_words;
                uint64_t lrsc_entry_base;
                uint64_t lrsc_entry_end;
                bool addr_match;

                //  Compute if the address matches the one of a previous LR reservation
                lrsc_rsrv_nline = get_nline(lrsc_buf_m.base_addr);
                lrsc_rsrv_word = get_offset(lrsc_buf_m.base_addr) >> 3;
                lrsc_entry_nline = get_nline(e.addr);
                lrsc_entry_words = e.bytes < 8 ? 1 : e.bytes >> 3;
                lrsc_entry_base = get_offset(e.addr) >> 3;
                lrsc_entry_end = lrsc_entry_base + lrsc_entry_words;

                addr_match = lrsc_buf_m.valid && (lrsc_rsrv_nline == lrsc_entry_nline)
                             && (lrsc_rsrv_word >= lrsc_entry_base)
                             && (lrsc_rsrv_word < lrsc_entry_end);

                if (req.is_amo_sc()) {
                    //  SC can get an error response only if there is a valid
                    //  reservation, otherwise the response shall be SC_FAILURE (but
                    //  without error)
                    e.is_error = e.is_error && addr_match;

                    //  If there is a previous reservation (previous LR) on the address
                    //  accessed by a SC operation, then the access MAY be atomic. The
                    //  scoreboard needs to wait for the acknowledgement from the memory to
                    //  actually know the atomicity of the access.
                    e.is_atomic = addr_match;
                }

                // Invalidate the active reservation (independently of the address match in
                // case of SC because as specified in the RISC-V ISA, one condition to be
                // fulfilled by a SC to succeed is that there is no other SC is between the LR
                // and itself in program order).
                if (addr_match || req.is_amo_sc()) {
                    if (check_verbosity(sc_core::SC_DEBUG)) {
                        print_debug("invalidate LR reservation");
                    }
                    lrsc_buf_m.valid = false;
                }
            }

#if !CONF_HPDCACHE_COHERENCE_ENABLE
            if (req.is_amo() || req.is_amo_lr() || (req.is_amo_sc() && e.is_atomic)) {
                if (check_verbosity(sc_core::SC_DEBUG)) {
                    print_debug("atomic operation shall be forwarded to memory");
                }
                //  Share transaction information with the memory interface threads
                if (!inflight_amo_req_m.nb_write(e)) {
                    print_error("inflight AMO request fifo is full");
                    continue;
                }
            }
#endif

            //  keep track of written data
            if (req.is_store() && !e.is_error) {
                ram_m->write(reinterpret_cast<uint8_t*>(e.wdata),
                             reinterpret_cast<uint8_t*>(e.be),
                             HPDCACHE_REQ_DATA_WIDTH / 8,
                             aligned_addr);

#if DEBUG_HPDCACHE_TEST_SCOREBOARD
                if (check_verbosity(sc_core::SC_DEBUG)) {
                    for (int i = 0; i < CORE_REQ_WORDS; i++) {
                        if (e.be[i]) {
                            std::stringstream ss;
                            ss << "store sb.mem @0x" << std::hex
                               << aligned_addr + i * CORE_REQ_WORD_BYTES << std::dec << " = 0x"
                               << std::hex << e.wdata[i] << std::dec << " / be = 0x" << std::hex
                               << (unsigned)e.be[i] << std::dec;

                            print_debug(ss.str());
                        }
                    }
                }
#endif
            }

            if (req.req_need_rsp) {
                //  add new core request into the table of inflight requests
                inflight_m.insert(inflight_map_pair_t(req_id, e));
            } else {
                //  deallocate the ID immediately for requests with no response
                seq->deallocate_id(req_id);
            }
        }
    }

    void core_resp_process()
    {
        hpdcache_test_transaction_resp resp;
        for (;;) {
            resp = core_resp_i.read();
            nb_core_resp++;

            nb_cycles_effective = nb_cycles;

            if (check_verbosity(sc_core::SC_MEDIUM)) {
                std::cout << sc_time_stamp().to_string() << " / " << resp << std::endl;
            }

            //  check if there is a matching request for the received response
            inflight_map_t::const_iterator it = inflight_m.find(resp.rsp_tid.to_uint());
            if (it == inflight_m.end()) {
                std::stringstream ss;
                ss << "core response ID "
                   << "0x" << std::hex << resp.rsp_tid.to_uint() << std::dec
                   << " does not match any inflight request";
                print_error(ss.str());
                continue;
            }

            const inflight_entry_t& e = it->second;

#if DEBUG_HPDCACHE_TEST_SCOREBOARD
            if (check_verbosity(sc_core::SC_DEBUG)) {
                print_debug(e.to_string());
            }
#endif

            if (!e.is_write && (resp.rsp_error != e.is_error)) {
                print_error("unexpected value in the error flag of the response");
                continue;
            }

            if (!e.is_error) {
                const uint64_t aligned_addr = align_to(e.addr, CORE_REQ_BYTES);
                const int _word = (e.addr / CORE_REQ_WORD_BYTES) % CORE_REQ_WORDS;
                const int _byte = e.addr % CORE_REQ_BYTES;

                //  check the response status for SC operations
                bool sc_ok;
                if (e.is_amo_sc) {
                    uint64_t sc_resp = resp.rsp_rdata
                                           .range((_word + 1) * HPDCACHE_WORD_WIDTH - 1,
                                                  _word * HPDCACHE_WORD_WIDTH)
                                           .to_uint64();
                    if (e.bytes == 4) {
                        sc_resp = (uint32_t)sc_resp;
                    }

                    // Read the is_atomic value from the map for thread-safe communication
                    bool sc_is_atomic_val = true;
                    auto it_atomic = sc_is_atomic_m.find(e.tid);
                    if (it_atomic != sc_is_atomic_m.end()) {
                        sc_is_atomic_val = it_atomic->second;
                        sc_is_atomic_m.erase(it_atomic);
                    }
                    sc_ok = e.is_atomic && sc_is_atomic_val;
                    if (sc_ok) {
                        ram_m->write(reinterpret_cast<const uint8_t*>(&e.wdata[_word]),
                                     reinterpret_cast<const uint8_t*>(&e.be[_word]),
                                     CORE_REQ_WORD_BYTES,
                                     align_to(e.addr, CORE_REQ_WORD_BYTES));

                        //  check response status
                        if (sc_resp != 0) {
                            print_error("response shall be SC_SUCCESS");
                        }
                    } else if (sc_resp != 1) {
                        print_error("response shall be SC_FAILURE");
                    }
                }

                //  check the response data
                if (e.is_read || e.is_amo || e.is_amo_lr) {
                    uint64_t rdata[CORE_REQ_WORDS];
                    for (int i = 0; i < CORE_REQ_WORDS; i++) {
                        rdata[i] =
                            resp.rsp_rdata
                                .range((i + 1) * HPDCACHE_WORD_WIDTH - 1, i * HPDCACHE_WORD_WIDTH)
                                .to_uint64();
                    }

                    //  check the received data
                    //  {{{
                    for (int i = _byte; i < (_byte + e.bytes); i++) {
                        const uint8_t recv = reinterpret_cast<const uint8_t*>(rdata)[i];
                        const uint8_t expc = reinterpret_cast<const uint8_t*>(e.rdata)[i];
                        const uint8_t rv =
                            reinterpret_cast<const uint8_t*>(e.rv)[i / CORE_REQ_WORD_BYTES];

                        if ((rv >> (i % CORE_REQ_WORD_BYTES)) & 0x1) {
                            if (recv != expc) {
                                std::stringstream ss;
                                ss << "response data is wrong"
                                   << " / @0x" << std::hex << aligned_addr + i << std::dec
                                   << " / actual = 0x" << std::hex << (unsigned)recv << std::dec
                                   << " / expected = 0x" << std::hex << (unsigned)expc << std::dec;
                                print_error(ss.str());
                            }
                        }
                    }
                    //  }}}

                    //  update the memory with the computed AMO word
                    //  {{{
                    if (e.is_amo) {
                        unsigned offset = (e.addr % CORE_REQ_WORD_BYTES) * CORE_REQ_WORD_BYTES;
                        uint64_t amo_new = e.wdata[_word];
                        uint64_t amo_old = rdata[_word];

                        if (e.bytes == 4) {
                            amo_new = static_cast<uint32_t>(amo_new >> offset);
                            amo_old = static_cast<uint32_t>(amo_old >> offset);
                        }
                        uint64_t amo_res =
                            hpdcache_test_amo::compute_amo(e.op, amo_old, amo_new, e.bytes);
                        uint8_t amo_be = e.be[_word];

                        amo_res = (amo_res << offset);
                        ram_m->write(reinterpret_cast<uint8_t*>(&amo_res),
                                     reinterpret_cast<uint8_t*>(&amo_be),
                                     CORE_REQ_WORD_BYTES,
                                     align_to(e.addr, CORE_REQ_WORD_BYTES));

#if DEBUG_HPDCACHE_TEST_SCOREBOARD
                        if (check_verbosity(sc_core::SC_DEBUG)) {
                            if (amo_be) {
                                std::stringstream ss;
                                ss << hpdcache_test_transaction_req::op_to_string(e.op)
                                   << " sb.mem @0x" << std::hex
                                   << align_to(e.addr, CORE_REQ_WORD_BYTES) << std::dec << " = 0x"
                                   << std::hex << amo_res << std::dec << " / be = 0x" << std::hex
                                   << (unsigned)amo_be << std::dec;

                                print_debug(ss.str());
                            }
                        }
#endif
                    }
                    //  }}}
                }
            }

            //  remove request from the inflight table
            inflight_m.erase(it);

            //  release response ID on the sequence
            seq->deallocate_id(resp.rsp_tid.to_uint());
        }
    }

    void mem_read_req_process()
    {
        hpdcache_test_transaction_mem_read_req req;
        for (;;) {
            req = mem_read_req_i.read();
            nb_mem_read_req++;

            if (check_verbosity(sc_core::SC_MEDIUM)) {
                std::cout << sc_time_stamp().to_string() << " / " << req << std::endl;
            }

            uint32_t req_id = req.id;

            inflight_mem_map_t::const_iterator it = inflight_mem_read_m.find(req_id);
            if (it != inflight_mem_read_m.end()) {
                std::stringstream ss;
                ss << "memory read request ID "
                   << "0x" << std::hex << req_id << std::dec << " matches an inflight request";
                print_error(ss.str());
                continue;
            }

            //  find the associated core request
            const inflight_entry_t* core_req = nullptr;
            for (const auto& cr : inflight_m) {
                const inflight_entry_t& _cr = cr.second;
                if (get_nline(_cr.addr) == get_nline(req.addr)) {
                    //  get first occurrence
                    if (core_req == nullptr) {
                        core_req = &_cr;
                        continue;
                    }

                    //  if multiple occurrences, get the oldest
                    if (_cr.time < core_req->time) {
                        core_req = &_cr;
                    }
                }
            }

            const uint64_t bytes = (1ULL << req.size);

            //  add new memory read request into the table of inflight memory requests
            inflight_mem_entry_t e;
            e.addr = req.addr;
            e.bytes = bytes;
            e.is_uncacheable = !req.cacheable;
            e.is_error = mem_resp_model->within_error_region(e.addr, e.addr + bytes);
            e.core_req_ptr = core_req;
            e.is_stex = false;

            inflight_mem_read_m.insert(inflight_mem_map_pair_t(req_id, e));

#if !CONF_HPDCACHE_COHERENCE_ENABLE
            if (req.is_ldex()) {
                inflight_entry_t inflight_ret;
                if (inflight_amo_req_m.num_available() > 1) {
                    print_error("there shall be a single inflight atomic operation");
                }
                if (!inflight_amo_req_m.nb_read(inflight_ret)) {
                    print_error("unexpected load-exclusive request");
                    continue;
                }
            }
#endif
        }
    }

    void mem_read_resp_process()
    {
        hpdcache_test_transaction_mem_read_resp resp;
        for (;;) {
            resp = mem_read_resp_i.read();
            nb_mem_read_resp++;

            if (check_verbosity(sc_core::SC_MEDIUM)) {
                std::cout << sc_time_stamp().to_string() << " / " << resp << std::endl;
            }

            inflight_mem_map_t::const_iterator it = inflight_mem_read_m.find(resp.id);
            if (it == inflight_mem_read_m.end()) {
                std::stringstream ss;
                ss << "memory read response ID "
                   << "0x" << std::hex << resp.id << std::dec
                   << " does not match any inflight request";
                print_error(ss.str());
                continue;
            }

            //  get a pointer to the originating core request
            const inflight_mem_entry_t* mem_req = &it->second;
            const inflight_entry_t* core_req = mem_req->core_req_ptr;

#if ENABLE_CACHE_DIR_VERIF
            if (!mem_req->is_uncacheable) {
                bool hit = cache_dir_m->hit(mem_req->addr, nullptr, nullptr);
                if (hit) {
                    print_error("memory read miss response while there is a corresponding line in "
                                "the cache");
                }

                //  replace a line in the cache in case of a read miss response
                uint64_t victim_tag;
                size_t victim_way;
                size_t victim_set;
                bool victim_valid = false;
                victim_valid =
                    cache_dir_m->repl(mem_req->addr, &victim_tag, &victim_way, &victim_set);

#if DEBUG_HPDCACHE_TEST_SCOREBOARD
                if (check_verbosity(sc_core::SC_DEBUG)) {
                    std::stringstream ss;

                    unsigned int lru_vector = 0;
                    for (int way = 0; way < cache_dir_m->getWays(); way++) {
                        if (cache_dir_m->getCachePlru(way,
                                                      cache_dir_m->getAddrSet(mem_req->addr))) {
                            lru_vector |= 1 << way;
                        }
                    }

                    if (victim_valid) {
                        ss << "TEST_SB.cache_dir / replacing @0x" << std::hex
                           << cache_dir_m->getAddr(victim_tag, victim_set) << std::dec
                           << " (set = 0x" << std::hex << victim_set << std::dec << ", tag = 0x"
                           << std::hex << victim_tag << std::dec << ") / @0x" << std::hex
                           << mem_req->addr << std::dec << " (tag = 0x" << std::hex
                           << cache_dir_m->getAddrTag(mem_req->addr) << std::dec << ", way = 0x"
                           << std::hex << victim_way << std::dec << ", lru = 0x" << std::hex
                           << lru_vector << std::dec << ")";
                    } else {
                        ss << "TEST_SB.cache_dir / allocating @0x" << std::hex << std::hex
                           << mem_req->addr << std::dec << " (set = 0x" << std::hex
                           << cache_dir_m->getAddrSet(mem_req->addr) << std::dec << ", tag = 0x"
                           << std::hex << cache_dir_m->getAddrTag(mem_req->addr) << std::dec
                           << ", way = 0x" << std::hex << victim_way << std::dec << ", lru = 0x"
                           << std::hex << lru_vector << std::dec << ")";
                    }
                    print_debug(ss.str());
                }
#endif
            }
#endif
            if (!resp.error) {
                const int MEM_WORDS = HPDCACHE_MEM_DATA_WIDTH / 64;
                const int MEM_BYTES = HPDCACHE_MEM_DATA_WIDTH / 8;
                const uint64_t aligned_addr = align_to(mem_req->addr, MEM_BYTES);
                const int _word = (mem_req->addr / MEM_BYTES) % MEM_WORDS;
                const int _byte = mem_req->addr % MEM_BYTES;

                //  update uninitialized bytes of the scoreboard memory with the
                //  response from the external memory
                //  {{{
                uint64_t rdata[MEM_WORDS];
                for (int i = 0; i < MEM_WORDS; i++) {
                    rdata[i] = resp.data.range((i + 1) * 64 - 1, i * 64).to_uint64();
                }

                uint8_t unset[MEM_WORDS];
                memset(unset, 0, sizeof(unset));
                for (int i = 0; i < MEM_BYTES; i++) {
                    unset[i / 8] |= (ram_m->getBmap(aligned_addr + i) ? 0x0 : 0x1) << (i % 8);
                }

                uint8_t be[MEM_WORDS];
                int bytes = mem_req->bytes;
                memset(be, 0, sizeof(be));
                for (int i = _word; bytes > 0; i++) {
                    uint8_t mask = static_cast<uint8_t>(((1UL << bytes) - 1) << (_byte - i * 8));
                    be[i] = mask & unset[i];
                    bytes -= 8;
                }

                ram_m->write(reinterpret_cast<uint8_t*>(rdata),
                             reinterpret_cast<uint8_t*>(be),
                             MEM_BYTES,
                             aligned_addr);

#if DEBUG_HPDCACHE_TEST_SCOREBOARD
                if (check_verbosity(sc_core::SC_DEBUG)) {
                    for (int i = 0; i < MEM_WORDS; i++) {
                        if (be[i]) {
                            std::stringstream ss;
                            ss << "update sb.mem @0x" << std::hex << aligned_addr + i * 8
                               << std::dec << " = 0x" << std::hex << rdata[i] << std::dec
                               << " / be = 0x" << std::hex << (unsigned)be[i] << std::dec;
                            print_debug(ss.str());
                        }
                    }
                }
#endif
                //  }}}
            }

            //  remove request from the inflight table
            if (resp.last) {
                inflight_mem_read_m.erase(it);
            }
        }
    }

    void mem_write_req_process()
    {
        hpdcache_test_transaction_mem_write_req req;
        for (;;) {
            req = mem_write_req_i.read();
            nb_mem_write_req++;

            if (check_verbosity(sc_core::SC_MEDIUM)) {
                std::cout << sc_time_stamp().to_string() << " / " << req << std::endl;
            }

            uint32_t req_id = req.id;
            uint64_t bytes = (1ULL << req.size);

            inflight_mem_map_t::const_iterator it = inflight_mem_write_m.find(req_id);
            if (it != inflight_mem_write_m.end()) {
                std::stringstream ss;
                ss << "memory write request ID "
                   << "0x" << std::hex << req_id << std::dec << " matches an inflight request";
                print_error(ss.str());
                continue;
            }

            //  find the associated core request
            const inflight_entry_t* core_req = nullptr;
            for (const auto& cr : inflight_m) {
                const inflight_entry_t& _cr = cr.second;
                if (get_nline(_cr.addr) == get_nline(req.addr)) {
                    //  get first occurrence
                    if (core_req == nullptr) {
                        core_req = &_cr;
                        continue;
                    }

                    //  if multiple occurrences, get the oldest
                    if (_cr.time < core_req->time) {
                        core_req = &_cr;
                    }
                }
            }

            //  add new memory write request into the table of inflight memory requests
            inflight_mem_entry_t e;
            e.addr = req.addr;
            e.bytes = bytes;
            e.is_uncacheable = !req.cacheable;
            e.is_error = mem_resp_model->within_error_region(e.addr, e.addr + bytes);
            e.core_req_ptr = core_req;
            e.is_stex = req.is_stex();

            inflight_mem_write_m.insert(inflight_mem_map_pair_t(req_id, e));

            if (req.is_amo()) {
#if !CONF_HPDCACHE_COHERENCE_ENABLE
                inflight_entry_t inflight_ret;
                if (inflight_amo_req_m.num_available() > 1) {
                    print_error("there shall be a single inflight atomic operation");
                }
                if (!inflight_amo_req_m.nb_read(inflight_ret)) {
                    print_error("unexpected AMO request");
                    continue;
                }
#endif
                if (core_req == nullptr) {
                    print_error("memory AMO request with no associated core request");
                }
                inflight_mem_read_m.insert(inflight_mem_map_pair_t(req_id, e));
            }

            if (req.is_stex()) {
#if !CONF_HPDCACHE_COHERENCE_ENABLE
                inflight_entry_t inflight_ret;
                if (inflight_amo_req_m.num_available() > 1) {
                    print_error("there shall be a single inflight atomic operation");
                }
                if (!inflight_amo_req_m.nb_read(inflight_ret)) {
                    print_error("unexpected store-exclusive request");
                    continue;
                }
                if (!inflight_ret.is_atomic) {
                    print_error("store exclusive access with no valid reservation");
                    continue;
                }
#endif
                if (core_req == nullptr) {
                    print_error("memory store-conditional request with no associated core request");
                }
            }
        }
    }

    void mem_write_resp_process()
    {
        hpdcache_test_transaction_mem_write_resp resp;
        for (;;) {
            resp = mem_write_resp_i.read();
            nb_mem_write_resp++;

            if (check_verbosity(sc_core::SC_MEDIUM)) {
                std::cout << sc_time_stamp().to_string() << " / " << resp << std::endl;
            }

            inflight_mem_map_t::const_iterator it = inflight_mem_write_m.find(resp.id);
            if (it == inflight_mem_write_m.end()) {
                std::stringstream ss;
                ss << "memory write response ID "
                   << "0x" << std::hex << resp.id << std::dec
                   << " does not match any inflight request";
                print_error(ss.str());
                continue;
            }

            // Only push the (tid, is_atomic) pair to the map if this is a store-exclusive (stex)
            if (it->second.core_req_ptr && it->second.is_stex) {
                uint32_t tid = it->second.core_req_ptr->tid;
                sc_is_atomic_m[tid] = resp.is_atomic;
            }

            //  remove request from the inflight table
            inflight_mem_write_m.erase(it);
        }
    }
};

#endif /* __HPDCACHE_TEST_SCOREBOARD_H__ */
