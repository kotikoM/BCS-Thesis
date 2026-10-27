// chapters/simulator.typ
#import "@preview/codelst:2.0.2": sourcecode
= Simulator <chap:simulator>

This chapter covers the design and implementation of a single-cycle MIPS simulator. The simulator runs a defined subset of the MIPS ISA (@I-Table, @R-Table, @J-Table) and was built mainly as a debugging tool for verifying assembly programs during development. The behavior follows the ISA specification from Section 8.2 of "A Basic Sequential MIPS Machine" in @sysarch.

MIPS simulators already exist. MARS @mars is probably the most widely used one. But using a general-purpose tool would have created friction: differences in how instructions are handled, how pseudo-instructions get expanded, and how labels are written would all have caused problems specific to our setup. Building our own meant we could match the exact ISA subset and assembly syntax we were working with. It also forced a clearer understanding of how hardware state and instruction execution actually relate to each other, which mattered for the rest of the project.

The rest of this chapter walks through the state model of the simulated machine, how the core simulation loop works, how key instruction groups were implemented, and how we checked the simulator's correctness using example programs. All the relevant classes are grouped under a package called _simulator_.

== Architectural State Model
=== Configuration

The simulated machine's state is stored in a single structure called the `Configuration`. It holds everything an instruction can read from or write to at any point during execution. That means three things: the Program Counter, the General-Purpose Register file, and main Memory. These are shown in @dig:mipsdatastructures.

#figure(
  caption: [Visible data structures of MIPS ISA]
)[#image("../res/mips isa data structures.svg", width: 50%)]
<dig:mipsdatastructures>

In the Java implementation, these components live directly inside the `Configuration.java` class, which holds the full machine state throughout simulation.

#pagebreak()

#figure(
sourcecode[
  ```java
    public class Configuration {
        private long pc;
        private final int[] gpr;
        private final Map<Integer, byte[]> memoryPaged;
        private boolean isRunning;
    
        public Configuration() {
            this.pc = 0L;
            this.gpr = new int[32];
            this.memory = new HashMap<>();
            this.isRunning = true;
        }
    
        // ... methods for getting/setting state ...
    }
    ```
], caption: [`Configuration` java class])

The class fields directly correspond to the MIPS architecture. The `pc` field is implemented as a 64-bit `long` to correctly represent the full range of a 32-bit unsigned address, as Java lacks a native unsigned 32-bit integer type. The `gpr` field is an array of 32 integers, directly modeling the MIPS general-purpose register file; the constant value of register `zero` is maintained by ensuring that any write operation to index 0 is ignored. The most significant design choice, however, lies in the implementation of the main memory.

=== Paged Memory

Simulating a full 32-bit address space directly would mean allocating an array of $2^32$ entries, which is not practical. Instead, we used a sparse memory model built on a `java.util.HashMap<Integer, byte[]>` that only allocates memory when something is actually written to it.

The address space is split into fixed 4KB blocks called pages. The map acts as a page table, where each entry maps a page ID to a `byte[]` of 4096 bytes. A page only gets created the first time a program writes to an address inside it.

Any 32-bit address breaks into two parts: the upper 20 bits identify the page, and the lower 12 bits give the offset within that page's array. Reads and writes inside an already-allocated page are then just direct array accesses. If a read hits a page that was never written to, the simulator returns zero, which matches the behavior of zeroed physical memory without needing to pre-allocate anything.


=== Memory Access and Byte Ordering

MIPS is byte-addressable, but instructions like `lw` and `sw` work on 32-bit words. So the simulator needs to pack four bytes into a single word on reads, and unpack a word back into four bytes on writes. This is done in the `getWord` and `setWord` methods inside Configuration.

#figure(
sourcecode[
  ```java
    public int getWord(int address) {
        return  ((getByte(address) & 0xFF) << 24) |
                ((getByte(address + 1) & 0xFF) << 16) |
                ((getByte(address + 2) & 0xFF) << 8) |
                ( getByte(address + 3) & 0xFF);
    }

    public void setWord(int address, int value) {
        setByte(address,     (byte) ((value >>> 24) & 0xFF));
        setByte(address + 1, (byte) ((value >>> 16) & 0xFF));
        setByte(address + 2, (byte) ((value >>> 8) & 0xFF));
        setByte(address + 3, (byte) (value & 0xFF));
    }
    ```
], caption: [`getWord`, `setWord` methods])

The tricky part is Java's handling of signed bytes. In `getWord`, each byte gets masked with `& 0xFF` before being combined, otherwise Java sign-extends it when promoting it to an integer and the result comes out wrong. In `setWord`, the unsigned right-shift `>>>` is used instead of `>>` to pull out the right eight bits without dragging the sign bit along.

== Simulation Cycle

The simulator runs one instruction at a time through a loop that mimics the classic Fetch-Decode-Execute cycle. It keeps going until either the program runs out of instructions or a `syscall` tells it to stop.

