## Botao: Current registers don't have reset signal!!! Please add

Based on the hart.v template's retire signal interface requirements and Project 5 documentation, let me **strictly** organize the signals needed for each pipeline register:

## Key Observation: What Does the Retire Interface Need?

The WB stage needs to output these retire signals:
- `o_retire_inst` → needs instruction
- `o_retire_rs1_raddr/rs2_raddr` → needs rs1_addr, rs2_addr
- `o_retire_rs1_rdata/rs2_rdata` → needs **original** rs1_rdata, rs2_rdata (read in ID stage)
- `o_retire_rd_waddr/rd_wdata` → needs rd_addr and writeback data
- `o_retire_dmem_*` → needs all dmem interface signals
- `o_retire_pc/next_pc` → needs PC and next PC

**Conclusion: Almost all signals must propagate to WB stage!**

---

## IF/ID Register

**Function:** IF stage fetches instruction, passes to ID stage

### Input Signals:
```
- i_clk
- i_imem_rdata[31:0]      // Instruction read from instruction memory
- i_pc[31:0]              // PC of current instruction
```

### Output Signals:
```
- o_instruction[31:0]     // Pass to ID stage
- o_pc[31:0]              // Pass to ID stage
```

---

## ID/EX Register

**Function:** ID stage decodes, reads registers, generates immediate, passes to EX stage

### Input Signals:
```
- i_clk
- i_pc[31:0]              // Must propagate to WB (retire_pc)
- i_pc_plus_4[31:0]       // For JAL/JALR writeback, also for retire_next_pc
- i_rs1_rdata[31:0]       // Must propagate to WB (retire_rs1_rdata)
- i_rs2_rdata[31:0]       // Must propagate to WB (retire_rs2_rdata)
- i_immediate[31:0]       // ALU operand
- i_rs1_addr[4:0]         // Must propagate to WB (retire_rs1_raddr)
- i_rs2_addr[4:0]         // Must propagate to WB (retire_rs2_raddr)
- i_rd_addr[4:0]          // Must propagate to WB (retire_rd_waddr)
- i_instruction[31:0]     // Must propagate to WB (retire_inst)

Control Signals:
- ALUSrc1, ALUSrc2        // Used in EX stage
- ALUOp, funct3, funct7_bit5  // ALU control
- Branch, Jump, is_jalr   // Branch/Jump control
- MemRead, MemWrite       // Must propagate to MEM and WB
- RegWrite, MemToReg      // Must propagate to WB
```

### Output Signals:
```
Corresponding o_ prefix signals
```

---

## EX/MEM Register

**Function:** EX stage performs ALU operation, branch resolution, passes to MEM stage

### Input Signals:
```
- i_clk
- i_alu_result[31:0]      // ALU result (could be address or writeback data)
- i_rs2_rdata[31:0]       // Store data + must propagate to WB (retire_rs2_rdata)
- i_rs1_rdata[31:0]       // Must propagate to WB (retire_rs1_rdata)
- i_pc_plus_4[31:0]       // JAL/JALR writeback + retire_next_pc
- i_pc[31:0]              // Must propagate to WB (retire_pc)
- i_instruction[31:0]     // Must propagate to WB (retire_inst)
- i_rs1_addr[4:0]         // Must propagate to WB (retire_rs1_raddr)
- i_rs2_addr[4:0]         // Must propagate to WB (retire_rs2_raddr)
- i_rd_addr[4:0]          // Must propagate to WB (retire_rd_waddr)

Control Signals:
- MemRead, MemWrite       // Used in MEM stage, must propagate to WB (retire_dmem_ren/wen)
- RegWrite, MemToReg      // Must propagate to WB
```

### Output Signals:
```
Corresponding o_ prefix signals
```

**Note:** All register addresses and data must propagate because retire needs them!

---

## MEM/WB Register

**Function:** MEM stage accesses data memory, passes to WB stage

