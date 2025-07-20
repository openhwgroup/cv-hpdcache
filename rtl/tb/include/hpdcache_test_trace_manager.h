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
 *  Description: Class definition of the reader/writer of trace
 */

#ifndef __HPDCACHE_TEST_TRACE_MANAGER__
#define __HPDCACHE_TEST_TRACE_MANAGER__

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
extern "C"
{
#include "miniz.h"
}
#include "hpdcache_test_transaction.h"

#define MAX_SIZE_BUFFER 5000000

class trace_reader
{
private:
    bool bool_finish = false;
    mz_stream* stream = nullptr;

public:
    int trace_descriptor;
    char buf[MAX_SIZE_BUFFER * 20]; // x20 -> maximum size after decompression
    int end_buffer;
    int read_buffer;

    trace_reader(std::string trace_name)
    {
        set_trace(trace_name);
        init_buf();
    }

    /**
     * @brief Open a trace and check if it can be read. If not, this function does an exit()
     *
     * @param trace_name The name of the trace
     */
    void set_trace(std::string trace_name)
    {
        trace_descriptor = open(trace_name.c_str(), O_RDONLY);
        if (trace_descriptor <= 0) {
            Logger::warning("The trace " + trace_name + " can't be open");
            exit(EXIT_FAILURE);
        }
        init_buf();
    }

    void init_buf()
    {
        end_buffer = MAX_SIZE_BUFFER;
        read_buffer = MAX_SIZE_BUFFER;
    }

    /**
     * @brief Debug function to display a number store in one byte within his binary
     * representation
     *
     * @param value A number store in 1 byte
     */
    static void display_binary(unsigned value)
    {
        unsigned tmp = value;
        std::cout << "\nI read " << tmp << " in binary :";
        for (int i = 8; i > 0; i--) {
            tmp = value;
            tmp = tmp << (8 - i);
            tmp = tmp >> 7;
            if ((tmp & 1) != 0) {
                std::cout << "1";
            } else {
                std::cout << "0";
            }
        }
        std::cout << "\n";
    }

    /**
     * @brief Allocate memory for the streaming used by the decompression
     */
    void init_stream()
    {
        stream = (mz_stream*)calloc(1, sizeof(mz_stream));
        if (!stream) {
            Logger::warning("Error on allocation of memory for the stream\n");
            exit(1);
        }
        if (mz_inflateInit(stream) != MZ_OK) {
            Logger::warning("Error on the initialisation of the decompression\n");
            exit(1);
        }
    }

    /**
     * @brief This function is used to decompress data from the trace. It use miniz and read the
     * trace by chunk when it's necessary
     */
    void decompress_data_from_trace()
    {
        int ret;
        unsigned char* in_buffer = (unsigned char*)calloc(1, MAX_SIZE_BUFFER);
        unsigned char* out_buffer = (unsigned char*)calloc(1, MAX_SIZE_BUFFER);

        if (!in_buffer || !out_buffer) {
            Logger::warning("Error on allocation of memory");
            exit(1);
        }

        if (!stream) { // we do this only the first time it's call
            init_stream();
        }

        stream->avail_in = 0;    // number of bytes on the entry
        stream->next_in = NULL;  // buffer for the entry
        stream->avail_out = 0;   // number of bytes on the exit
        stream->next_out = NULL; // buffer for the exit

        stream->avail_in = read(trace_descriptor, in_buffer, MAX_SIZE_BUFFER);
        stream->next_in = in_buffer;
        ssize_t have = 0;
        do {
            stream->avail_out = MAX_SIZE_BUFFER;
            stream->next_out = out_buffer;
            // This decompress data and store it in stream->next_out
            ret = mz_inflate(stream, MZ_SYNC_FLUSH);
            if (ret == MZ_STREAM_ERROR) {
                Logger::warning("Error during decompression\n");
                exit(1);
            }
            have = MAX_SIZE_BUFFER - stream->avail_out;
            if (have > 0) {
                memcpy(&(buf[end_buffer]), out_buffer, have);
                end_buffer += have;
            }
        } while (stream->avail_in > 0); // compressed data can be larger than the size of
                                        // the buffer on exit, so we maybe need to multiple
                                        // decompression in order to have all data

        bool_finish = (ret == MZ_STREAM_END);
        if (bool_finish) {
            ret = mz_inflateEnd(stream);
            if (ret != MZ_OK) {
                Logger::warning("Error when closing the stream of decompression\n");
                exit(1);
            }
            free(stream);
        }
        free(in_buffer);
        free(out_buffer);
    }

