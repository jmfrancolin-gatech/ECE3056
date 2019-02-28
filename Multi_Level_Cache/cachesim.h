#ifndef __CACHESIM_H
#define __CACHESIM_H

#include <stdbool.h>

typedef unsigned long long addr_t;
typedef unsigned long long counter_t;

typedef struct {
    addr_t tag[128];
    int validBit[128];
    int dirtyBit[128];
    int LRU_counter[128];
} l2_cache_struct;

typedef struct {
    addr_t tag;
    int validBit;
    int dirtyBit;
} l1_cache_struct;



void cachesim_init(int, int, int);
void l1_cachesim_access(addr_t, char);
void l2_cachesim_access(addr_t, char);
int check_hit_l1_cache(l1_cache_struct, addr_t);
int check_hit_l2_cache(l2_cache_struct, addr_t);
int get_LRU_index(l2_cache_struct);
void cachesim_print_stats(void);

int get_LRU_index(l2_cache_struct);
int check_tag_and_validBit(l2_cache_struct cache, addr_t tag);


#endif
