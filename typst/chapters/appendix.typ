// chapters/appendix.typ
#import "@preview/codelst:2.0.2": sourcecode


#heading(numbering: none)[Appendix]

#set heading(numbering: "A.1")
#counter(heading).update(1)

== C0 Grammar 
#figure(
  caption: [Original C0 grammar]
)[#image("../res/c0 grammar.JPG", width: 90%)]
<dig:c0-grammar>


== Instruction Set Implementation
<appendix:mips-isa>

Translating MIPS mnemonics into 32-bit binary formats is not straightforward. Each instruction has its own operand layout, and the types and ranges of those operands all need to be validated before anything can be encoded. To keep this manageable, we structured the code around an abstract `Instruction` class, shown in @fig:inst.

#figure(
sourcecode()[
  ```java
    public abstract class Instruction {
        protected final int opcode;
    
        protected Instruction(int opcode) {
            this.opcode = opcode;
        }
    
        public abstract int encode();
    
        public abstract boolean isResolved();
    
        public void execute(Configuration config) {
            // Default behavior is to throw an error for non-executable instructions.
            throw new UnsupportedOperationException("Cannot be executed.");
        }
    
        public String toBinaryString() {
            return Integer.toBinaryString(encode());
        }
    }
  ```
], caption: [Abstract instruction class])
<fig:inst>

Three concrete subclasses extend it, one for each MIPS format: *I-type*, *R-type*, and *J-type*. Each one handles the bit layout for its format, as shown in @fig:inst-I, @fig:inst-R, and @fig:inst-J. The J-type case needs a two-stage resolution process because the target address may not be known yet when the instruction is first encountered.


#figure(
sourcecode()[
  ```java
    class ITypeInstruction extends Instruction {
        private final int rs, rt, immediate;
    
        public ITypeInstruction(int opcode, int rs, int rt, int immediate) {
            super(opcode);
            this.rs = rs;
            this.rt = rt;
            this.immediate = immediate;
        }
    
        @Override
        public int encode() {
            // opcode (6) | rs (5) | rt (5) | immediate (16)
            return (opcode << 26) | (rs << 21) | (rt << 16) | (immediate & 0xFFFF);
        }
        // ...
    }
  ```
], caption: [I Type instruction class])
<fig:inst-I>

#figure(
sourcecode()[
  ```java
    class RTypeInstruction extends Instruction {
        private final int rs, rt, rd, sa, fun;
    
        public RTypeInstruction(int opcode, int rs, int rt,
                                int rd, int sa, int fun) {
           // ... constructor ...
        }
    
        @Override
        public int encode() {
            // opcode (6) | rs (5) | rt (5) | rd (5) | sa (5) | fun (6)
            return (opcode << 26) | (rs << 21) | (rt << 16) 
                   (rd << 11) | (sa << 6) | fun;
        }
        // ...
    }
  ```
], caption: [R Type instruction class])
<fig:inst-R>

#figure(
sourcecode()[
  ```java
    public class JTypeInstruction extends Instruction {
        private final long address;
        private int iindex = -1;
        private boolean isResolved;
    
        // ... constructors and resolve() method ...
    
        @Override
        public int encode() {
            if (!isResolved) {
                throw new AssemblerException("Attempt to encode unresolved J-type.");
            }
            // opcode (6) | iindex (26)
            return (opcode << 26) | (iindex & 0x03FFFFFF);
        }
        // ...
    }
  ```
], caption: [J Type instruction class])
<fig:inst-J>

#pagebreak()
=== The Instruction Registry

Creating and managing instruction objects for both the assembler and the simulator is handled through a single centralized factory: the `InstructionRegistry` (@fig:registry). It sits between the high-level assembler and simulator logic on one side, and the details of individual instructions on the other.

#figure(
sourcecode()[
  ```java
    public class InstructionRegistry {
        Map<String, InstructionCreator> encoderInstructionMap =
        Initializer.initializeEncoderMap();
        
        Map<String, InstructionCreator> executableInstructionMap = 
        Initializer.initializeExecutableMap();
        
        Map<String, List<OperandType>> operandTypesMap = 
        Initializer.initializeOperandTypesMap();
    
        public static Instruction createForEncoder(String mnemonic, int[] operands) {
            // ...
        }
    
        public static Instruction createForExecutor(String mnemonic, int[] operands) {
            // ...
        }
    }
  ```
], caption: [Instruction registry])
<fig:registry>