    /**
     * @brief This function read the  buffer who contains the trace
     *        By edge effect, read the trace if it's necessary.
     *
     * @param ptr A pointer on any type where the size next bytes will became the content of the
     *            trace
     *
     * @param size The number of bytes to read
     */
    void get_content_of_trace(void* ptr, int size)
    {
        if (size == 0) {
            return;
        }
        if (read_buffer == end_buffer) {
            end_buffer = 0;
            read_buffer = 0;
            decompress_data_from_trace();
            /*
            if (compress_data) {
                decompress_data_from_trace();
            } else{
                end_buffer = read(trace_descriptor, buf, MAX_SIZE_BUFFER);
                // check if we read all the trace. It's useful only if size of the trace
            is a multiple of MAX_SIZE_BUFFER off_t current = lseek(fd, 0, SEEK_CUR);
                off_t end     = lseek(fd, 0, SEEK_END);
                lseek(fd, current, SEEK_SET);
                if (current == end || end_buffer < MAX_SIZE_BUFFER) {
                    bool_finish = true;
                }
            }
            */
        }
        *((char*)ptr) = buf[read_buffer];
        read_buffer++;
        get_content_of_trace((char*)ptr + 1, size - 1);
    }

    /**
     * @brief This function check if all the trace has been read
     */
    bool is_finish() { return ((end_buffer <= read_buffer) && bool_finish); }

    uint64_t read_address()
    {
        uint64_t address_64 = 0;
        get_content_of_trace(&address_64, sizeof(uint64_t));
        return address_64;
    }

    inline unsigned read_type_transaction()
    {
        char result = 0;
        get_content_of_trace(&result, sizeof(char));
        return *((unsigned*)&result);
    }

    inline unsigned read_size(uint8_t* size_value)
    {
        char result = 0;
        get_content_of_trace(&result, sizeof(char));
        *size_value = result >> 4;
        result <<= 4;
        result >>= 4;
        return *((unsigned*)&result);
    }

    /**
     * @brief This function set boolean value of the transaction, all value are stored in 1 bit
     *
     * @param result a pointer on a transaction
     */
    void read_boolean_and_type(std::shared_ptr<hpdcache_test_transaction_req> result)
    {
        uint8_t tmp = 0;
        get_content_of_trace(&tmp, sizeof(uint8_t));

        uint8_t type_operation = tmp >> 2;
        result->req_op = (unsigned)type_operation;
        result->req_need_rsp = get_bit(tmp, 2);
        result->req_uncacheable = get_bit(tmp, 1);
        result->req_phys_indexed = true;
        result->req_io = result->req_uncacheable;
        result->req_abort = false;
    }

    /**
     * @brief This function can extract the value of 1 bit in a byte
     *
     * @param to_read a value store in a single byte
     *
     * @param position The position of the bit in the byte. Consider bit 8 its msb bit and
     *                 bit 1 its the lsb
     *
     * @return true if bit value is 1, else false
     */
    bool get_bit(char to_read, short position)
    {
        to_read = to_read << (8 - position);
        to_read = to_read >> 7;
        return (to_read & 1) != 0;
    }

    inline int is_big_endian()
    {
        int i = 1;
        return !*((char*)&i);
    }

    uint64_t get_address(uint8_t size, uint64_t address_on_real_computer)
    {
        size <<= 2; // multiply by 4
        if (size > HPDCACHE_REQ_DATA_WIDTH) {
            Logger::warning("A value larger than the cache width need to be store");
            exit(1);
        }
        if (!is_big_endian()) {
            return address_on_real_computer + HPDCACHE_REQ_DATA_WIDTH - size;
        } else {
            return address_on_real_computer;
        }
    }

    void read_value(std::shared_ptr<hpdcache_test_transaction_req> transaction,
                    uint8_t size_value_store)
    {
        switch (size_value_store) {
            case 0:
                uint8_t result8;
                get_content_of_trace(&(result8), sizeof(uint8_t));
                transaction->req_wdata = result8;
                break;
            case 1:
                uint16_t result16;
                get_content_of_trace(&(result16), sizeof(uint16_t));
                transaction->req_wdata = result16;
                break;
            case 2:
                uint32_t result32;
                get_content_of_trace(&(result32), sizeof(uint32_t));
                transaction->req_wdata = result32;
                break;
            case 3:
                uint64_t result64;
                get_content_of_trace(&(result64), sizeof(uint64_t));
                transaction->req_wdata = result64;
                break;
            case 4:
                uint64_t result128;
                get_content_of_trace(&(result128), sizeof(uint64_t));
                transaction->req_wdata = result128;
                break;
        }
        return;
    }

