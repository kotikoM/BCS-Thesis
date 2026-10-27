// chapters/runvm.typ
#import "@preview/codelst:2.0.2": sourcecode

= Basic OS-Support <chap:kernel>

== Overview


To support the execution of multiple _users'_ #h(0.2em) processes, we introduce a minimal operating‐system kernel, whose services should later also be deployed on FPGA board. This chapter presents kernel's implementation details, which comprises two primary components:

#set enum(indent: 1em)
  + _*bootloader*_ - detects _reset_ signal and fetches translated kernel code from disk. 
  
  + _*runvm*_ - kernel primitive for running _virtual user's_ code on _host_ with transparent handling of invalid page-fault interrupt.  
#set enum(indent: 0em)

For delivering _bootloader_, we reserve the starting portion of main memory -- _ROM_ and initialize it alongside with _bootloader's_ machine code. On power-up - or upon any interrupt signal -- control immediately switches to the _ROM_ region. We assume that _reset_ interrupt is raised only during the first hardware cycle. Once it is obtained, _bootloader_ fetches translated kernel code from disk into a fixed region of main memory and begins to execute it. If _reset_ is not detected -- indicating that kernel is already present -- _bootloader_ finishes execution with direct jump inside _runvm_ primitive. The latter saves current _user's_ process and handles transparently any subsequent invalid-page-fault interrupt.

#figure(
  image("../res/diag-bootloader.svg", width: 80%),
  caption: [Interrupt detection],
)<dig:bootloader>

Switching between _user_ and kernel modes requires saving and restoring each _user's_ configuration portions. Furthermore, _users'_ memory accesses must be translated through MMU. To support above, kernel usually provides globally defined data structures for its _users_. After fetching, kernel initializes each data block with corresponding values and then enters its main scheduling loop:

#set enum(indent: 1em)
  
  + select next _user_ process to run - via _scheduler_

  + restore respective _user's_ configuration and execute its code - via _runvm_.
  
#set enum(indent: 0em)

Only invalid‐page‐fault interrupt is handled within _runvm_. Normally, _dispatcher_ provides treatment for other interrupts. However, to keep kernel simple and remain focused on our goal - running multiple _users'_ processes on FPGA board, we consequently leave out _dispatcher_ from main loop (@code:kernel).


#figure(
sourcecode()[
```C
[...] // initialize data structures 
while true 
{
  scheduler();
  runvm()
}
    
```],
caption: [Kernel])<code:kernel>

The implementation details rely directly on the specifications given in Chapter 15 @sysarch. In the following sub-sections, we will cover only those parts that are essential for kernel programming. Detailed description of disk-access management is therefore omitted. To see a full treatment of it, refer to Chapter 14.3 @sysarch.
\
We begin this section by presenting kernel's core components: 
#set list(indent: 1em)

  - memory layout and initialization of data structures
  - simple _scheduler_ to support simulating more than a single _user's_ process, and 
  - description of _runvm_ primitive tasks.  


  
  
#set list(indent: 0em)

In the latter half, we go back to the _bootloader_, detailing its design and the major challenges encountered during its development.


== Basic Kernel: Technical Aspects
#figure(
  image("../res/diag-main-memory.svg", width: 40%),
  caption: [_main memory_ layout],
)<dig:main-memory>


Before diving into the design details below, we will first review the key technical decisions made for kernel programming. The entire kernel is written in "C0 + Assembly"  within a single program -  `AbstractKernel.c0`. This approach greatly simplifies build process - there is no need to generate code portions separately -  but it comes at the cost of generality. Because C0 does not support parameter-sized data structures, we are forced to use constant-sized structures and maintain extra global variables to track their lengths. At present, kernel is expected to simulate two different _user's_ tasks, anyone wishing to increase this number should explicitly modify - `AbstractKernel.c0`. 
\
Similar approach is exploited for _bootloader_ as well, both - `AbstractKernel.c0`, `FetchKernel.c0` appear in Appendix - @appendix:kernel-program, @appendix:kernel-fetch-program, alongside with the MIPS instructions used to initialize _ROM_ - `RPM.asm` - @appendix:ROM. 


== _Main Memory System_ Layout