### Input Signals:
```
- i_clk
- i_alu_result[31:0]      // Could be writeback data
- i_load_data[31:0]       // Data read from memory for load (Note: from external i_dmem_rdata, after processing)
- i_pc_plus_4[31:0]       // JAL/JALR writeback
- i_pc[31:0]              // retire_pc
- i_instruction[31:0]     // retire_inst
- i_rs1_addr[4:0]         // retire_rs1_raddr
- i_rs2_addr[4:0]         // retire_rs2_raddr
- i_rs1_rdata[31:0]       // retire_rs1_rdata
- i_rs2_rdata[31:0]       // retire_rs2_rdata
- i_rd_addr[4:0]          // retire_rd_waddr

Data Memory Interface Signals (for retire_dmem_*):
- i_dmem_addr[31:0]       // retire_dmem_addr
- i_dmem_mask[3:0]        // retire_dmem_mask
- i_dmem_ren              // retire_dmem_ren
- i_dmem_wen              // retire_dmem_wen
- i_dmem_rdata[31:0]      // retire_dmem_rdata
- i_dmem_wdata[31:0]      // retire_dmem_wdata

Control Signals:
- RegWrite                // Used in WB stage
- MemToReg                // Select writeback data
```

### Output Signals:
```
Corresponding o_ prefix signals, directly used to generate retire signals
```

---

## Signal Propagation Path Summary

| Signal | IF/ID | ID/EX | EX/MEM | MEM/WB | Purpose |
|--------|-------|-------|--------|--------|---------|
| **instruction** | ✓ | ✓ | ✓ | ✓ | retire_inst, field extraction |
| **pc** | ✓ | ✓ | ✓ | ✓ | retire_pc |
| **pc_plus_4** | - | ✓ | ✓ | ✓ | JAL/JALR writeback, retire_next_pc |
| **rs1_addr** | - | ✓ | ✓ | ✓ | retire_rs1_raddr |
| **rs2_addr** | - | ✓ | ✓ | ✓ | retire_rs2_raddr |
| **rs1_rdata** | - | ✓ | ✓ | ✓ | retire_rs1_rdata |
| **rs2_rdata** | - | ✓ | ✓ | ✓ | retire_rs2_rdata + store |
| **rd_addr** | - | ✓ | ✓ | ✓ | retire_rd_waddr |
| **immediate** | - | ✓ | - | - | ALU operand |
| **alu_result** | - | - | ✓ | ✓ | Writeback data/memory address |
| **load_data** | - | - | - | ✓ | Load writeback data |
| **dmem interface** | - | - | - | ✓ | retire_dmem_* |

---

## Important Reminders

1. **rs1_rdata and rs2_rdata must propagate all the way to WB**, even though they are consumed by ALU in EX stage
2. **All dmem interface signals must be latched in registers in MEM stage**, then passed to WB for retire
3. **instruction must propagate to all stages**, for control and retire
4. **Control signals also need to propagate through pipeline**, each stage only uses what it needs

This design ensures WB stage has sufficient information to generate all retire signals!

Good, let me reorganize the summary following your approach: **First create 4 pipeline register modules, then modify hart.v to connect datapath and control path**. This division of work is clearer!

---

## Overall Strategy

### Phase One: Create 4 Pipeline Register Modules (Independent Work)
### Phase Two: Modify hart.v to Connect All Paths (Core Work)

---

# Phase One: Create 4 Pipeline Register Modules

## Design Principles

Each module is a **pure register**:
- Input ports = all signals that need to be passed
- Output ports = corresponding output signals
- Function = latch inputs to outputs on clock rising edge
- **Contains no logic**, just a "relay station" for data transfer

---

## 1. IF/ID Register (`if_id.v`)

### Function
Latch instruction and PC from IF stage, pass to ID stage

### Port Design
```
Inputs:
- i_clk
- i_pc[31:0]              // PC of current instruction
- i_instruction[31:0]     // Instruction read from imem

Outputs:
- o_pc[31:0]
- o_instruction[31:0]
```

### Internal Implementation
```
A set of 32-bit registers for pc
A set of 32-bit registers for instruction
Latch on posedge clk
```

---

## 2. ID/EX Register (`id_ex.v`)

### Function
Latch all decoded information from ID stage, pass to EX stage

### Port Design (Critical! Most signals)
```
Inputs:
Data signals:
- i_clk
- i_pc[31:0]
- i_pc_plus_4[31:0]
- i_rs1_rdata[31:0]
- i_rs2_rdata[31:0]
- i_immediate[31:0]
- i_instruction[31:0]

Address signals:
- i_rs1_addr[4:0]
- i_rs2_addr[4:0]
- i_rd_addr[4:0]

Control signals (need to pass to EX/MEM/WB):
- i_alu_src1              // Used by EX
- i_alu_src2              // Used by EX
- i_alu_op[?:0]           // Used by EX (width depends on your design)
- i_branch                // Used by EX
- i_jump                  // Used by EX
- i_mem_read              // Used by MEM, needs to pass
- i_mem_write             // Used by MEM, needs to pass
- i_reg_write             // Used by WB, needs to pass
- i_mem_to_reg            // Used by WB, needs to pass
- ... other control signals in your design

Outputs:
Corresponding o_ prefix signals
```

