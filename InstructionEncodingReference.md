# Instruction encoding reference

```
20-bit instruction word:
[19:16] opcode  [15:12] rA  [11:8] rB  [7:0] imm

R0  = hardwired zero (writes discarded)
R15 = stack pointer (SP), initialized to 119
PC  = 12 bits (4096-word instruction ROM)

Data address space (20-bit, from register-indirect addressing):
  0–119:   Internal SRAM (120 words)
  120–127: Peripheral registers
  128+:    External memory bus

Peripheral map:
  120: GPIO_OUT   (R/W)
  121: GPIO_IN    (read-only)
  122: TIMER_VAL  (read-only, auto-reload counter)
  123: TIMER_CTRL (write: bit0=enable, bit1=irq enable; resets counter)
  124: TIMER_CMP  (R/W: compare value, interrupt fires on match)
  125: IRQ_FLAGS  (read: bit0=timer pending; write 1 to clear)

Interrupt behavior:
  Vector at address 1 (address 0 = reset jump)
  On entry:  push PC to stack, SP--, clear IE, jump to vector
  ISR must clear IRQ_FLAGS before RETI
  RETI: pop PC from stack, SP++, set IE

 Opcode | Mnemonic              | Operation
--------|-----------------------|------------------------------------------
  0000  | MISC group (rB selects sub-function):
        |  rB=0: NOP/MFHI rA   | no-op (rA=0), rA = HI (rA!=0)
        |  rB=1: PUSH rA        | mem[SP] = rA, SP--
        |  rB=2: POP  rA        | SP++, rA = mem[SP]
        |  rB=3: CMP  rA, Rx    | flags ← rA - reg[imm[3:0]]
        |  rB=4: CMPI rA, imm   | flags ← rA - zero_ext(imm)
        |  rB=5: EI              | enable interrupts
        |  rB=6: DI              | disable interrupts
        |  rB=7: LUI  rA, imm   | rA = {imm, 12'b0}
  0001  | LOAD rA, [rB+imm]     | rA = mem[rB + zero_ext(imm)]
  0010  | STORE rA, [rB+imm]    | mem[rB + zero_ext(imm)] = rA
  0011  | MOVI rA, imm          | rA = zero_ext(imm)
  0100  | ADDI rA, rB, imm      | rA = rB + zero_ext(imm)
  0101  | SUBI rA, rB, imm      | rA = rB - zero_ext(imm)
  0110  | AND  rA, rB           | rA = rA & rB
  0111  | OR   rA, rB           | rA = rA | rB
  1000  | XOR  rA, rB           | rA = rA ^ rB
  1001  | NOT  rA               | rA = ~rA
  1010  | SHL  rA, imm          | rA = rA << imm[4:0]
  1011  | SHR  rA, imm          | rA = rA >> imm[4:0]
  1100  | MUL  rA, rB           | {HI, rA} = rA * rB
  1101  | DIV  rA, rB           | rA = rA / rB, HI = rA % rB
  1110  | IO   rA, rB           | rB[0]=0: IN (rA=data_in)
        |                       | rB[0]=1: OUT (data_out=rA)
  1111  | BRANCH group (rA selects type, target = {rB, imm} = 12-bit):
        |  rA=0:  JMP  target    | PC = target
        |  rA=1:  BEQ  rB, imm   | if flags.Z, PC = {0, imm} (8-bit)
        |  rA=2:  BNE  rB, imm   | if !flags.Z, PC = {0, imm} (8-bit)
        |  rA=3:  HALT            | stop execution
        |  rA=4:  BGT  target     | if Z=0 & N=0, PC = target
        |  rA=5:  BLT  target     | if N=1, PC = target
        |  rA=6:  BGE  target     | if N=0, PC = target
        |  rA=7:  BLE  target     | if Z=1 | N=1, PC = target
        |  rA=8:  CALL target     | push PC+1, SP--, PC = target
        |  rA=9:  RET             | SP++, PC = mem[SP]
        |  rA=10: RETI            | SP++, PC = mem[SP], IE = 1
```