To ensure that the _bootloader_, kernel, and _disk-access_ primitives share consistent memory map, we first define _host machine's_ memory system layout (see @dig:main-memory). Below, *$K$* defines the number of _words_ into a single page - 1024. 
\
The reserved regions are:
#set list(indent: 1em)

  - *_ROM_ - $[0 : 4K]$* - contains _bootloader_. At start-up, only _ROM_ is present.

  - *_scratch_ - $[4K : 8K]$* - used for saving and restoring register contents. (Chapter 15.5.1 @sysarch) 

  - *_kernel_ - $[12K : 20K]$* - holds two pages of translated kernel code - (1,629 MIPS instructions).

  - *_stack_ - $[24K : 32K]$* - allocates data structures and function frames for kernel. 

  - *_heap_ - $[36K : 40K]$* - reserved region for heap‐allocated variables inside kernel (current implementation does not utilize any dynamic heap variables). 

  - *_upbase_ - $[44K : 52K]$* - provides memory space, where _users'_ virtual pages are allocated on _host_ machine. Presently, it can hold only --- 2 pages. This region is accessed during _ipf_-page fault interrupt handling.

  - *_hd-ports_ - $[56K : 64K]$* - two pages mapped to disk-ports (Chapter 14.3 @sysarch).

#set list(indent: 0em)

Note that address ranges are given in bytes, and chosen so that each region is page aligned.

== Kernel Data Structures & Initialization

Having defined memory layout, we now begin to describe _kernel's_ core data structures - global variables and arrays allocated on _stack_. These structures are usually utilized to provide two major goals: 

#set enum(indent: 1em)

  + performing address translation and tracking virtual pages for each _user_
  
  + saving and restoring _user_ processes between switching modes.

#set enum(indent: 0em)

Below, we explain how these structures are used and show their initialization routine. For more details, see Appendix - @appendix:kernel-program.  

=== Address Translation Support

To enable _virtual users_ perform their corresponding memory accesses, address translation is required. Normally, each _user_ maps its virtual pages into _hosts_' physical memory, providing page tables. When page is not yet loaded in the table, _ipf_-page fault is raised (see Chapter 14.2 @sysarch). This interrupt is handled  transparently by _runvm_ primitive. 
\
For managing page tables, kernel consequently introduces two  global arrays:

#set list(indent: 1em)

 - _PTA_ - (flat page table array) comprising map of all _users'_ pages tables. 

 - _PTOI_ - (page table origin index) indicating for each _user_ the beginning of their page table map in _PTA_.  
 
 
#set list(indent: 0em)

#sourcecode[
    ```C
     typedef uint[PTASIZE] PTAt; // mapping of all users' virtual pages
     typedef uint[p+1] PTOIt; // size of p + 1 - for better indexing
     ...
     PTAt PTA; 
     PTOIt PTOI; 
  ```]

At present, maximum number of pages each _user_ can allocate is specified by global variable _PTL_, therefore - 
$
P T A S I Z E = p * P T L.
$
Since no virtual pages are loaded at startup, _PTA_ - array should be initialized with 0's. We don't provide any explicit C0 code portion for that, as it will implicitly be zero-initialized in the beginning of kernel's execution. 

As for _PTOI_ -- first _user_ should start its page table in the beginning of _PTA_, and any subsequent _user_ should continue after contiguous block of _PTL_ entries in the table. 


#figure(
sourcecode[
    ```C
     i = 1u;
     while i<p+1u {
          PTOI[i] = (i-1u)*PTL;
          i = i + 1u
     }; 
  ```])

=== Process Control Block

For storing _users'_  CPU configuration - both $g p r$, $s p r$ - on _host_ machine, we define global array of process control blocks - _PCB_.  

#sourcecode[
    ```C
     typedef uint[32] u; // gpr 
     typedef uint[8] v; // spr 
     typedef struct {u GPR; v SPR} pcb; // gpr + spr 
     typedef pcb[p+1] PCB_t; // for p - user and kernel
     ...
     PCB_t PCB;
  ```]

When restoring current _user_ process, kernel loads its saved registers from #raw(lang: "C", "PCB[CP]"). To guarantee correct control switching, we must initialize each - #raw(lang: "C", "PCB[i]") accordingly.  Below is the initialization loop for each _users'_ four key $s p r$:
#sourcecode[
      ```C
      i = 1u;
      while i<p+1u {
            PCB[i].SPR[1] = 4294967295u;
            PCB[i].SPR[3] = 0u;
            gpr(1) = PTA[PTOI[i]]&;
            PCB[i].SPR[5] = gpr(1);
            PCB[i].SPR[6] = PTL;
            i = i + 1u
      };
      ...
    ```]

