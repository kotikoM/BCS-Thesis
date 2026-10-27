= Conclusion: Limitations & Future Work
== Overview

This thesis covers the design and implementation of a toolchain that takes C0 source code and produces executable MIPS bytecode, ending with a basic OS kernel that runs the result on hardware. The pipeline goes all the way from a high-level language down to a managed runtime.

The main things we built:

- An extension of the C0 compiler that adds a "C0 + Assembly" dialect, making kernel-level programming possible.
- A standalone MIPS assembler that handles forward-label references and macro expansion.
- A MIPS simulator with a demand-paged memory model, which turned out to be essential for debugging the translation pipeline.
- A basic OS kernel with a bootloader and a `runvm` primitive that can run virtual user processes and handle page-fault interrupts.

The full system was tested across a range of C0 programs and behaved correctly throughout.

== Limitations

A few limitations are worth noting, most of them caused by hardware and software development happening at the same time.

- *Hardware unavailability:* The OS kernel was never tested on the actual FPGA board. The hardware designs for disk access, interrupt handling, and the MMU were not finished in time, so those parts of the kernel could only be verified in simulation.
- *Simplified kernel services:* The kernel is intentionally minimal. Scheduling is round-robin, and only invalid-page-fault interrupts are handled.
- *Fixed-size kernel structures:* Several kernel data structures have fixed sizes due to constraints in C0. Adding support for more user processes would mean editing the kernel source by hand.

== Future Work

The most pressing next step is running the kernel on real hardware. That would put the disk I/O routines, the bootloader, and the interrupt handling under conditions the simulator cannot fully replicate.

Beyond that, the C0 compiler could be extended to cover more language features, and the assembler could be updated to recognize a wider set of standard MIPS pseudo-instructions, which would make it easier to use with existing MIPS code.