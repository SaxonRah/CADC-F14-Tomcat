# CADC-F14-Tomcat

A 20-bit microprocessor in Verilog, inspired by the Central Air Data Computer from the F-14 Tomcat.

The CADC is widely considered one of the first microprocessors; predating the Intel 4004; but it wasn't really a single chip. It was a collection of ICs designed to compute air data (Mach, altitude, etc.) for the F-14's flight control system. This project asks: what if that 20-bit architecture had been generalized into a real microprocessor? What if history went differently and a 20-bit computer was developed off the back of the F-14 program?

This is an extremely difficult project with tons of liberties taken from a lack of information and documentation. Reverse engineering the die photos instead of relying on the reports and manuals will be the most accurate path to creating a CADC and generalizing a system; but that's the pipe dream branch. The CATC branch is what actually exists.

![CADC System Outline](https://github.com/SaxonRah/CADC-F14-Tomcat/blob/main/fig_outline.png?raw=true)

---

## Branches

### CADC Branch (pipe dream)
A one-to-one, pure Verilog implementation of the entire CADC system. You would need PMOD hardware for A/D, sensors, and vendor-specific stuff for a demo. Maybe someday.

### CATC Branch (functional)
General purpose 20-bit microprocessor and microcontroller implementation in pure Verilog. This is the working branch.

---

## CATC Architecture

The CATC is a single-cycle Harvard architecture 20-bit microcontroller.

### Core
- **20-bit data path** with 20-bit instruction word
- **16 general-purpose registers** (R0–R15), R0 hardwired to zero
- **R15** is the dedicated stack pointer, initialized to top of SRAM
- **12-bit program counter** - 4096-word instruction ROM
- **HI register** for multiply upper bits and divide remainder
- **Flags register** (Z, N) set by CMP/CMPI, used by conditional branches
- **Interrupt support** with vectored entry, automatic PC save/restore, and global enable

### Arithmetic Units
- **PMU** (Parallel Multiply Unit); 20×20 → 40-bit combinational multiply
- **PDU** (Parallel Division Unit); 20÷20 restoring division with divide-by-zero guard

### Memory Map
| Address Range | Region |
|---------------|--------|
| 0–119 | Internal SRAM (120 words) |
| 120 | GPIO_OUT (R/W) |
| 121 | GPIO_IN (read-only) |
| 122 | TIMER_VAL (read-only, auto-reload counter) |
| 123 | TIMER_CTRL (write: bit 0 = enable, bit 1 = IRQ enable) |
| 124 | TIMER_CMP (R/W, interrupt fires on match) |
| 125 | IRQ_FLAGS (read: pending flags; write 1 to clear) |
| 126–127 | Reserved |
| 128+ | External memory bus |

Register-indirect LOAD/STORE (`[rB + imm]`) opens the full 20-bit address space. With LUI to build upper addresses and ADDI for the lower bits, you can reach any word in a 1M-word space. The top module exposes `ext_addr`, `ext_wdata`, `ext_rdata`, `ext_we`, and `ext_re`; wire up whatever RAM you want.

### Interrupts
- Vector at address 1 (address 0 is the reset jump)
- On entry: push PC to stack, SP--, clear IE, jump to vector
- ISR must clear IRQ_FLAGS before RETI or the interrupt re-fires immediately
- RETI: pop PC from stack, SP++, set IE (atomic return + re-enable)
- Timer auto-reloads on compare match and fires an edge-triggered interrupt

### Instruction Set

See [`InstructionEncodingReference.md`](InstructionEncodingReference.md) for the full ISA encoding.
```
Opcode | Mnemonic  | Operation
-------|-----------|------------------------------------------
 0000  | MISC      | NOP, MFHI, PUSH, POP, CMP, CMPI, EI, DI, LUI
 0001  | LOAD      | rA = mem[rB + imm]
 0010  | STORE     | mem[rB + imm] = rA
 0011  | MOVI      | rA = zero_ext(imm)
 0100  | ADDI      | rA = rB + zero_ext(imm)
 0101  | SUBI      | rA = rB - zero_ext(imm)
 0110  | AND       | rA = rA & rB
 0111  | OR        | rA = rA | rB
 1000  | XOR       | rA = rA ^ rB
 1001  | NOT       | rA = ~rA
 1010  | SHL       | rA = rA << imm[4:0]
 1011  | SHR       | rA = rA >> imm[4:0]
 1100  | MUL       | {HI, rA} = rA * rB
 1101  | DIV       | rA = rA / rB, HI = rA % rB
 1110  | IO        | IN / OUT (selected by rB[0])
 1111  | BRANCH    | JMP, BEQ, BNE, BGT, BLT, BGE, BLE, CALL, RET, RETI, HALT
```

---

## Files

| File | Description |
|------|-------------|
| `CATC.v` | Processor core; register file, ALU, memory, PC, interrupt logic |
| `CATC_top.v` | Top-level module wiring ROM to CPU with external bus |
| `PMU.v` | Parallel Multiply Unit (20×20 combinational) |
| `PDU.v` | Parallel Division Unit (restoring, with div-by-zero guard) |
| `ROM.v` | 4096-word async-read instruction ROM, loaded from `program.mem` |
| `CATCTest_tb.v` | Testbench with external RAM model, pass/fail checks, cycle trace |
| `program.mem` | Test program exercising all opcodes, interrupts, and external RAM |
| `InstructionEncodingReference.md` | Full ISA encoding reference |

---

## Status

The CATC has not been compiled or tested in a simulator yet, but the design should be close to functional. The test program exercises every feature: ALU ops, multiply/divide with MFHI, stack push/pop around a CALL/RET subroutine, CMP with flag-driven conditional branches, LUI + register-indirect store/load to external RAM, GPIO writes, timer configuration with interrupts, and HALT.

### What's next
- **Assembler** - the ISA is stable enough to warrant one, so you're not hand-encoding hex
- **Simulation** - compile and run in Icarus Verilog or Verilator, fix whatever breaks
- **More peripherals** - UART, SPI, or additional timer channels via the memory-mapped bus
- **FPGA target** - get it running on real hardware

---

## References

- [firstmicroprocessor.com; Info and Powerpoint on the F-14 CADC](https://firstmicroprocessor.com/wp-content/uploads/2020/02/2013powerpoint.ppt) ([archived site](https://web.archive.org/web/20240118055150/https://firstmicroprocessor.com/?doing_wp_cron=1705556352.5010390281677246093750))
- [Ken Shirriff; Reverse-engineering the Bendix Central Air Data Computer](https://www.righto.com/2023/10/bendix-cadc-reverse-engineering.html)
- [NAVAIRDEVCEN; Dynamic Flight Simulator F-14 (PDF)](https://apps.dtic.mil/sti/tr/pdf/ADA327438.pdf)
- [Advanced Aircraft Electrical System (AAES) for F-14 (PDF)](https://apps.dtic.mil/sti/tr/pdf/ADA047858.pdf)
- [NATOPS Flight Manual; Navy Model F-14D Aircraft (PDF)](https://info.publicintelligence.net/F14AAD-1.pdf)
- [NASA; Advanced Flight Control System Study Final Report (PDF)](https://core.ac.uk/download/pdf/42853936.pdf)