The registry uses a dual-map factory pattern. At startup, an `Initializer` class fills two separate maps:

- `encoderInstructionMap`: holds factory lambdas that produce basic `Instruction` objects for bytecode encoding.
- `executableInstructionMap`: holds factory lambdas that produce `Instruction` objects with simulation logic inside an overridden `execute` method.

#figure(
sourcecode()[
  ```java
    class Initializer {
        // ... maps and initialization blocks ...
    
        private static void register(String mnemonic,
                                     List<OperandType> operandTypes,
                                     InstructionCreator encoder,
                                     InstructionCreator executor) {
            encoderInstructionMap.put(mnemonic, encoder);
            executableInstructionMap.put(mnemonic, executor);
            operandTypesMap.put(mnemonic, operandTypes);
        }
    
        private static void lw() {
            int opcode = 0b100011;
            register(
              "lw", // Mnemonic
              List.of(REG5, REG5, IMM16), // Operand types for parsing
              
              // Factory #1: For the Assembler/Encoder
              operands -> new ITypeInstruction(opcode, operands[1], operands[0], operands[2]),
              
              // Factory #2: For the Simulator/Executor
              operands -> {
                  int rs = operands[0], rt = operands[1], imm = operands[2];
                  return new ITypeInstruction(opcode, rs, rt, imm) {
                      @Override
                      public void execute(Configuration c) {
                          int address = c.getRegister(rs) + imm;
                          int value = c.getWord(address);
                          c.setRegister(rt, value);
                          c.setPC(c.getPC() + 4);
                      }
                  };
              });
        }
    }
  ```
], caption: [Instruction registration])
<fig:registration>

== End-to-End Simulation

This section follows a single C0 program through the full pipeline, from source code to a simulated result. The example is a recursive function that computes `pow(2, 3)`, shown in @fig:example-c0-program. It was chosen because it exercises both the compiler's handling of recursion and the simulator's call stack management at the same time.


#figure(
sourcecode()[
  ```C
  int res; 
  int pow(int a, int n){
    int res;
    if n==0 {
      res = 1
    } 
    else {
      n = n-1;
      res = pow(a, n);
      res = res*a
    }; 
    
    return res
  }; 
  
  int main(){
    int a; 
    int n;
    
    a = 2; 
    n = 3;
    res = pow(a, n);
    
    return 1
  }
  ```
], caption: [Example of a recursive C0 program.])
<fig:example-c0-program>

#pagebreak()

=== Step 1: C0 to MIPS Assembly

The compiler takes the C0 source and produces MIPS assembly. This intermediate output mixes standard MIPS instructions with custom macros like `macro: gpr(...)` that the assembler expands later. The generated code, shown below, covers stack pointer initialization, the main function body, and the recursive `pow` function.

#sourcecode()[
  ```C
  macro: gpr(30) = enc(10240, uint)
  macro: gpr(28) = enc(5120, uint)
  addiu 29 28 20
  subu 1 29 28
  srl 1 1 2
  macro: zero(28, 1)
  macro: gpr(28) = enc(5120, uint)
  j _main
  
  _main:
  addi 1 29 -8
  macro: gpr(2) = enc(2, int)
  sw 2 1 0
  addi 1 29 -4
  macro: gpr(2) = enc(3, int)
  sw 2 1 0
  addi 1 28 0
  addi 2 29 -8
  lw 2 2 0
  addi 3 29 -4
  lw 3 3 0
  addi 4 29 12
  addi 4 4 -9216
  blez 4 4
  macro: gpr(1) = enc(41, uint)
  sysc
  addi 29 29 20
  sw 1 29 -16
  sw 2 29 -12
  sw 3 29 -8
  addi 1 29 -4
  addi 2 0 1
  macro: zero(1, 2)
  jal _pow
  macro: gpr(1) = enc(1, int)
  sysc
  
  _pow:
  sw 31 29 -20
  addi 1 29 -8
  lw 1 1 0
  macro: gpr(2) = enc(0, int)
  bne 1 2 3
  addi 1 0 1
  blez 0 2
  add 1 0 0
  beq 1 0 6
  addi 2 29 -4
  macro: gpr(3) = enc(1, int)
  sw 3 2 0
  blez 0 46
  addi 1 29 -8
  addi 2 29 -8
  lw 2 2 0
  macro: gpr(3) = enc(1, int)
  sub 2 2 3
  sw 2 1 0
  addi 1 29 -4
  addi 2 29 -12
  lw 2 2 0
  addi 3 29 -8
  lw 3 3 0
  addi 4 29 12
  addi 4 4 -9216
  blez 4 4
  macro: gpr(1) = enc(41, uint)
  sysc
  addi 29 29 20
  sw 1 29 -16
  sw 2 29 -12
  sw 3 29 -8
  addi 1 29 -4
  addi 2 0 1
  macro: zero(1, 2)
  jal _pow
  addi 1 29 -4
  addi 2 29 -4
  lw 2 2 0
  addi 3 29 -12
  lw 3 3 0
  macro: mul(2, 2, 3)
  sw 2 1 0
  addi 1 29 -4
  lw 1 1 0
  lw 2 29 -16
  sw 1 2 0
  lw 1 29 -20
  addi 29 29 -20
  jr 1
  ```
]

