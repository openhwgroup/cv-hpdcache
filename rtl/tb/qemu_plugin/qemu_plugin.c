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
 *  Description:  Plugin to extract information from QEMU.
 */

#include <stdio.h>
#include <inttypes.h>
#include <qemu-plugin.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>


#include "miniz.h"
QEMU_PLUGIN_EXPORT int qemu_plugin_version = QEMU_PLUGIN_VERSION;

#define SIZE_BUFFER 5000 


typedef enum mode{
    WRITE_BINARY,
    WRITE_ASCII,
    NO_WRITE
} mode_write;
mode_write mode; // Use to know which mode the user want. this is give on the command line


bool is_64_bits; // we use this to know how many bits are used to decribe an adress
char buffer_compress[SIZE_BUFFER]; // A buffer to store data collected by the plugin. We write it by chunk in the file
int buffer_begin; // an index in the buffer  
bool need_to_compress = true; // true -> we encrypt the data; false -> data are stored whitout compression
bool write_data = true; // TODO ask to Fred 


int file_descriptor; // The file where we store data 
mz_stream *stream = NULL; // We use this to compress data
int current_instruction = 0; // We use this to count the number of instructions happen between two acces in memory

/**
 * @brief This function is used to create a stream. This must be call only one time before the first write in the file
 */
static void init_stream(void){
    stream = malloc(sizeof (mz_stream));
    if (mz_deflateInit(stream, MZ_BEST_SPEED) != MZ_OK){
        fprintf(stderr, "Error initialisation of the stream\n");
        exit(1);
    }
}

/**
 * @brief  this function use miniz to compress data in a file. 
 *
 * @param last_call This parameter can take two value : MZ_FINISH, MZ_NO_FLUSH. MZ_FINISH is only for the last call when qemu exit
 */
static void compress_data_to_file(int last_call) {
    size_t buffer_size = buffer_begin;  // Taille du buffer pour chaque "chunk" 
    unsigned char *out_buffer = malloc(buffer_begin);  // Buffer de sortie pour les données compressées
    if (!out_buffer) {
        perror("Error in memory allocation");
        exit(1);
    }

    if (!stream){ 
        init_stream();
    }

    stream->avail_in = 0;  // number of bytes on the entry 
    stream->next_in = NULL; // buffer for the entry 
    stream->avail_out = 0; // number of bytes on the exit 
    stream->next_out = NULL; // buffer for the exit 

    size_t offset = 0;
    while (offset < buffer_begin - 1) {
        size_t chunk_size = (buffer_begin- offset) >= buffer_size ? buffer_size : (buffer_begin - offset);
        stream->avail_in = chunk_size;
        stream->next_in = (unsigned char *)( buffer_compress + offset);

        do {
            stream->avail_out = buffer_size;
            stream->next_out = out_buffer;

            if ( mz_deflate(stream, last_call) ==  MZ_STREAM_ERROR) {
                fprintf(stderr, "Error during compression\n");
                free(out_buffer);
                mz_deflateEnd(stream);
                exit(1);
            }

            size_t have = buffer_begin - stream->avail_out;
            if (write(file_descriptor, out_buffer, have) != have) {
                fprintf(stderr, "Error, can't write in the file\n");
                free(out_buffer);
                mz_deflateEnd(stream);
                exit(1);
            }
        } while (stream->avail_out <= 0);  
        offset += chunk_size;  
    }
    
    if (last_call == MZ_FINISH){
        // Execution in QEMU is finish, so we stop the stream and desallocate it 
        if (mz_deflateEnd(stream) != MZ_OK){
            fprintf(stderr, "Error when closing the stream of compression\n");
            exit(1);
        }
        free(out_buffer);
    }
}

/**
 * @brief This function set the mode of write the pluin will use
 *
 * @param arg a string which can be convert to an integer between 0 and 2
 */