Formally, the MIPS ISA can be described as a state transition function $delta$ that takes one machine configuration and produces the next, as defined in chapter 8.2.1 of @sysarch. Each instruction execution is a single step of that transition:

$
c' = delta(c, 0) \
c^(i+1) = delta(c_i, 0),
$

In the Java implementation, this is what `simulateStep` does. It takes the current `Configuration`, decodes and executes one instruction, and updates the state in place, directly implementing $delta$.

The simulation can be started in two ways: either by passing in raw bytecode, which gets loaded into a fresh configuration, or by handing it a configuration that already has a program loaded. The first approach looks like this:

#sourcecode(
  lang: "Java",
  ```
  FUNCTION simulate(program_bytecode):
    config = CREATE_NEW_CONFIGURATION()
    FOR i FROM 0 TO program_bytecode.length - 1:
      address = i * 4
      config.setWord(address, program_bytecode[i])
    END FOR
  
    WHILE config.isRunning() AND config.hasWordAt(config.getPC()):
      instruction_word = config.getWord(config.getPC())
      simulateStep(config, instruction_word)
    END WHILE
  
    RETURN config
  END FUNCTION
  ```
)
The *Fetch* phase reads the 32-bit instruction word at the address the Program Counter currently points to, matching the formal definition $I(c) = c.m_4(c."pc")$.

In the *Decode* phase, `simulateStep` extracts the 6-bit opcode from bits 31-26 of that word, as defined by $"opc"(c) = I(c)[31:26]$:

#sourcecode(
```java
    int opcode = (instructionWord >>> 26);
```
)

The opcode determines the instruction format. `simulateStep` acts as a dispatcher, routing to the right handler based on the predicates from @sysarch:

$
"rtype"(c) &equiv "opc" = 0\*0^4 \
"jtype"(c) &equiv "opc" = 0^4 1 \* \
"itype"(c) &equiv overline("rtype"(c) or "jtype"(c))
$\

#sourcecode(
```java
      void simulateStep(Configuration configuration, int instructionWord) {
        int opcode = (instructionWord >>> 26);

        if (opcode == 0b000000 || opcode == 0b010000) {
            simulateRType(configuration, opcode, instructionWord);
        } else if (opcode == 0b000010 || opcode == 0b000011) {
            simulateJType(configuration, opcode, instructionWord);
        } else {
            simulateIType(configuration, opcode, instructionWord);
        }
    }
```
)

Each handler then parses the remaining fields, things like `rs`, `rt`, `rd`, or an immediate value, according to the layouts in @inst-fields-fig. The general structure looks like this:

#sourcecode(
  lang: "java",
  ```
FUNCTION simulateSpecificType(config, opcode, instructionWord):
  operands = PARSE_OPERANDS(instructionWord)
  mnemonic = MnemonicUtils.getMnemonic(opcode, fun, ...)
  instruction = InstructionRegistry.getExecutableInstruction(mnemonic, operands)
  instruction.execute(config)
END FUNCTION
  ```
)

== Instruction Registry

The `InstructionRegistry` sits at the center of both the assembler and the simulator. It uses a map-based factory pattern, but keeps two separate maps: one that creates instruction objects for encoding (`encoderInstructionMap`), and one that creates objects for execution (`executableInstructionMap`).

Both maps are populated once at startup. For each mnemonic, say "add", two factory lambdas get registered. The first creates a basic instruction object the assembler uses to produce bytecode. The second creates an object that carries the actual simulation logic inside its `execute` method. When the simulator calls it, that method updates the `Configuration` state according to the ISA spec.

Keeping the two maps separate means the dispatch logic does not need to know anything about how individual instructions work. Adding a new instruction is just a matter of registering it in both maps. See @fig:registry.

== C0-Programs Simulation

Although we are unable to provide encoded abstract C0 configuration, correctness of large translation portions can still be checked with the simple simulator. Currently, we can fully simulate _virtual user_'s programs that do not access _disk_ and _special purpose registers_, nor lead to _interrupts_. Below, we briefly describe our methodology for validating translation.