### Key Points
- **All** control signals must be passed, as different stages use different control signals
- All addresses and data must be passed, as retire ultimately needs them

---

## 3. EX/MEM Register (`ex_mem.v`)

### Function
Latch ALU results from EX stage and signals that need to continue passing

### Port Design
```
Inputs:
Computation results:
- i_clk
- i_alu_result[31:0]      // ALU computation result

Data that needs to continue passing:
- i_rs1_rdata[31:0]       // Needed by retire
- i_rs2_rdata[31:0]       // Needed by store + retire
- i_pc[31:0]              // Needed by retire
- i_pc_plus_4[31:0]       // Possible writeback + needed by retire
- i_instruction[31:0]     // Needed by retire

Address signals:
- i_rs1_addr[4:0]         // Needed by retire
- i_rs2_addr[4:0]         // Needed by retire
- i_rd_addr[4:0]          // Needed by writeback + retire

Control signals (used by MEM and WB stages):
- i_mem_read
- i_mem_write
- i_reg_write
- i_mem_to_reg
- ... other passing control signals

Outputs:
Corresponding o_ prefix signals
```

---

## 4. MEM/WB Register (`mem_wb.v`)

### Function
Latch results from MEM stage and all signals needed by retire

### Port Design (Most Complex!)
```
Inputs:
Writeback data candidates:
- i_clk
- i_alu_result[31:0]      // Could be writeback data
- i_load_data[31:0]       // Writeback data for load
- i_pc_plus_4[31:0]       // Writeback data for JAL/JALR

Original data needed by retire:
- i_rs1_rdata[31:0]       // retire_rs1_rdata
- i_rs2_rdata[31:0]       // retire_rs2_rdata
- i_pc[31:0]              // retire_pc
- i_instruction[31:0]     // retire_inst

Address signals:
- i_rs1_addr[4:0]         // retire_rs1_raddr
- i_rs2_addr[4:0]         // retire_rs2_raddr
- i_rd_addr[4:0]          // retire_rd_waddr

Data memory interface (retire_dmem_*):
- i_dmem_addr[31:0]
- i_dmem_mask[3:0]
- i_dmem_ren
- i_dmem_wen
- i_dmem_rdata[31:0]
- i_dmem_wdata[31:0]

Control signals (used by WB):
- i_reg_write
- i_mem_to_reg

Outputs:
Corresponding o_ prefix signals
```

### Key Points
- This register is most complex because all signals needed by retire are here
- dmem interface signals need to be completely preserved

---

## Generic Template for Module Implementation

Each module has similar internal structure:
```
module xxx_stage (
    input wire clk,
    input wire [31:0] i_signal1,
    input wire [4:0] i_signal2,
    ...
    output reg [31:0] o_signal1,
    output reg [4:0] o_signal2,
    ...
);

always @(posedge clk) begin
    o_signal1 <= i_signal1;
    o_signal2 <= i_signal2;
    ...
end

endmodule
```

**Key Points:**
- All outputs are `reg` type
- All signals in the same `always @(posedge clk)` block
- No reset needed (initial state handled through software/nop)
- Step 1 doesn't need enable signal (add in Step 2)

---

# Phase Two: Modify hart.v to Connect Datapath and Control Path

After completing the 4 register modules, enter the core work: reorganize hart.v

---

## Overall Approach

1. **Keep existing module instances unchanged** (pc.v, rf.v, alu.v, ctrl.v, imm.v, etc.)
2. **Add 4 pipeline register instances**
3. **Reorganize signal flow**: single-cycle signal flow is cut by registers, changed to multi-cycle
4. **Organize code by stages**: divide hart.v code into 5 clear sections

---

## Modification Steps

### Step 1: Declare All Intermediate Signals

**Recommend using stage prefix naming:**