    void read_delay(uint8_t* delay) { get_content_of_trace(delay, sizeof(uint8_t)); }

    /**
     * @brief Read a transaction in a binary trace
     * @param transaction A pointer on a well formed transaction for the core previously allowed
     * @return  the delay to wait before sending the transaction
     */
    int read_transaction(std::shared_ptr<hpdcache_test_transaction_req> transaction)
    {
        uint8_t size_value_store, delay;
        read_delay(&delay); // read 1 byte
        transaction->req_addr =
            read_address(); // read (HPDCACHE_WORD_WIDTH * HPDCACHE_REQ_WORDS ) / 8 bytes
        transaction->req_size = read_size(&size_value_store); // read 1 byte for value and address
        read_boolean_and_type(transaction);                   // read 1 byte

        // TODO Add missing instructions with write data (e.g. AMO)
        if (transaction->req_op == hpdcache_test_transaction_req::HPDCACHE_REQ_STORE) {
            read_value(transaction, size_value_store); // read 8 byte
        }
        return delay;
    }

    void my_close() { close(trace_descriptor); }
};

/**
 * @class trace_writer
 * @brief This class is used for debug purpose. It's a singleton who allow us to store an execution
 *        of other mode (random write etc ) in the format for reader class in order to test it. For
 *        the moment it doesn't compress data. To use this, CREATE_FILE need to be set at the
 *        compilation
 */
class trace_writer
{
private:
    std::ofstream* trace;
    static std::mutex mutex_;
    static trace_writer* is_instance;

public:
    void write_address(std::shared_ptr<hpdcache_test_transaction_req> t)
    {
        uint64_t address_64 = t->req_addr.to_uint64();
        trace->write((char*)(&(address_64)), sizeof(uint64_t));
        return;
    }

    void write_type_transaction(std::shared_ptr<hpdcache_test_transaction_req> t)
    {
        unsigned op = t->req_op.to_uint();
        trace->write((char*)(&op), 1);
    }

    void write_size(std::shared_ptr<hpdcache_test_transaction_req> t)
    {
        unsigned op = t->req_size.to_uint();
        trace->write((char*)(&op), 1);
    }

    void write_boolean(std::shared_ptr<hpdcache_test_transaction_req> t)
    {
        unsigned bool_value = 0;
        bool_value = construct_bool_in_one_byte(t->get_need_resp(), bool_value);
        bool_value = construct_bool_in_one_byte(t->is_phys_indexed(), bool_value);
        bool_value = construct_bool_in_one_byte(t->is_uncacheable(), bool_value);
        bool_value = construct_bool_in_one_byte(t->is_io(), bool_value);
        bool_value = construct_bool_in_one_byte(t->is_aborted(), bool_value);
        if (Logger::is_debug_enabled()) {
            // display_binary(bool_value);
        }
        trace->write((char*)(&bool_value), 1);
    }

    unsigned construct_bool_in_one_byte(const bool to_add, unsigned result)
    {
        result = result << 1;
        if (to_add) {
            result |= 1;
        }
        return result;
    }

    void open_trace(std::string trace_name)
    {

        trace = new std::ofstream(trace_name, std::ios_base::binary | std::ios::trunc);
    }

    void close_trace() { trace->close(); }

    void write_delay(int* delay) { trace->write((char*)delay, sizeof(int)); }

    void write_in_trace(std::shared_ptr<hpdcache_test_transaction_req> t, int* delay)
    {
        write_delay(delay);
        write_address(t);
        write_type_transaction(t);
        write_size(t);
        write_boolean(t);
        return;
    }
};

trace_writer* is_instance = nullptr;
std::mutex mutex_;

trace_writer*
instance_trace_writter()
{
    std::lock_guard<std::mutex> lock(mutex_);
    if (is_instance) {
        return is_instance;
    }
    is_instance = new trace_writer();
    return is_instance;
}

#endif // __HPDCACHE_TEST_TRACE_MANAGER__
