#import "@preview/codelst:2.0.2": sourcecode
#let DK = math.italic("DK")

= Extending C0 Grammar and Compiler <chap:c0>

== Overview 
Kernel programming often requires accessing data outside the scope of standard C0 variables. In this case, data can come from:
#set enum(indent: 1em)

  + registers and their content. <read-write-gpr>
  + memory addresses outside the range of C0 variables. <inline-assembly>
To handle #link(<read-write-gpr>)[(1)] one should extend the grammar 
#set enum(indent: 0em)
with instructions that enable direct register access for reading and writing C0 variables (see Chapter 13.3 @sysarch).
$
italic("gpr")(i) = i d #h(1em) {J}
$
or, 
$
italic("id") = g p  r(i) #h(1em) {J}
$
Here, $J$ specifies the set of registers that should remain unchanged for the statement translation, it can be empty as well. Note that when reading from register $i$, we also don't use it throughout $italic("id")$ evaluation, despite not being directly mentioned in $J$.  

For #link(<inline-assembly>)[(2)], we introduce plain inline assembly on C0 level. Besides standard memory accesses with _lw_ and _sw_, all other MIPS instructions can be used while programming on high-level.
$
a s m ("MIPS")
$
Later for the kernel implementation, we provide the primitive functions such as _copyms_, _readdisk_, _writedisk_, etc. As all these primitives don't indent to return any value, one intuitively observes the need of void functions in C0. During code generation, void functions are translated similarly to regular functions (see Chapter 12.4 @sysarch).

$
v o i d #h(1em)  f(t_1 #h(0.5em) x_1, dots , t_p #h(0.5em) x_p) #h(1em) { t_(p + 1) #h(0.5em) x_(p + 1), dots , t_r #h(0.5em) x_r; #h(0.5em) b o d y  }
$

Major challenge in extending grammar is to keep the resulting language in $L R(1)$ class. After constructing automaton, this is normally validated with $DK_1$ test. For full details see Chapter 2.4 @sipser.  

Because our work highly hinges on the existing compiler and parser @compthesis, we leave out the unchanged code generation details and instead exclusively describe the extension points and the implementation of our modifications.

This chapter ends with the report on those bugs we detected so far during translation phase. For every issue, we explain the problem and outline the changes made to resolve it.  

== C0 + Assembly

=== Grammar

First, we discuss how original grammar - @dig:c0-grammar was adapted, and what other considerations are taken to fulfill $D K_1$ test. To generate set of registers $J$, the grammar is extended with nonterminal -- Number Set  
#raw(lang:"C", "<NuS>") symbol. 

#figure(
sourcecode()[
```text
<Di>  -> 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
<DiS> -> <Di> | <Di><DiS>
<NuS> -> <DiS> | <DiS>,<NuS>
   
  .
  .
  .
  
<St> -> ... | <id>=gpr(<DiS>) | <id>=gpr(<DiS>) {<NuS>} |
     -> ... | gpr(<DiS>)=<id> | gpr(<DiS>)=<id> {<NuS>} 
```],
caption: [Reading and writing to registers])<code:set-J>

As it is depicted on @code:set-J, #raw(lang:"C", "<NuS>") generates the sequence of 
#raw(lang:"C", "<DiS>"). To specify the register $i$ -- we simply use #raw(lang:"C", "<DiS>") node. Additionally, "$italic("gpr")$" is required to be included in the terminal symbols list. Finally, we finish extensions to #raw(lang:"C", "<St>") with statements reading and writing from $g p r$#raw(lang:"C", "(<DiS>)").  \ 

#figure(
sourcecode()[
```text
<Di>      -> 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
<DiS>     -> <Di> | <Di><DiS>
<Le>      -> A | B | C | D | E | F | G | H | I | J | K | L | M | N | O | ...

<DiLe>    -> <Le> | <Di>
<DiLeS>   -> <DiLe> | <DiLe><DiLeS>

<DiLeCC>  -> - | <DiLe>
<DiLeCCS> -> <DiLeCC> | <DiLeCCS><DiLeCC>
<ASM>     -> <DiLeCCS> | <ASM> <DiLeCCS>

<St>      -> ... | asm( <ASM> )

```],
caption: [Inline assembly])<code:inline-assembly>



For inline assembly instructions, @code:inline-assembly shows the presence of three additional nonterminal symbols.\ 

#set list(indent: 1em)

  - #raw(lang:"C", "<DiLeCC>") -- extends digit/letter with "-". The last alteration suffices describing negative intermediate values for _lw_, _sw_ (e.g.  #raw(lang: "C", "sw  31  29  -(size($f)+8)") first statement of 
    #raw(lang:"C", "<body>") translation). \
  
  - #raw(lang:"C", "<DiLeCCS>") -- simply generates sequence of #raw(lang:"C", "<DiLeCC>"). \

  - #raw(lang:"C", "<ASM>") -- combines arbitrary number of words containing $italic("Letters") union italic("Digits") union {"-"}$ separated with " ".  
