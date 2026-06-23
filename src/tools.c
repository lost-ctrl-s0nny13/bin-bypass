#include "tools.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <malloc.h>
#include <assert.h>
static_assert(sizeof(void*) == 8, "Error: this utility supports only 64-bit systems"); //check system
#define SWAP_FLAG(flag, n) ((flag) ^ (1U << (n))) //bit flag implementation
#define GET_FLAG(flag, n) (((flag) & (1U << (n))) >> (n)) //bit flag implementation
#define SET_FLAG(flag, n) ((flag) | (1U << (n))) //bit flag implementation
#define UNSET_FLAG(flag, n) ((flag) & (~(1U << (n)))) //bit flag implementation
#define TRUE 1U //bit flag implementation
#define FALSE 0U //bit flag implementation
#define FRAGMENT_SIZE_OLD 209715200 // 200MB VK limit on files
#define FRAGMENT_SIZE     10485760 // 10MB old version works bad
#define BYPASS_AUTOMOD_SIMPLE_SHIFT 13

typedef struct file_info{
    size_t file_size;
    char* filename;
    size_t filename_size;
    FILE* fd;
} _fi;

typedef struct file_fragments_info{
    char enc_type;
    uint32_t fragments_count;
    char** fragments_arrange;
} _ffi;

_fi executable;
_ffi fragments;
#ifdef _WINDOWS_BUILD
unsigned char buffer[FRAGMENT_SIZE] __attribute__((section(".huge")));
#endif
#ifdef _LINUX_BUILD
unsigned char buffer[FRAGMENT_SIZE] __attribute__((section(".huge_bss")));
#endif

//open_file
void open_file(const char* file_path){
    FILE* binary_file = fopen(file_path, "rb");
    if(binary_file == NULL){ fprintf(stderr, "[bin-bypass][x]: Cant reach file: %s\n", file_path); return; }

    //file size calculating
    fseek(binary_file, 0, SEEK_END);
    #ifdef _WINDOWS_BUILD
    long long file_size = _ftelli64(binary_file);
    #endif
    #ifdef _LINUX_BUILD
    long long file_size = ftello(binary_file);
    #endif
    executable.file_size = file_size;

    //parsing filename from file_path
    uint8_t flags = 0b00000000;// flag 0 - filename not ended
    executable.filename_size = 0;
    long long index = -1;
    for(long long i = strlen(file_path) - 1; i >= 0; --i){
        if((file_path[i] == '\\') || (file_path[i] == '/')){
            flags = SET_FLAG(flags, 0);
            break;
        }else if(GET_FLAG(flags, 0) == FALSE){
            index = i;
            ++executable.filename_size;
        }
    }
    executable.filename = (char *)malloc(sizeof(char) * (executable.filename_size + 1));
    for(long long i = index, j = 0; j < executable.filename_size; ++j, ++i){
        executable.filename[j] = file_path[i];
    }
    executable.filename[executable.filename_size] = '\0';
    printf("[bin-bypass][v]: filename: %s\n", executable.filename);
    printf("[bin-bypass][v]: file size: %zu bytes\n", executable.file_size);
    rewind(binary_file);
    executable.fd = binary_file;
}

