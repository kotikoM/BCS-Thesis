#import "@preview/codelst:2.0.2": sourcecode

= Assembler <chap:assembler>
This chapter presents the implementation of the MIPS assembler. Our objective was to develop an assembler capable of translating assembly code to binary in a single pass, while minimizing memory usage. To achieve this, we aimed to emit the binary representation of each instruction to the output file as early as possible, thereby avoiding the need to store intermediate results in memory.

== Assembler Input
The input to our assembler is a file (or stream) containing an assembly program written in our custom syntax. An example of such program is shown in @mips-examp. 

#figure(
sourcecode()[
```asm
macro: gpr(30) = enc(10240, uint)
macro: gpr(28) = enc(5120, uint)
addiu 29 28 16
subu 1 29 28
srl 1 1 2
macro: zero(28, 1)
macro: gpr(28) = enc(5120, uint)
j _main

_main:
addi 1 28 0
macro: gpr(2) = enc(2, int)
sw 2 1 0
addi 1 28 4
macro: gpr(2) = enc(10, int)
sw 2 1 0
addi 1 29 0
addi 1 1 -9216
blez 1 4
macro: gpr(1) = enc(41, uint)
sysc
addi 29 29 4
jal _swap
macro: gpr(1) = enc(1, int)
sysc

_swap:
sw 31 29 -4
addi 1 28 0
lw 1 1 0
addi 29 29 -4
jr 1
```
],
caption: [Example of an assembler input]
)<mips-examp>
Each non‑blank line in the source is one of three forms:
1. *Instruction*: as defined in _Assembler Syntax_ section of @I-Table, @R-Table, @J-Table with the addition of *J-type* instructions that can take labels as operands (e.g. ```asm j _main```), in which case the jump target is the address marked by that label.
2. *Macro invocation*: use of a predefined pseudo‑operation (e.g. ```asm macro: gpr(28) = enc(5120, uint)```), expanded inline to one or more real instructions.
3. *Label definition*: an identifier given by regular expression ``` $_[A-Za-z]:^``` (e.g. ```asm _main:``` or ```asm _swap:```) that marks the address of the very next instruction or macro invocation.

== Assembler Implementation
The assembler processes the input one line at a time, emitting the corresponding bytecode as early as possible. As described previously, each non-blank line in the input falls into one of three categories, and the assembler handles each form differently:
1. *Instructions*: For this form, the bytecode can typically be emitted immediately. The only exceptions involve interactions with label definitions and references, which are discussed in @chap:assem-labels.\
  To support efficient opcode lookup, operand parsing, and argument ordering, without resorting to large `switch` statements, we use an `InstructionRegistry` implemented using the factory pattern. This design allows each instruction format to be registered declaratively. When the assembler encounters an instruction, it queries the registry to retrieve the corresponding encoder, syntax, and parsing rules. Implementation are provided in the appendix (@appendix:mips-isa).
2. *Macro Invocation*: Each macro invocation is expanded into one or more internal instruction objects (`Instruction` class shown in @fig:inst), which are then handled exactly like ordinary instructions, including any necessary delays for label resolution, before bytecode emission. More on them in @chap:assem-macros.
3. *Label definition*: When the assembler encounters a label definition, its current bytecode offset is recorded to be used for future *J-type* instructions. If the label was previously used, all pending instructions waiting on it are now resolved and emitted. Further details on labels are given in @chap:assem-labels.

=== Labels <chap:assem-labels>
A key challenge in assembler implementation of labels is handling _forward references_, where a label is used as an operand before its definition. In such cases, neither the machine code for that instruction nor for any subsequent instructions can be emitted until the label’s address has been resolved. Consider the assembly code in @mips-forw-examp.
#figure(
sourcecode()[
```asm
j _loop       # forward‐refers to _loop
addi 2 2 1    # also deferred until _loop is known

_loop:
subu 3 3 3
jr 31
```
],
caption: [Example of a label forward reference]
)<mips-forw-examp>
Since the assembler processes input in a single, line‑by‑line pass, it cannot emit the machine code for 
```asm j _loop``` as ```asm _loop``` is not defined yet. We call any such instruction _unresolved_. Since output machine code is streamed in order, the very next instruction ```asm addi 2 2 1``` must also be deferred until its predecessor is resolved. This chain of deferral continues for every instruction that follows, up to the point where the assembler finally encounters ```asm _loop:```, at that moment, it records the label’s byte‑offset, resolved jump and emits all the pending instructions.