=== Step 2: MIPS Assembly to Bytecode

The assembler takes that output, resolves labels, expands macros, and encodes each instruction into a 32-bit integer. The result is an array of bytecode ready to be loaded into the simulator's memory.

// #sourcecode()[
//   ```C
//   00111100000111100000000000000000
//   00110111110111100010100000000000
//   00111100000111000000000000000000
//   00110111100111000001010000000000
//   00100111100111010000000000010100
//   00000011101111000000100000100011
//   00000000000000010000100010000010
//   10101111100000000000000000000000
//   00100011100111000000000000000100
//   00100000001000011111111111111111
//   00010100000000011111111111111101
//   00111100000111000000000000000000
//   00110111100111000001010000000000
//   00001000000000000000000000000100
//   00100011101000011111111111111000
//   00111100000000100000000000000000
//   00110100010000100000000000000010
//   10101100001000100000000000000000
//   00100011101000011111111111111100
//   00111100000000100000000000000000
//   00110100010000100000000000000011
//   10101100001000100000000000000000
//   00100011100000010000000000000000
//   00100011101000101111111111111000
//   10001100010000100000000000000000
//   00100011101000111111111111111100
//   10001100011000110000000000000000
//   00100011101001000000000000001100
//   00100000100001001101110000000000
//   00011000100000000000000000000100
//   00111100000000010000000000000000
//   00110100001000010000000000101001
//   00000000000000000000000000001100
//   00100011101111010000000000010100
//   10101111101000011111111111110000
//   10101111101000101111111111110100
//   10101111101000111111111111111000
//   00100011101000011111111111111100
//   00100000000000100000000000000001
//   10101100001000000000000000000000
//   00100000001000010000000000000100
//   00100000010000101111111111111111
//   00010100000000101111111111111101
//   00001100000000000000000000010000
//   00111100000000010000000000000000
//   00110100001000010000000000000001
//   00000000000000000000000000001100
//   10101111101111111111111111101100
//   00100011101000011111111111111000
//   10001100001000010000000000000000
//   00111100000000100000000000000000
//   00110100010000100000000000000000
//   00010100001000100000000000000011
//   00100000000000010000000000000001
//   00011000000000000000000000000010
//   00000000000000000000100000100000
//   00010000001000000000000000000110
//   00100011101000101111111111111100
//   00111100000000110000000000000000
//   00110100011000110000000000000001
//   10101100010000110000000000000000
//   00011000000000000000000000101110
//   00100011101000011111111111111000
//   00100011101000101111111111111000
//   10001100010000100000000000000000
//   00111100000000110000000000000000
//   00110100011000110000000000000001
//   00000000010000110001000000100010
//   10101100001000100000000000000000
//   00100011101000011111111111111100
//   00100011101000101111111111110100
//   10001100010000100000000000000000
//   00100011101000111111111111111000
//   10001100011000110000000000000000
//   00100011101001000000000000001100
//   00100000100001001101110000000000
//   00011000100000000000000000000100
//   00111100000000010000000000000000
//   00110100001000010000000000101001
//   00000000000000000000000000001100
//   00100011101111010000000000010100
//   10101111101000011111111111110000
//   10101111101000101111111111110100
//   10101111101000111111111111111000
//   00100011101000011111111111111100
//   00100000000000100000000000000001
//   10101100001000000000000000000000
//   00100000001000010000000000000100
//   00100000010000101111111111111111
//   00010100000000101111111111111101
//   00001111111111111111111101010100
//   00100011101000011111111111111100
//   00100011101000101111111111111100
//   10001100010000100000000000000000
//   00100011101000111111111111110100
//   10001100011000110000000000000000
//   00100000000110000000000000000001
//   00100000010110100000000000000000
//   00100000000110110000000000000000
//   00000000011110001100100000100100
//   00010011001000000000000000000010
//   00000011011110101101100000100000
//   00000011000110001100000000100000
//   00000011010110101101000000100000
//   00010111000000001111111111111011
//   00100011011000100000000000000000
//   10101100001000100000000000000000
//   00100011101000011111111111111100
//   10001100001000010000000000000000
//   10001111101000101111111111110000
//   10101100010000010000000000000000
//   10001111101000011111111111101100
//   00100011101111011111111111101100
//   00000000001000000000000000001000
//   ```
// ]