static void set_mode(char * arg){
    switch (arg[0]){
        case '0':
            mode = WRITE_BINARY;
            break;
        case '1':
            mode = WRITE_ASCII;
            break;
        case '2':
            mode = NO_WRITE;
            break;
        default:
            fprintf(stderr, "\nMode must be between 0 and 2\n0 -> write in binary\n1 -> write in ascii\n2 -> do nothing\n");
            exit(1);
    }
    if (arg[1] != 0){
        fprintf(stderr, "\nMode must be between 0 and 2\n0 -> write in binary\n1 -> write in ascii\n2 -> do nothing\n");
        exit(1);
    }
}

/**
 * @brief This function is the only place where we can store new data in the buffer. 
 *
 * @param data An array of data we want to store in the file
 * @param size The number of bytes we used in this array
 */
static void write_buffer(char * data, int size){
    
    if (need_to_compress){
        for (int i = 0; i < size; i++){
            buffer_compress[buffer_begin] = data[i];
            buffer_begin++;
            if (buffer_begin  == SIZE_BUFFER){
               compress_data_to_file(MZ_NO_FLUSH);  
               buffer_begin = 0;
            }
        }
    } else{
        if (write(file_descriptor, data, size) == 0){
            printf("some error occur, can't write in the file !!!!!!!!\n");
            exit(1);
        };
    }
}


static void write_adress(uint64_t *adress)
{
    if (is_64_bits){
        write_buffer((char *) (adress), sizeof(uint64_t));
    } else{
        write_buffer((char *) ((uint32_t *) adress), sizeof(uint32_t));
    }

}

static void write_type_transaction(bool is_store) 
{
    char type = 0;
    if (is_store){
        type = 1;
    }
    write_buffer((char *) (&type), 1);
}

static uint8_t get_size_value(enum qemu_plugin_mem_value_type value)
{
    switch (value){
        case QEMU_PLUGIN_MEM_VALUE_U8:
            return 0;
        case QEMU_PLUGIN_MEM_VALUE_U16:
            return 1;
        case QEMU_PLUGIN_MEM_VALUE_U32:
            return 2;
        case QEMU_PLUGIN_MEM_VALUE_U64:
            return 3;
        case QEMU_PLUGIN_MEM_VALUE_U128:
            return 4;
        default:
            return 0;
    }

}

/**
 * @brief This function write in the file the size of the adress access and also the size of the data if a value need to be store. All in one byte
 *
 * @param size_adress describe the width used in the address  
 * @param size_value an enum provided by QEMU to know the size of the value ( see get_size_value )
 */
static void write_size(uint8_t * size_adress, enum qemu_plugin_mem_value_type size_value )
{
    char value = (*size_adress) | ( get_size_value(size_value) << 4 ); 
    write_buffer((char *) (&value), 1);
}

static void write_boolean(uint8_t value) 
{
    write_buffer((char *) (&value), 1);
}

static void write_delay(uint8_t *delay)
{
    write_buffer((char *) (delay), sizeof(uint8_t));
}


static void write_value(qemu_plugin_mem_value value)
{
//    printf("je vais écrire une valeur \n");
    switch (value.type){

        case QEMU_PLUGIN_MEM_VALUE_U8:
            write_buffer( (char *) &(value.data.u8), sizeof(uint8_t));
            //printf("j'écris valeur = %d\n", value.data.u8);
            break;
        case QEMU_PLUGIN_MEM_VALUE_U16:
            write_buffer( (char *) &(value.data.u16), sizeof(uint16_t));
            //printf("j'écris valeur = %d\n", value.data.u16);
            break;
        case QEMU_PLUGIN_MEM_VALUE_U32:
            write_buffer( (char *) &(value.data.u32), sizeof(uint32_t));
            //printf("j'écris valeur = %d\n", value.data.u32);
            break;
        case QEMU_PLUGIN_MEM_VALUE_U64:
            write_buffer( (char *) &(value.data.u64), sizeof(uint64_t));
            //printf("j'écris valeur = %ld\n", value.data.u64);
            break;
        case QEMU_PLUGIN_MEM_VALUE_U128:
            //printf("je devrais écrire sur 128 bits\n");
            // TODO use like this
            // value.data.u128.low = low;
            // value.data.u128.high = current_cpu->neg.plugin_mem_value_high;
            break;
    }
}


