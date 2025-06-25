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
 *  Description: Class definition of the HPDCACHE test random sequence
 */
#ifndef __HPDCACHE_TEST_FROM_FILE_SEQ_H__
#define __HPDCACHE_TEST_FROM_FILE_SEQ_H__

#include <systemc>
#include <thread>
#include <cstdint>

#include "scv.h"
#include "hpdcache_test_defs.h"
#include "hpdcache_test_sequence.h"
#include "hpd_cache_file_gestion.h"

#define HPDCACHE_TEST_SEQUENCE_ENABLE_ERROR_SEGMENTS 1

/**
 * @class hpdcache_test_from_file_seq
 * @brief This class allow to run test by reading transaction directly from a binary file  
 *
 */
class hpdcache_test_from_file_seq : public hpdcache_test_sequence
{
private:
    typedef sc_bv<HPDCACHE_REQ_DATA_WIDTH> req_data_t;
    
    File_reader *my_file;
    hpdcache_test_sequence::hpdcache_test_memory_segment seg;
    scv_smart_ptr<sc_bv<HPDCACHE_REQ_DATA_WIDTH> > data;
    scv_smart_ptr<req_data_t> size;
    const unsigned int HPDCACHE_REQ_DATA_BYTES = HPDCACHE_REQ_DATA_WIDTH/8;


#if SC_VERSION_MAJOR < 3
    SC_HAS_PROCESS(hpdcache_test_read_seq);
#endif

public:

    hpdcache_test_from_file_seq(sc_core::sc_module_name nm, std::string file_name) : hpdcache_test_sequence(nm, "from_file_seq")
    {
        my_file =  new File_reader(file_name);
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

    inline sc_bv<HPDCACHE_REQ_DATA_WIDTH> create_random_data()
    {
        data->next();
        return data->read();
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
        scv_smart_ptr<int> lrsc_inbetween_instrs;
        lrsc_inbetween_instrs->keep_only(0, 10);
        lrsc_inbetween_instrs->next();
        int delay_transaction;
        delay->next();
        while (!my_file->is_finish()) 
        {
            std::shared_ptr<hpdcache_test_transaction_req> t;
            while (!is_available_id()){
                wait();
            }
            t = acquire_transaction<hpdcache_test_transaction_req>();
            t->req_tid = allocate_id();
            delay_transaction = my_file->read_transaction(t);
            if (t != nullptr){
                send_transaction(t, delay_transaction);
            } else{
                std::cerr<<"Null pointer but file is not finish ERROR\n";
            }
        }
        std::cout<<"J'ai fini le fichier\n";
        //  ask the driver to stop
        transaction_fifo_o->write(nullptr);
        my_file->my_close(); // remplacer par my_close
    }
};
#endif  // __HPDCACHE_TEST_FROM_FILE_SEQ_H__ 