For labels that are defined before their use, however, any jump referring to them is marked resolved immediately and its machine code is emitted on the spot.

To implement this deferral logic, we introduced an instruction queue in the assembler. Every instruction (whether coming directly from source or expanded from a macro) is enqueued before any emission is attempted. After processing each input line, we invoke a drain routine that walks the queue, emitting all instructions whose labels have now been resolved. In pseudocode, the drain function is given in @drain-fun.
#figure(
sourcecode(
  lang: "java",
  ```
  FUNCTION drainInstructions():
    // 1. Attempt to emit as many resolved instructions as possible
    WHILE queue IS NOT EMPTY:
      instr = queue.PEEK()
      // 2. If the next instruction is still waiting on a label, stop
      IF NOT instr.isResolved():
        BREAK
      END IF
      // 3. Remove and emit the resolved instruction
      queue.POP()
      emit(instr)
    END WHILE

  // 4. Any remaining instructions in the queue are still unresolved
  END FUNCTION
  ```
),
caption: [Instruction queue drain function]
) <drain-fun>

=== Macros <chap:assem-macros>

Macros provide reusable MIPS code snippets which can be accessed as a single instruction anywhere in assembly. It is generally exploited to encapsulate repetitive tasks such as --- software division, multiplication, constant evaluation, etc. At translation time, each macro is expanded into its underlying instruction set, keeping the source assembly code concise and readable, while generating the full instruction sequence in the bytecode. 
\
Below, we define a few key macros, their specification details are covered in Chapter 9.1 @sysarch:

  - #raw(lang: "C", "gpr(i) = enc(val, simple type)") -- used to evaluate constant values. 
  
  - #raw(lang: "C", "zero(i, j)") -- initializes $g p r (j)$ memory words starting from address $g p r (i)$. After completing this macro both registers -  _i_ and _j_ are modified.  
 
  - #raw(lang: "C", "mul(k, i, j)") -- encodes software multiplication of binary numbers specified by registers _i_ and _j_ and stores result in register _k_. Note that both signed and unsigned integer multiplication are supported by this macro.  
  
  - #raw(lang: "C", "divu(k, i, j)") -- provides unsigned integer division of binary numbers specified by registers _i_ and _j_. Consequently, result is stored in register _k_.  
  
  - #raw(lang: "C", "divt(k, i, j)") -- executes division of signed integer numbers, specifications follow $d i v u (k, i, j)$.   
  
Later for kernel programming, this list is extended with four new instructions.

 - #raw(lang: "C", "ssave(r)") -- stores register $i$ into its corresponding address in scratch memory (see Chapter 15.5. @sysarch).  

 - #raw(lang: "C", "srestore(r)") -- restores register $i$ from scratch memory (see Chapter 15.5.1 @sysarch).
 
 - #raw(lang: "asm", "restore-user") --  it restores current user process and its configuration, while saving host's portions accordingly (see Chapter 15.5.4 @sysarch).

 - #raw(lang: "asm", "save-user") -- Upon a failed _reset_ signal check, this macro saves current user process and restores host's configuration. (see Chapter 15.5.7 @sysarch) 

All these macro-expansion logic is included inside class -- `Macros.java`, which defines for each pseudo-instruction respective expansion into the underlying MIPS sequence.

#figure(
  grid(
    columns: (1fr, 1fr),
    column-gutter: 5em,
    sourcecode()[
    ```ASM
    macro: gpr(1) = enc(-1, int)
    ```],
    sourcecode()[
    ```ASM
    # lui 1 (upper half of -1)
    00111100000000011111111111111111 
    # ori 1 1 (lower half of -1)
    00110100001000011111111111111111    
    ```],
  ),
  caption: [Macro expansion],
) <macro-expansion>
