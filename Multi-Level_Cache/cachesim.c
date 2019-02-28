#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <math.h>
#include "cachesim.h"

l2_cache_struct *l2_cache;
l1_cache_struct *i_cache;
l1_cache_struct *d_cache;

counter_t accesses = 0, hits = 0, misses = 0, writebacks = 0;
counter_t d_hit = 0, d_miss = 0, i_hit = 0, i_miss = 0, l2_hit = 0, l2_miss = 0;

// l2 cache variables
unsigned int l2_offset_size, l2_index_size, l2_tag_size, l2_index_max, max_LRU;
// l1 cache variables
unsigned int l1_offset_size, l1_index_size, l1_tag_size, l1_index_max;

counter_t write_miss = 0, write_count = 0, read_count = 0, fetch_count = 0;

// Initialize caches to 0's and -1 for invalid
void cachesim_init(int l2_blocksize, int l2_cachesize, int l2_ways)
{
    // L2 CACHE
    l2_index_max = l2_cachesize / (l2_blocksize * l2_ways);
    l2_index_size = (unsigned int) log2(l2_index_max);
    l2_offset_size = (unsigned int) log2(l2_blocksize);
    l2_tag_size = (unsigned int) (64 - l2_index_size - l2_offset_size);

    // L1 CACHE
    l1_index_max = 256;
    l1_index_size = log2(l1_index_max);
    l1_offset_size = log2(64);
    l1_tag_size = (64 - l1_index_size - l1_offset_size);

    // allocate space for array of structs 
    l2_cache = malloc(l2_index_max * sizeof(l2_cache_struct));
    i_cache = malloc(l1_index_max * sizeof(l1_cache_struct));
    d_cache = malloc(l1_index_max * sizeof(l1_cache_struct));

    // make ways "public" in order to implement LRU
    max_LRU = l2_ways;
    
    // initialize l2_cache array of structs
    for (int i = 0; i < l2_index_max; i++) {
        for (int j = 0; j < 128; j++) {
            if (j < l2_ways) {
                l2_cache[i].tag[j] = 0;
                l2_cache[i].validBit[j] = 0;
                l2_cache[i].dirtyBit[j] = 0;
                l2_cache[i].LRU_counter[j] = j;
            }
            else {
                l2_cache[i].tag[j] = -1;
                l2_cache[i].validBit[j] = -1;
                l2_cache[i].dirtyBit[j] = -1;
                l2_cache[i].LRU_counter[j] = -1;
            }
        }
    }
    
    // initialize i_cache & d_cache array of structs
    for (int i = 0; i < 256; i++) {
        i_cache[i].tag = 0;
        i_cache[i].validBit = 0;
        i_cache[i].dirtyBit = 0;

        d_cache[i].tag = 0;
        d_cache[i].validBit = 0;
        d_cache[i].dirtyBit = 0;
    }
}

// l1_cache
void l1_cachesim_access(addr_t physical_addr, char input)
{

    // L1 CACHE
    addr_t l1_set =  physical_addr << l1_tag_size;
    l1_set = l1_set >> l1_tag_size;
    addr_t l1_tag = physical_addr >> (l1_index_size + l1_offset_size);
    addr_t l1_index = l1_set >> l1_offset_size;

    // accesses
    accesses++;

    // check data cache
    if (input == 'w' || input == 'r')
    {
        if (d_cache[l1_index].tag == l1_tag)
        {
            d_hit++;

            // instruction to be written is already there
            if (input == 'w')
            d_cache[l1_index].dirtyBit = 1;

            // instruction to be read is already there
            // it is implided thta input == 'r'
        }
        else
        {
            d_miss++;
            // check into l2 ()
            l2_cachesim_access(physical_addr, input);

            // increment write_back and reset dirtybit to 0
            if (d_cache[l1_index].dirtyBit == 1)
            {
                //writebacks++;
                d_cache[l1_index].dirtyBit = 0;
            }
        
            // update tag
            d_cache[l1_index].tag = l1_tag;
            
            // update valid bit
            d_cache[l1_index].validBit = 1;
            
            // set dirty to 1 and incremment write_miss
            if (input == 'w')
            {
                d_cache[l1_index].dirtyBit = 1;
                //write_miss++;
            } 
        }
    }
    // check instruction cache
    else if (input == 'i')
    {
        if (i_cache[l1_index].tag == l1_tag)
        {
            i_hit++;
        }
        else
        {
            i_miss++;
            // check into l2 ()
            l2_cachesim_access(physical_addr, input);

            // increment write_back and reset dirtybit to 0
            if (i_cache[l1_index].dirtyBit == 1)
            {
                //writebacks++;
                i_cache[l1_index].dirtyBit = 0;
            }
        
            // update tag
            i_cache[l1_index].tag = l1_tag;
            
            // update valid bit
            i_cache[l1_index].validBit = 1;
            
            // set dirty to 1 and incremment write_miss
            if (input == 'w')
            {
                i_cache[l1_index].dirtyBit = 1;
                //write_miss++;
            } 
        }

    }
}

