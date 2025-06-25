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


#define MAX_SIZE_BUFFER 5000 

class File_reader
{
private:
    bool bool_finish = false;
    mz_stream *strm = nullptr;

public:

    int file_descriptor;
    char buf[MAX_SIZE_BUFFER * 20]; // * 20 car ça semble être la maximum de compression que l'on peut avoir
    int end_buffer;
    int read_buffer;


    File_reader(std::string file_name)
    {
    //    set_file(parse_name(file_name, "/"));
        set_file(file_name);
        init_buf();
    }
   /* 
    std::string parse_name(std::string s, std::string delimiter) {
        size_t pos_start = 0, pos_end, delim_len = delimiter.length();
        std::string token;
        std::vector<std::string> res;

        while ((pos_end = s.find(delimiter, pos_start)) != std::string::npos) {
            token = s.substr (pos_start, pos_end - pos_start);
            pos_start = pos_end + delim_len;
        }
        return token;
    }
   */
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

    int decompress_data_from_file() {
        int flush = MZ_SYNC_FLUSH;
        int ret;
        size_t buffer_size = MAX_SIZE_BUFFER;  // Taille du buffer pour chaque "chunk" (64 Ko ici)
        unsigned char *in_buffer = (unsigned char *) malloc(buffer_size);  // Buffer pour les données compressées lues
        unsigned char *out_buffer = (unsigned char *) malloc(buffer_size);  // Buffer pour les données décompressées
        memset(in_buffer, 0, buffer_size);
        memset(out_buffer, 0, buffer_size);
        
        if (!in_buffer || !out_buffer) {
            perror("Erreur allocation mémoire");
            exit(1);
        }

        // Initialiser le flux de décompression

        if (! strm){
            strm = (mz_stream *) malloc(sizeof (mz_stream));
            memset(strm, 0, sizeof(mz_stream));
            if (!strm){    
                fprintf(stderr, "Erreur d'allocation poour le stream\n");
                exit(1);
            }
            ret = mz_inflateInit(strm);
            if (ret != MZ_OK) {
                fprintf(stderr, "Erreur d'initialisation de la décompression: %d\n", ret);
                free(in_buffer);
                free(out_buffer);
                exit(1);
            }
        }

        strm->avail_in = 0;  // Nombre d'octets d'entrée
        strm->next_in = NULL; // Pointeur sur les données d'entrée
        strm->avail_out = 0;  // Nombre d'octets de sortie
        strm->next_out = NULL; // Pointeur sur le buffer de sortie

        end_buffer = 0;
        size_t total_read = 0;
        // Lire un bloc de données compressées
        strm->avail_in = read(file_descriptor, in_buffer, buffer_size);
        /*
           if (ferror(file_descriptor)) {
           fprintf(stderr, "Erreur de lecture du fichier\n");
           free(in_buffer);
           free(out_buffer);
           mz_inflateEnd(&strm);
           return -1;
           }
           */
        strm->next_in = in_buffer;
        ssize_t have = 0;
        // Décompresser le bloc de données
        do {
            strm->avail_out = buffer_size;
            strm->next_out = out_buffer;
            ret = mz_inflate(strm, flush);
            if (ret == MZ_STREAM_ERROR) {
                fprintf(stderr, "Erreur lors de la décompression\n");
                free(in_buffer);
                free(out_buffer);
                mz_inflateEnd(strm);
                exit(1);
            }
            have = buffer_size - strm->avail_out;
            if (have > 0) {
                memcpy(&(buf[end_buffer]), out_buffer, have);
                end_buffer += have;
            }
        } while ( strm->avail_in > 0);  // Continue tant qu'il y a encore des données décompressées à écrire

        bool_finish = (ret == MZ_STREAM_END);
        // Terminer la décompression et libérer les ressources
        if (bool_finish) {
            ret = mz_inflateEnd(strm);
            std::cout<<"c'est fini\n";
            std::flush(std::cout);
            if (ret != MZ_OK) {
                fprintf(stderr, "Erreur lors de la fermeture du flux de décompression\n");
                exit(1);
            }
            free(strm);
        }
        free(in_buffer);
        free(out_buffer);
        
        return 0;  // Décompression réussie
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
            decompress_data_from_file();
            read_buffer = 0;
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
    
    inline unsigned read_size()
    {
        char result = 0;
        get_content_of_file(&result, 1);
        return *((unsigned *) &result);
    }

    /**
     * @brief This function set boolean value of the transaction, all value are stored in 1 byte
     *        
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
     * @brief This function can extranct the value of 1 bit in a byte 
     *
     * @param to_read a value store in a signle byte 
     * @param position The position of the bit in the byte. Consider bit 8 is heavyweighti bit and bit 1 is the lightweight bit
     * @return true if bit value is 1, else false 
     */
    bool get_bit(char to_read, short position)
    {
        to_read = to_read << (8 - position);
        to_read = to_read >> 7;
        return (to_read & 1) != 0;

    }

    uint64_t read_value()
    {
       uint64_t result;
       get_content_of_file(&result, sizeof(uint64_t));
       return *((uint64_t *) &result);

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
        read_delay(&delay);
        transaction->req_addr = read_address(); // lit 8 octets
        transaction->req_op = read_type_transaction(); // lit 1 octet
        transaction->req_size = read_size(); // lit 1 octet
        read_boolean(transaction); // lit 1 octet
        transaction->req_wdata = read_value();
        return delay;
    }

    void my_close()
    {
        close(file_descriptor);
    }

};

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
            // address -> 8 octets car machine 64 bits
    }

    void write_type_transaction( std::shared_ptr<hpdcache_test_transaction_req> t) 
    {
        // type -> 1 octets ou 6 bits si ça marche Il y a 21 type actuellement.
        unsigned op = t->req_op.to_uint();
        file->write((char *) (&op), 1 ); // 1 octet
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
