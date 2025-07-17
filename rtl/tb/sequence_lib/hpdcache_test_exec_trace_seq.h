/**
 *  Copyright 2025 Inria, Universite Grenoble-Alpes, TIMA
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 *  Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 *  may not use this trace except in compliance with the License, or, at your
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
 *  Author     : Tommy PRATS
 *  Date       : June, 2025
 *  Description: Class definition of the HPDCACHE test from trace
 */
#ifndef __HPDCACHE_TEST_FROM_FILE_SEQ_H__
#define __HPDCACHE_TEST_FROM_FILE_SEQ_H__

#include <systemc>
#include <thread>
#include <cstdint>

#include "scv.h"
#include "hpdcache_test_defs.h"
#include "hpdcache_test_sequence.h"
#include "hpdcache_test_trace_manager.h"

#define HPDCACHE_TEST_SEQUENCE_ENABLE_ERROR_SEGMENTS 1

/**
 * @class hpdcache_test_from_trace_seq
 * @brief This class allow to run test by reading transaction directly from a binary trace
 *
 */
class hpdcache_test_exec_trace_seq : public hpdcache_test_sequence
{
private:
    typedef sc_bv<HPDCACHE_REQ_DATA_WIDTH> req_data_t;

    Trace_reader *my_trace;
    hpdcache_test_sequence::hpdcache_test_memory_segment seg;


#if SC_VERSION_MAJOR < 3
    SC_HAS_PROCESS(hpdcache_test_read_seq);
#endif

public:

    hpdcache_test_exec_trace_seq(sc_core::sc_module_name nm, std::string trace_name) : hpdcache_test_sequence(nm, "from_trace_seq")
    {
        my_trace =  new Trace_reader(trace_name);
        SC_THREAD(run);
        sensitive << clk_i.pos();

        seg.set_base(0x00000000ULL);
        seg.set_length(0x00080000ULL);
        seg.set_uncached(false);
        seg.set_amo_supported  (true);

        hpdcache_test_sequence::segptr->keep_only(0);
        hpdcache_test_sequence::delay->keep_only(0);
        hpdcache_test_sequence::op->keep_only(hpdcache_test_transaction_req::HPDCACHE_REQ_LOAD);
    }

    void run()
    {
#if HPDCACHE_TEST_SEQUENCE_ENABLE_ERROR_SEGMENTS
        if (hpdcache_test_sequence::mem_resp_model) {
            hpdcache_test_sequence::mem_resp_model->add_error_segment(
                hpdcache_test_mem_resp_model_base::segment_t(
                    0x00000000ULL, 0x00000200ULL, true
                )
            );
            hpdcache_test_sequence::mem_resp_model->add_error_segment(
                hpdcache_test_mem_resp_model_base::segment_t(
                    0x40004000ULL, 0x40004200ULL, true
                )
            );
            hpdcache_test_sequence::mem_resp_model->add_error_segment(
                hpdcache_test_mem_resp_model_base::segment_t(
                    0xC000C000ULL, 0xC000C200ULL, true
                )
            );
        }
#endif
        int delay_transaction;
        size_t n = 0;
        while (!my_trace->is_finish() && n < this->max_transactions )
        {
            std::shared_ptr<hpdcache_test_transaction_req> t;
            while (!is_available_id()){
                wait();
            }
            t = acquire_transaction<hpdcache_test_transaction_req>();
            t->req_tid = allocate_id();
            delay_transaction = my_trace->read_transaction(t);
            send_transaction(t, delay_transaction);
            n++;
        }
        //  ask the driver to stop
        transaction_fifo_o->write(nullptr);
        my_trace->my_close();
    }
};
#endif  // __HPDCACHE_TEST_FROM_FILE_SEQ_H__
