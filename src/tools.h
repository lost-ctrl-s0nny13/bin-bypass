#ifndef _TOOLS_H
#define _TOOLS_H

#include "config.h"

#ifdef _LINUX_BUILD
#define _FILE_OFFSET_BITS 64
#endif

#ifdef _WINDOWS_BUILD
#define _CRT_SECURE_NO_WARNINGS 1
#endif

//open_file
void open_file(const char*);
void save_fragments(char);
void free_resources();
//bypass_automod_simple - caesar_shift
void bypass_automod_simple(unsigned char*, char, size_t);
//load_fragments
void load_fragments(char*);
//inspect_file
//inspect_fragments
//split
//buildup
//save
void save_file();

#endif