# CHEATOID VIRTUAL MACHINE (CVM)

*A Turing-complete, feature-rich, object-oriented Virtual Machine in pure Lua*

## Complete Documentation

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Installation & Usage](#installation--usage)
4. [Memory Model](#memory-model)
5. [Register Set](#register-set)
6. [Opcode Reference](#opcode-reference)
7. [Assembly Language](#assembly-language)
8. [System Calls](#system-calls)
9. [API Reference](#api-reference)
10. [Turing Completeness Proof](#turing-completeness-proof)
11. [SOLID & DRY Principles](#made-with-solid--dry-principles-in-mind)
12. [Examples](#examples)

---

## Overview

Cheatoid Virtual Machine (CVM) is a **Turing-complete**, **feature-rich**, **object-oriented** virtual machine implemented in pure Lua.  
It provides a robust platform for code execution with comprehensive debugging, memory management, and I/O capabilities.

### Key Features

- **16 General-Purpose Registers** (R0-R15)
- **256KB Addressable Memory** with heap allocation
- **70+ Opcodes** covering arithmetic, logic, control flow, memory, and I/O
- **Floating-Point Support** (IEEE 754 single precision)
- **Vector/SIMD Operations** for parallel processing
- **String Operations** for text processing
- **Built-in Assembler** with label and constant support
- **Built-in Disassembler** for debugging
- **Interactive Debugger** with breakpoints
- **System Call Interface** for I/O operations
- **Interrupt System** for exception handling

### Naming Convention

Canonical API names use `camelCase`. Deprecated `snake_case` aliases are kept for
compatibility and delegate to the `camelCase` implementation. New code should use
`camelCase`; examples below use canonical names (e.g. `readByte` not `read_byte`,
`loadProgram` not `load_program`, `isFlagSet` not `is_flag_set`).

---

## Architecture

### Memory Layout

```
| Address Range     | Description                  |
| ----------------- | ---------------------------- |
| 0x00000 - 0x0FFFF | Code Segment (64KB)          |
| 0x10000 - 0xEFFFF | Heap/Data Segment (896KB)    |
| 0xF0000 - 0xFFFFF | Stack (64KB, grows downward) |
```

### Register Set

| Register | Purpose                          |
| -------- | -------------------------------- |
| R0-R15   | General-purpose 32-bit registers |
| PC       | Program Counter                  |
| SP       | Stack Pointer                    |
| FP       | Frame Pointer                    |
| IR       | Instruction Register             |
| FLAGS    | Status flags register            |

### Flags Register

| Bit | Flag | Description                                 |
| --- | ---- | ------------------------------------------- |
| 0   | Z    | Zero flag - set when result is zero         |
| 1   | C    | Carry flag - set on unsigned overflow       |
| 2   | O    | Overflow flag - set on signed overflow      |
| 3   | N    | Negative flag - set when result is negative |
| 4   | I    | Interrupt enable flag                       |

---

## Installation & Usage

### Prerequisites

- Lua 5.3+ (LuaJIT/5.1 support is coming soon)

### Running the VM

```lua
-- Load the VM module
local CVM = require "vm" -- or dofile "vm.lua"

-- Create a new VM instance
local vm = CVM.VM.new()

-- Load and run a program
local assembler = CVM.Assembler.new()
local program = assembler:assemble([[
    MOV_RI R0, 42
    SYSCALL 0x01    ; Print integer
    HALT
]])

vm:loadProgram(program)
vm:run()
```

### Running Tests

```bash
lua vm.tests.lua
```

---

## Memory Model

### Memory Operations

```lua
-- Create memory instance
local memory = CVM.Memory.new()

-- Byte operations
memory:writeByte(0x1000, 0x42)
local byte = memory:readByte(0x1000)

-- Word operations (16-bit)
memory:writeWord(0x1000, 0x1234)
local word = memory:readWord(0x1000)

-- DWord operations (32-bit)
memory:writeDWord(0x1000, 0xDEADBEEF)
local dword = memory:readDWord(0x1000)

-- String operations
memory:writeString(0x1000, "Hello, World!")
local str = memory:readString(0x1000)

-- Heap allocation
local addr = memory:allocate(256)  -- Allocate 256 bytes
memory:free(addr)                  -- Free the block

-- Memory dump
print(memory:dump(0x1000, 64))     -- Hex dump
```

---

## Register Set

### Register Operations

```lua
local registers = CVM.Registers.new()

-- Get/set register values
registers:set(0, 12345)
local value = registers:get(0)

-- Flag operations
registers:setFlag(CVM.Registers.FLAG_Z, true)
local isZero = registers:isFlagSet(CVM.Registers.FLAG_Z)

-- Update flags based on result
registers:updateFlags(result, isSubtraction)

-- Print register state
print(registers:toString())
```

---

## Opcode Reference

### Control Operations (0x00-0x0F)

| Opcode | Name  | Operands | Description        |
| ------ | ----- | -------- | ------------------ |
| 0x00   | NOP   | 0        | No operation       |
| 0x01   | HALT  | 0        | Stop execution     |
| 0x02   | BREAK | 0        | Trigger breakpoint |
| 0x03   | WAIT  | 1        | Wait for N cycles  |

### Data Movement (0x10-0x2F)

| Opcode | Name     | Operands | Description                          |
| ------ | -------- | -------- | ------------------------------------ |
| 0x10   | MOV_RR   | 2        | Move register to register            |
| 0x11   | MOV_RI   | 2        | Move immediate to register           |
| 0x12   | LOAD_R   | 2        | Load from memory address in register |
| 0x13   | LOAD_I   | 3        | Load from immediate address          |
| 0x14   | STORE_R  | 2        | Store to memory address in register  |
| 0x15   | STORE_I  | 3        | Store to immediate address           |
| 0x16   | LOADB_R  | 2        | Load byte from memory                |
| 0x17   | STOREB_R | 2        | Store byte to memory                 |
| 0x18   | LOADW_R  | 2        | Load word (16-bit) from memory       |
| 0x19   | STOREW_R | 2        | Store word (16-bit) to memory        |
| 0x1A   | PUSH_R   | 1        | Push register onto stack             |
| 0x1B   | PUSH_I   | 1        | Push immediate value onto stack      |
| 0x1C   | POP_R    | 1        | Pop from stack into register         |
| 0x1D   | PEEK_R   | 1        | Peek at top of stack                 |
| 0x1E   | SWAP     | 2        | Swap values of two registers         |

### Arithmetic Operations (0x30-0x4F)

| Opcode | Name   | Operands | Description                      |
| ------ | ------ | -------- | -------------------------------- |
| 0x30   | ADD_RR | 3        | Add registers                    |
| 0x31   | ADD_RI | 3        | Add register and immediate       |
| 0x32   | SUB_RR | 3        | Subtract registers               |
| 0x33   | SUB_RI | 3        | Subtract immediate from register |
| 0x34   | MUL_RR | 3        | Multiply registers               |
| 0x35   | MUL_RI | 3        | Multiply register by immediate   |
| 0x36   | DIV_RR | 3        | Divide registers                 |
| 0x37   | DIV_RI | 3        | Divide register by immediate     |
| 0x38   | MOD_RR | 3        | Modulo of registers              |
| 0x39   | MOD_RI | 3        | Modulo of register by immediate  |
| 0x3A   | INC_R  | 1        | Increment register               |
| 0x3B   | DEC_R  | 1        | Decrement register               |
| 0x3C   | NEG_R  | 1        | Negate register                  |
| 0x3D   | ABS_R  | 1        | Absolute value                   |

### Bitwise Operations (0x50-0x5F)

| Opcode | Name   | Operands | Description                        |
| ------ | ------ | -------- | ---------------------------------- |
| 0x50   | AND_RR | 3        | Bitwise AND of registers           |
| 0x51   | AND_RI | 3        | Bitwise AND with immediate         |
| 0x52   | OR_RR  | 3        | Bitwise OR of registers            |
| 0x53   | OR_RI  | 3        | Bitwise OR with immediate          |
| 0x54   | XOR_RR | 3        | Bitwise XOR of registers           |
| 0x55   | XOR_RI | 3        | Bitwise XOR with immediate         |
| 0x56   | NOT_R  | 2        | Bitwise NOT                        |
| 0x57   | SHL_RR | 3        | Shift left by register value       |
| 0x58   | SHL_RI | 3        | Shift left by immediate            |
| 0x59   | SHR_RR | 3        | Shift right (logical) by register  |
| 0x5A   | SHR_RI | 3        | Shift right (logical) by immediate |
| 0x5B   | SAR_RR | 3        | Arithmetic shift right             |
| 0x5C   | ROL_RI | 3        | Rotate left                        |
| 0x5D   | ROR_RI | 3        | Rotate right                       |

### Comparison Operations (0x60-0x6F)

| Opcode | Name    | Operands | Description                     |
| ------ | ------- | -------- | ------------------------------- |
| 0x60   | CMP_RR  | 2        | Compare registers               |
| 0x61   | CMP_RI  | 2        | Compare register with immediate |
| 0x62   | TEST_RR | 2        | Test registers (bitwise AND)    |
| 0x63   | TEST_RI | 2        | Test register with immediate    |

### Control Flow - Jumps (0x70-0x7F)

| Opcode | Name  | Operands | Condition                  |
| ------ | ----- | -------- | -------------------------- |
| 0x70   | JMP_I | 1        | Unconditional (immediate)  |
| 0x71   | JMP_R | 1        | Unconditional (register)   |
| 0x72   | JZ_I  | 1        | Zero flag set              |
| 0x73   | JNZ_I | 1        | Zero flag not set          |
| 0x74   | JC_I  | 1        | Carry flag set             |
| 0x75   | JNC_I | 1        | Carry flag not set         |
| 0x76   | JN_I  | 1        | Negative flag set          |
| 0x77   | JNN_I | 1        | Negative flag not set      |
| 0x78   | JO_I  | 1        | Overflow flag set          |
| 0x79   | JNO_I | 1        | Overflow flag not set      |
| 0x7A   | JGT_I | 1        | Greater than (Z=0, N=0)    |
| 0x7B   | JLT_I | 1        | Less than (N=1)            |
| 0x7C   | JGE_I | 1        | Greater or equal (N=0)     |
| 0x7D   | JLE_I | 1        | Less or equal (Z=1 or N=1) |

### Subroutine Control (0x80-0x8F)

| Opcode | Name   | Operands | Description                            |
| ------ | ------ | -------- | -------------------------------------- |
| 0x80   | CALL_I | 1        | Call subroutine at immediate address   |
| 0x81   | CALL_R | 1        | Call subroutine at address in register |
| 0x82   | RET    | 0        | Return from subroutine                 |
| 0x83   | RET_I  | 1        | Return and pop N bytes                 |
| 0x84   | ENTER  | 1        | Enter new stack frame                  |
| 0x85   | LEAVE  | 0        | Leave current stack frame              |

### System and I/O (0x90-0x9F)

| Opcode | Name    | Operands | Description                    |
| ------ | ------- | -------- | ------------------------------ |
| 0x90   | SYSCALL | 1        | System call with function code |
| 0x91   | INT     | 1        | Software interrupt             |
| 0x92   | IRET    | 0        | Return from interrupt          |
| 0x93   | CLI     | 0        | Disable interrupts             |
| 0x94   | STI     | 0        | Enable interrupts              |

### Extended Operations (0xA0-0xAF)

| Opcode | Name   | Operands | Description            |
| ------ | ------ | -------- | ---------------------- |
| 0xA0   | MALLOC | 2        | Allocate memory        |
| 0xA1   | FREE   | 1        | Free allocated memory  |
| 0xA2   | MEMCPY | 3        | Copy memory block      |
| 0xA3   | MEMSET | 3        | Set memory block       |
| 0xA4   | MEMCMP | 4        | Compare memory blocks  |
| 0xA5   | LEA    | 2        | Load effective address |

### String Operations (0xB0-0xBF)

| Opcode | Name   | Operands | Description         |
| ------ | ------ | -------- | ------------------- |
| 0xB0   | STRLEN | 2        | Get string length   |
| 0xB1   | STRCPY | 2        | Copy string         |
| 0xB2   | STRCAT | 2        | Concatenate strings |
| 0xB3   | STRCMP | 3        | Compare strings     |

### Floating Point Operations (0xC0-0xCF)

| Opcode | Name    | Operands | Description                      |
| ------ | ------- | -------- | -------------------------------- |
| 0xC0   | FADD_RR | 3        | Floating-point add               |
| 0xC1   | FSUB_RR | 3        | Floating-point subtract          |
| 0xC2   | FMUL_RR | 3        | Floating-point multiply          |
| 0xC3   | FDIV_RR | 3        | Floating-point divide            |
| 0xC4   | FSQRT_R | 2        | Floating-point square root       |
| 0xC5   | FLOOR_R | 2        | Convert float to integer (floor) |
| 0xC6   | CEIL_R  | 2        | Convert float to integer (ceil)  |
| 0xC7   | ROUND_R | 2        | Convert float to integer (round) |
| 0xC8   | ITOF_R  | 2        | Convert integer to float         |

### Vector/SIMD Operations (0xD0-0xDF)

| Opcode | Name   | Operands | Description                   |
| ------ | ------ | -------- | ----------------------------- |
| 0xD0   | VADD_4 | 3        | Vector add 4 elements         |
| 0xD1   | VSUB_4 | 3        | Vector subtract 4 elements    |
| 0xD2   | VMUL_4 | 3        | Vector multiply 4 elements    |
| 0xD3   | VDP_4  | 3        | Vector dot product 4 elements |

### Extended Control (0xE0-0xEF)

| Opcode | Name   | Operands | Description                            |
| ------ | ------ | -------- | -------------------------------------- |
| 0xE0   | LOOP   | 2        | Decrement counter and jump if not zero |
| 0xE1   | LOOPZ  | 2        | Loop while zero flag set               |
| 0xE2   | LOOPNZ | 2        | Loop while zero flag not set           |

### Debug/Profiling (0xF0-0xFF)

| Opcode | Name          | Operands | Description                 |
| ------ | ------------- | -------- | --------------------------- |
| 0xF0   | DEBUG_REG     | 1        | Print register value        |
| 0xF1   | DEBUG_MEM     | 2        | Dump memory region          |
| 0xF2   | PROFILE_START | 0        | Start profiling timer       |
| 0xF3   | PROFILE_END   | 1        | End profiling, store result |
| 0xFF   | EXTENDED      | 0        | Extended opcode prefix      |

---

## Assembly Language

### Syntax

```asm
; This is a comment
label:              ; Labels end with colon
    MOV_RI R0, 42   ; Instructions
    ADD_RI R0, R0, 8
    JMP_I label     ; Jump to label

; Constants
MAX_VALUE = 100

; Data directives
.org 0x1000         ; Set origin address
message:
    .db "Hello", 0  ; Define bytes
numbers:
    .dw 1, 2, 3     ; Define words
values:
    .dd 100, 200    ; Define dwords
buffer:
    .resb 256       ; Reserve 256 bytes
```

### Addressing Modes

| Mode             | Syntax | Example           |
| ---------------- | ------ | ----------------- |
| Register         | Rn     | MOV_RR R0, R1     |
| Immediate        | value  | MOV_RI R0, 42     |
| Direct Address   | [addr] | LOAD_I R0, 0x1000 |
| Indirect Address | [Rn]   | LOAD_R R0, R1     |

### Number Formats

| Format      | Syntax | Example  |
| ----------- | ------ | -------- |
| Decimal     | number | 42       |
| Hexadecimal | 0x...  | 0x2A     |
| Binary      | 0b...  | 0b101010 |
| Character   | '...'  | 'A'      |

---

## System Calls

Invoke with `SYSCALL code`

| Code | Name              | Input     | Output    | Description        |
| ---- | ----------------- | --------- | --------- | ------------------ |
| 0x00 | SYS_EXIT          | -         | -         | Terminate program  |
| 0x01 | SYS_PRINT_INT     | R0        | -         | Print integer      |
| 0x02 | SYS_PRINT_CHAR    | R0        | -         | Print character    |
| 0x03 | SYS_PRINT_STRING  | R0 (addr) | -         | Print string       |
| 0x04 | SYS_PRINT_NEWLINE | -         | -         | Print newline      |
| 0x05 | SYS_READ_INT      | -         | R0        | Read integer       |
| 0x06 | SYS_READ_CHAR     | -         | R0        | Read character     |
| 0x07 | SYS_READ_STRING   | R0 (addr) | R1 (len)  | Read string        |
| 0x10 | SYS_TIME          | -         | R0        | Get Unix timestamp |
| 0x11 | SYS_CLOCK         | -         | R0        | Get milliseconds   |
| 0x20 | SYS_MALLOC        | R0 (size) | R1 (addr) | Allocate memory    |
| 0x21 | SYS_FREE          | R0 (addr) | -         | Free memory        |
| 0x30 | SYS_RANDOM        | -         | R0        | Random 32-bit      |
| 0x31 | SYS_RANDOM_RANGE  | R0, R1    | R2        | Random in range    |

---

## API Reference

### VM Class

```lua
local vm = CVM.VM.new()

-- Program loading
vm:loadProgram(bytecode, startAddress)
vm:loadFile(filename, startAddress)

-- Execution
vm:run(maxCycles)
vm:step()

-- State management
vm:reset()
vm:push(value)
vm:pop()
vm:peek()

-- Interrupts and syscalls
vm:syscall(code)
vm:interrupt(vector)

-- Debugging
vm:setBreakpoint(address)
vm:clearBreakpoint(address)
vm:toString()

-- Floating point conversion
vm:intToFloat(i)
vm:floatToInt(f)
```

### Memory Class

```lua
local memory = CVM.Memory.new(size)

-- Read operations
memory:readByte(address)
memory:readWord(address)
memory:readDWord(address)
memory:readString(address, maxLength)

-- Write operations
memory:writeByte(address, value)
memory:writeWord(address, value)
memory:writeDWord(address, value)
memory:writeString(address, string)

-- Heap management
memory:allocate(size)
memory:free(address)

-- Utilities
memory:clear()
memory:dump(start, length)
```

### Registers Class

```lua
local registers = CVM.Registers.new()

-- Register access
registers:get(index)
registers:set(index, value)

-- Flag operations
registers:isFlagSet(flag)
registers:setFlag(flag, value)
registers:updateFlags(result, isSubtraction)

-- State
registers:reset()
registers:toString()
```

### Assembler Class

```lua
local assembler = CVM.Assembler.new()
local bytecode = assembler:assemble(source)
```

### Disassembler Class

```lua
local disasm = CVM.Disassembler.new()
local assembly = disasm:disassemble(bytecode, startAddress)
```

### Debugger Class

```lua
local debugger = CVM.Debugger.new(vm)
debugger:start()  -- Interactive debug session
```

---

## Turing Completeness Proof

CVM is **Turing-complete** because it implements all three requirements:

### 1. Conditional Branching

```asm
; Multiple conditional jump instructions
JZ_I addr    ; Jump if zero
JNZ_I addr   ; Jump if not zero
JC_I addr    ; Jump if carry
JN_I addr    ; Jump if negative
JGT_I addr   ; Jump if greater than
JLT_I addr   ; Jump if less than
; ... and more
```

### 2. Arbitrary Memory Access

```asm
; Read/write any memory location
LOAD_I R0, 0x12345   ; Read from address
STORE_I 0x12345, R0  ; Write to address

; Indirect addressing
LOAD_R R0, R1        ; Read from address in register
STORE_R R0, R1       ; Write to address in register

; Dynamic heap allocation
SYSCALL 0x20         ; malloc
SYSCALL 0x21         ; free
```

### 3. Unbounded Iteration

```asm
; While loop pattern
loop:
    CMP_RI R0, 0
    JZ_I done
    ; ... loop body ...
    DEC_R R0
    JMP_I loop
done:

; For loop pattern
    MOV_RI R0, 10
for_loop:
    ; ... loop body ...
    LOOP R0, for_loop
```

### Example: Turing Machine Simulation

```asm
; This program simulates a simple Turing machine
; that increments a binary counter

    ; Initialize tape with "1011" (binary 11)
    MOV_RI R0, 0x3000   ; Tape address
    MOV_RI R1, 1
    STOREB_R R0, R1     ; tape[0] = 1

    ; Increment operation
    MOV_RI R2, 0x3000   ; Head position
    MOV_RI R3, 1        ; Carry = 1

increment:
    ; Read current cell
    LOADB_R R4, R2

    ; Add carry
    ADD_RR R4, R4, R3

    ; Check if overflow
    CMP_RI R4, 2
    JNZ_I no_carry

    ; Set to 0, keep carry
    MOV_RI R4, 0
    STOREB_R R2, R4
    INC_R R2            ; Move head
    JMP_I increment

no_carry:
    STOREB_R R2, R4
    HALT
```

---

## Made with SOLID & DRY principles in-mind

### Single Responsibility Principle (SRP)

Each module handles one concern:

- `Memory`: Memory access and heap management
- `Registers`: CPU register state
- `Assembler`: Assembly to bytecode conversion
- `Disassembler`: Bytecode to assembly conversion
- `Debugger`: Interactive debugging

### Open/Closed Principle (OCP)

The opcode system is extensible:

```lua
-- Adding new opcodes without modifying existing code
defineOpcode(0xE0, "CUSTOM_OP", 2, "Custom operation",
    function(vm, a, b)
        -- Custom implementation
    end)
```

### Liskov Substitution Principle (LSP)

All module interfaces are properly implemented and can be substituted with compatible implementations.

### Interface Segregation Principle (ISP)

Each module exposes only the necessary methods for its functionality.

### Dependency Inversion Principle (DIP)

High-level modules (VM) depend on abstractions (Memory, Registers interfaces).

### DRY (Don't Repeat Yourself)

- Common operations are factored into helper methods
- Opcode dispatch uses a table-driven approach
- Memory operations are centralized in the Memory module
- Flag updates use a single `updateFlags` method

---

## Examples

### Hello World

```asm
.org 0x1000
message:
    .db "Hello, World!", 0

.org 0x0000
    MOV_RI R0, message
    SYSCALL 0x03    ; Print string
    SYSCALL 0x04    ; Newline
    HALT
```

### Fibonacci

```asm
; Calculate Fibonacci(n)
    MOV_RI R0, 10       ; n = 10
    MOV_RI R1, 0        ; fib(n-2)
    MOV_RI R2, 1        ; fib(n-1)
    MOV_RI R3, 0        ; counter

loop:
    CMP_RR R3, R0
    JGE_I done
    
    ADD_RR R4, R1, R2   ; next = prev + current
    MOV_RR R1, R2
    MOV_RR R2, R4
    
    INC_R R3
    JMP_I loop

done:
    ; Result in R2
    SYSCALL 0x01
    HALT
```

### Factorial

```asm
; Calculate n!
    MOV_RI R0, 6        ; n = 6
    MOV_RI R1, 1        ; result = 1

loop:
    CMP_RI R0, 1
    JLE_I done
    
    MUL_RR R1, R1, R0   ; result *= n
    DEC_R R0
    JMP_I loop

done:
    ; Result in R1 (720)
    SYSCALL 0x01
    HALT
```

### Bubble Sort

```asm
; Sort array at R0, length R1
    MOV_RI R0, 0x2000   ; Array address
    MOV_RI R1, 8        ; Length

outer:
    MOV_RR R2, R1
    DEC_R R2
    MOV_RI R3, 0        ; i = 0
    
outer_check:
    CMP_RR R3, R2
    JGE_I done

inner:
    MOV_RI R4, 0        ; j = 0
    MOV_RR R5, R1
    SUB_RR R5, R5, R3
    DEC_R R5
    
inner_check:
    CMP_RR R4, R5
    JGE_I next_i
    
    ; Compare and swap arr[j], arr[j+1]
    ; ... implementation ...
    
    INC_R R4
    JMP_I inner_check

next_i:
    INC_R R3
    JMP_I outer_check

done:
    HALT
```

---

## License

MIT License - Feel free to use, modify, and distribute, just make sure to give credit :)