#set list(indent: 0em)

Apart from MIPS, adapted grammar may also cover almost every random sequence of digits/letters. We would not stress ourselves with this exception, as assembly instructions are usually referred specifically only for kernel programming. Finally, complete the extension of #raw(lang:"C", "<St>") similarly with $a s m$(#raw(lang:"C", "<ASM>")) and include "$a s m $" symbol in the terminals list. \
Note that current grammar generates each MIPS instruction separately (see @code:readms-function).
#figure(
sourcecode()[
```C
    int readms(uint a){ // software read from main memory
        
        int tmp;
        gpr(1) = a;
        asm( lw 2 1 0 );
        asm( sw 2 29 -4 );
        return tmp
    }
```],
caption: [Primitive - _readms_])<code:readms-function>

=== $DK_1$ Test 
We didn't make any changes to parser generation @compthesis and therefore, _DK#sub[1]_  automaton is obtained as it was for the original grammar. Alongside this, we expect to encounter similar problems mentioned in Chapter 2.6 @compthesis that could fail $DK_1$ test. 

Unfortunately, our initial attempt of introducing MIPS was unsuccessful.
$
#raw(lang:"C", "R1:    ")& #raw(lang:"C", "<ASM>  ->  <DiLeCCS>") \
#raw(lang:"C", "R2:    ")& #raw(lang:"C",  "<ASM>  ->  <DiLeCCS>. <ASM>") 
$

In both case follow-up look-ahead symbol is -- " ", the latter makes _accept_ state failing (2) condition of _DK#sub[1]_ test. To prevent this, we also invert the derivation order as it is shown at @code:inline-assembly.

=== Implementation
Our overall idea was to keep code generation process almost the same to use most of available portions as black boxes. Therefore, all these changes follow the same intention. 
Inside class `CodeGenerator.java` while iterating through derivation tree, we modify function `generateStS`. Now, it additionally checks existence of both reading and writing to registers and inline assembly. This inspection purely depends on the border word structure of #raw(lang: "C", "DTE st"), and once it is observed, one of the following functions are called: `generateReadGPR, generateWriteGPR, generateInlineAsm` ...

@dig:readgpr shows the translation mechanism of #raw(lang: "C", "id = gpr(i) {J}" ). We use function `evaluteId` to 
evaluate left value of $i d$. As a result, it returns `VarRegId`  containing register index, that stores the base address of identifier. For writing to $g p r$ one should, obviously, evaluate right value of $i d$.    

#figure(
  caption: [Read register content]
)[#image("../res/diag-readgpr.svg", width: 50%)]
<dig:readgpr>

#v(2em)

As it is described on @code:gpr-read-write-implementation, first we block the register set that should not be accessed throughout the translation phase and after evaluating $i d$, add $s w$ instruction. 
Note that when writing to register -- ```asm addi i varRegId.register 0``` is generated.
#figure(
sourcecode()[
```Java
    FUNCTION generateReadGPR(id, registerIdx):
      // 1. Initialize restricted register list with registerIdx 
      restrictedRegisterList.add(idx)
      // 2. Check if J - is present.
      IF id.siblingsCount() > 5:
          // 3. Extract registers from J.
          FOR each j extracted in J: 
            // 4. Update restrictedRegisterList with j
            restrictedRegisterList.add(j)
          END FOR
      END IF
      // 5. Block registers from restrictedRegisterList
      FOR reg in restrictedRegisterList:
        // 6. Block each restricted register
          occupy(reg)
      END FOR 
      // 7. Finish translation with sw instruction 
      addInstruction(Instruction.sw(idx, varRegId.register, 0))
      // 8. Free occupied registers for J 
      FOR reg in restrictedRegisterList:
          // 9. Block each restricted register
          free(reg)
      END FOR
      // 10. Free register used in id translation
      free(varRegId.reg)
    END FUNCTION    
```],
caption: [generateReadGPR])<code:gpr-read-write-implementation>


Unlike reading or writing to registers, inline assembly itself provides MIPS instruction. Therefore, it does not require any further translation. We simply copy the the content under its derivation tree node - #raw(lang: "C", "<ASM>") as it is given at @code:inline-assembly-implementation.  

#figure(
sourcecode()[
```Java
    FUNCTION generateInlineASM(instrNode):
      // 1. create new instruction with content of instrNode
      instruction = instrNode.getBorderWord()
      // 2. add instruction to the instruction list.
      addInstruction.add(instruction)
    END FUNCTION
    
```],
caption: [generateInlineASM])<code:inline-assembly-implementation>



== Void Function
=== Grammar

