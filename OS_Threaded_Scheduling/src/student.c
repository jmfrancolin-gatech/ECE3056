/*
 * student.c
 * Multithreaded OS Simulation for ECE 3056
 *
 * This file contains the CPU scheduler for the simulation.
 *
 * @author Joao Matheus Nascimento Francolin
 */

#include <assert.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

#include "os-sim.h"

/** Function prototypes **/
extern void idle(unsigned int cpu_id);
extern void preempt(unsigned int cpu_id);
extern void yield(unsigned int cpu_id);
extern void terminate(unsigned int cpu_id);
extern void wake_up(pcb_t *process);

static void push_to_queue(pcb_t *pcb);
static pcb_t* pop_from_queue();


/*
 * current[] is an array of pointers to the currently running processes.
 * There is one array element corresponding to each CPU in the simulation.
 *
 * current[] should be updated by schedule() each time a process is scheduled
 * on a CPU.  Since the current[] array is accessed by multiple threads, you
 * will need to use a mutex to protect it.  current_mutex has been provided
 * for your use.
 */
static pcb_t **current;
static pthread_mutex_t current_mutex;
static pcb_t *head;
static pthread_mutex_t ready_mutex;
static pthread_cond_t not_idle;

static int time_slice;
static int cpu_count;
static char scheduling_alg;

/*
 * schedule() is your CPU scheduler.  It should perform the following tasks:
 *
 *   1. Select and remove a runnable process from your ready queue which
 *	you will have to implement with a linked list or something of the sort.
 *
 *   2. Set the process state to RUNNING
 *
 *   3. Call context_switch(), to tell the simulator which process to execute
 *      next on the CPU.  If no process is runnable, call context_switch()
 *      with a pointer to NULL to select the idle process.
 *	The current array (see above) is how you access the currently running process indexed by the cpu id.
 *	See above for full description.
 *	context_switch() is prototyped in os-sim.h. Look there for more information
 *	about it and its parameters.
 */

static void schedule(unsigned int cpu_id)
{
    pcb_t *pcb;
    pcb = pop_from_queue();

    if(pcb != NULL) {
        pcb->state = PROCESS_RUNNING;
    }
    pthread_mutex_lock(&current_mutex);
    current[cpu_id] = pcb;
    pthread_mutex_unlock(&current_mutex);
    context_switch(cpu_id, pcb, time_slice);
}

static void push_to_queue(pcb_t *pcb)
{
    pcb_t *curr;
    pthread_mutex_lock(&ready_mutex);
    curr = head;
    if(curr == NULL) {
        head = pcb;
    }
    else {
        while(curr->next != NULL) {
           curr = curr->next;
        }
        curr->next = pcb;
    }
    pcb->next = NULL;
    pthread_cond_broadcast(&not_idle);
    pthread_mutex_unlock(&ready_mutex);
}

static pcb_t* pop_from_queue()
{
    pcb_t *node;
    pcb_t *curr;
    pcb_t *prev;

    int high = 0;
    switch (scheduling_alg){

        // LRTF
        case 'l':
            pthread_mutex_lock(&ready_mutex);
            if(head == NULL) {
                node = NULL;
            }
            else {
                curr = head;
                while(curr != NULL) {
                    if(curr->time_remaining > high) {
                        high = curr->time_remaining;
                    }
                    curr = curr->next;
                }
                curr = head;
                prev = head;
                while(curr != NULL) {
                    if(curr->time_remaining == high) {
                        node = curr;
                        if(curr==head) {
                            head = curr->next;
                        }
                        else {
                            prev->next = curr->next;
                        }
                        break;
                    }
                    prev = curr;
                    curr = curr->next;
                }
            }
            pthread_mutex_unlock(&ready_mutex);
            return node;
            break;

        // FIFO or Round-Robin
        default:

            pthread_mutex_lock(&ready_mutex);
            node = head;
            if(node != NULL) {
                head = node->next;
            }
            pthread_mutex_unlock(&ready_mutex);
            return node;
    }
}

/*
 * idle() is your idle process.  It is called by the simulator when the idle
 * process is scheduled.
 *
 * This function should block until a process is added to your ready queue.
 * It should then call schedule() to select the process to run on the CPU.
 */
extern void idle(unsigned int cpu_id)
{
    pthread_mutex_lock(&ready_mutex);

    while(head==NULL){
        pthread_cond_wait(&not_idle,&ready_mutex);
    }

    pthread_mutex_unlock(&ready_mutex);
    schedule(cpu_id);
}

