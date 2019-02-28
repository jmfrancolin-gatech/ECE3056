#include "paging.h"
#include "swapops.h"
#include "stats.h"

/*  --------------------------------- PROBLEM 6 --------------------------------------
    Page fault handler.

    When the CPU encounters an invalid address mapping in a page table,
    it invokes the OS via this handler.

    Your job is to put a mapping in place so that the translation can
    succeed. You can use free_frame() to make an available frame.
    Update the page table with the new frame, and don't forget
    to fill in the frame table.

    Lastly, you must fill your newly-mapped page with data. If the page
    has never mapped before, just zero the memory out. Otherwise, the
    data will have been swapped to the disk when the page was
    evicted. Call swap_read() to pull the data back in.

    HINTS:
         - You will need to use the global variable current_process when
           setting the frame table entry.

    ----------------------------------------------------------------------------------
 */
void page_fault(vaddr_t address) {
    /* First, split the faulting address and locate the page table entry */

    vpn_t vpn = vaddr_vpn(address);
    pte_t* entry = (pte_t*) (mem + (current_process -> saved_ptbr * PAGE_SIZE)) + vpn;

    /* It's a page fault, so the entry obviously won't be valid. Grab
       a frame to use by calling free_frame(). */
    
    pfn_t frame = free_frame();


    /* Update the page table entry. Make sure you set any relevant bits. */
    
    entry -> pfn = frame;
    entry -> valid = 1;
    entry -> dirty = 0;
    
    /* Update the frame table. Make sure you set any relevant bits. */

    frame_table[frame].mapped = 1;
    frame_table[frame].protected = 0;
    frame_table[frame].vpn = vpn;
    frame_table[frame].process = current_process;
    

    /* Initialize the page's memory. On a page fault, it is not enough
     * just to allocate a new frame. We must load in the old data from
     * disk into the frame. If there was no old data on disk, then
     * we need to clear out the memory (why?).
     *
     * 1) Get a pointer to the new frame in memory.
     * 2) If the page has swap set, then we need to load in data from memory
     *    using swap_read().
     * 3) Else, just clear the memory.
     *
     * Otherwise, zero the page's memory. If the page is later written
     * back, swap_write() will automatically allocate a swap entry.
     */
    
    fte_t* frame_pointer = (fte_t*) (mem + (frame * PAGE_SIZE));
    
    // if swap
    if (entry -> swap) {
        
        swap_read(entry, frame_pointer);
    }

    else {
        
        // for (int i = 0; i < PAGE_SIZE; i++) {  
        //     frame_pointer + i = 0;
        // }
        memset(frame_pointer, 0, PAGE_SIZE);
    }

    // update stats
    stats.page_faults++;
}
