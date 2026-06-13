#include <stdio.h>
#include <string.h>
#include "tools.h"
#define EXT_COUNT 1
#define CMD_COUNT 2

char* EXTs[EXT_COUNT] = {"simple_vk_bypass"};
char* CMDs[CMD_COUNT] = {"split", "build"};

void help_msg(){
    printf("To use this tool follow this syntax:\n");
    printf("bin-bypass split <path_to_binary> [EXT] - to split binary\n");
    printf("bin-bypass build <path_to_info.txt> - to build up binary\n");
    printf("EXT can be:\n");
    printf("1. simple_vk_bypass - uses caesar shift to bypass vk.com automoderation of files\n");
    printf("other EXT maybe coming soon...\n");
}

int main(int argc, char** argv){
    char cmd_index = -1;
    char ext_index = -1;
    if(argc > 1)
    for(int i = 0; i < CMD_COUNT; ++i){
        if(strcmp(argv[1], CMDs[i]) == 0){
            cmd_index = i;
            break;
        }
    }
    switch(argc){
        case 1:
            help_msg();
            break;
        case 3://without EXT
            ext_index = 0;
            switch(cmd_index){
                case 0:
                    printf("[bin-bypass][v]: splitting origin file\n");
                    printf("[bin-bypass][!]: without EXT\n");
                    open_file(argv[2]);
                    save_fragments(ext_index);
                    free_resources();
                    break;
                case 1:
                    printf("[bin-bypass][v]: building origin file\n");
                    printf("[bin-bypass][!]: without EXT\n");
                    load_fragments(argv[2]);
                    save_file();
                    free_resources();
                    break;
                default:
                    fprintf(stderr, "[bin-bypass][x]: unrecoginzed CMD - \"%s\"\n", argv[1]);
                    help_msg();
            }
        break;
        case 4://EXT
            for(int i = 0; i < EXT_COUNT; ++i){
                if(strcmp(argv[3], EXTs[i]) == 0){
                    ext_index = i+1;
                    break;
                }
            }
            if(ext_index == -1){
                fprintf(stderr, "[bin-bypass][x]: unrecoginzed EXT - \"%s\"\n", argv[3]);
                return 0;
            }
            switch(cmd_index){
                case 0:
                    printf("[bin-bypass][v]: splitting origin file\n");
                    printf("[bin-bypass][v]: EXT - \"%s\"\n", argv[3]);
                    open_file(argv[2]);
                    save_fragments(ext_index);
                    free_resources();
                    break;
                case 1:
                    printf("[bin-bypass][v]: building origin file\n");
                    printf("[bin-bypass][v]: EXT - will parse from info.txt\n");
                    load_fragments(argv[2]);
                    save_file();
                    free_resources();
                    break;
                default:
                    fprintf(stderr, "[bin-bypass][x]: unrecoginzed CMD - \"%s\"\n", argv[1]);
                    help_msg();
            }
        break;
        default:
            fprintf(stderr, "[bin-bypass][x]: syntax error\n");
            help_msg();
    }
    return 0;
}