/*
 * preempt() is the handler called by the simulator when a process is
 * preempted due to its timeslice expiring.
 *
 * This function should place the currently running process back in the
 * ready queue, and call schedule() to select a new runnable process.
 */
extern void preempt(unsigned int cpu_id)
{
    pcb_t* pcb;
    pthread_mutex_lock(&current_mutex);
    pcb = current[cpu_id];
    pcb->state = PROCESS_READY;
    pthread_mutex_unlock(&current_mutex);
    push_to_queue(pcb);
    schedule(cpu_id);
}


/*
 * yield() is the handler called by the simulator when a process yields the
 * CPU to perform an I/O request.
 *
 * It should mark the process as WAITING, then call schedule() to select
 * a new process for the CPU.
 */
extern void yield(unsigned int cpu_id)
{
    pcb_t *pcb;
    pthread_mutex_lock(&current_mutex);
    pcb = current[cpu_id];
    pcb->state = PROCESS_WAITING;
    pthread_mutex_unlock(&current_mutex);
    schedule(cpu_id);
}


/*
 * terminate() is the handler called by the simulator when a process completes.
 * It should mark the process as terminated, then call schedule() to select
 * a new process for the CPU.
 */
extern void terminate(unsigned int cpu_id)
{
    pcb_t *pcb;
    pthread_mutex_lock(&current_mutex);
    pcb = current[cpu_id];
    pcb->state = PROCESS_TERMINATED;
    pthread_mutex_unlock(&current_mutex);
    schedule(cpu_id);
}


/*
 * wake_up() is the handler called by the simulator when a process's I/O
 * request completes.  It should perform the following tasks:
 *
 *   1. Mark the process as READY, and insert it into the ready queue.
 *
 *   2. If the scheduling algorithm is LRTF, wake_up() may need
 *      to preempt the CPU with lower remaining time left to allow it to
 *      execute the process which just woke up with higher reimaing time.
 * 	However, if any CPU is currently running idle,
* 	or all of the CPUs are running processes
 *      with a higher remaining time left than the one which just woke up, wake_up()
 *      should not preempt any CPUs.
 *	To preempt a process, use force_preempt(). Look in os-sim.h for
 * 	its prototype and the parameters it takes in.
 */
extern void wake_up(pcb_t *process)
{
    int low;
    int low_id;

    process->state = PROCESS_READY;
    push_to_queue(process);

    if(scheduling_alg == 'l') {
        pthread_mutex_lock(&current_mutex);
        low_id = -1;
        low = 10;
        for(int i = 0; i < cpu_count; i++) {
                if(current[i] == NULL) {
                    low_id = -1;
                    break;
                }
                if(current[i]->time_remaining < low) {
                    low = current[i]->time_remaining;
                    low_id = i;
                }
        }
        pthread_mutex_unlock(&current_mutex);
        if(low_id != -1 && low < process->time_remaining) {
            force_preempt(low_id);
        }
    }
}

/*
 * main() simply parses command line arguments, then calls start_simulator().
 * You will need to modify it to support the -l and -r command-line parameters.
 */
int main(int argc, char *argv[])
{
    if (argc < 1 || argc > 4)
    {
        fprintf(stderr, "ECE 3056 OS Sim -- Multithreaded OS Simulator\n"
            "Usage: ./os-sim <# CPUs> [ -l | -r <time slice> ]\n"
            "    Default : FIFO Scheduler\n"
	        "         -l : Longest Remaining Time First Scheduler\n"
            "         -r : Round-Robin Scheduler\n\n");
        return -1;
    }

    unsigned int cpu_count;
    cpu_count = strtoul(argv[1], NULL, 0);
    time_slice = -1;

    for(int i = 0; i < argc; i++) {

        if(strcmp(argv[i],"-r") == 0){
            scheduling_alg = 'r';
            time_slice = atoi(argv[i + 1]);
        }
        else if(strcmp(argv[i],"-l") == 0){
            scheduling_alg = 'l';
        }
        else {
            scheduling_alg = 'f';
        }
    }

    current = malloc(sizeof(pcb_t*) * cpu_count);
    assert(current != NULL);
    pthread_mutex_init(&current_mutex, NULL);

    head = NULL;
    pthread_mutex_init(&ready_mutex, NULL);
    pthread_cond_init(&not_idle, NULL);

    start_simulator(cpu_count);
    return 0;
}
