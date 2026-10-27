#align(center)[= Abstract]

This thesis presents the development of a complete toolchain that takes the C0 programming language code and compiles it into a custom bytecode format. Alongside this, we built a minimal operating system kernel to execute the resulting programs on an FPGA board. 

We started from an existing C0-to-MIPS compiler and extended it in several ways. First, we wrote standalone assembler that converts MIPS instructions into bytecode. We built a MIPS simulator to help with debugging. We extended the C0 grammar into a "C0 + Assembly" dialect, that adds inline assembly and direct register access to standard C0. These features are necessary for writing operating systems code. Extended language was kept within $italic("LR")(1)$ language class.

Furthermore, we achieved our major goal of implementing a basic OS-kernel. We implemented a _bootloader_ that reads translated kernel code from disk and loads it into memory. We wrote _runvm_ primitive capable of running virtual user's code and deals with page fault interrupts.

The end result result is a full pipeline. Code written "C0 + Assembly" goes through compiler then the assembler, gets loaded by _bootloader_ and runs under kernel on target hardware.

#v(1em)
#set par(first-line-indent: 0em)
Keywords: C0, compiler, MIPS, assembler, bytecode, simulator, bootloader, virtual machine, page fault, LR(1) grammar, FPGA, instruction set architecture. 