```
// IF stage signals
wire [31:0] if_pc;
wire [31:0] if_instruction;
wire [31:0] if_pc_plus_4;

// ID stage signals (IF/ID register outputs)
wire [31:0] id_pc;
wire [31:0] id_instruction;
wire [31:0] id_rs1_rdata;
wire [31:0] id_rs2_rdata;
wire [31:0] id_immediate;
wire [4:0] id_rs1_addr;
wire [4:0] id_rs2_addr;
wire [4:0] id_rd_addr;
wire [31:0] id_pc_plus_4;
// ID stage control signals
wire id_alu_src1, id_alu_src2, id_mem_read, id_mem_write, ...;

// EX stage signals (ID/EX register outputs)
wire [31:0] ex_pc;
wire [31:0] ex_alu_result;
wire [31:0] ex_rs1_rdata;
wire [31:0] ex_rs2_rdata;
wire [31:0] ex_pc_plus_4;
wire [4:0] ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
wire [31:0] ex_instruction;
wire ex_mem_read, ex_mem_write, ex_reg_write, ...;

// MEM stage signals (EX/MEM register outputs)
wire [31:0] mem_alu_result;
wire [31:0] mem_load_data;
wire [31:0] mem_rs1_rdata, mem_rs2_rdata;
wire [31:0] mem_pc, mem_pc_plus_4;
wire [4:0] mem_rs1_addr, mem_rs2_addr, mem_rd_addr;
wire [31:0] mem_instruction;
// MEM stage dmem interface
wire [31:0] mem_dmem_addr;
wire [3:0] mem_dmem_mask;
wire mem_dmem_ren, mem_dmem_wen;
wire [31:0] mem_dmem_wdata;

// WB stage signals (MEM/WB register outputs)
wire [31:0] wb_alu_result;
wire [31:0] wb_load_data;
wire [31:0] wb_pc_plus_4;
wire [31:0] wb_rs1_rdata, wb_rs2_rdata;
wire [31:0] wb_pc;
wire [4:0] wb_rs1_addr, wb_rs2_addr, wb_rd_addr;
wire [31:0] wb_instruction;
wire [31:0] wb_rd_wdata;
wire wb_reg_write;
// WB stage dmem interface (for retire)
wire [31:0] wb_dmem_addr;
wire [3:0] wb_dmem_mask;
wire wb_dmem_ren, wb_dmem_wen;
wire [31:0] wb_dmem_rdata, wb_dmem_wdata;
```

---

### Step 2: Organize IF Stage Logic

**IF stage tasks:**
1. PC module generates current PC
2. Output PC to instruction memory
3. Receive instruction
4. Calculate PC+4

```
Location: Before IF/ID register instance

Connections:
- PC module: outputs if_pc
- assign o_imem_raddr = if_pc;  // Drive top-level output
- assign if_instruction = i_imem_rdata;  // Receive from top-level input
- assign if_pc_plus_4 = if_pc + 4;  // Simple adder
```

**Note:**
- Step 1 can have PC increment by 4 every cycle (ignore branches)
- Branch handling implemented in Step 3

---

### Step 3: Instantiate IF/ID Register

```
Connections:
- Inputs: if_pc, if_instruction
- Outputs: id_pc, id_instruction
```

---

### Step 4: Organize ID Stage Logic

**ID stage tasks:**
1. Extract fields from instruction
2. Control module decodes to generate control signals
3. Register file read
4. ImmGen generates immediate

```
Location: Between IF/ID and ID/EX registers

Signal extraction:
- assign id_rs1_addr = id_instruction[19:15];
- assign id_rs2_addr = id_instruction[24:20];
- assign id_rd_addr = id_instruction[11:7];
- assign id_pc_plus_4 = id_pc + 4;  // Or pass from IF stage

Module instances:
- Control module:
  Input: id_instruction
  Output: id_alu_src1, id_alu_src2, id_mem_read, id_mem_write, id_reg_write, ...
  
- Register File module:
  Input: i_rs1_raddr = id_rs1_addr
         i_rs2_raddr = id_rs2_addr
         i_rd_waddr = wb_rd_addr  // From WB stage!
         i_rd_wdata = wb_rd_wdata  // From WB stage!
         i_rd_wen = wb_reg_write   // From WB stage!
  Output: id_rs1_rdata, id_rs2_rdata

- ImmGen module:
  Input: id_instruction
  Output: id_immediate
```

**Key Point:**
- Register file write port connects to WB stage!
- This forms a "feedback" path

---

### Step 5: Instantiate ID/EX Register