#sourcecode()[
  ```C
  00111100000111100000000000000000
  00110111110111100010100000000000
  00111100000111000000000000000000
  00110111100111000001010000000000
  00100111100111010000000000010100
  ...
  00100011011000100000000000000000
  10101100001000100000000000000000
  00100011101000011111111111111100
  10001100001000010000000000000000
  10001111101000101111111111110000
  10101100010000010000000000000000
  10001111101000011111111111101100
  00100011101111011111111111101100
  00000000001000000000000000001000
  ```
]

=== Step 3: Simulation and Final State

The bytecode gets loaded into a fresh `Configuration` and the simulator starts running. It works through each instruction, updating registers and memory as it goes. Once the program hits `syscall` and stops, the final configuration can be checked to see if the output is correct.

#figure(
sourcecode()[
  ```C
  Configuration{
    pc = 184,
    gpr = {
      gpr 0 - 0
      gpr 1 - 1
      gpr 2 - 5120
      gpr 3 - 2
      gpr 4 - -4004
      gpr 5 - 0
      gpr 6 - 0
      ...
      gpr 25 - 0
      gpr 26 - 0
      gpr 27 - 8
      gpr 28 - 5120
      gpr 29 - 5140
      gpr 30 - 10240
      gpr 31 - 364
    }
  }
  ```
], caption: [Final state of the simulator after execution.])

The program stopped with the PC at address 184. Register `$v0` (`gpr[2]`) holds the memory address of the result, and reading that address with `config.getWord(5120)` gives `8`, which is the correct value for $2^3$. Register `$a0` (`gpr[1]`) contains `1`, signaling a clean exit.


== Program Tests
<appendix:tests>
A suite of JUnit tests covers the full pipeline end-to-end. Each test compiles a C0 program to MIPS assembly, assembles it to bytecode, runs it through the simulator, and checks that the final register and memory values match what is expected. Examples are shown in @fig:program-tests.

#figure(
sourcecode()[
  ```java
class C0ProgramTest {
        private Configuration config;
    
        @BeforeEach
        void setUp() {
            config = new Configuration();
        }
    
        @Test
        void test_trivial_program() {
            // arrange
            String code = "int main(){asm( addi 2 0 3 ); return 1}~";
            C0Program pr = new C0Program(code);
    
            // act
            simulateProgram(pr);
    
            // assert
            assertEquals(1, config.getRegister(1));
            assertEquals(3, config.getRegister(2));
        }
    
        @Test
        void test_single_int_max_constant_program() {
            // arrange
            String code = "int a; int main(){a = 2147483647; return 1}~";
            C0Program pr = new C0Program(code);
    
            // act
            simulateProgram(pr);
    
            // assert
            int expectedValue = 2147483647;
            assertEquals(1, config.getRegister(1));
            assertEquals(expectedValue, config.getWord(pr.SBASE));
        }

        // 70 more tests
  ```
], caption: [Instruction Registration])
<fig:program-tests>

== Kernel C0-Program 
<appendix:kernel-program>

This section provides the "C0 + Assembly" source code for simple operating system kernel, which was translated into _MIPS_ bytecode.
\
The full _C0_ implementation with comments for further explanation can be found in the project's #link("https://github.com/System-Architecture-WJP/WARS/blob/main/src/main/resources/c0%20programs/AbstractKernel.c0")[`resources/c0 programs/AbstractKernel.c0`] repository. The resulting _MIPS code_ consists of just below 900 native instructions, which expands to over 1,600 instructions after _macro_ expansion. It can be seen in `resources/mips programs` 