#set list(indent: 1em)

 - $s p r (1)$ --- exception status register --- restores status of maskable interrupts. Initialized to all 1's,   as a result, maskable interrupts are not disabled by default.

 - $s p r (3)$ --- exception _pc_ --- specifies program counter, where _user_ should begin its execution. Set to 0 so that _user's_ program simulation starts at the beginning of its memory.

 - $s p r (5)$ --- page table origin --- indicates the beginning of _user's_ page table array portion inside _PTA_. Since _PTOI_ manages this, we would simply load the base address of - #raw(lang: "C", "PTA[PTOI[i]]&"). Note that to achieve this, mixed C0 syntax is needed, as type of #raw(lang: "C", "PCB[i].SPR[5]") is - _uint_.  
   
 - $s p r (6)$ --- page table length --- defines maximum number of _virtual pages_ that _user_ can allocate on _host_. Global variable _PTL_ fixes this value and $s p r (6)$ does not change after its initialization.    
  
  
#set list(indent: 0em)

Unlike data structures supporting address translation for _users_, an extra _PCB_ block is allocated for _host_. However, it is usually affected while switching between processes by _macros_ -- _restore-user_ and _save-user_, and therefore, does not require any further initialization. 
  
== Simple Scheduling Mechanism 


For scheduling, simple round-robin approach is used. During each iteration of infinite loop, scheduler selects current _user_  process. As long as _user_ continues running - or raises only invalid-page-fault interrupt - control goes back to it. Once they suspend, _scheduler_ advances to the next _user_.

#figure(
sourcecode[
    ```C
    void scheduler(){

        if (CP==p) {CP = 1u} else {CP = CP+1u} // arbitration
    };
  ```]
)

== Kernel Primitive -- _runvm_

#figure(
  image("../res/diag-runvm.svg", width: 70%),
  caption: [_runvm_ Primitive],
)<dig:runvm>

After scheduling current _user_ process - _CP_, control switches from kernel to _user_ via _runvm_ primitive, which additionally detects _ipf_-page fault and invokes _ipfHandler_ function to resolve it. This interrupt handling mechanism follows the direct specifications given in Chapter 15.6 @sysarch, without any further modifications. Thus, we would not include it here, its construction details can be seen in Appendix - @appendix:kernel-program.  
\
As it is depicted on @dig:runvm _runvm_ function's control flow consists of the following steps:
#set enum(indent: 1em)

  + Switch from kernel to _user_ in the beginning of _runvm_  -- _restore-user_. 

  + Saving a _user_ task and returning control to the kernel after detecting an interrupt - handled by  -  _save-user_

  + Testing after an interrupt whether an _ipf_-page fault has to be handled by _runvm_. Here, we generate explicit _ipf_ detection logic directly within _runvm_.

  + Transparent handling of _ipf_-page fault by function call _ipfHandler_. 

  + Process switch from kernel to _user_ after handling of an _ipf_-page-fault, achieved similarly with macro - _restore_.

  + Exit to the kernel after the suspension of _user_ code. 
 
  
#set enum(indent: 0em)

Note that, when switching modes, we need to ensure that the _virtual user's_ configuration - $g p r$, $s p r$ - can correctly be loaded to their physical counterparts. Consequently, in the beginning of restoring _user_ process, we first store the
base address of its process-control block - #raw(lang: "C", "PCB[CP]") into scratch memory. We accomplish this with the instruction:
#sourcecode()[
  ```C
    // Note that PCB[CP].GPR[0] and PCB[CP] share the same base address
    gpr(1) = PCB[CP].GPR[0]&;
    asm( sw 1 0 4K+4 ) // first instruction of macro - restore-user
    ...
  ```
]
Since the translation of first statement depends on the kernel's current configuration, we leave out it from the _restore-user_ macro and provide explicitly inside the _runvm_ primitive. For full details, see @code:runvm.