After translating high-level program, we initialize memory component of configuration - $c. m$ with machine code. Note that, since both -  #raw(lang: "ASM", "j") and #raw(lang: "ASM", "jal") instruction performs _pc_ relative jumps, one may put _Bytecode_ anywhere in region -  $[a : b]$. Additionally, we also specify memory portion - _stack_ - for allocating global variables and function frames. For further details see -- `Simulator.java`
#figure(
sourcecode()[
  ```C 
  int a = 0; // Beginning of translated code 
  int b = 4 * K; // Code should fit into a single page (1024 words)

  int SBASE = 5 * K; // Beginning of stack
  int SMAX = 9 * K; // Size of the stack is also fixed with 1024 words

  int HBASE = 10 * K; // Beginning of heap
  int HMAX = 14 * K; // End of heap, total 1024 words as well.
  ```
], caption: [Simulator's configuration])
<code:simulator-configuration>
Correctness of the simulation relies on 2 key factors:
#set enum(indent: 1em)
 + values of variables defined in program, and  
 + status of $italic("gpr")(1)$ after completion of simulation. 
#set enum(indent: 0em)

We finish each testing program's _main_ function with _return_ 1. Consequently, its translation ends up with:
#figure(
sourcecode()[
  ```asm
  macro: gpr(1) = enc(1, int)
  syscall 
  ```
], caption: [Translation of _main_'s return])
<code:main-return>
In our simulator - #raw(lang: "ASM", "syscall") interrupt is used to complete execution. Once halted, we inspect $italic("gpr")(1)$ and selected global/local variables to deduce whether simulation was held correctly or not. By doing so, we are also able to validate independent translation regions.  


== Translation-to-Simulation: Challenges & Solutions

After enabling the simulation of actual C0 programs, we encountered several minor challenges. Although, the code generation strictly follows book specifications, simulation revealed existence of necessary adaptions to the compiler, that otherwise will fail simulation of programs.

=== Initialize Stack Pointers
To track stack pointers throughout code generation, it requires to precede each translated program with instructions that explicitly initializes stack, heap and base pointer registers respectively. Additionally, it also zero-initialize all global memory variables  - *_gm_*. 
For achieving the second goal, _macro_ zero is exploited. 
#figure(
sourcecode()[
  ```asm
  # gpr(28) - specifies base address
  # gpr(1) - number of words that assign 0.
  zero(28, 1) 
  ```
], caption: [Initialize _gm_ with Zeros])
<code:gm-initialize>

After executing this _macro_, register $g p r(28)$ no longer contains the original _sbase_ value, since the _zero_'s expansion overwrote it. Consequently, any subsequent access to global variables will use wrong base address. To prevent this, we insert an extra instruction immediately after zero‐initializing *_gm_* that restores $g p r (28)$ to its correct _sbase_ value. 

#figure(
sourcecode()[
  ```asm
  macro: gpr(30) = enc(hbase, uint)
  macro: gpr(28) = enc(sbase, uint)
  addiu 29 28 size($gm) + size($main) + 8
  
  subu 1 29 28
  srl 1 1 2
  macro: zero(28, 1)
  
  macro: gpr(28) = enc(sbase, uint)
  ```
], caption: [Initialize _gm_ and pointer registers])
<code:gm-initialize>

=== Function call 

Originally, _function-call_ generation first increments the stack pointer by the size of the function frame, and only then computes the base address of the return-destination variable and evaluates the arguments for the _function_. However, adjusting the stack pointer in the first place, disrupts later calculations — both arguments and the return destination rely on the original stack-pointer value. 

There are two intuitive solutions for that, we describe each of them, and explain the one we adopted to continue work with. 

#set enum(indent: 1em)
 + Re-order steps: evaluate arguments first and hold their values into registers, adjust stack-pointer and only after store previously evaluated arguments to the newly allocated function frame. In this scenario, maximum  number of arguments is limited 32 available registers.<function-call-2> 
 
 + Keep the original sequence, but instead modify the generation of _arguments_ by explicitly adjusting it to _old frame_. In this case one should  update -- `ExpressionEvaluation.java`.  
 
#set enum(indent: 0em)

We settled on solution #link(<function-call-2>)[(1)], as it merely changes the order of the steps without altering any code modules. 
On @code:function-call we describe generation according to @dig:function-call.
#figure(
sourcecode()[
  ```C
  // Return destination variables' base address computation
  code (n_0)

  // Evaluate arguments for all 1 <= y <= p
  code (n_y)

  // Adjust stack pointer 

  // Store base address on the stack frame
  sw j spt -($size(g) + 4)

  // Store each argument at its proper offset on the stack frame
  sw j_y spt -$size(g) + displ(e_y, $g)
  
  
  ```
], caption: [Function call])
<code:function-call>


#figure(
  image("../res/diag-function-call.svg", width: 60%),
  caption: [Function call],
)<dig:function-call>

== Verification

To test both the C0 compiler and the MIPS simulator, we wrote over 70 C0 test programs covering a broad range of language features: integer and unsigned integer arithmetic, pointers, structs, loops, conditionals, and recursive calls.

Each program is self-verifying. It runs some operations, puts the result somewhere predictable in memory or a register, then exits with a status code of 1 through a `syscall`. If the simulator ends up with the wrong values, the test fails.

The whole process is automated with `JUnit`. For each program, the test does the following:

+ Compiles the C0 source to MIPS bytecode using the compiler from @compthesis.
+ Creates a fresh `Configuration`.
+ Loads the bytecode into memory.
+ Runs `simulate()`.
+ Checks that the registers and memory locations match the expected values after the simulation stops.

This covers the full pipeline from source code to execution in a single test run. All test programs live under the `test/c0 programs` package.