// #figure(
// sourcecode()[
//   ```java
//     // --- Type and Global Variable Definitions ---
//     typedef uint' ptrunsigned;
//     typedef uint[32] u;
//     typedef uint[8] v;
//     typedef struct {u GPR; v SPR} pcb;
//     typedef pcb[3] PCBt;
//     // ... other definitions ...

//     uint CP; // Current Process
//     bool ipf; // Invalid Page Fault
//     PCBt PCB; // Process Control Block
//     // ... other globals ...

//     // --- Core Kernel Functions ---
//     int readms(uint a){ /* ... */ };
//     void writems(uint x, uint a){ /* ... */ };
//     void copyms(uint a, uint b, uint L){ /* ... */ };
//     void readdisk(uint ppx, uint spx){ /* ... */ };
//     void writedisk(uint spx, uint ppx){ /* ... */ };
//     void swapIn(){ /* ... */ };
//     void swapOut(){ /* ... */ };
//     void ipfHandler(){ /* ... */ };
//     void scheduler(){ /* ... */ };

//     void runvm(){
//         // Main virtual machine execution loop
//         gpr(1) = PCB[CP].GPR[0]&;
//         asm( macro: restore-user );
//         asm( macro: save-user );
//         // ... interrupt handling ...
//         if (bool)ipf {ipfHandler(); /* ... */}
//     };

//     int main(){
//         // Initialization of memory regions and kernel state
//         p = 2u;
//         nup = 2u;
//         K = 1024u;
//         // ... other initializations ...

//         // Main scheduler loop
//         while true {
//             scheduler();
//             runvm();
//         };
//         return 1;
//     }
//   ```
// ], caption: [Abstract Kernel])
// <fig:abstract-kernel>



// #sourcecode[
// ```java
// typedef uint' ptrunsigned;
// typedef uint[32] u;
// typedef uint[8] v;
// typedef struct {u GPR; v SPR} pcb;
// typedef pcb[3] PCBt;

// typedef uint[4] PTAt;
// typedef uint[3] PTOIt;

// typedef struct {uint usr; uint px} auxrec;
// typedef auxrec[2] IPTt;


// uint CP;
// bool ipf;
// PCBt PCB;
// PTAt PTA;
// PTOIt PTOI;

// uint i;
// uint IL;
// uint found;
// uint EVA;
// uint EVPX;
// bool ptle;
// bool psfull;
// uint nextup;
// IPTt ipt;
// int WOV;

// uint p;
// uint PTASIZE;
// uint nup;
// uint PTL;

// uint K;

// uint HDBASE;
// uint UPBASE; 
// uint SMBASE;
// uint SMPAGENUM; 
// uint SMSIZE;




// int readms(uint a){

//         int tmp;
//         gpr(1) = a;
//         asm( lw 2 1 0 );
//         asm( sw 2 29 -4 );
//         return tmp
// };


// void writems(uint x, uint a){

//         gpr(1) = x;
//         gpr(2) = a {1};
//         asm( sw 1 2 0 )
// };


// void copyms(uint a, uint b, uint L){

//         gpr(1) = a;
//         gpr(2) = b {1};
//         gpr(3) = L {1, 2};

//         asm( blez 3 7 );
//         asm( lw 4 1 0 );
//         asm( sw 4 2 0 );
//         asm( addi 1 1 4 );
//         asm( addi 2 2 4 );
//         asm( addi 3 3 -1 );
//         asm( blez 0 -6 )
// };


// void readdisk(uint ppx, uint spx){

//         int y;
//         writems(spx, HDBASE+4096u);
//         writems(1u, HDBASE+4096u+4u);

//         y = 1;
//         while y!=0 {
//                 y = readms(HDBASE+4096u+4u)
//         };

//         copyms(HDBASE, ppx*4096u, K)
// };


// void writedisk(uint spx, uint ppx){

//         int y;
//         copyms(ppx*4096u, HDBASE, K);
//         writems(spx, HDBASE+4096u);
//         writems(2u, HDBASE+4096u+4u);

//         y = 2;
//         while y!=0 {
//                 y = readms(HDBASE+4096u+4u)
//         }

// };