```
Connections:
Input: id_pc, id_pc_plus_4, id_rs1_rdata, id_rs2_rdata, id_immediate,
       id_instruction, id_rs1_addr, id_rs2_addr, id_rd_addr,
       all id_ control signals
     
Output: ex_pc, ex_pc_plus_4, ex_rs1_rdata, ex_rs2_rdata, ex_immediate,
        ex_instruction, ex_rs1_addr, ex_rs2_addr, ex_rd_addr,
        all ex_ control signals
```

---

### Step 6: Organize EX Stage Logic

**EX stage tasks:**
1. Select ALU operands (mux)
2. ALU computation
3. Branch condition check (can be simplified in Step 1)

```
Location: Between ID/EX and EX/MEM registers

ALU operand selection:
wire [31:0] alu_op1 = ex_alu_src1 ? ex_pc : ex_rs1_rdata;
wire [31:0] alu_op2 = ex_alu_src2 ? ex_immediate : ex_rs2_rdata;

ALU module:
  Input: alu_op1, alu_op2, ex_alu_op
  Output: ex_alu_result

Branch check: (can be simplified or ignored in Step 1)
wire branch_taken = ex_branch && (condition);
```

---

### Step 7: Instantiate EX/MEM Register

```
Connections:
Input: ex_alu_result, ex_rs1_rdata, ex_rs2_rdata,
       ex_pc, ex_pc_plus_4, ex_instruction,
       ex_rs1_addr, ex_rs2_addr, ex_rd_addr,
       ex_mem_read, ex_mem_write, ex_reg_write, ex_mem_to_reg
     
Output: mem_alu_result, mem_rs1_rdata, mem_rs2_rdata,
        mem_pc, mem_pc_plus_4, mem_instruction,
        mem_rs1_addr, mem_rs2_addr, mem_rd_addr,
        mem_mem_read, mem_mem_write, mem_reg_write, mem_mem_to_reg
```

---

### Step 8: Organize MEM Stage Logic

**MEM stage tasks:**
1. Process data memory address (alignment)
2. Process write data (shift)
3. Generate mask
4. Drive dmem interface
5. Process read data (extraction)

```
Location: Between EX/MEM and MEM/WB registers

Data memory address processing:
assign mem_dmem_addr = {mem_alu_result[31:2], 2'b00};  // Clear lower 2 bits

Write data processing:
assign mem_dmem_wdata = mem_rs2_rdata << (mem_alu_result[1:0] * 8);

Mask generation:
Generate based on mem_instruction's funct3 and mem_alu_result[1:0]

Drive top-level dmem interface:
assign o_dmem_addr = mem_dmem_addr;
assign o_dmem_ren = mem_mem_read;
assign o_dmem_wen = mem_mem_write;
assign o_dmem_wdata = mem_dmem_wdata;
assign o_dmem_mask = mem_dmem_mask;

Read data processing:
wire [31:0] raw_load_data = i_dmem_rdata;
Shift and sign/zero extend based on funct3 and address offset
assign mem_load_data = ... (processed load data);
```

---

### Step 9: Instantiate MEM/WB Register

```
Connections:
Input: mem_alu_result, mem_load_data,
       mem_rs1_rdata, mem_rs2_rdata,
       mem_pc, mem_pc_plus_4, mem_instruction,
       mem_rs1_addr, mem_rs2_addr, mem_rd_addr,
       mem_dmem_addr, mem_dmem_mask, mem_dmem_ren, mem_dmem_wen,
       mem_dmem_wdata, i_dmem_rdata,  // Note: rdata from top-level
       mem_reg_write, mem_mem_to_reg
     
Output: wb_alu_result, wb_load_data,
        wb_rs1_rdata, wb_rs2_rdata,
        wb_pc, wb_pc_plus_4, wb_instruction,
        wb_rs1_addr, wb_rs2_addr, wb_rd_addr,
        wb_dmem_addr, wb_dmem_mask, wb_dmem_ren, wb_dmem_wen,
        wb_dmem_wdata, wb_dmem_rdata,
        wb_reg_write, wb_mem_to_reg
```

---

### Step 10: Organize WB Stage Logic

**WB stage tasks:**
1. Select writeback data
2. Drive register file write port (already connected in ID stage)
3. Generate all retire signals

