#ifndef __HPD_CACHE_FILE_GESTION__
#define __HPD_CACHE_FILE_GESTION__

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
extern "C" {
    #include "miniz.h"
}
#include "hpdcache_test_transaction.h"


#define MAX_SIZE_BUFFER 5000000

class File_reader
{
private:
    bool bool_finish = false;
    mz_stream *stream = nullptr;

public:

    int file_descriptor;
    char buf[MAX_SIZE_BUFFER * 20]; // * 20 because it seems to be the maximum size after decompression
    int end_buffer;
    int read_buffer;


    File_reader(std::string file_name)
    {
        set_file(file_name);
        init_buf();
    }

    /**
     * @brief Open a file and check if it can be read. If not, this function does an exit()
     *
     * @param file_name The name of the file  
     */
    void set_file(std::string file_name)
    {
        file_descriptor = open(file_name.c_str(), O_RDONLY);
        if (file_descriptor <= 0){
            Logger::warning("Le fichier " + file_name + " n'a pas pu être ouvert");
            exit(EXIT_FAILURE);
        }
        Logger::info("Le fichier a bien était lu dans la version compress \n");
        init_buf();
    }

    void init_buf()
    {
        end_buffer = MAX_SIZE_BUFFER;
        read_buffer = MAX_SIZE_BUFFER;
    }

    /**
     * @brief Debug function to display a number store in one byte whith his binary representation 
     *
     * @param value A number store in 1 byte 
     */
    static void display_binary(unsigned value){ 
        unsigned tmp = value;
        std::cout<<"\nJ'ai lu " << tmp << "soit :";
        for (int i = 8 ; i > 0; i--){
            tmp = value;
            tmp = tmp << (8 - i);
            tmp = tmp >> 7;
            if ((tmp & 1) != 0){
                std::cout << "1";
            } else{
                std::cout << "0";
            }
        }
        std::cout << " fini\n";
    }

    /**
     * @brief Allocate memory for the streaming used by the decompression
     */
    void init_stream(){
        stream = (mz_stream *) calloc(1, sizeof(mz_stream));
        if (!stream){    
            Logger::warning("Error on allocation of memory for the stream\n");
            exit(1);
        }
        if (mz_inflateInit(stream) != MZ_OK) {
            Logger::warning("Error on the initialisation of the decompression\n");
            exit(1);
        }
    }