// void swapIn(){

//         uint PPXIN;
//         uint SPAIN;
//         uint PTEIIN;

//         PPXIN = UPBASE / 4096u + nextup;
//         SPAIN = SMBASE + CP*SMPAGENUM + EVPX;
//         PTEIIN = PTOI[CP] + EVPX;
//         readdisk(PPXIN, SPAIN);
//         PTA[PTEIIN] = PPXIN*4096u + 2048u;

//         ipt[nextup].usr = CP;
//         ipt[nextup].px = EVPX

// };

// void swapOut(){

//         uint PPXOUT;
//         uint SPAOUT;
//         uint PTEIOUT;

//         PPXOUT = UPBASE / 4096u + nextup;
//         SPAOUT = SMBASE + ipt[nextup].usr*SMPAGENUM + ipt[nextup].px;
//         PTEIOUT = PTOI[ipt[nextup].usr] + ipt[nextup].px;

//         writedisk(SPAOUT, PPXOUT);
//         PTA[PTEIOUT] = PTA[PTEIOUT]-2048u

// };

// void ipfHandler(){

//         if (!(bool)psfull) {swapIn()} else {swapOut(); swapIn()};

//         nextup = nextup + 1u;
//         if nextup==nup {nextup = 0u; psfull = true}
// };

// void scheduler(){

//         if CP==p {CP = 1u} else {CP = CP+1u}
// };


// void runvm(){

//         gpr(1) = PCB[CP].GPR[0]&;
//         asm( macro: restore-user );

//         asm( macro: save-user );

//         IL = 0u;
//         i = 1u;
//         found = 0u;
//         while found==0u {
//                 IL = IL+1u;
//                 i = 2u*i;
//                 gpr(1) = i;
//                 gpr(2) = PCB[CP].SPR[2] {1};
//                 asm( and 3 1 2 );
//                 found = gpr(3)
//         };

//         EVA = 0u;
//         if IL==17u {EVA = PCB[CP].SPR[3]};
//         if IL==20u {EVA = PCB[CP].SPR[4]};

//         gpr(1) = EVA;
//         asm( srl 1 1 12 );
//         EVPX = gpr(1);

//         ptle = (EVPX>=PCB[CP].SPR[6]);
//         ipf = (IL==17u||IL==20u)&&!(bool)ptle;


//         if (bool)ipf {ipfHandler(); gpr(1) = PCB[CP].GPR[0]&; asm( macro: restore-user )}
// };

// int main(){
//         uint i;

//         p = 2u;
//         nup = 2u;
//         K = 1024u;
//         SMPAGENUM = 1048576u;
//         PTL = 2u;
//         SMSIZE = 268435456u;

//         PTASIZE = p*PTL;
//         UPBASE = 44u*K;
//         HDBASE = 56u*K;
//         SMBASE = SMSIZE-p*SMPAGENUM;

//         i = 1u;
//         while i<p+1u {
//                 PTOI[i] = (i-1u)*PTL;
//                 i = i + 1u
//         };

//         i = 1u;
//         while i<p+1u {
//                 PCB[i].SPR[1] = 4294967295u;
//                 PCB[i].SPR[3] = 0u;
//                 gpr(1) = PTA[PTOI[i]]&;
//                 PCB[i].SPR[5] = gpr(1);
//                 PCB[i].SPR[6] = PTL;
//                 i = i + 1u
//         };


//         gpr(1) = PCB[0].GPR[0]&;
//         asm( sw 1 0 4096 );

//         while true {
//                 scheduler();
//                 runvm()
//         };
//         return 1
// }~
// ```]
#pagebreak()

== Bootloader: Kernel Fetch Routine <appendix:kernel-fetch-program>
Here, we describe _C0_ + _Assembly_ program responsible for loading translated kernel code into _host_ machine's predefined memory region. It can be seen with comments in #link("https://github.com/System-Architecture-WJP/WARS/blob/main/src/main/resources/c0%20programs/FetchKernel.c0")[`resources/c0 programs/FetchKernel.c0`] repository


== ROM Initialization <appendix:ROM>
_MIPS_ code provided below describes initial configuration of _host's_ main memory - _ROM_ region. It can be found in the project's repository:
#link("https://github.com/System-Architecture-WJP/WARS/blob/main/src/main/resources/mips%20programs/ROM")[`resources/mips programs/ROM`].