// l2 cache
void l2_cachesim_access(addr_t physical_addr, char input)
{
    // get set
    addr_t set =  physical_addr << l2_tag_size;
    set = set >> l2_tag_size;
    // get tag
    addr_t tag = physical_addr >> (l2_index_size + l2_offset_size);
    // get index
    addr_t index = set >> l2_offset_size;
     
    // accesses
    accesses++;
    if (input == 'w')
    write_count++;

    // condition for hit
    int block_index = check_tag_and_validBit(l2_cache[index], tag);
       
    // hit
    if (block_index != -1) {
        
        l2_hit++;

        // set dirty bit to 1
        if (input == 'w')
        l2_cache[index].dirtyBit[block_index] = 1;
    }
    // miss
    else {
        l2_miss++;
        block_index = get_LRU_index(l2_cache[index]);
       
        // increment write_back and reset dirtybit to 0
        if (l2_cache[index].dirtyBit[block_index] == 1) {
            writebacks++;
            l2_cache[index].dirtyBit[block_index] = 0;
        }

        // update tag
        l2_cache[index].tag[block_index] = tag;
        
        // update valid bit
        l2_cache[index].validBit[block_index] = 1;
        
        // set dirty to 1 and incremment write_miss
        if (input == 'w') {
            l2_cache[index].dirtyBit[block_index] = 1;
            write_miss++;
        }
    }

    // set LRU counter
    for (int i = 0; i < 128; i++) {     
        if (l2_cache[index].LRU_counter[i] != -1) {
            if (l2_cache[index].LRU_counter[i] > l2_cache[index].LRU_counter[block_index]) {
            l2_cache[index].LRU_counter[i]--;
            }
        }
    }
    l2_cache[index].LRU_counter[block_index] = max_LRU - 1;
}

// loop over LRU array to find 0
int get_LRU_index(l2_cache_struct cache) {

    for (int i = 0; i < 128; i++) {
        if (cache.LRU_counter[i] == 0)
        return i;
    }
    return -1;
}

// tag if the tags match and valid bit
int check_tag_and_validBit(l2_cache_struct cache, addr_t tag) {
    
    for (int i = 0; i < 128; i++) {
        if (cache.tag[i] != -1 && cache.validBit[i] && cache.tag[i] == tag)
        return i;
    }
    return -1;
}

// prinf function
void cachesim_print_stats() {
    
    //FILE *fp;
    //fp = fopen("part 2.cvs", "a");

    //fprintf(fp, "%llu, %llu, %llu, %llu, %llu, %llu\n", accesses, hits, misses,
    //writebacks, write_miss, write_count);
    //fclose(fp);
    //printf("%llu, %llu, %llu, %llu\n", accesses, hits, misses, writebacks);
    
    printf("access\t= %llu\n", accesses);
    printf("d_hit\t= %llu\td_miss\t= %llu\n", d_hit, d_miss);
    printf("i_hit\t= %llu\ti_miss\t= %llu\n", i_hit, i_miss);
    printf("l2_hit\t= %llu\t\tl2_miss\t= %llu\n", l2_hit, l2_miss);

    printf("D miss rate\t=\t%f\n", (double) d_miss / (double) (d_miss + d_hit));
    printf("I miss rate\t=\t%f\n", (double) i_miss / (double) (i_miss + i_hit));
    printf("L2 miss rate\t=\t%f\n", (double) l2_miss / (double) (l2_miss + l2_hit));
    printf("Glob miss rate\t=\t%f\n", (double) l2_miss / (double) (d_miss + i_miss + l2_hit));
}
