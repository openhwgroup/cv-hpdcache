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
#ifndef __HPDCACHE_TEST_FROM_TRACE_SEQ_H__
#define __HPDCACHE_TEST_FROM_TRACE_SEQ_H__

#include <systemc>
#include <thread>
#include <cstdint>

#include "scv.h"
#include "hpdcache_test_defs.h"
#include "hpdcache_test_sequence.h"
#include "hpdcache_test_trace_manager.h"

/**
 * @class hpdcache_test_from_trace_seq
 * @brief This class allow to run test by reading transaction directly from a binary trace
 *
 */
class hpdcache_test_from_trace_seq : public hpdcache_test_sequence
{
private:
    typedef sc_bv<HPDCACHE_REQ_DATA_WIDTH> req_data_t;

    trace_reader *my_trace;

#if SC_VERSION_MAJOR < 3
    SC_HAS_PROCESS(hpdcache_test_from_trace_seq);
#endif

public:

    hpdcache_test_from_trace_seq(sc_core::sc_module_name nm, std::string trace_name)
        : hpdcache_test_sequence(nm, "from_trace_seq")
    {
        my_trace = new trace_reader(trace_name);
        SC_THREAD(run);
        sensitive << clk_i.pos();
    }

    void run()
    {
        for (size_t n = 0; !my_trace->is_finish() && (n < this->max_transactions); n++)
        {
            std::shared_ptr<hpdcache_test_transaction_req> t;
            while (!is_available_id()){
                wait();
            }
            t = acquire_transaction<hpdcache_test_transaction_req>();
            t->req_tid = allocate_id();
            int delay = my_trace->read_transaction(t);
            send_transaction(t, delay);
        }
        //  ask the driver to stop
        transaction_fifo_o->write(nullptr);
        my_trace->my_close();
    }
};
#endif  // __HPDCACHE_TEST_FROM_TRACE_SEQ_H__
