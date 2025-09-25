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
 *  Date       : May, 2025
 *  Description: Class definition of the HPDCACHE test unique set sequence
 */
#ifndef __HPDCACHE_TEST_UNIQUE_SET_SEQ_H__
#define __HPDCACHE_TEST_UNIQUE_SET_SEQ_H__

#include "hpdcache_test_defs.h"
#include "hpdcache_test_sequence.h"
#include "scv.h"
#include <systemc>

class hpdcache_test_unique_set_seq : public hpdcache_test_sequence
{
public:
    hpdcache_test_unique_set_seq(sc_core::sc_module_name nm)
      : hpdcache_test_sequence(nm, "random_seq")
    {
        SC_THREAD(run);
        sensitive << clk_i.pos();

        seg[0].set_base(0x00000000ULL);
        seg[0].set_length(0x00004000ULL);
        seg[0].set_uncached(false);
        seg[0].set_amo_supported(true);
        seg[0].set_wr_policy_hint(hpdcache_test_memory_segment::WR_POLICY_RANDOM);

        seg[1].set_base(0x40004000ULL);
        seg[1].set_length(0x00004000ULL);
        seg[1].set_uncached(false);
        seg[1].set_amo_supported(true);
        seg[1].set_wr_policy_hint(hpdcache_test_memory_segment::WR_POLICY_WB);

        seg[2].set_base(0x80008000ULL);
        seg[2].set_length(0x00004000ULL);
        seg[2].set_uncached(false);
        seg[3].set_amo_supported(true);
        seg[3].set_wr_policy_hint(hpdcache_test_memory_segment::WR_POLICY_WT);

        seg[3].set_base(0xC000C000ULL);
        seg[3].set_length(0x00004000ULL);
        seg[3].set_uncached(false);
        seg[3].set_amo_supported(true);
        seg[3].set_wr_policy_hint(hpdcache_test_memory_segment::WR_POLICY_AUTO);

        hpdcache_test_sequence::seg_distribution.push(0, 100 / 4);
        hpdcache_test_sequence::seg_distribution.push(1, 100 / 4);
        hpdcache_test_sequence::seg_distribution.push(2, 100 / 4);
        hpdcache_test_sequence::seg_distribution.push(3, 100 / 4);
        hpdcache_test_sequence::segptr->set_mode(seg_distribution);

        hpdcache_test_sequence::delay_distribution.push(pair<int, int>(0, 0), 80);
        hpdcache_test_sequence::delay_distribution.push(pair<int, int>(1, 4), 18);
        hpdcache_test_sequence::delay_distribution.push(pair<int, int>(5, 20), 2);
        hpdcache_test_sequence::delay->set_mode(delay_distribution);

        hpdcache_test_sequence::amo_sc_do_distribution.push(false, 25);
        hpdcache_test_sequence::amo_sc_do_distribution.push(true, 75);
        hpdcache_test_sequence::amo_sc_do->set_mode(amo_sc_do_distribution);

        hpdcache_test_sequence::wr_policy_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_WR_POLICY_AUTO, 80);
        hpdcache_test_sequence::wr_policy_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_WR_POLICY_WB, 10);
        hpdcache_test_sequence::wr_policy_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_WR_POLICY_WT, 10);
        hpdcache_test_sequence::wr_policy->set_mode(wr_policy_distribution);

        hpdcache_test_sequence::op_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_LOAD, 400);
        hpdcache_test_sequence::op_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_STORE, 350);
        hpdcache_test_sequence::op_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_FENCE, 10);
        hpdcache_test_sequence::op_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_PREFETCH, 10);
        //        hpdcache_test_sequence::op_distribution.push(hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_INVAL_NLINE,
        //        15);
        //        hpdcache_test_sequence::op_distribution.push(hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_INVAL_ALL,
        //        15);
        hpdcache_test_sequence::op_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_FLUSH_NLINE, 10);
        hpdcache_test_sequence::op_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_FLUSH_ALL, 1);
        hpdcache_test_sequence::op_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE, 10);
        hpdcache_test_sequence::op_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL, 1);
        hpdcache_test_sequence::op->set_mode(op_distribution);

        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_LOAD, 400);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_STORE, 350);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_FENCE, 10);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_PREFETCH, 10);
        //        hpdcache_test_sequence::op_distribution.push(hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_INVAL_NLINE,
        //        15);
        //        hpdcache_test_sequence::op_distribution.push(hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_INVAL_ALL,
        //        15);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_FLUSH_NLINE, 10);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_FLUSH_ALL, 1);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_FLUSH_INVAL_NLINE, 10);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL, 1);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_AMO_LR, 4);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_AMO_SC, 4);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_AMO_SWAP, 4);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_AMO_ADD, 4);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_AMO_AND, 4);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_AMO_OR, 4);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_AMO_XOR, 4);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_AMO_MAX, 4);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_AMO_MAXU, 4);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_AMO_MIN, 4);
        hpdcache_test_sequence::op_amo_distribution.push(
            hpdcache_test_transaction_req::HPDCACHE_REQ_AMO_MINU, 4);
        hpdcache_test_sequence::op_amo->set_mode(op_amo_distribution);

        scv_bag<bool> need_rsp_distribution;
        need_rsp_distribution.push(false, 5);
        need_rsp_distribution.push(true, 95);
        need_rsp_rnd->set_mode(need_rsp_distribution);

        size->keep_only(0, LOG2_REQ_DATA_BYTES);
    }

