# Instruction encoding reference

```
20-bit instruction word:
[19:16] opcode  [15:12] rA  [11:8] rB  [7:0] imm

Opcode | Mnemonic       | Operation
-------|----------------|------------------------------------------
 0000  | NOP / MFHI rA  | no-op (rA=0), or rA = HI (rA!=0)
 0001  | LOAD rA, [imm] | rA = mem[imm[6:0]]
 0010  | STORE rA, [imm]| mem[imm[6:0]] = rA
 0011  | MOVI rA, imm   | rA = zero_ext(imm)
 0100  | ADDI rA, rB, im| rA = rB + zero_ext(imm)
 0101  | SUBI rA, rB, im| rA = rB - zero_ext(imm)
 0110  | AND rA, rB     | rA = rA & rB
 0111  | OR  rA, rB     | rA = rA | rB
 1000  | XOR rA, rB     | rA = rA ^ rB
 1001  | NOT rA         | rA = ~rA
 1010  | SHL rA, imm    | rA = rA << imm[4:0]
 1011  | SHR rA, imm    | rA = rA >> imm[4:0]
 1100  | MUL rA, rB     | {HI, rA} = rA * rB
 1101  | DIV rA, rB     | rA = rA / rB, HI = rA % rB
 1110  | IO  rA, rB     | rB[0]=0: IN (rA=data_in)
       |                | rB[0]=1: OUT (data_out=rA)
 1111  | BRANCH         | rA selects type:
       |  JMP  imm      |  rA=0: PC = imm[6:0]
       |  BEQ rB, imm   |  rA=1: if reg[rB]==0, PC = imm[6:0]
       |  BNE rB, imm   |  rA=2: if reg[rB]!=0, PC = imm[6:0]
       |  HALT          |  rA=3: stop execution
```