//save_fragments
void save_fragments(char enc_type){
    if(executable.fd == NULL){ return; }
    //counting fragments
    fragments.fragments_count = (executable.file_size + FRAGMENT_SIZE - 1) / FRAGMENT_SIZE;
    printf("[bin-bypass][v]: binary file will be splited to %u fragments\n", fragments.fragments_count);
    fragments.fragments_arrange = (char**)calloc(fragments.fragments_count, sizeof(char*));
    if(fragments.fragments_arrange == NULL){
        fprintf(stderr, "[bin-bypass][x]: allocation error in \"save_fragments()\"\n");
        return;
    }
    printf("[bin-bypass][v]: this tool will generate next %u files:\n", fragments.fragments_count+1);
    printf("\t\t[1] info.txt\n");
    FILE* info_file = fopen("info.txt", "w+");
    if(info_file == NULL){
        fprintf(stderr, "[bin-bypass][x]: cant create service file \"info.txt\"\n");
        return;
    }
    fprintf(info_file, "f_name = %s\nf_size = %zu\nenc_type = %d\nf_count = %u", executable.filename, executable.file_size, enc_type, fragments.fragments_count);
    fclose(info_file);
    for(uint32_t i = 0; i < fragments.fragments_count; ++i){
        fragments.fragments_arrange[i] = (char*)malloc(sizeof(char) * (1 + ((i >= 100) ? 3 : (i >= 10) ? 2 : 1) + 5));
        sprintf(fragments.fragments_arrange[i], "f%u.txt", i);
        printf("\t\t[%u] %s\n", i+2, fragments.fragments_arrange[i]);
        FILE* fragment_file = fopen(fragments.fragments_arrange[i], "wb");
        if(fragment_file == NULL){
            fprintf(stderr, "[bin-bypass][x]: cant create fragment file \"%s\"\n", fragments.fragments_arrange[i]);
            return;
        }
        size_t read_bytes = fread(buffer, sizeof(char), FRAGMENT_SIZE, executable.fd);
        switch(enc_type){
            case 0:
                break;
            case 1:
                bypass_automod_simple(buffer, 0, read_bytes);
                break;
            default:
                break;
        }
        size_t written_bytes = fwrite(buffer, sizeof(char), read_bytes, fragment_file);
        fclose(fragment_file);
    }
}
//load_fragments
void load_fragments(char* info_file_path){
    //loading info about fragments
    FILE* info_file = fopen(info_file_path, "rb");
    if(info_file == NULL){
        fprintf(stderr, "[bin-bypass][x]: cant reach info file \"%s\"\n", info_file_path);
        executable.fd = NULL;
        return;
    }
    fseek(info_file, 9, 0);
    executable.filename_size = 0;
    while(fgetc(info_file) != '\n'){
        ++executable.filename_size;
    }
    executable.filename = (char*)malloc(sizeof(char) * (executable.filename_size + 1));
    rewind(info_file);
    fscanf(info_file, "f_name = %s\nf_size = %zu\nenc_type = %d\nf_count = %u", executable.filename, &executable.file_size, &fragments.enc_type, &fragments.fragments_count);
    fclose(info_file);
    executable.fd = fopen(executable.filename, "wb");
    //checking existing of fragments
    for(uint32_t i = 0; i < fragments.fragments_count; ++i){
        printf("[bin-bypass]: checking file f%u.txt - ", i);
        char ffile_name[10];
        sprintf(ffile_name, "f%u.txt", i);
        FILE* fragment_file = fopen(ffile_name, "r");
        if(fragment_file == NULL){
            printf("[x] cant reach this file\n");
            executable.fd = NULL;
        } else {
            printf("[v] file available\n");;
        }
        fclose(fragment_file);
    }
    return;
}
//save_file
void save_file(){
    if(executable.fd == NULL){
        return;
    }
    printf("[bin-bypass][v]: starting reassembling of origin binary\n");
    if(executable.fd == NULL){
        fprintf(stderr, "[bin-bypass][x]: failed to create binary \"%s\"\n", executable.filename);
        return;
    }
    for(uint32_t i = 0; i < fragments.fragments_count; ++i){
        sprintf(buffer, "f%u.txt", i);
        printf("[bin-bypass]: trying to process file \"%s\" - ", buffer);
        FILE* fragment_file = fopen(buffer, "rb");
        if(fragment_file == NULL){
            fprintf(stderr, "[bin-bypass][x]: failed to open fragment file \"%s\"\n", buffer);
            return;
        }
        size_t read_bytes = fread(buffer, sizeof(unsigned char), FRAGMENT_SIZE, fragment_file);
        fclose(fragment_file);
        switch(fragments.enc_type){
            case 0:
            break;
            case 1:
                bypass_automod_simple(buffer, 1, read_bytes);
            break;
            default:
                fprintf(stderr, "[bin-bypass][!]: maybe you re using old version of tool. skipping \"enc_type = %u\"\n", fragments.enc_type);
            break;
        }
        size_t written_bytes = fwrite(buffer, sizeof(unsigned char), read_bytes, executable.fd);
        if((read_bytes != written_bytes) || (read_bytes == 0)){
            fprintf(stderr, "[bin-bypass][x]: failed to process fragment file \"f%u.txt\"\n", i);
            return;
        } else {
            printf("[v]\n");
        }
    }
    fclose(executable.fd);
}
//free_resources
void free_resources(){
    if(executable.filename != NULL){
        free(executable.filename);
    }
    if(fragments.fragments_arrange != NULL){
        for(uint32_t i = 0; i < fragments.fragments_count; ++i){
            if(fragments.fragments_arrange[i] != NULL){
                free(fragments.fragments_arrange[i]);
            }
        }
        free(fragments.fragments_arrange);
    }
    printf("[bin-bypass][v]: tool ended work\n");
}
//bypass_automod_simple - caesar_shift
void bypass_automod_simple(unsigned char* buffer, char rev, size_t read_bytes){
    for(uint64_t i = 0; i < read_bytes; i++){
        buffer[i] += (rev == 0)? BYPASS_AUTOMOD_SIMPLE_SHIFT : -BYPASS_AUTOMOD_SIMPLE_SHIFT;
    }
}