#figure(
sourcecode()[
```C
void runvm(){
        // initialize register 1 to restore correct user - CP
        gpr(1) = PCB[CP].GPR[0]&; 
        asm( macro: restore-user ); // macro - restore
        asm( macro: save-user ); // macro - save 

        // ipf-page fault detection
        IL = 0u;
        i = 1u;
        found = 0u;
        while found==0u {
                IL = IL+1u;
                i = 2u*i;
                gpr(1) = i;
                gpr(2) = PCB[CP].SPR[2] {1};
                asm( and 3 1 2 );
                found = gpr(3)
        };

        EVA = 0u;
        if IL==17u {EVA = PCB[CP].SPR[3]};
        if IL==20u {EVA = PCB[CP].SPR[4]};

        gpr(1) = EVA;
        asm( srl 1 1 12 );
        EVPX = gpr(1);
        ptle = (EVPX>=PCB[CP].SPR[6]);
        ipf = (IL==17u||IL==20u)&&!(bool)ptle;
        // in case ipf-page fault, handle it, restore user. 
        if (bool)ipf {
            ipfHandler(); 
            gpr(1) = PCB[CP].GPR[0]&; 
            asm( macro: restore-user )
          } 
};
...  
```],
caption: [Primitive - _runvm_])<code:runvm>

== Bootloader


We conclude this chapter by outlining _bootloader's_ primary objective and the challenges we faced. Upon any interrupt, control is immediately given to the ROM region, where _bootloader_ inspects the interrupt type. If _reset_ is detected, it loads the translated kernel code from disk and then transfers control to the kernel to begin execution. If no _reset_ is present - indicating the kernel is already in place - _bootloader_ jumps directly to the middle of the _runvm_ primitive, which saves _user_ configuration and continues to monitor for invalid-page-fault interrupts. For more details, see Chapter 15.5.6 @sysarch


#sourcecode()[
  ```ASM
    macro: ssave(1)
    movs2g 2 1
    andi 1 1 1
    blez 1 len(KernelFetch) + 2

    # Translation of KernelFetch C0 program 
    j _beginning of kernel

    macro: srestore(1)
    j _user save portion in runvm
    
    
  ```
]

=== Interrupt Signal Inspection


In order to detect whether _reset_ is raised or not, one should normally use _host's_ general purpose registers. We load exception-cause $s p r$ into - $g p r(1)$. However, since register $1$ may still hold a value from the previously running _user_ -- and that value is not yet saved in #raw(lang :"C", "PCB[CP]") -- we must save it first on _scratch_ memory. On startup, when no _user_ process exists, $g p r(1)$ contains no meaningful data, so we only restore it, if _reset_ not is detected.

=== Fetching Kernel Code

After observing _reset_, it start execution of program - `FetchKernel.c0`. It is written in "C0 + Assembly" to load kernel code from disk into predetermined region on _host's_ memory layout (@dig:main-memory). Although `FetchKernel.c0` uses _host stack_ for its own function call frames and variables, it runs only once at startup when there is no kernel loaded and therefore, does not alter the kernel's configuration and its data structures. The entire description of this program is in Appendix - @appendix:kernel-fetch-program. 

#figure(
sourcecode()[
  ```C
        SPX = 0u;
        PPX = a/4096u;
        L = (b-a+4u)/4096u;

        while L>0u {
              readdisk(PPX, SPX);
              SPX = SPX + 1u;
              PPX = PPX + 1u;
              L = L-1u
        };
  ```
], caption: [Loading kernel code],
)<code:fetch-kernel>

At boot time, kernel is expected to be stored in the beginning of _swap memory_ (disk) and is fetched one page at a time into the region - *$[a : b]$* (see @code:fetch-kernel). Local variables -- #raw(lang: "C", "SPX,PPX") are initialized with the starting page of disk and *$[a : b]$* region, respectively. In this case, it is essential that both *$a, b$* are page aligned (@dig:main-memory).

Note that standard C0 programs usually end with _return_ statement, we get it rid of it here, when translating from C0 to MIPS code, and instead of generating _syscall_ instruction accordingly, execution continues with jump to the beginning of kernel. For full MIPS code that initializes _ROM_ see Appendix - @appendix:ROM

=== Adjusting Jump Lengths 

As specified in @mips-isa-overview our MIPS provides _pc_ relative jumps. Therefore, to generate - #raw(lang: "ASM", "j") instruction into predetermined address, we should take into consideration the current value of _pc_.

Consequently, at the end of kernel-loading routine - rather than jumping into *_a_*, we explicitly evaluate current _pc_ and specify offset as: *$a - p c$*.

The similar approach of offset computation is used for jumping inside the _runvm_ primitive, with one additional step - we are manually looking for the statement *$gamma$ -  _macro: save-user_* (see @dig:runvm) in _runvm_ and use it as a target address. 