    /**
     * @brief This function is used to decompress data from the file. It use miniz and read the file by chunk when it's necessary
     *
     */
    void decompress_data_from_file() {
        int ret;
        unsigned char *in_buffer = (unsigned char *) calloc(1, MAX_SIZE_BUFFER);  // Buffer for compressed data 
        unsigned char *out_buffer = (unsigned char *) calloc(1, MAX_SIZE_BUFFER);  // Buffer where we decompress data
        
        if (!in_buffer || !out_buffer) {
            Logger::warning("Error on allocation of memory");
            exit(1);
        }

        if (! stream){ // we do this only the first time it's call 
            init_stream();
        }

        stream->avail_in = 0;  // number of bytes on the entry 
        stream->next_in = NULL; // buffer for the entry 
        stream->avail_out = 0; // number of bytes on the exit 
        stream->next_out = NULL; // buffer for the exit 

        stream->avail_in = read(file_descriptor, in_buffer, MAX_SIZE_BUFFER);
        stream->next_in = in_buffer;
        ssize_t have = 0;
        do {
            stream->avail_out = MAX_SIZE_BUFFER;
            stream->next_out = out_buffer;
            ret = mz_inflate(stream, MZ_SYNC_FLUSH); // This decompress data and store it in stream->next_out
            if (ret == MZ_STREAM_ERROR) {
                Logger::warning("Error during decompression\n");
                exit(1);
            }
            have = MAX_SIZE_BUFFER - stream->avail_out;
            if (have > 0) {
                memcpy(&(buf[end_buffer]), out_buffer, have);
                end_buffer += have;
            }
        } while ( stream->avail_in > 0); // compressed data can be larger than the size of the buffer on exit, so we maybe need to multiple decompression in order 
                                         // to have all data

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
     * @brief This function read the  buffer who contains the file
     *        By edge effect, read the file if it's necessary.
     *
     * @param pointer A pointer on any type where the size next bytes will became the content of the file 
     * @param size The number of bytes to read
     */
    void get_content_of_file(void * pointer, int size){
        if (size == 0){
            return;
        }
        if ( read_buffer == end_buffer){
            end_buffer = 0;
            read_buffer = 0;
            decompress_data_from_file();
            /*
            if (compress_data){
                decompress_data_from_file();
            } else{
                end_buffer = read(file_descriptor, buf, MAX_SIZE_BUFFER); 
                // check if we read all the file. It's useful only if size of the file is a multiple of MAX_SIZE_BUFFER
                off_t current = lseek(fd, 0, SEEK_CUR); 
                off_t end     = lseek(fd, 0, SEEK_END);
                lseek(fd, current, SEEK_SET); 
                if (current == end || end_buffer < MAX_SIZE_BUFFER) {
                    bool_finish = true;
                }
            }
            */
        }
        *((char *) pointer) = buf[read_buffer];
        read_buffer++;
        get_content_of_file(pointer + 1, size - 1);
    }
   
    /**
     * @brief This function check if all the file has been read
     */
    bool is_finish()
    {
        return ((end_buffer <= read_buffer) && bool_finish);
    }

    uint64_t read_address()
    {
        switch (HPDCACHE_WORD_WIDTH)
        {
            case 32:
            {
                uint32_t address_32 = 0;
                get_content_of_file(&address_32, sizeof(uint32_t));
                return address_32;
            }
            case 64:
            {
                switch ( HPDCACHE_REQ_WORDS)
                {
                    case 1: // 64 bits
                    {
                        uint64_t address_64= 0;
                        get_content_of_file(&address_64, sizeof(uint64_t));
                        return address_64;
                    }
                    case 2: // 128 bits
                    {
                        break;
                    }
                    case 4: // 256 bits
                    {
                        break;
                    }
                }
            }
            default:
            {
                break;
            }
        }
        return 0;
    }

    inline unsigned read_type_transaction()
    {
        char result = 0;
        get_content_of_file(&result, 1);
        return *((unsigned *) &result);
    }
    
    inline unsigned read_size(uint8_t *size_value)
    {
        char result = 0;
        get_content_of_file(&result, 1);
        *size_value = result >> 4;
        result <<= 4;
        result >>= 4;
        return *((unsigned *) &result);
    }

    /**
     * @brief This function set boolean value of the transaction, all value are stored in 1 bit
     *
     * @param result a pointer on a transaction 
     */
    void read_boolean(std::shared_ptr<hpdcache_test_transaction_req> result)
    {
        unsigned tmp = 0;
        get_content_of_file(&tmp, 1);
        if (Logger::is_debug_enabled()){
            //display_binary(tmp);
        }
        result->req_need_rsp = get_bit(tmp, 5);
        result->req_phys_indexed = get_bit(tmp, 4);
        result->req_uncacheable = get_bit(tmp, 3);
        result->req_io = get_bit(tmp, 2);
        result->req_abort = get_bit(tmp, 1);
    }

    /**
     * @brief This function can extract the value of 1 bit in a byte 
     *
     * @param to_read a value store in a sigle byte 
     * @param position The position of the bit in the byte. Consider bit 8 is heavyweighti bit and bit 1 is the lightweight bit
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
        int i=1;
        return ! *((char *)&i);
    }

    uint64_t get_adress(uint8_t size, uint64_t adress_on_real_computer)
    {
        size  <<= 2; // mutliplie par 4
        if (size > HPDCACHE_REQ_DATA_WIDTH){
            Logger::warning("A value larger than the cache witdh need to be store");
            exit(1);
        }
        if ( ! is_big_endian()){
            return adress_on_real_computer + HPDCACHE_REQ_DATA_WIDTH - size;
        } else {
            return adress_on_real_computer;
        }

    }

    void read_value(std::shared_ptr<hpdcache_test_transaction_req> transaction, uint8_t size_value_store)
    {
       switch (size_value_store){
            case 0:
                uint8_t result8;
                get_content_of_file( &(result8), sizeof(uint8_t));
                transaction->req_wdata = result8;
                break;
            case 1:
                uint16_t result16;
                get_content_of_file( &(result16),sizeof(uint16_t));
                transaction->req_wdata = result16;
                break;
            case 2:
                uint32_t result32;
                get_content_of_file( &(result32), sizeof(uint32_t));
                transaction->req_wdata = result32;
                break;
            case 3:
                uint64_t result64;
                get_content_of_file( &(result64), sizeof(uint64_t));
                transaction->req_wdata = result64;
                break;
            case 4:
                uint64_t result128;
                //get_adress();
                get_content_of_file( &(result128), sizeof(uint64_t));
                transaction->req_wdata = result128;
                break;

       }
       return; 

    }

    void read_delay(int * delay)
    {
        get_content_of_file(delay, sizeof(int));
    }

    /**
     * @brief Read a transaction in a binary file 
     *
     * @param transaction A pointer on a well formed transaction for the core previously allowed
     * @return  the delay to wait before sending the transaction
     */
    int read_transaction(std::shared_ptr<hpdcache_test_transaction_req> transaction)
    {
        int delay;
        uint8_t size_value_store;
        read_delay(&delay); // read 4 byte
        transaction->req_addr = read_address(); // read 8 bytes
        transaction->req_op = read_type_transaction(); // read 1 byte
        transaction->req_size = read_size(&size_value_store); // read 1 byte
        read_boolean(transaction); // read 1 byte
        if (transaction->req_op == hpdcache_test_transaction_req::HPDCACHE_REQ_STORE ){ // TODO Add more instructions supported in this sequence
            read_value(transaction, size_value_store ); // read 8 byte
        }
        return delay;
    }

    void my_close()
    {
        close(file_descriptor);
    }

};

/**
 * @class File_writer
 * @brief This class is used for debug purpose. It's a singleton who allow us to store an execution of other mode ( random write etc )
 * in the format for reader class in order to test it. For the moment it doesn't compress data. To use this, CREATE_FILE need to be set at te compilation
 *
 */
class File_writer
{ 
private:
    std::ofstream *file;
    static std::mutex mutex_;
    static File_writer* is_instance; 
public:


