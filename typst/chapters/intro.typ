// chapters/intro.typ
#show link: underline
= Introduction

== Overview

Thesis covers two things: a toolchain that compiles C0 code down to bytecode and a basic operating system kernel that runs the resulting programs on target FPGA board. The C0 language borrows C's syntax but follows the semantics of FreePascal. The language is formally defined by a context-free grammar, as detailed in System Architecture: An Ordinary Engineering Discipline @sysarch. This grammar is illustrated in Appendix  @dig:c0-grammar.

Our work began with an existing C0 compiler and parser project developed at Kutaisi International University, by Toma Pirtskhelani and Irakli Khotchava @compthesis, which could take C0 source code and produce MIPS assembly. We utilized its core components: lexical analysis, parsing, and initial code generation and used them as a base for our extensions.

One of the first things we added was an assembler that takes MIPS instructions and converts them into byte format our target machine expects.

Writing an OS kernel in plain C0 turned out to be impossible. The language had no way to touch registers directly or drop into raw assembly when needed. So we extended the grammar and parser to support both. The result is what we call "C0 + Assembly", which adds inline assembly and direct register access to the language. We also added support for void function declarations. The extended language still parses as $L R(1)$ language., which we verified.


As the project evolved into a multi-layered system, testing and debugging became a significant difficulty. To facilitate this process, we implemented a basic MIPS simulator. This tool proved invaluable for testing the translation process from C0 to bytecode and for identifying bugs in the assembly generation phase. It is important to note that the simulator's purpose is to aid in debugging the translation pipeline, not to formally verify the correctness of the generated code.


Finally, to achieve the ultimate goal -- simulating several _users'_ programs on FPGA board -- we've implemented core OS services that are capable of being simulated on the hardware supporting - _Disk accesses, Interrupts and MMU_. At present, we are unable to test these services on the actual board, as the corresponding hardware designs were not finalized early enough. Our implementation focuses on two critical components: a _bootloader_, which handles the correct detection of a _reset_ signal and loads the translated kernel code from disk, and a virtual machine runner (_runvm_), which manages virtual users and provides transparent handling of invalid-page-fault interrupts. See @appendix:kernel-program.


The remainder of this thesis details the components of our system. @chap:assembler addresses the MIPS-to-bytecode assembler. @chap:c0 steps back to describe the critical modifications to the C0 compiler, which resulted in the "C0 + Assembly" dialect used for kernel development. To support this multi-stage translation, @chap:simulator introduces the MIPS simulator built for debugging and validation. Finally, @chap:kernel  presents the design and implementation of the operating system kernel, focusing on the _bootloader_ and _runvm_ component that brings all previous parts together.

The entire implementation of project, written in Java, is accesible on 
#link("https://github.com/System-Architecture-WJP/WARS/tree/labels-simulator-kernel-compiler")[
  GitHub.
]

== Author Contributions

The development of this project was a collaborative effort, with primary responsibilities for the core components and corresponding thesis chapters distributed as follows:
- @chap:assembler focusing on the MIPS assembler is done by Mirian Shilakadze.
- @chap:c0 and @chap:kernel focusing on compiler modifications and kernel is done by Mikheili Kvinikadze.
- @chap:simulator focusing on instruction simulation is done by Konstantine Machavariani.