# program.mem — loaded by ROM via $readmemh
```
=== Vector table ===
Addr | Hex   | Assembly                    | Effect
-----|-------|-----------------------------|-----------------------------
 0   | F0005 | JMP 5                       | reset → skip ISR, go to main

=== Timer ISR (vector at address 1) ===
 1   | 4DD01 | ADDI R13, R13, 1            | R13++ (interrupt counter)
 2   | 3C001 | MOVI R12, 1                 | R12 = 1
 3   | 2C07D | STORE R12, [R0+125]         | clear IRQ_FLAGS bit 0
 4   | FA000 | RETI                         | return from interrupt

=== Main program (address 5) ===
 5   | 3100A | MOVI R1, 10                 | R1 = 10
 6   | 32003 | MOVI R2, 3                  | R2 = 3
 7   | 43105 | ADDI R3, R1, 5              | R3 = 15
 8   | 54302 | SUBI R4, R3, 2              | R4 = 13
 9   | C1200 | MUL  R1, R2                 | R1 = 30, HI = 0
10   | D3200 | DIV  R3, R2                 | R3 = 5,  HI = 0
11   | 05000 | MFHI R5                     | R5 = 0

--- Stack and subroutine ---
12   | 01100 | PUSH R1                     | save R1 = 30
13   | 02100 | PUSH R2                     | save R2 = 3
14   | 31007 | MOVI R1, 7                  | R1 = 7
15   | F8037 | CALL 55                     | call subroutine (doubles R1)
16   | 02200 | POP  R2                     | restore R2 = 3
17   | 01200 | POP  R1                     | restore R1 = 30

--- CMP + flag branch ---
18   | 01302 | CMP  R1, R2                 | 30-3=27 → Z=0, N=0
19   | F4016 | BGT  22                     | Z=0 && N=0 → taken
20   | 3A063 | MOVI R10, 99                | (skipped)
21   | F0017 | JMP  23                     | (skipped)
22   | 3A02A | MOVI R10, 42                | R10 = 42

--- External memory test ---
23   | 0E701 | LUI  R14, 1                 | R14 = 0x01000 (4096)
24   | 2AE00 | STORE R10, [R14+0]          | ext_mem[4096] = 42
25   | 1BE00 | LOAD  R11, [R14+0]          | R11 = ext_mem[4096] = 42

--- GPIO peripheral output ---
26   | 2A078 | STORE R10, [R0+120]         | gpio_out = 42

--- Timer interrupt setup ---
27   | 38008 | MOVI R8, 8                  | timer compare = 8
28   | 2807C | STORE R8, [R0+124]          | TIMER_CMP = 8
29   | 38003 | MOVI R8, 3                  | enable=1, irq_en=1
30   | 2807B | STORE R8, [R0+123]          | TIMER_CTRL = 3 (start timer)
31   | 00500 | EI                           | enable global interrupts

--- Wait loop (timer fires interrupts during these NOPs) ---
32-51: NOP x20

--- Post-interrupt ---
52   | 00600 | DI                           | disable interrupts
53   | ED100 | OUT  R13                     | data_out = interrupt count
54   | F3000 | HALT                         | stop

--- Subroutine at address 55: double R1 ---
55   | A1001 | SHL  R1, 1                  | R1 <<= 1
56   | F9000 | RET                          | return

```

```
F0005
4DD01
3C001
2C07D
FA000
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
F8037
02200
01200
01302
F4016
3A063
F0017
3A02A
0E701
2AE00
1BE00
2A078
38008
2807C
38003
2807B
00500
00000
00000
00000
00000
00000
00000
00000
00000
00000
00000
00000
00000
00000
00000
00000
00000
00000
00000
00000
00000
00600
ED100
F3000
A1001
F9000
```
