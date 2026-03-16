# Instruction encoding reference

```
20-bit instruction word:
[19:16] opcode  [15:12] rA  [11:8] rB  [7:0] imm

R15 is the stack pointer (SP), initialized to 123.
Data memory 0–123 is general purpose. 124–127 are memory-mapped peripherals.

 Opcode | Mnemonic             | Operation
--------|----------------------|---------------------------------------------
  0000  | MISC group (rB selects sub-function):
        |  rB=0: NOP/MFHI rA  | no-op (rA=0), rA = HI (rA!=0)
        |  rB=1: PUSH rA      | mem[SP] = rA, SP = SP - 1
        |  rB=2: POP  rA      | SP = SP + 1, rA = mem[SP]
        |  rB=3: CMP  rA, Rx  | flags ← rA - reg[imm[3:0]], no writeback
        |  rB=4: CMPI rA, imm | flags ← rA - zero_ext(imm), no writeback
  0001  | LOAD rA, [imm]       | rA = mem/periph[imm[6:0]]
  0010  | STORE rA, [imm]      | mem/periph[imm[6:0]] = rA
  0011  | MOVI rA, imm         | rA = zero_ext(imm)
  0100  | ADDI rA, rB, imm     | rA = rB + zero_ext(imm)
  0101  | SUBI rA, rB, imm     | rA = rB - zero_ext(imm)
  0110  | AND  rA, rB          | rA = rA & rB
  0111  | OR   rA, rB          | rA = rA | rB
  1000  | XOR  rA, rB          | rA = rA ^ rB
  1001  | NOT  rA              | rA = ~rA
  1010  | SHL  rA, imm         | rA = rA << imm[4:0]
  1011  | SHR  rA, imm         | rA = rA >> imm[4:0]
  1100  | MUL  rA, rB          | {HI, rA} = rA * rB
  1101  | DIV  rA, rB          | rA = rA / rB, HI = rA % rB
  1110  | IO   rA, rB          | rB[0]=0: IN (rA=data_in)
        |                      | rB[0]=1: OUT (data_out=rA)
  1111  | BRANCH group (rA selects type):
        |  rA=0:  JMP  imm     | PC = imm[6:0]
        |  rA=1:  BEQ  rB, imm | if reg[rB]==0, PC = imm[6:0]
        |  rA=2:  BNE  rB, imm | if reg[rB]!=0, PC = imm[6:0]
        |  rA=3:  HALT         | stop execution
        |  rA=4:  BGT  imm     | if Z==0 && N==0, PC = imm[6:0]
        |  rA=5:  BLT  imm     | if N==1, PC = imm[6:0]
        |  rA=6:  BGE  imm     | if N==0, PC = imm[6:0]
        |  rA=7:  BLE  imm     | if Z==1 || N==1, PC = imm[6:0]
        |  rA=8:  CALL imm     | mem[SP] = PC+1, SP--, PC = imm[6:0]
        |  rA=9:  RET          | SP++, PC = mem[SP]

Peripheral memory map:
  124 (0x7C): GPIO_OUT   (read/write)
  125 (0x7D): GPIO_IN    (read-only)
  126 (0x7E): TIMER_VAL  (read-only, free-running counter)
  127 (0x7F): TIMER_CTRL (write: bit 0 = enable, resets counter)

Flags register (set by CMP / CMPI only):
  Z — zero:     result == 0
  N — negative: result[19] == 1 (sign bit)
```


# program.mem — loaded by ROM via $readmemh
```
Addr | Hex   | Assembly               | Effect
-----|-------|------------------------|-------------------------------
 0   | 3100A | MOVI  R1, 10           | R1 = 10
 1   | 32003 | MOVI  R2, 3            | R2 = 3
 2   | 43105 | ADDI  R3, R1, 5        | R3 = 15
 3   | 54302 | SUBI  R4, R3, 2        | R4 = 13
 4   | C1200 | MUL   R1, R2           | R1 = 30, HI = 0
 5   | D3200 | DIV   R3, R2           | R3 = 5,  HI = 0
 6   | 05000 | MFHI  R5               | R5 = 0  (remainder from DIV)

--- Stack save before subroutine ---
 7   | 01100 | PUSH  R1               | mem[123] = 30, SP = 122
 8   | 02100 | PUSH  R2               | mem[122] = 3,  SP = 121

 9   | 31007 | MOVI  R1, 7            | R1 = 7
10   | F801E | CALL  30               | push PC+1(=11), SP=120, PC=30
       (execution jumps to subroutine at addr 30)
       (subroutine: SHL R1,1 → R1=14, then RET → PC=11, SP=121)

--- Stack restore ---
11   | 02200 | POP   R2               | SP = 122, R2 = mem[122] = 3
12   | 01200 | POP   R1               | SP = 123, R1 = mem[123] = 30

--- Flags-based branch ---
13   | 01302 | CMP   R1, R2           | 30 - 3 = 27 → Z=0, N=0
14   | F4011 | BGT   17               | Z=0 && N=0 → taken, PC = 17
15   | 3A063 | MOVI  R10, 99          | (skipped)
16   | F0012 | JMP   18               | (skipped)
17   | 3A02A | MOVI  R10, 42          | R10 = 42

--- Memory-mapped GPIO peripheral ---
18   | 2A07C | STORE R10, [124]       | gpio_out = 42

--- Memory-mapped timer peripheral ---
19   | 38001 | MOVI  R8, 1            | R8 = 1
20   | 2807F | STORE R8, [127]        | timer_en=1, counter reset
21   | 00000 | NOP                    | (timer ticks)
22   | 00000 | NOP                    | (timer ticks)
23   | 1907E | LOAD  R9, [126]        | R9 = timer_count (expect 2)
24   | E9100 | OUT   R9               | data_out = timer value

25   | F3000 | HALT                   | stop

--- Padding to subroutine ---
26–29: NOPs

--- Subroutine: double R1 ---
30   | A1001 | SHL   R1, 1            | R1 = R1 << 1
31   | F9000 | RET                    | pop return addr, jump back

```

```
3100A
32003
43105
54302
C1200
D3200
05000
01100
02100
31007
F801E
02200
01200
01302
F4011
3A063
F0012
3A02A
2A07C
38001
2807F
00000
00000
1907E
E9100
F3000
00000
00000
00000
00000
A1001
F9000
```