/**
 * @brief Open a file and truncate it if it already exists else we juste create it
 *
 * @param file_name The name of file we will create
 */
static void open_file(char * file_name)
{
    file_descriptor = open(file_name, O_CREAT | O_WRONLY | O_TRUNC,  S_IRWXU);
    if (file_descriptor == -1)
    {
        if (write(2, strerror(errno), strlen(strerror(errno))) == -1 ||  write(2, "\n", 1) == -1 ){
            printf("some error occur !!!!!!!!\n");
            exit(1);
        }
    }
}

static void close_file(void)
{
    close(file_descriptor);
}


/**
 * @brief Store a transaction in a file
 *
 * @param is_store A boolean where true -> transaction is a store 
 * @param adress An adress in Qemu store in 8 bytes
 * @param size The type of the request to know if adress must be interpreted for 1,16, 32 or 64 bytes
 * @param time_elapsed the number of instruction who happened before this instruction excluding all memory access
 * @param value an integer on 8 bytes representing the value for a store 
 */
static void write_in_file(bool is_store, uint64_t adress, uint8_t size, uint8_t time_elapsed, qemu_plugin_mem_value value, uint8_t cacheable) 
{
    write_delay(&time_elapsed); // 1 byte
    write_adress(&adress); // 8 bytes
    write_size(&size, value.type); // 1 byte
    uint8_t boolean_value_and_type = 2; // need response
    if (is_store){
        boolean_value_and_type |= (1 << 2); // store
        boolean_value_and_type -= 2;
    }
    boolean_value_and_type |= cacheable;
    
//    write_type_transaction(is_store);
    write_boolean(boolean_value_and_type); // 1 byte
    if (is_store){
        write_value(value); // 8 bytes
    }
    return;
}


/**
 * @brief This function is called each time an instruction is executed if it's a memory access. Also reboot the counter of instruction
 *
 * @param vcpu_index Don't care 
 * @param info information about the instruction
 * @param vaddr The adress concered by the instruction
 * @param userdata NULL pointer, we don't send something
 */
static void mem_cb(unsigned int vcpu_index,
        qemu_plugin_meminfo_t info,
        uint64_t vaddr,
        void *userdata) {
    size_t size = qemu_plugin_mem_size_shift(info);
    struct qemu_plugin_hwaddr *hwaddr = qemu_plugin_get_hwaddr(info, vaddr);
    uint8_t uncacheable = 0;
    if (hwaddr) {
        vaddr = qemu_plugin_hwaddr_phys_addr(hwaddr);
        if ((vaddr >= 0x10000000 && vaddr < 0x10000100) ||  // UART
            (vaddr >= 0x10001000 && vaddr < 0x10009000) ||  // VirtIO MMIO
            (vaddr >= 0x00100000 && vaddr < 0x00102000) ||  // Test + RTC
            (vaddr >= 0x10100000 && vaddr < 0x10100018) ||  // fw_cfg
            (vaddr >= 0x02000000 && vaddr < 0x02010000) ||  // CLINT
            (vaddr >= 0x0c000000 && vaddr < 0x0c600000) ||  // PLIC
            (vaddr >= 0x20000000 && vaddr < 0x24000000) ||  // Flash banks
            (vaddr >= 0x30000000 && vaddr < 0x40000000) ||  // PCIe
            (vaddr >= 0x04000000 && vaddr < 0x06000000))    // Platform bus
        {
            uncacheable = 1;
        }
    }
    char my_string[75];
    const char *type = qemu_plugin_mem_is_store(info) ? "store" : "load";
    qemu_plugin_mem_value value_store = qemu_plugin_mem_get_value(info);
    
    if (! write_data ) { // TODO ask to Fred what instruction trigger this
        return;
    }

    switch (mode){
        case WRITE_BINARY:
            write_in_file(qemu_plugin_mem_is_store(info), vaddr, size, current_instruction, value_store, uncacheable);
            break;
        case WRITE_ASCII:
            snprintf(my_string, 75, "%d [MEM] %-5s vcpu=%u addr=0x%" PRIx64 " size=%zu value=%lu\n", 
                    current_instruction, type, vcpu_index, vaddr, size, value_store.data.u64);
            write_buffer(my_string, strlen(my_string));
            break;
        default:
            break;
    }
    current_instruction = 0; // reboot the counter of instruction who are not a memory access
}