#figure(
  caption: [Void Function Derivation]
)[#image("../res/diag-void-function-decl.svg", width: 50%)]
<dig:void-function-decl>

#v(1em)
Void functions, unlike ordinary ones, do not return any value and therefore possesses a predetermined $italic("void")$ type. Consequently, their entire body can simply be described with  #raw(lang: "C", "<StS>"). As regular functions, it may declare both -- parameters to be passed upon function call and local variables in the beginning of function definition. @dig:void-function-decl depicts only one of the four possible void  generation. Luckily, this change to the grammar did not become any source of an overhead to $DK_1$ test.
// #figure(
// sourcecode()[
// ```text
// <FuD> -> ... | void <Na>(<PaDS>){<VaDS>;<StS>} | 
//              | void <Na>(<PaDS>){<StS>}
//              | void <Na>(){<VaDS>;<StS>}
//              | void <Na>(){<StS>}

// <St> -> ...  | <Na>() | <Na>(<PaS>) 
// ```],
// caption: [Void Function])<code:void-function-grammar>



=== Derivation

#figure(
  caption: [Void function derivation]
)[#image("../res/diag-void-function-gen.svg", width: 60%)]
<dig:void-function-gen>

Before actual jump into the function execution, first one should check available space on the stack, whether it can allocate the new function frame. In case there is not enough space, $italic("syscall")$ interrupt is generated and to indicate its status $italic("gpr(1)")$ is updated with value $41$. As before we keep `MemoryHelper.java` for that. 
\
@dig:void-function-gen displays an extra word stored on stack indicating return address at which assembly program should continue execution. This is achieved with the aid of #raw(lang: "ASM", "jal") and the first instruction in function body translation. For more details, see Chapter 12.4 @sysarch.  

=== Implementation

When a void function declaration is detected at the #raw(lang: "C", "DTE <St>") border word, it requires to evaluate all arguments and initialize values of local variables (if they present) with zeros. This is usually done with helper functions `setParametersRegisterList, initializeLocalVariables`. Translation is completed by providing generation of function body -- #raw(lang: "C", "<StS>") with `generateCodeVoidFunction` (see at @code:void-function-call). 

#figure(
sourcecode()[
```Java
    FUNCTION generateCodeVoidFunction(call):
      // 1. generate instruction store return address on the stack
      addInstruction(Instruction.sw(31, 29, -(size(call) + 4))
      // 2. Extract body from function
      body = call.getFunction().getBody()
      // 3. generate translation for function body
      generateStS(body)
      // 4. Add instruction for returning from function
      addInstruction(Instruction.lw(1, 29, -(call.frameSize + 4)))
      // 5. Decrease stack pointer
      addInstruction(Instruction.addi(29, 29, -(call.frameSize + 4)))
      // 6. Generate instruction jumping to return address
      addInstruction(Instruction.jr(1))
    END FUNCTION
```],

caption: [generateCodeVoidFunction])<code:void-function-call>

== Examples

This chapter summarizes translation examples of _writems_ and _copyms_. Throughout kernel programming, these helper functions are exploited to access disk. 

#set list(indent: 1em)

  - #raw(lang:"C", "void writems(uint x, uint a)") -- stores value $x$ in main memory at $a$ \

  - #raw(lang:"C", "void copyms(uint a, uint b, uint L)") -- copies $L$ consecutive words from main memory starting at address $a$ to main memory starting at address  $b$    

  #set list(indent: 0em)

#v(2em)


#figure(
  grid(
    columns: (1.5fr, 1fr),
    column-gutter: 2em,
    sourcecode()[
    ```C
    
    
    void writems(uint x, uint a){ 

        gpr(1) = x;
        gpr(2) = a {1};
        asm( sw 1 2 0 )
    }

    ```
    ],
    // ,
    //  align(center + horizon)[
    //   #text("⟶", size: 2em)
    // ],
    sourcecode()[
    ```asm
    _writems:
    sw 31 29 -12
    addi 1 29 -8
    lw 1 1 0
    addi 1 1 0
    addi 2 29 -4
    lw 2 2 0
    addi 2 2 0
    sw 1 2 0
    lw 1 29 -12
    addi 29 29 -12
    jr 1
    ```
    ],
    // ,
  ),
  caption: [_writems_ translation],
) <code:writems-function-translation>

