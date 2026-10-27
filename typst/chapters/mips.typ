#import "@preview/cetz:0.4.0"
#let pc = math.italic("c.pc")
#let gpr = math.italic("c.gpr")
#let mem = math.italic("c.m")
#let opc = math.italic("opc(c)")
#let rtype = math.italic("rtype(c)")
#let itype = math.italic("itype(c)")
#let jtype = math.italic("jtype(c)")
#let rc = math.italic("rc(c)")
#let rt = math.italic("rt(c)")
#let rd = math.italic("rd(c)")
#let imm = math.italic("imm(c)")
#let iindex = math.italic("iindex(c)")
#let zxtimm = math.italic("zxtimm(c)")
#let sxtimm = math.italic("sxtimm(c)") 
// Function to draw instruction format
#let draw_instruction(name, y_pos, fields) = {
  let x_start = 0
  let box_height = 0.8
  let total_width = 8
  
  cetz.draw.content((x_start - 0.5, y_pos + box_height/2), [*#name*], anchor: "east")
  
  for field in fields {
    let field_width = (field.start - field.end + 1) / 32 * total_width
    
    cetz.draw.rect((x_start, y_pos), (x_start + field_width, y_pos + box_height), 
              stroke: black + 1pt, fill: none)
    
    if field.start != field.end {
      cetz.draw.content((x_start + 0.05, y_pos + box_height + 0.1), 
                   text(size: 8pt)[#field.start], anchor: "south-west")
      cetz.draw.content((x_start + field_width - 0.05, y_pos + box_height + 0.1), 
                   text(size: 8pt)[#field.end], anchor: "south-east")
    } else {
      cetz.draw.content((x_start + field_width/2, y_pos + box_height + 0.1), 
                   text(size: 8pt)[#field.start], anchor: "south")
    }
    
    cetz.draw.content((x_start + field_width/2, y_pos + box_height/2), 
                 emph[#field.name], anchor: "center")
    
    x_start += field_width
  }
}

= MIPS ISA Overview  <mips-isa-overview>
This chapter provides concise overview of the MIPS ISA, closely following the formal definitions presented in @sysarch. The instruction set and assembler syntax is presented in tables (@I-Table, @R-Table, @J-Table), followed by precise interpretation of the tables in @inst-fields.

// In this chapter we make a short overview of MIPS ISA. For a more detailed explanation refer to @sysarch. As in @sysarch, we present MIPS ISA and assembler syntax in the form of tables (@I-Table, @R-Table, @J-Table) and provide precise interpretation of the tables in @inst-fields.

#figure(
  table(
    columns: 5,
  
    table.header(
      [*opc*], [*rt*], [*Mnemonic*], [*Assembler Syntax*], [*Effect*]
    ),

    table.cell(colspan: 5, align: center)[Data Transfer],
    [100011], [], [lw], [lw rt rs imm], [rt = m],
    [101011], [], [sw], [sw rt rs imm], [m = rt],
  
    table.cell(colspan: 5, align: center)[Arithmetic, Logic, Test-and-Set],
    [001000], [], [addi], [addi rt rs imm], [rt = rs + sxt(imm)],
    [001001], [], [addiu], [addiu rt rs imm], [rt = rs + sxt(imm)],
    [001010], [], [slti], [slti rt rs imm], [rt = (rs < sxt(imm) ? $1_32$ : $0_32$)],
    [001011], [], [sltiu], [sltiu rt rs imm], [rt = (rs < sxt(imm) ? $1_32$ : $0_32$)],
    [001100], [], [andi], [andi rt rs imm], [rt = rs $and$ zxt(imm)],
    [001101], [], [ori], [ori rt rs imm], [rt = rs $or$ zxt(imm)],
    [001110], [], [xori], [xori rt rs imm], [rt = rs $xor$ zxt(imm)],
    [001111], [], [lui], [lui rt imm], [rt = imm$2^16$],

    table.cell(colspan: 5, align: center)[Branch],
    [000001], [00000], [bltz], [bltz rs imm], [pc = pc + (rs < 0 ? imm00 : $4_32$)],
    [000001], [00001], [bgez], [bgez rs imm], [pc = pc + (rs $>=$ 0 ? imm00 : $4_32$)],
    [000100], [], [beq], [beq rs rt imm], [pc = pc + (rs = rt ? imm00 : $4_32$)],
    [000101], [], [bne], [bne rs rt imm], [pc = pc + (rs $!=$ rt ? imm00 : $4_32$)],
    [000110], [00000], [blez], [blez rs imm], [pc = pc + (rs $<=$ 0 ? imm00 : $4_32$)],
    [000111], [00000], [bgtz], [bgtz rs imm], [pc = pc + (rs $>=$ 0 ? imm00 : $4_32$)]
  ),
  caption: [*I-type* instructions],
) <I-Table>

#figure(
  table(
    columns: 6,
  
    table.header(
      [*opcode*], [*fun*], [*rs*], [*Mnemonic*], [*Assembler Syntax*], [*Effect*]
    ),
    
    table.cell(colspan: 6, align: center)[Shift Operation],
    [000000], [000010], [], [srl], [srl rd rt sa], [rd = srl(rt, sa)],
  
    table.cell(colspan: 6, align: center)[Arithmetic, Logical Operation],
    [000000], [100000], [], [add], [add rd rs rt], [rd = rs + rt],
    [000000], [100001], [], [addu], [addu rd rs rt], [rd = rs + rt],
    [000000], [100010], [], [sub], [sub rd rs rt], [rd = rs - rt],
    [000000], [100011], [], [subu], [subu rd rs rt], [rd = rs - rt],
    [000000], [100100], [], [and], [and rd rs rt], [rd = rs $and$ rt],
    [000000], [100101], [], [or], [or rd rs rt], [rd = rs $or$ rt],
    [000000], [100110], [], [xor], [xor rd rs rt], [rd = rs $xor$ rt],
    [000000], [100111], [], [nor], [nor rd rs rt], [rd = rs $or$ rt̄],
  
    table.cell(colspan: 6, align: center)[Test-and-Set Operation],
    [000000], [101010], [], [slt], [slt rd rs rt], [rd = (rs < rt ? $1_32$ : $0_32$)],
    [000000], [101011], [], [sltu], [sltu rd rs rt], [rd = (rs < rt ? $1_32$ : $0_32$)],
  
    table.cell(colspan: 6, align: center)[Jumps, System Call],
    [000000], [001000], [], [jr], [jr rs], [pc = rs],
    [000000], [001001], [], [jalr], [jalr rd rs], [rd = pc + $4_32$     pc = rs],
    [000000], [001100], [], [sysc], [sysc], [System Call],
  
    table.cell(colspan: 6, align: center)[Coprocessor Instructions],
    [010000], [011000], [10000], [eret], [eret], [Exception Return],
    [010000], [], [00100], [movg2s], [movg2s rd rt], [spr[rd] := gpr[rt]],
    [010000], [], [00000], [movs2g], [movs2g rd rt], [gpr[rt] := spr[rd]]
  ),
  caption: [*R-type* instructions]
) <R-Table>

#figure(
  table(
    columns: 4,
  
    table.header(
      [*opc*], [*Mnemonic*], [*Assembler Syntax*], [*Effect*]
    ),
    
    table.cell(colspan: 4, align: center)[Jumps],
    [000010], [j], [j iindex], [pc = pc + $"sxt"$(iindex)],
    [000011], [jal], [jal iindex], [R31 = pc + $4_32$, \ pc = pc + $"sxt"$(iindex)]
  ),
  caption: [*J-type* instructions],
) <J-Table>

#pagebreak()

== MIPS configuration and Instruction Fields <inst-fields>
A MIPS configuration $c$ has 3 data structures:
  - $pc in BB^32$: The program counter; points to the instruction to be executed.
  - $gpr : BB^5 arrow BB^32$: 32 general-purpose registers each 32 bit wide. For register address $x in BB^32$, $gpr(x) in BB^32$ denotes the content of register $x$ in configuration $c$. Register $0_5$ is always $0_32$. $ gpr(0_5) = 0_32 $
  - $mem : BB^32 arrow BB^8$: The byte-addressable processor memory. For address $a in BB^32$, $mem(a) in BB^8$ defines the content of the memory location $a$ in configuration $c$.
For memory $m : BB^32 arrow BB^5$, address $a in BB^32$ and a natural number $d in NN$, we denote the content of $d$ consecutive bytes by $ m_1(a) &= m(a) \ m_(d + 1) (a) &= m(a +_32 d_32) circle.small m_d (a) $
where $circle.small : BB^n times BB^m arrow BB^(n + m)$ denotes concatenation operator.
$I(c)$ defines the current instruction to be executed in configuration $c$: $ I(c) = mem_4(pc) $

The six high-order bits of the instruction are called the opcode of the instruction:
$
opc=I(c)[31:26]
$
There are 3 types of MIPS instructions: *I-type*, *R-type* and *J-type*. Depending on the instruction type, the bits of an instruction is subdivided sections as shown in @inst-fields-fig. The instruction type is determined by the following predicates:
$
rtype &equiv opc = 0\*0^4 \
jtype &equiv opc = 0^4 1 \* \
itype &equiv overline(rtype or jtype)
$
#figure(
  cetz.canvas({
    draw_instruction("I-type", 4, (
      (name: "opc", start: 31, end: 26),
      (name: "rs", start: 25, end: 21),
      (name: "rt", start: 20, end: 16), 
      (name: "imm", start: 15, end: 0)
    ))
    
    draw_instruction("R-type", 2, (
      (name: "opc", start: 31, end: 26),
      (name: "rs", start: 25, end: 21),
      (name: "rt", start: 20, end: 16),
      (name: "rd", start: 15, end: 11), 
      (name: "sa", start: 10, end: 6),
      (name: "fun", start: 5, end: 0)
    ))
    
    draw_instruction("J-type", 0, (
      (name: "opc", start: 31, end: 26),
      (name: "iindex", start: 25, end: 0)
    ))
  }),
  caption: [Types and fields of MIPS instructions]
) <inst-fields-fig>
Addresses of registers in the general-purpose register file are specified in the following fields of the instruction:
$
rc &equiv I(c)[25:21] \
rt &equiv I(c)[20:16] \
rd &equiv I(c)[15:11]
$
Two kinds of immediate constants can be specified:
$
imm &equiv I(c)[15:0] \
iindex &equiv I(c)[25:0]
$\
In order to apply operations to them, the constant can be extended with 16 high-order bits in two ways: zero extension and sign extension:
$
zxtimm &equiv 0^16 circle.small imm\
sxtimm &equiv imm[15]^16 circle.small imm
$