    void write_adress(std::shared_ptr<hpdcache_test_transaction_req> t) 
    {
        switch (HPDCACHE_WORD_WIDTH)
        {
            case 32:
            {
                uint32_t address_32 = t->req_addr.to_uint64();
                file->write((char*)(&(address_32)), sizeof(uint32_t));
                break;
            }
            case 64:
            {
                switch ( HPDCACHE_REQ_WORDS)
                {
                    case 1: // 64 bits
                    {
                        uint64_t address_64 = t->req_addr.to_uint64();
                        file->write((char*)(&(address_64)), sizeof(uint64_t));
                        break;
                    }
                    case 2: // 128 bits
                    {
                        break;
                    }
                    case 4: // 256 bits
                    {
                        break;
                    }
                }
            }
            default:
            {
                break;
            }
        }
    }

    void write_type_transaction( std::shared_ptr<hpdcache_test_transaction_req> t) 
    {
        unsigned op = t->req_op.to_uint();
        file->write((char *) (&op), 1 ); 
    }

    void write_size(std::shared_ptr<hpdcache_test_transaction_req> t) 
    {
        unsigned op = t->req_size.to_uint();
        file->write((char *) (&op), 1);
    }

    void write_boolean(std::shared_ptr<hpdcache_test_transaction_req> t) 
    {
        unsigned bool_value = 0;
        bool_value = construct_bool_in_one_byte(t->get_need_resp(), bool_value);
        bool_value = construct_bool_in_one_byte(t->is_phys_indexed(), bool_value);
        bool_value = construct_bool_in_one_byte(t->is_uncacheable(), bool_value);
        bool_value = construct_bool_in_one_byte(t->is_io(), bool_value);
        bool_value = construct_bool_in_one_byte(t->is_aborted(), bool_value);
        if (Logger::is_debug_enabled()){
            //display_binary(bool_value);
        }
        file->write((char *) (&bool_value), 1);
    }
    
    unsigned construct_bool_in_one_byte(const bool to_add, unsigned result) 
    {
        result = result << 1;
        if (to_add){
            result |= 1;
        }
        return result;
    }

    void open_file(std::string file_name)
    {

        file = new std::ofstream(file_name, std::ios_base::binary | std::ios::trunc);
    }

    void close_file()
    {
        file->close();
    }

    void write_delay(int *delay)
    {
        file->write( (char *) delay, sizeof(int)); 
    }



    void write_in_file(std::shared_ptr<hpdcache_test_transaction_req> t, int *delay) 
    {
        write_delay(delay);
        write_adress(t);
        write_type_transaction(t);
        write_size(t);
        write_boolean(t);
        return;
    }
};
File_writer *is_instance = nullptr; 
std::mutex mutex_;

File_writer* instance_file_writter()
{
    std::lock_guard<std::mutex> lock(mutex_);
    if (is_instance){
        return is_instance;
    }
    is_instance = new File_writer();
    return is_instance;
}

#endif // __HPD_CACHE_FILE_GESTION__