#figure(
  grid(
    columns: (2fr, 1fr),
    column-gutter: 5em,
    sourcecode()[
    ```C
    void copyms(uint a, uint b, uint L){ 
    
            gpr(1) = a;
            gpr(2) = b {1};
            gpr(3) = L {1, 2};
    
            asm( blez 3 7 ); 
            asm( lw 4 1 0 );
            asm( sw 4 2 0 );
            asm( addi 1 1 4 );
            asm( addi 2 2 4 );
            asm( addi 3 3 -1 );
            asm( blez 0 -6 )
    };

    ```],
    sourcecode()[
    ```asm
    _copyms:
    sw 31 29 -16
    addi 1 29 -12
    lw 1 1 0
    addi 1 1 0
    addi 2 29 -8
    lw 2 2 0
    addi 2 2 0
    addi 3 29 -4
    lw 3 3 0
    addi 3 3 0
    blez 3 7
    lw 4 1 0
    sw 4 2 0
    addi 1 1 4
    addi 2 2 4
    addi 3 3 -1
    blez 0 -6
    lw 1 29 -16
    addi 29 29 -16
    jr 1
    ```],
  ),
  caption: [_copyms_ translation],
) <code:copyms-function-translation>

== Corrections to Pre-Existing Bugs

While integrating our modifications, certain bugs were uncovered inside already existing code generation portions. Here, we underline those that we consider the most significant.

=== Macros Inside Conditional Statement

Translation process is usually simplified with _macros_ — each grouping together sets of MIPS instructions that serve the same purpose. _macro_ instructions are usually unfolded from MIPS to bytecode translation stage. For further details see @chap:assem-macros,
// \
// Below, we specify a few key _macro_ instructions. The list will be extended in the kernel section.

// #set list(indent: 1em)
//   - #raw(lang: "C", "gpr(i) = enc(val, simple type)") -- used to evaluate constant values. 
  
//   - #raw(lang: "C", "zero(i, j)") -- initializes $g p r (j)$ memory words starting from address $g p r (i)$. After completing this _macro_ both _i_ and _j_ are modified.  
 
//   - #raw(lang: "C", "mul(k, i, j)") -- encodes software multiplication of binary numbers specified by registers _i_ and _j_ and stores result in register _k_. Note that both signed and unsigned integer multiplication are supported by this _macro_.  
  
//   - #raw(lang: "C", "divu(k, i, j)") -- provides unsigned integer division of binary numbers specified by registers _i_ and _j_. Consequently, result is stored in register _k_.  
  
//   - #raw(lang: "C", "divt(k, i, j)") -- executes signed integer number division, specifications follow $d i v u (k, i, j)$.   
  
// #set list(indent: 0em)

For conditional statements: _while_, _if_, and _if else_, we evaluate the condition first and then generate a branch instruction with calculated offset (see @diag-while-derivation). Initially, these branches targeted in the wrong place because offset computation logic treated each macro as a single instruction. To handle this, _macro_'s full length must be included in the offset by maintaining a map - #raw(lang:"Java", "Map<String, Integer> instructionsRealSize") - that stores actual number of MIPS instructions generated for each _macro_.

#figure(
  grid(
    columns: (1.5fr, 2fr),
    column-gutter: 2em,
    image("../res/diag-while-generation.svg", width: 80%),  
    //  align(center + horizon)[
    //   #text("⟶", size: 2em)
    // ],
    sourcecode()[
    ```asm
    code (n1)
    beqz j |code(n3) + 2|

    code(n3)
    blez 0 -(|code(n1) + |code(n3)| + 1)
    ```
  ],
  ),
  caption: [_while_ derivation],
)<diag-while-derivation>

#pagebreak()
=== Constant Evaluation

Next, we handle the bug found in loading constant values. According to specifications given in Chapter 12.2.5 @sysarch, constants generation of simple types such as: #h(0.5em) #raw(lang: "Text", "bool, char, int, uint") should be achieved with _macro_ instruction. In this case, _macro_ loads upper and lower part of value separately with _lui_ and _ori_ (see @macro-expansion). 
Initially, there was a temptation to use  #raw(lang: "ASM", "addi i 0 val") to load constants, but since this is limited to only 16-bit immediate values, we replaced it with _macros_ accordingly. 
#figure(
sourcecode()[
  ```asm
  # Before (using addi, limited to 16-bit)
  addi 1 0 1000
 
  # After (using our macro for a 32-bit unsigned constant)
  macro: gpr(1) = enc(1000, int) 
  ```
], caption: [Constant evaluation])
<code:constant-evaluation>

=== Array Element Generation
Last major bug was found in sub-variable generation from array. The derivation -- #raw(lang: "C", "id -> id[e]") returns new *_Variable_* with following components:
#set list(indent: 1em)
 - *_Base Address_*  - evaluates base address of the sub-variable;

 - *_Type_* - returns respective type that was used to define array-type;

 - *_Displacement_* - computes displacement of #raw(lang: "C", "id[e]") inside #raw(lang: "C", "id") variable;   
 
 
#set list(indent: 0em)

Some of these calculations were implemented incorrectly, causing sub-variable accessing to wrong memory locations.
We reviewed all three components — base‐address evaluation, element‐type lookup, and displacement computation - so that the resulting *_Variable_* now accurately represents $i d [ e ]$ and its memory layout. 

