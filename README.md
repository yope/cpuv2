
## A simplistic 32-bit CPU

This is just a learning project and not meant to be anything serious.
This project contains the design of a SoC, currently sythesizable for the ULX3S FPGA board.
It contains my own design of a 32-bit CPU core without any fancy stuff like an MMU, pipelines or
caches (yet?). It doesn't even have a multiplier nor a barrel-shifter. That's because I like
simplicity and a small(ish) footprint. Besides the CPU there is currently some internal RAM and
a very simple video interface using the HDMI output of the ULX3S board. Currently it only supports
text though. No idea where I will go from here, but I'll probably add a UART also at least.

### CPU design

The CPU core is extremely simple and unfinished. It has two banks of 16 32-bit registers. One
bank is not used yet, and I am still undecided how to use it. At first I thought to implement
quick bank switching on interrupts, to enable low-latency interrupt handling.... but that would
limit interrupt nesting to one level only. Not sure yet, if I want that.

The bus interface is supposed to be wishbone compatible to some degree, although I never
really tested it. It might just work though.

The CPU executes instrucions in 3 or 4 steps (clock cycles): Fetch, decode, execude and (optionally)
load or store. The bus is 32-bit wide, and all instrucions are also 32-bit wide and must be
32-bit aligned.

#### Registers

16 32-bit registers. There are 4 registers that have a special function:

 * R0: Usually should have the value 0 for convinience, although it can be used as a general purpose
 register. It is not (yet) hard-wired to the value 0.
 * R1...R12: General purpose registers
 * R13: Stack pointer (SP). This register is special. If used as an address pointer in LDW/STW instructions,
 it will get decremented on store and incremented on load, like a downward growing stack pointer.
 * R14: Link-register (LR). This register is used to store the return address when doing a JSR call. It
 is copied to the program counter (PC) when an RTS instruction is executed.
 * R15: Program counter (PC). Yes, you can treat it like a regular register if you are brave.

#### Arithmetic and Logic Unit (ALU)

The ALU of this CPU is extremely simple and does not require a clock. It is purely combinatorial.
It has two 32-bit input ports for operands A and B, a carry input port, a 32-bit result port, 
a 4-bit operation port, as well as 3 1-bit outputs for carru (C), zero (Z) and negative (N). It
supports the following operations:

NOTE: All operations will affect the outputs of C, Z and N.

 * 0: ADD: Addition without carry.
 * 1: SUB: Substraction without carry.
 * 2: ADC: Add with carry.
 * 3: SBC: Subtract with carry.
 * 4: NOT: Negates operand A, inverting all bits. Operand B is unused.
 * 5: AND: Result is A & B.
 * 6: OR: Result is A | B.
 * 7: XOR: Result is A ^ B.
 * 8: SHL: Shift left operand A by one bit. Operand B is ignored.
 * 9: SHR: Shift right operant A by one bit. Operand B is ignored.
 * 10: ASL: Arithmetic shift left operand A (with carry). Operand B is ignored.
 * 11: ASR: Arithmetic shift right operand A (with carry). Operand B is ignored.
 * 12: SL4: Shift left operand A by 4 bits.
 * 13: SL16: Shift left operand A by 16 bits.
 * 14: SR4: Shift right operand A by 4 bits.
 * 15: SR16: Shift right operand A by 16 bits.

The last 4 operations are basically meant to implement other fixed amounts of shifts in as little
instructions (cycles) as possible. This also aids multiplication and division routines. SL16/SR16
als server as half-word swaps.

#### Instructions

There are several instrucion formats, with some aspects copied from ARM or MIPS. Each instruction
has a 4-bit opcode and a 4-bit condition code. This makes all instrucions conditional if needed.
The opcode is placed in the 4 MSBs of the instruction register. After it comes the condition code
in the next 4 bits. This is followed by 0 or more 4-bit fields and one larger immediate data field
taking up the rest of the 32 bits of the instruction register. The possible fiels are as follows:

 * OPC: 4-bit opcode
 * COND: 4-bit conditional code
 * Rd: 4-bit destination register index
 * Rs1: 4-bit operand (source) 1 register index
 * ALU: 4-bit ALU operation code
 * Rs2: 4-bit operand (source) 2 register index
 * IMM12: 12-bit immediate value
 * IMM16: 16-bit immediate value
 * IMM20: 20-bit immediate value
 * IMM24: 24-bit immediate value
 * EXT: 4-bit extension code for Opcode 15.
 * RESV: Reserved, variable length. Should be all-0.

##### 0. Register ALU instructions: OPC, COND, Rd, Rs1, ALU, Rs2, RESV(8-bit).

Rd = Rs1 ALU-operation Rs2

##### 1. Register immediate ALU operaions: OPC, COND, Rd, Rs1, ALU, IMM12

Rd = Rs1 ALU-operation IMM12

##### 2. Load immediate operation (LDI): OPC, COND, Rd, IMM20

Rd = IMM20 (12 MSB's padded with 0)

##### 3. Load immediate signed (LDIS): OPC, COND, Rd, IMM20

Rd = IMM20 (12 MSB's sign extended IMM20)

##### 7. Load immediate upper (LDIU): OPC, COND, Rd, IMM20

Rd = IMM20 << 12

##### 4. Load byte (LDB): OPC, COND, Rd, Rs1, IMM16

Rd = (byte address)(Rs1 + IMM16) & 0xff

##### 5. Load half-word (LDH): OPC, COND, Rd, Rs1, IMM16

Rd = (half-word address)(Rs1 + IMM16) & 0xffff

##### 6. Load word (LDW): OPC, COND, Rd, Rs1, IMM16

Rd = (Rs1 + IMM16)

##### 8. Store byte (STB): OPC, COND, Rd, Rs1, IMM16

(Rd + IMM16) = Rs1 & 0xff

##### 9. Store half-word (STH): OPC, COND, Rd, Rs1, IMM16

(Rd + IMM16) = Rs1 & 0xffff

##### 10. Store word (STW): OPC, COND, Rd, Rs1, IMM16

(Rd + IMM16) = Rs1

##### 11. Unused

##### 12. Branch instruction (B): OPC, COND, IMM24

PC = PC + IMM24 (sign extended)

##### 13. Decrement and Branch if not zero (BDEC): OPC, COND, Rd, IMM20

Rd = Rd - 1
if (Rd != 0) PC = PC + IMM20 (sign extended)

##### 14. Jump to Sub Routine (JSR): OPC, COND, Rd, IMM20

LR = PC + 4 (next instruction after this)
PC = PC + Rd + IMM20 (sign extended)

##### 15.0. Return from Subroutine (RTS): OPC, COND, EXT=0, RESV(20-bit)

PC = LR

##### 15.1. Return from interrupt (RTI): OPC, COND, EXT=1, RESV(20-bit)

Not yet implemented


### Video display interface

The video controller currently has its own RAM buffer for a 80x60 character text display.
This is displayed on a monitor connected to the HDMI port, at 640x480 pixel resolution.
A font is incorporated (in chargen.hex) with fixed with 8x8 pixel characters.
Video (text) RAM is only byte-addressable right now for simplicity.