private:
    hpdcache_test_sequence::hpdcache_test_memory_segment seg[4];
    scv_smart_ptr<uint64_t> addr;
    scv_smart_ptr<sc_bv<HPDCACHE_REQ_DATA_WIDTH>> data;
    scv_smart_ptr<sc_bv<HPDCACHE_REQ_DATA_WIDTH>> size;
    uint64_t set;
    scv_smart_ptr<bool> need_rsp_rnd;
    static constexpr unsigned int REQ_DATA_BYTES = HPDCACHE_REQ_DATA_WIDTH / 8;
    static constexpr unsigned int LOG2_REQ_DATA_BYTES = HPDCACHE_TEST_DEFS_LOG2(REQ_DATA_BYTES);

#if SC_VERSION_MAJOR < 3
    SC_HAS_PROCESS(hpdcache_test_unique_set_seq);
#endif

    inline sc_bv<HPDCACHE_REQ_DATA_WIDTH> create_random_data()
    {
        data->next();
        return data->read();
    }

    inline uint32_t create_random_size(bool is_amo)
    {
        uint32_t ret;
        size->next();
        ret = size->read().to_uint();
        if (is_amo) {
            return (ret >= 3) ? 3 : 2;
        }
        return ret;
    }

    inline uint64_t create_random_addr(uint64_t seg_base, uint64_t seg_length, uint32_t bytes)
    {
        static const uint64_t _set_mask = ((1 << HPDCACHE_SET_WIDTH) - 1);
        static const uint64_t set_mask = _set_mask << HPDCACHE_CL_OFFSET_WIDTH;
        uint64_t address;
        addr->next();
        address = ((seg_base + (addr->read() % seg_length)) / bytes) * bytes;
        return (address & ~set_mask) | (set << HPDCACHE_CL_OFFSET_WIDTH);
    }

    inline hpdcache_test_transaction_req::hpdcache_wr_policy_hint_e select_random_wr_policy(
        hpdcache_test_memory_segment::wr_policy_e seg_wr_policy)
    {
        if (seg_wr_policy == hpdcache_test_memory_segment::WR_POLICY_RANDOM) {
            wr_policy->next();
            return static_cast<hpdcache_test_transaction_req::hpdcache_wr_policy_hint_e>(
                wr_policy->read());
        } else if (seg_wr_policy == hpdcache_test_memory_segment::WR_POLICY_WB) {
            return hpdcache_test_transaction_req::HPDCACHE_WR_POLICY_WB;
        } else if (seg_wr_policy == hpdcache_test_memory_segment::WR_POLICY_WT) {
            return hpdcache_test_transaction_req::HPDCACHE_WR_POLICY_WT;
        }
        return hpdcache_test_transaction_req::HPDCACHE_WR_POLICY_AUTO;
    }

    std::shared_ptr<hpdcache_test_transaction_req> create_random_transaction()
    {
        std::shared_ptr<hpdcache_test_transaction_req> t;

        bool seg_amo_supported;
        hpdcache_test_memory_segment::wr_policy_e seg_wr_policy;
        int segn;

        while (!is_available_id()) wait();

        segptr->next();
        segn = segptr->read();
        seg_wr_policy = seg[segn].get_wr_policy_hint();
        seg_amo_supported = seg[segn].is_amo_supported();

        t = acquire_transaction<hpdcache_test_transaction_req>();

        //  Select operation
        if (seg_amo_supported) {
            hpdcache_test_sequence::op_amo->next();
            t->req_op = op_amo->read();
        } else {
            hpdcache_test_sequence::op->next();
            t->req_op = op->read();
        }

        t->req_wdata = create_random_data();
        t->req_sid = 0;
        t->req_tid = allocate_id();
        t->req_abort = false;
        t->req_phys_indexed = false;
        t->req_wr_policy_hint = select_random_wr_policy(seg_wr_policy);

        //  Select address and size
        bool req_is_amo = t->is_amo() || t->is_amo_sc() || t->is_amo_lr();
        uint32_t sz = create_random_size(req_is_amo);
        uint32_t bytes = 1 << sz;
        uint64_t address = create_random_addr(seg[segn].get_base(), seg[segn].get_length(), bytes);
        t->req_addr = address;
        need_rsp_rnd->next();
        t->req_need_rsp = req_is_amo || need_rsp_rnd->read();
        if (t->is_cmo()) {
            t->req_be = 0;
            t->req_size = 0;
            t->req_uncacheable = false;
        } else {
            uint32_t offset = address % REQ_DATA_BYTES;
            t->req_be = ((1UL << bytes) - 1) << offset;
            t->req_size = sz;
            t->req_uncacheable = seg[segptr->read()].is_uncached() ? 1 : 0;
        }
        return t;
    }

    std::shared_ptr<hpdcache_test_transaction_req> create_sc_transaction(uint64_t addr,
                                                                         bool uncacheable)
    {
        std::shared_ptr<hpdcache_test_transaction_req> t;

        while (!is_available_id()) wait();

        segptr->next();

        uint32_t sz = create_random_size(true);
        uint32_t bytes = 1 << sz;
        uint64_t address = (addr / bytes) * bytes;
        uint32_t offset = address % REQ_DATA_BYTES;

        t = acquire_transaction<hpdcache_test_transaction_req>();
        t->req_op = hpdcache_test_transaction_req::HPDCACHE_REQ_AMO_SC;
        t->req_wdata = create_random_data();
        t->req_sid = 0;
        t->req_tid = allocate_id();
        t->req_addr = address;
        t->req_be = ((1UL << bytes) - 1) << offset;
        t->req_size = sz;
        t->req_uncacheable = uncacheable;
        t->req_need_rsp = true;

        return t;
    }

    void run()
    {
        while (rst_ni == 0) wait();

        wait();

        scv_smart_ptr<int> lrsc_inbetween_instrs;
        lrsc_inbetween_instrs->keep_only(0, 10);
        lrsc_inbetween_instrs->next();

        delay->next();

        //  randomize the unique set for each execution
        set = rand() % HPDCACHE_SETS;

        for (size_t n = 0; n < this->max_transactions; n++) {
            std::shared_ptr<hpdcache_test_transaction_req> t;
            t = create_random_transaction();

            if (t->is_amo_lr()) {
                hpdcache_test_transaction_req prev_lr = *t;
                send_transaction(t, delay->read());
                delay->next();

                amo_sc_do->next();
                if (amo_sc_do->read()) {
                    for (int i = 0; i < lrsc_inbetween_instrs.read(); i++) {
                        t = create_random_transaction();
                        send_transaction(t, delay->read());
                        delay->next();
                    }

                    t = create_sc_transaction(prev_lr.req_addr.to_uint64(),
                                              prev_lr.req_uncacheable);
                    send_transaction(t, delay->read());
                    delay->next();
                }

                continue;
            }
            send_transaction(t, delay->read());
            delay->next();
        }

        //  ask the driver to stop
        transaction_fifo_o->write(nullptr);
    }
};

#endif // __HPDCACHE_TEST_RANDOM_SEQ_H__