/**
 * @brief This function is called when QEMU finish the simulation. It close the stream if we compress data and it also close the file.
 *
 * @param id Don't care
 * @param p Don't care
 */
static void plugin_exit(qemu_plugin_id_t id, void *p)
{
    if (need_to_compress){
        compress_data_to_file(MZ_FINISH);  
    }
    if (mode != NO_WRITE ){
        close_file();
    }
}

/**
 * @brief This function is called after each instruction executed in QEMU and we use this to count the number of instructions. 
 * Counter is reboot when we see a memory access
 *
 * @param vcpu_index Don't care
 * @param userdata  Don't care
 */
static void counter_inst(unsigned int vcpu_index,   void * userdata){
    current_instruction++;
}

/**
 * @brief This function is called when a tb ( translation block ) is ready. We can register ourself to be call on a certain instruction 
 * We register on each instruction just to increase the instruction counter
 * We also register on memory access instruction in order to log it in our file
 *
 * @param id Don't care
 * @param tb the translation block
 */
static void tb_trans_cb(qemu_plugin_id_t id, struct qemu_plugin_tb *tb) {
    int n = qemu_plugin_tb_n_insns(tb);
    for (int i = 0; i < n; i++) {
        
        struct qemu_plugin_insn *insn = qemu_plugin_tb_get_insn(tb, i);
        qemu_plugin_register_vcpu_mem_cb(insn, mem_cb, QEMU_PLUGIN_CB_NO_REGS, QEMU_PLUGIN_MEM_RW, NULL);
        qemu_plugin_register_vcpu_insn_exec_cb(insn, counter_inst, 0, NULL);
    }
}

static void usage(void){
    fprintf(stderr, "\nUsage : \nmode=<0,1,2 ( 0-> binary, 1 -> ascii, 2 -> nothing )>, file=<name_of_a_file>, compress=<true, false>\n");
}

QEMU_PLUGIN_EXPORT int qemu_plugin_install(qemu_plugin_id_t id, const qemu_info_t *info, int argc, char **argv) {
    if (argc != 3 ){
        usage();
        return -1;
    }

    for (int i = 0; i < argc; i++) {
        char *opt = argv[i];
        g_auto(GStrv) tokens = g_strsplit(opt, "=", 2);
        if (g_strcmp0(tokens[0], "mode") == 0) {
            set_mode(tokens[1]);
        } else if (g_strcmp0(tokens[0], "file_to_write") == 0) {
            open_file(tokens[1]);
        } else if (g_strcmp0(tokens[0], "compress") == 0) {
            need_to_compress= (strcmp(tokens[1], "true") == 0);
        } else {
            fprintf(stderr, "option parsing failed: %s\n", opt);
            return -1;
        }
    }
    printf("architecture : %s\n",info->target_name);
    is_64_bits = (strcmp(info->target_name, "riscv64") == 0);
    buffer_begin = 0;
    qemu_plugin_register_vcpu_tb_trans_cb(id, tb_trans_cb);
    qemu_plugin_register_atexit_cb(id, plugin_exit, NULL);
    return 0;
}