```
Location: After MEM/WB register

Writeback data selection:
assign wb_rd_wdata = wb_mem_to_reg ? wb_load_data : 
                     (is_jal_jalr ? wb_pc_plus_4 : wb_alu_result);

Generate retire signals:
assign o_retire_valid = 1'b1;  // Step 1 retires every cycle (no stall)
assign o_retire_inst = wb_instruction;
assign o_retire_trap = ... (trap detection logic);
assign o_retire_halt = (wb_instruction == 32'h00100073);  // ebreak
assign o_retire_rs1_raddr = wb_rs1_addr;
assign o_retire_rs2_raddr = wb_rs2_addr;
assign o_retire_rs1_rdata = wb_rs1_rdata;
assign o_retire_rs2_rdata = wb_rs2_rdata;
assign o_retire_rd_waddr = wb_rd_addr;
assign o_retire_rd_wdata = wb_rd_wdata;
assign o_retire_dmem_addr = wb_dmem_addr;
assign o_retire_dmem_mask = wb_dmem_mask;
assign o_retire_dmem_ren = wb_dmem_ren;
assign o_retire_dmem_wen = wb_dmem_wen;
assign o_retire_dmem_rdata = wb_dmem_rdata;
assign o_retire_dmem_wdata = wb_dmem_wdata;
assign o_retire_pc = wb_pc;
assign o_retire_next_pc = ... (computation logic);
```

---

## Summary of Key Modification Points

### 1. Register File Read/Write Connection
```
Read port: used in ID stage
Write port: driven in WB stage, but connected in ID stage's rf instance
Need to implement bypassing in rf.v
```

### 2. PC Update Logic
```
Step 1 simplified approach:
- PC increments by 4 every cycle
- Ignore branches (program avoids branches or manually inserts nop)

Complete approach (optional):
- Check branch_taken in EX stage
- Feedback to IF stage to update PC
- Flush IF/ID and ID/EX
```

### 3. Control Signal Propagation
```
Control generated in ID stage
Passed to EX through ID/EX
Passed to MEM through EX/MEM
Passed to WB through MEM/WB
Each stage only uses what it needs
```

### 4. Retire Signal Generation
```
All retire signals generated from WB stage signals
Ensure MEM/WB register contains all needed signals
```

---

## Code Organization Suggestions

**Structure of hart.v:**
```
module hart(...);

// ========== Signal Declarations ==========
// IF stage signals
// ID stage signals
// EX stage signals
// MEM stage signals
// WB stage signals

// ========== IF Stage Logic ==========
// PC module instance
// if_pc_plus_4 calculation
// imem interface drive

// ========== IF/ID Register ==========
if_id IF_ID_REG(...);

// ========== ID Stage Logic ==========
// Field extraction
// Control module instance
// Register File module instance
// ImmGen module instance

// ========== ID/EX Register ==========
id_ex ID_EX_REG(...);

// ========== EX Stage Logic ==========
// ALU operand mux
// ALU module instance
// Branch check logic

// ========== EX/MEM Register ==========
ex_mem EX_MEM_REG(...);

// ========== MEM Stage Logic ==========
// dmem address processing
// dmem write data processing
// dmem mask generation
// dmem interface drive
// load data processing

// ========== MEM/WB Register ==========
mem_wb MEM_WB_REG(...);

// ========== WB Stage Logic ==========
// Writeback data selection
// retire signal generation

endmodule
```

---

## Debugging Techniques

### 1. Modular Verification
- First verify the 4 register modules can pass data normally
- Test simple add instruction alone
- Gradually add other instruction types

### 2. Waveform Observation
Focus on:
- Position of same instruction across 5 cycles
- instruction value in each stage
- Register file read/write timing
- Correctness of retire signals

### 3. Compare with Single-Cycle
- Final results should match single-cycle
- Just delayed by 4 cycles

---

## Summary

**Workflow:**
1. **Phase One:** Create 4 independent pipeline register modules (.v files)
   - Write and test each module independently
   - Ensure complete port definitions
   
2. **Phase Two:** Modify hart.v
   - Declare all intermediate signals (named by stage)
   - Organize code in IF → ID → EX → MEM → WB order
   - Instantiate 4 registers, connect all signals
   - Generate retire signals

**Key Points:**
- Pipeline registers are pure registers, contain no logic
- All logic is in hart.v's respective stages
- Clear signal naming (stage prefixes)
- Control signals flow with data

This division makes each part's responsibility clear, facilitating implementation and debugging!