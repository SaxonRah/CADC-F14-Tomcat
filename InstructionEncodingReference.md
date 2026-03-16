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


# program.mem — loaded by ROM via $readmemh
```
Addr | Hex   | Assembly                | Effect
-----|-------|-------------------------|---------------------------
0    | 3100A | MOVI  R1, 10            | R1 = 10
1    | 32003 | MOVI  R2, 3             | R2 = 3
2    | 43105 | ADDI  R3, R1, 5         | R3 = 15
3    | 54302 | SUBI  R4, R3, 2         | R4 = 13
4    | C1200 | MUL   R1, R2            | R1 = 30, HI = 0
5    | D3200 | DIV   R3, R2            | R3 = 5, HI = 0
6    | 05000 | MFHI  R5                | R5 = HI = 0
7    | 75200 | OR    R5, R2            | R5 = 0 | 3 = 3
8    | 86500 | XOR   R6, R5            | R6 = 0 ^ 3 = 3
9    | 96000 | NOT   R6                | R6 = ~3 = FFFFC
10   | A2002 | SHL   R2, 2             | R2 = 3 << 2 = 12
11   | B2001 | SHR   R2, 1             | R2 = 12 >> 1 = 6
12   | 21000 | STORE R1, [0]           | mem[0] = 30
13   | 17000 | LOAD  R7, [0]           | R7 = 30
14   | E7100 | OUT   R7                | data_out = 30
15   | 39000 | MOVI  R9, 0             | R9 = 0
16   | F1914 | BEQ   R9, 20            | R9==0 → jump to addr 20
17   | 3A063 | MOVI  R10, 99           | (skipped)
18   | 3A063 | MOVI  R10, 99           | (skipped)
19   | 3A063 | MOVI  R10, 99           | (skipped)
20   | E3100 | OUT   R3                | data_out = 5
21   | 3B001 | MOVI  R11, 1            | R11 = 1
22   | F2B18 | BNE   R11, 24           | R11!=0 → jump to addr 24
23   | 3A063 | MOVI  R10, 99           | (skipped)
24   | F0019 | JMP   25                | unconditional jump
25   | F3000 | HALT                    | stop
```

```
3100A
32003
43105
54302
C1200
D3200
05000
75200
86500
96000
A2002
B2001
21000
17000
E7100
39000
F1914
3A063
3A063
3A063
E3100
3B001
F2B18
3A063
F0019
F3000
```
