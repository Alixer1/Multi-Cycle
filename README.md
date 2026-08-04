# MIPS 32-Bit Multi-Cycle Processor

![Verilog](https://img.shields.io/badge/Language-Verilog-blue.svg)
![Tools](https://img.shields.io/badge/Tools-ModelSim%20%7C%20Quartus-orange.svg)
![Architecture](https://img.shields.io/badge/Architecture-MIPS%20Multi--Cycle-brightgreen.svg)
![Status](https://img.shields.io/badge/Status-Completed-success.svg)

## 📌 Overview

This repository contains the design, hardware description, and simulation of a **32-bit Multi-Cycle MIPS Processor**. 

Unlike single-cycle processors where every instruction takes a single long clock cycle, this multi-cycle implementation breaks instruction execution into multiple shorter clock cycles. By reusing key hardware components (such as a single ALU and a unified memory unit) across different clock cycles, this design optimizes hardware resource utilization while maintaining architectural accuracy.

---

## 🏗️ Architecture & Datapath

The processor is directed by a **Finite State Machine (FSM)** based Control Unit that generates control signals step-by-step for each execution phase.

### Full Datapath Diagram
![MIPS Multi-Cycle Datapath](full%20datapath.png)

### Key Architectural Highlights:
- **Unified Memory Architecture**: A single memory unit handles both instruction fetching and data reads/writes in separate cycles.
- **Shared ALU**: A single Arithmetic Logic Unit executes address computation, branch comparisons, and arithmetic operations.
- **Internal Storage Registers**: Intermediate registers (`IR`, `MDR`, `A`, `B`, `ALUOut`) hold intermediate values between cycles.
- **FSM Control Unit**: Steers execution states dynamically according to the instruction opcode and function codes.

---

## ⚡ Supported Instruction Set

The processor implements key MIPS instructions across R-type, I-type, and J-type formats:

| Instruction | Type | Opcode / Funct | Description |
| :--- | :---: | :---: | :--- |
| **`ADD`** | R-Type | `0x00 / 0x20` | `Reg[rd] = Reg[rs] + Reg[rt]` |
| **`SUB`** | R-Type | `0x00 / 0x22` | `Reg[rd] = Reg[rs] - Reg[rt]` |
| **`AND`** | R-Type | `0x00 / 0x24` | `Reg[rd] = Reg[rs] & Reg[rt]` |
| **`OR`**  | R-Type | `0x00 / 0x25` | `Reg[rd] = Reg[rs] | Reg[rt]` |
| **`SLT`** | R-Type | `0x00 / 0x2A` | `Reg[rd] = (Reg[rs] < Reg[rt]) ? 1 : 0` |
| **`LW`**  | I-Type | `0x23` | Load Word from Memory into Register |
| **`SW`**  | I-Type | `0x2B` | Store Word from Register to Memory |
| **`BEQ`** | I-Type | `0x04` | Branch if Equal (`if Reg[rs] == Reg[rt] PC = PC + offset`) |
| **`J`**   | J-Type | `0x02` | Jump to Target Address |

---

## 🔄 Execution Stages (FSM States)

Each instruction progresses through a subset of 5 execution stages:

1. **Instruction Fetch (IF)**:
   - `IR = Memory[PC]`
   - `PC = PC + 4`
2. **Instruction Decode & Register Read (ID)**:
   - `A = Reg[IR[25:21]]`
   - `B = Reg[IR[20:16]]`
   - `ALUOut = PC + (SignExtend(IR[15:0]) << 2)`
3. **Execution, Memory Address Computation, or Branch Completion (EX)**:
   - Memory Ref: `ALUOut = A + SignExtend(IR[15:0])`
   - R-type: `ALUOut = A op B`
   - Branch: `if (A == B) PC = ALUOut`
   - Jump: `PC = {PC[31:28], IR[25:0], 2'b00}`
4. **Memory Access or R-type Completion (MEM / WB)**:
   - Memory Read: `MDR = Memory[ALUOut]`
   - Memory Write: `Memory[ALUOut] = B`
   - R-type Writeback: `Reg[IR[15:11]] = ALUOut`
5. **Memory Read Write-Back (WB)**:
   - Load Writeback: `Reg[IR[20:16]] = MDR`

---

## 📁 Repository Content

- **`full datapath.png`**: Complete datapath schematic diagram.
- **`Aliasghar report.docx`**: Full technical documentation and project report.
- **`README.md`**: Project summary and repository guide.

---

## 🛠️ Simulation & Setup

To simulate the processor waveforms using **ModelSim** or **Icarus Verilog**:

1. Clone the repository:
   ```bash
   git clone [https://github.com/Alixer1/MultiCycle.git](https://github.com/Alixer1/MultiCycle.git)
   cd MultiCycle
