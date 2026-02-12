# Control Flow Integrity

The Zicfiss and Zicfilp extensions build on these conventions and hints and provide backward-edge and forward-edge control flow integrity respectively.

## Issues to be solved

1. ROP
2. COP/JOP

## RISC V Details

### Types of Control Flow instructions

#### Conditional Branches

Conditional branches encode an offset in the immediate field of the instruction and are thus direct branches that are not susceptible to control-flow subversion.

#### Unconditional Jumps

1. Unconditional Direct Jumps: Unconditional direct jumps using JAL transfer control to a target that is in a +/- 1 MiB range from the current pc.
2. _Unconditional Indirect Jumps <- This is the main issue_ : Unconditional indirect jumps using the JALR obtain their branch target by adding the sign extended 12-bit immediate encoded in the instruction to the rs1 register.

### Difference between Call and Return

- The term call is used to refer to a JAL or JALR instruction with a link register as destination, i.e., rd≠x0. Conventionally, the link register is x1 or x5. A call using JAL or C.JAL is termed a direct call. A C.JALR expands to JALR x1, 0(rs1) and is a call. A call using JALR or C.JALR is termed an indirect-call.

- The term return is used to refer to a JALR instruction with rd=x0 and with rs1=x1 or rs1=x5. A C.JR instruction expands to JALR x0, 0(rs1) and is a return if rs1=x1 or rs1=x5. The term indirect-jump is used to refer to a JALR instruction with rd=x0 and where the rs1 is not x1 or x5 (i.e., not a return). A C.JR instruction where rs1 is not x1 or x5 (i.e., not a return) is an indirect-jump.

## Landing Pad (Zicfilp)

- To enforce forward-edge CFI
- LPAD instruction
- ELP (Expected Landing Pad) At every target of indirect-jump or call
- Labelling Enabled allows to be more strict with landing pad
- Software Exception raised when invalid landing pad
- In simplest for, course-grained landing pad with single label value for control flow integrity

## Issues with Zicfilp Compiler:

1. Memset.S
2. Global pointer parts
3. \_\_sfputc_r
4. \_\_sfvwrite_r
5. Still issues with buffering
