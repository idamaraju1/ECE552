# Step 1: Adding Pipeline Registers to Your Design

## Part I: Four Pipeline Register Modules to Create

### **1. IF_ID Pipeline Register**

```verilog
`default_nettype none
module IF_ID_reg (
    input  wire        i_clk,
    input  wire        i_rst,
    // Input (from IF stage)
    input  wire [31:0] i_pc,           // From: o_imem_raddr
    input  wire [31:0] i_instruction,  // From: i_imem_rdata
    // Output (to ID stage)
    output reg  [31:0] o_pc,
    output reg  [31:0] o_instruction
);
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_pc <= 32'h0;
            o_instruction <= 32'h00000013; // NOP (addi x0, x0, 0)
        end else begin
            o_pc <= i_pc;
            o_instruction <= i_instruction;
        end
    end
endmodule
`default_nettype wire
```

### **2. ID_EX Pipeline Register**

```verilog
`default_nettype none
module ID_EX_reg (
    input  wire        i_clk,
    input  wire        i_rst,
    
    // === Data Signals ===
    input  wire [31:0] i_pc,              // From: IF_ID.o_pc
    input  wire [31:0] i_rs1_rdata,       // From: rf.o_rs1_rdata
    input  wire [31:0] i_rs2_rdata,       // From: rf.o_rs2_rdata
    input  wire [31:0] i_immediate,       // From: ImmGen.o_immediate
    input  wire [31:0] i_instruction,     // From: IF_ID.o_instruction (for later load/store)
    
    // === Register Addresses ===
    input  wire [ 4:0] i_rs1_addr,        // From: IF_ID.o_instruction[19:15]
    input  wire [ 4:0] i_rs2_addr,        // From: IF_ID.o_instruction[24:20]
    input  wire [ 4:0] i_rd_addr,         // From: IF_ID.o_instruction[11:7]
    
    // === EX Stage Control Signals ===
    input  wire        i_ALUSrc1,         // From: Control.o_ALUSrc1
    input  wire        i_ALUSrc2,         // From: Control.o_ALUSrc2
    input  wire [ 3:0] i_alu_ctrl,        // From: ALU_control.o_alu_ctrl
    input  wire        i_is_bne,          // From: ALU_control.o_is_bne
    input  wire        i_lui,             // From: Control.o_lui
    input  wire        i_Branch,          // From: Control.o_Branch
    input  wire        i_Jump,            // From: Control.o_Jump
    
    // === MEM Stage Control Signals ===
    input  wire        i_dmem_ren,        // From: Control.o_dmem_ren
    input  wire        i_dmem_wen,        // From: Control.o_dmem_wen
    
    // === WB Stage Control Signals ===
    input  wire        i_RegWrite,        // From: Control.o_RegWrite
    input  wire        i_MemtoReg,        // From: Control.o_MemtoReg
    
    // === Output (to EX stage) ===
    output reg  [31:0] o_pc,
    output reg  [31:0] o_rs1_rdata,
    output reg  [31:0] o_rs2_rdata,
    output reg  [31:0] o_immediate,
    output reg  [31:0] o_instruction,
    
    output reg  [ 4:0] o_rs1_addr,
    output reg  [ 4:0] o_rs2_addr,
    output reg  [ 4:0] o_rd_addr,
    
    output reg         o_ALUSrc1,
    output reg         o_ALUSrc2,
    output reg  [ 3:0] o_alu_ctrl,
    output reg         o_is_bne,
    output reg         o_lui,
    output reg         o_Branch,
    output reg         o_Jump,
    
    output reg         o_dmem_ren,
    output reg         o_dmem_wen,
    
    output reg         o_RegWrite,
    output reg         o_MemtoReg
);
    always @(posedge i_clk) begin
        if (i_rst) begin
            // Data signals
            o_pc <= 32'h0;
            o_rs1_rdata <= 32'h0;
            o_rs2_rdata <= 32'h0;
            o_immediate <= 32'h0;
            o_instruction <= 32'h00000013;
            
            // Addresses
            o_rs1_addr <= 5'h0;
            o_rs2_addr <= 5'h0;
            o_rd_addr <= 5'h0;
            
            // Control signals (all zero = NOP)
            o_ALUSrc1 <= 1'b0;
            o_ALUSrc2 <= 1'b0;
            o_alu_ctrl <= 4'h0;
            o_is_bne <= 1'b0;
            o_lui <= 1'b0;
            o_Branch <= 1'b0;
            o_Jump <= 1'b0;
            o_dmem_ren <= 1'b0;
            o_dmem_wen <= 1'b0;
            o_RegWrite <= 1'b0;  // Important: no register write
            o_MemtoReg <= 1'b0;
        end else begin
            o_pc <= i_pc;
            o_rs1_rdata <= i_rs1_rdata;
            o_rs2_rdata <= i_rs2_rdata;
            o_immediate <= i_immediate;
            o_instruction <= i_instruction;
            
            o_rs1_addr <= i_rs1_addr;
            o_rs2_addr <= i_rs2_addr;
            o_rd_addr <= i_rd_addr;
            
            o_ALUSrc1 <= i_ALUSrc1;
            o_ALUSrc2 <= i_ALUSrc2;
            o_alu_ctrl <= i_alu_ctrl;
            o_is_bne <= i_is_bne;
            o_lui <= i_lui;
            o_Branch <= i_Branch;
            o_Jump <= i_Jump;
            
            o_dmem_ren <= i_dmem_ren;
            o_dmem_wen <= i_dmem_wen;
            
            o_RegWrite <= i_RegWrite;
            o_MemtoReg <= i_MemtoReg;
        end
    end
endmodule
`default_nettype wire
```

### **3. EX_MEM Pipeline Register**

```verilog
`default_nettype none
module EX_MEM_reg (
    input  wire        i_clk,
    input  wire        i_rst,
    
    // === Data Signals ===
    input  wire [31:0] i_alu_result,       // From: ALU.o_result
    input  wire [31:0] i_rs2_rdata,        // From: ID_EX.o_rs2_rdata (for store)
    input  wire [31:0] i_pc_plus_4,        // From: ID_EX.o_pc + 4 (for JAL/JALR)
    input  wire [31:0] i_branch_target,    // From: ID_EX.o_pc + ID_EX.o_immediate (branch target)
    input  wire        i_branch_condition, // From: ALU.o_jump_condition
    input  wire [31:0] i_instruction,      // From: ID_EX.o_instruction
    
    // === Register Address ===
    input  wire [ 4:0] i_rd_addr,          // From: ID_EX.o_rd_addr
    
    // === MEM Stage Control Signals ===
    input  wire        i_dmem_ren,         // From: ID_EX.o_dmem_ren
    input  wire        i_dmem_wen,         // From: ID_EX.o_dmem_wen
    input  wire        i_Branch,           // From: ID_EX.o_Branch
    input  wire        i_Jump,             // From: ID_EX.o_Jump
    input  wire        i_is_bne,           // From: ID_EX.o_is_bne
    
    // === WB Stage Control Signals ===
    input  wire        i_RegWrite,         // From: ID_EX.o_RegWrite
    input  wire        i_MemtoReg,         // From: ID_EX.o_MemtoReg
    
    // === Output (to MEM stage) ===
    output reg  [31:0] o_alu_result,
    output reg  [31:0] o_rs2_rdata,
    output reg  [31:0] o_pc_plus_4,
    output reg  [31:0] o_branch_target,
    output reg         o_branch_condition,
    output reg  [31:0] o_instruction,
    
    output reg  [ 4:0] o_rd_addr,
    
    output reg         o_dmem_ren,
    output reg         o_dmem_wen,
    output reg         o_Branch,
    output reg         o_Jump,
    output reg         o_is_bne,
    
    output reg         o_RegWrite,
    output reg         o_MemtoReg
);
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_alu_result <= 32'h0;
            o_rs2_rdata <= 32'h0;
            o_pc_plus_4 <= 32'h0;
            o_branch_target <= 32'h0;
            o_branch_condition <= 1'b0;
            o_instruction <= 32'h00000013;
            
            o_rd_addr <= 5'h0;
            
            o_dmem_ren <= 1'b0;
            o_dmem_wen <= 1'b0;
            o_Branch <= 1'b0;
            o_Jump <= 1'b0;
            o_is_bne <= 1'b0;
            
            o_RegWrite <= 1'b0;
            o_MemtoReg <= 1'b0;
        end else begin
            o_alu_result <= i_alu_result;
            o_rs2_rdata <= i_rs2_rdata;
            o_pc_plus_4 <= i_pc_plus_4;
            o_branch_target <= i_branch_target;
            o_branch_condition <= i_branch_condition;
            o_instruction <= i_instruction;
            
            o_rd_addr <= i_rd_addr;
            
            o_dmem_ren <= i_dmem_ren;
            o_dmem_wen <= i_dmem_wen;
            o_Branch <= i_Branch;
            o_Jump <= i_Jump;
            o_is_bne <= i_is_bne;
            
            o_RegWrite <= i_RegWrite;
            o_MemtoReg <= i_MemtoReg;
        end
    end
endmodule
`default_nettype wire
```

### **4. MEM_WB Pipeline Register**

```verilog
`default_nettype none
module MEM_WB_reg (
    input  wire        i_clk,
    input  wire        i_rst,
    
    // === Data Signals ===
    input  wire [31:0] i_load_data,        // From: load_data (after Read Data Extraction)
    input  wire [31:0] i_alu_result,       // From: EX_MEM.o_alu_result
    input  wire [31:0] i_pc_plus_4,        // From: EX_MEM.o_pc_plus_4
    input  wire [31:0] i_instruction,      // From: EX_MEM.o_instruction
    
    // === Register Address ===
    input  wire [ 4:0] i_rd_addr,          // From: EX_MEM.o_rd_addr
    
    // === Source Register Addresses and Data (for retire output) ===
    input  wire [ 4:0] i_rs1_addr,
    input  wire [ 4:0] i_rs2_addr,
    input  wire [31:0] i_rs1_rdata,
    input  wire [31:0] i_rs2_rdata,
    input  wire [31:0] i_pc,
    
    // === WB Stage Control Signals ===
    input  wire        i_RegWrite,         // From: EX_MEM.o_RegWrite
    input  wire        i_MemtoReg,         // From: EX_MEM.o_MemtoReg
    input  wire        i_Jump,             // From: EX_MEM.o_Jump
    
    // === Output (to WB stage) ===
    output reg  [31:0] o_load_data,
    output reg  [31:0] o_alu_result,
    output reg  [31:0] o_pc_plus_4,
    output reg  [31:0] o_instruction,
    
    output reg  [ 4:0] o_rd_addr,
    
    output reg  [ 4:0] o_rs1_addr,
    output reg  [ 4:0] o_rs2_addr,
    output reg  [31:0] o_rs1_rdata,
    output reg  [31:0] o_rs2_rdata,
    output reg  [31:0] o_pc,
    
    output reg         o_RegWrite,
    output reg         o_MemtoReg,
    output reg         o_Jump
);
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_load_data <= 32'h0;
            o_alu_result <= 32'h0;
            o_pc_plus_4 <= 32'h0;
            o_instruction <= 32'h00000013;
            
            o_rd_addr <= 5'h0;
            
            o_rs1_addr <= 5'h0;
            o_rs2_addr <= 5'h0;
            o_rs1_rdata <= 32'h0;
            o_rs2_rdata <= 32'h0;
            o_pc <= 32'h0;
            
            o_RegWrite <= 1'b0;
            o_MemtoReg <= 1'b0;
            o_Jump <= 1'b0;
        end else begin
            o_load_data <= i_load_data;
            o_alu_result <= i_alu_result;
            o_pc_plus_4 <= i_pc_plus_4;
            o_instruction <= i_instruction;
            
            o_rd_addr <= i_rd_addr;
            
            o_rs1_addr <= i_rs1_addr;
            o_rs2_addr <= i_rs2_addr;
            o_rs1_rdata <= i_rs1_rdata;
            o_rs2_rdata <= i_rs2_rdata;
            o_pc <= i_pc;
            
            o_RegWrite <= i_RegWrite;
            o_MemtoReg <= i_MemtoReg;
            o_Jump <= i_Jump;
        end
    end
endmodule
`default_nettype wire
```

---

## Part II: Modifying hart.v - Detailed Connection Guide

Below are the key modifications to hart.v. I'll mark each change:

```verilog
module hart #(
    parameter RESET_ADDR = 32'h00000000
) (
    // ... all ports remain unchanged ...
);

    ////////////////////////////////////////////////////////////////////////////////
    // IF/ID Pipeline Register
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] IF_ID_pc;
    wire [31:0] IF_ID_instruction;
    
    IF_ID_reg IF_ID (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_pc(o_imem_raddr),           // From PC module output
        .i_instruction(i_imem_rdata),   // From instruction memory
        .o_pc(IF_ID_pc),
        .o_instruction(IF_ID_instruction)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // ID Stage: Control Unit
    ////////////////////////////////////////////////////////////////////////////////
    wire       RegWrite_ID;
    wire [5:0] inst_format_ID;
    wire       ALUSrc1_ID;
    wire       ALUSrc2_ID;
    wire [1:0] ALUop_ID;
    wire       lui_ID;
    wire       MemtoReg_ID;
    wire       Jump_ID;
    wire       Branch_ID;
    wire       dmem_ren_ID;
    wire       dmem_wen_ID;
    
    ctrl Control (
        .i_inst(IF_ID_instruction),      // ← CHANGED: from IF/ID register
        .i_o_retire_trap(o_retire_trap),
        .o_RegWrite(RegWrite_ID),
        .o_inst_format(inst_format_ID),
        .o_ALUSrc1(ALUSrc1_ID),
        .o_ALUSrc2(ALUSrc2_ID),
        .o_ALUop(ALUop_ID),
        .o_lui(lui_ID),
        .o_dmem_ren(dmem_ren_ID),
        .o_dmem_wen(dmem_wen_ID),
        .o_MemtoReg(MemtoReg_ID),
        .o_Jump(Jump_ID),
        .o_Branch(Branch_ID),
        .o_retire_halt(o_retire_halt)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // ID Stage: RegisterFile
    ////////////////////////////////////////////////////////////////////////////////
    wire [4:0] rs1_addr_ID;
    wire [4:0] rs2_addr_ID;
    wire [4:0] rd_addr_ID;
    wire [31:0] rs1_rdata_ID;
    wire [31:0] rs2_rdata_ID;
    
    assign rs1_addr_ID = IF_ID_instruction[19:15];  // ← CHANGED: from IF/ID
    assign rs2_addr_ID = IF_ID_instruction[24:20];  // ← CHANGED: from IF/ID
    assign rd_addr_ID  = IF_ID_instruction[11:7];   // ← CHANGED: from IF/ID
    
    // Note: Set BYPASS_EN to 0 for Step 1, change to 1 after Step 2
    rf #(.BYPASS_EN(0)) rf (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_rs1_raddr(rs1_addr_ID),
        .i_rs2_raddr(rs2_addr_ID),
        .i_rd_waddr(MEM_WB_rd_addr),    // ← CHANGED: from MEM/WB
        .i_rd_wdata(wb_data),            // ← CHANGED: from WB stage
        .o_rs1_rdata(rs1_rdata_ID),
        .o_rs2_rdata(rs2_rdata_ID)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // ID Stage: ImmGen
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] immediate_ID;
    imm ImmGen (
        .i_inst(IF_ID_instruction),      // ← CHANGED: from IF/ID
        .i_format(inst_format_ID),
        .o_immediate(immediate_ID)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // ID Stage: ALU Control
    ////////////////////////////////////////////////////////////////////////////////
    wire [3:0] alu_ctrl_ID;
    wire       is_bne_ID;
    alu_ctrl ALU_control (
        .i_ALUop(ALUop_ID),
        .i_funct3(IF_ID_instruction[14:12]),     // ← CHANGED: from IF/ID
        .i_funct7_bit5(IF_ID_instruction[30]),   // ← CHANGED: from IF/ID
        .o_alu_ctrl(alu_ctrl_ID),
        .o_is_bne(is_bne_ID)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // ID/EX Pipeline Register
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] ID_EX_pc;
    wire [31:0] ID_EX_rs1_rdata;
    wire [31:0] ID_EX_rs2_rdata;
    wire [31:0] ID_EX_immediate;
    wire [31:0] ID_EX_instruction;
    wire [4:0]  ID_EX_rs1_addr;
    wire [4:0]  ID_EX_rs2_addr;
    wire [4:0]  ID_EX_rd_addr;
    wire        ID_EX_ALUSrc1;
    wire        ID_EX_ALUSrc2;
    wire [3:0]  ID_EX_alu_ctrl;
    wire        ID_EX_is_bne;
    wire        ID_EX_lui;
    wire        ID_EX_Branch;
    wire        ID_EX_Jump;
    wire        ID_EX_dmem_ren;
    wire        ID_EX_dmem_wen;
    wire        ID_EX_RegWrite;
    wire        ID_EX_MemtoReg;
    
    ID_EX_reg ID_EX (
        .i_clk(i_clk),
        .i_rst(i_rst),
        // Data signals
        .i_pc(IF_ID_pc),
        .i_rs1_rdata(rs1_rdata_ID),
        .i_rs2_rdata(rs2_rdata_ID),
        .i_immediate(immediate_ID),
        .i_instruction(IF_ID_instruction),
        // Addresses
        .i_rs1_addr(rs1_addr_ID),
        .i_rs2_addr(rs2_addr_ID),
        .i_rd_addr(rd_addr_ID),
        // Control signals
        .i_ALUSrc1(ALUSrc1_ID),
        .i_ALUSrc2(ALUSrc2_ID),
        .i_alu_ctrl(alu_ctrl_ID),
        .i_is_bne(is_bne_ID),
        .i_lui(lui_ID),
        .i_Branch(Branch_ID),
        .i_Jump(Jump_ID),
        .i_dmem_ren(dmem_ren_ID),
        .i_dmem_wen(dmem_wen_ID),
        .i_RegWrite(RegWrite_ID),
        .i_MemtoReg(MemtoReg_ID),
        // Outputs
        .o_pc(ID_EX_pc),
        .o_rs1_rdata(ID_EX_rs1_rdata),
        .o_rs2_rdata(ID_EX_rs2_rdata),
        .o_immediate(ID_EX_immediate),
        .o_instruction(ID_EX_instruction),
        .o_rs1_addr(ID_EX_rs1_addr),
        .o_rs2_addr(ID_EX_rs2_addr),
        .o_rd_addr(ID_EX_rd_addr),
        .o_ALUSrc1(ID_EX_ALUSrc1),
        .o_ALUSrc2(ID_EX_ALUSrc2),
        .o_alu_ctrl(ID_EX_alu_ctrl),
        .o_is_bne(ID_EX_is_bne),
        .o_lui(ID_EX_lui),
        .o_Branch(ID_EX_Branch),
        .o_Jump(ID_EX_Jump),
        .o_dmem_ren(ID_EX_dmem_ren),
        .o_dmem_wen(ID_EX_dmem_wen),
        .o_RegWrite(ID_EX_RegWrite),
        .o_MemtoReg(ID_EX_MemtoReg)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // EX Stage: ALU
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] alu_result_EX;
    wire        branch_condition_EX;
    
    alu ALU (
        .i_op1(ID_EX_ALUSrc1 ? (ID_EX_lui ? 32'd0 : ID_EX_pc) : ID_EX_rs1_rdata),  // ← CHANGED
        .i_op2(ID_EX_ALUSrc2 ? ID_EX_immediate : ID_EX_rs2_rdata),                 // ← CHANGED
        .i_opsel(ID_EX_alu_ctrl),                                                   // ← CHANGED
        .i_is_bne(ID_EX_is_bne),                                                    // ← CHANGED
        .o_result(alu_result_EX),
        .o_jump_condition(branch_condition_EX)
    );
    
    // Calculate branch target and PC+4
    wire [31:0] branch_target_EX;
    wire [31:0] pc_plus_4_EX;
    assign branch_target_EX = ID_EX_pc + ID_EX_immediate;
    assign pc_plus_4_EX = ID_EX_pc + 32'd4;

    ////////////////////////////////////////////////////////////////////////////////
    // EX/MEM Pipeline Register
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] EX_MEM_alu_result;
    wire [31:0] EX_MEM_rs2_rdata;
    wire [31:0] EX_MEM_pc_plus_4;
    wire [31:0] EX_MEM_branch_target;
    wire        EX_MEM_branch_condition;
    wire [31:0] EX_MEM_instruction;
    wire [4:0]  EX_MEM_rd_addr;
    wire        EX_MEM_dmem_ren;
    wire        EX_MEM_dmem_wen;
    wire        EX_MEM_Branch;
    wire        EX_MEM_Jump;
    wire        EX_MEM_is_bne;
    wire        EX_MEM_RegWrite;
    wire        EX_MEM_MemtoReg;
    
    EX_MEM_reg EX_MEM (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_alu_result(alu_result_EX),
        .i_rs2_rdata(ID_EX_rs2_rdata),
        .i_pc_plus_4(pc_plus_4_EX),
        .i_branch_target(branch_target_EX),
        .i_branch_condition(branch_condition_EX),
        .i_instruction(ID_EX_instruction),
        .i_rd_addr(ID_EX_rd_addr),
        .i_dmem_ren(ID_EX_dmem_ren),
        .i_dmem_wen(ID_EX_dmem_wen),
        .i_Branch(ID_EX_Branch),
        .i_Jump(ID_EX_Jump),
        .i_is_bne(ID_EX_is_bne),
        .i_RegWrite(ID_EX_RegWrite),
        .i_MemtoReg(ID_EX_MemtoReg),
        // Outputs
        .o_alu_result(EX_MEM_alu_result),
        .o_rs2_rdata(EX_MEM_rs2_rdata),
        .o_pc_plus_4(EX_MEM_pc_plus_4),
        .o_branch_target(EX_MEM_branch_target),
        .o_branch_condition(EX_MEM_branch_condition),
        .o_instruction(EX_MEM_instruction),
        .o_rd_addr(EX_MEM_rd_addr),
        .o_dmem_ren(EX_MEM_dmem_ren),
        .o_dmem_wen(EX_MEM_dmem_wen),
        .o_Branch(EX_MEM_Branch),
        .o_Jump(EX_MEM_Jump),
        .o_is_bne(EX_MEM_is_bne),
        .o_RegWrite(EX_MEM_RegWrite),
        .o_MemtoReg(EX_MEM_MemtoReg)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // MEM Stage: Data Memory Access
    ////////////////////////////////////////////////////////////////////////////////
    // Calculate aligned address
    assign o_dmem_addr = {EX_MEM_alu_result[31:2], 2'b00};  // ← CHANGED
    
    // Byte offset
    wire [1:0] byte_offset_MEM;
    assign byte_offset_MEM = EX_MEM_alu_result[1:0];        // ← CHANGED
    
    // Mask adjustment - using instruction from EX_MEM
    assign o_dmem_mask = 
        (EX_MEM_instruction[6:0] == 7'b0100011 && EX_MEM_instruction[14:12] == 3'b000) ? (4'b0001 << byte_offset_MEM) :
        (EX_MEM_instruction[6:0] == 7'b0000011 && EX_MEM_instruction[14:12] == 3'b000) ? (4'b0001 << byte_offset_MEM) :
        (EX_MEM_instruction[6:0] == 7'b0000011 && EX_MEM_instruction[14:12] == 3'b100) ? (4'b0001 << byte_offset_MEM) :
        (EX_MEM_instruction[6:0] == 7'b0100011 && EX_MEM_instruction[14:12] == 3'b001) ? (byte_offset_MEM[1] ? 4'b1100 : 4'b0011) :
        (EX_MEM_instruction[6:0] == 7'b0000011 && EX_MEM_instruction[14:12] == 3'b001) ? (byte_offset_MEM[1] ? 4'b1100 : 4'b0011) :
        (EX_MEM_instruction[6:0] == 7'b0000011 && EX_MEM_instruction[14:12] == 3'b101) ? (byte_offset_MEM[1] ? 4'b1100 : 4'b0011) :
        4'b1111;
    
    // Write data adjustment - using rs2_rdata from EX_MEM
    assign o_dmem_wdata = 
        (EX_MEM_instruction[6:0] == 7'b0100011 && EX_MEM_instruction[14:12] == 3'b000) ? (EX_MEM_rs2_rdata << (byte_offset_MEM * 8)) :
        (EX_MEM_instruction[6:0] == 7'b0100011 && EX_MEM_instruction[14:12] == 3'b001) ? (EX_MEM_rs2_rdata << (byte_offset_MEM[1] * 16)) :
        EX_MEM_rs2_rdata;
    
    assign o_dmem_ren = EX_MEM_dmem_ren;  // ← CHANGED
    assign o_dmem_wen = EX_MEM_dmem_wen;  // ← CHANGED
    
    // Load data extraction
    wire [31:0] load_data_MEM;
    assign load_data_MEM = 
        (EX_MEM_instruction[14:12] == 3'b010) ? i_dmem_rdata :
        (EX_MEM_instruction[14:12] == 3'b001) ? 
            (byte_offset_MEM[1] ? {{16{i_dmem_rdata[31]}}, i_dmem_rdata[31:16]} :
                                 {{16{i_dmem_rdata[15]}}, i_dmem_rdata[15:0]}) :
        (EX_MEM_instruction[14:12] == 3'b101) ?
            (byte_offset_MEM[1] ? {16'd0, i_dmem_rdata[31:16]} :
                                 {16'd0, i_dmem_rdata[15:0]}) :
        (EX_MEM_instruction[14:12] == 3'b000) ?
            (byte_offset_MEM == 2'b00 ? {{24{i_dmem_rdata[7]}}, i_dmem_rdata[7:0]} :
             byte_offset_MEM == 2'b01 ? {{24{i_dmem_rdata[15]}}, i_dmem_rdata[15:8]} :
             byte_offset_MEM == 2'b10 ? {{24{i_dmem_rdata[23]}}, i_dmem_rdata[23:16]} :
                                       {{24{i_dmem_rdata[31]}}, i_dmem_rdata[31:24]}) :
        (byte_offset_MEM == 2'b00 ? {24'd0, i_dmem_rdata[7:0]} :
         byte_offset_MEM == 2'b01 ? {24'd0, i_dmem_rdata[15:8]} :
         byte_offset_MEM == 2'b10 ? {24'd0, i_dmem_rdata[23:16]} :
                                   {24'd0, i_dmem_rdata[31:24]});

    ////////////////////////////////////////////////////////////////////////////////
    // MEM/WB Pipeline Register
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] MEM_WB_load_data;
    wire [31:0] MEM_WB_alu_result;
    wire [31:0] MEM_WB_pc_plus_4;
    wire [31:0] MEM_WB_instruction;
    wire [4:0]  MEM_WB_rd_addr;
    wire [4:0]  MEM_WB_rs1_addr;
    wire [4:0]  MEM_WB_rs2_addr;
    wire [31:0] MEM_WB_rs1_rdata;
    wire [31:0] MEM_WB_rs2_rdata;
    wire [31:0] MEM_WB_pc;
    wire        MEM_WB_RegWrite;
    wire        MEM_WB_MemtoReg;
    wire        MEM_WB_Jump;
    
    // To pass retire information, we need to propagate rs1/rs2 addresses and data through the pipeline
    // These signals need to be added to ID/EX and EX/MEM as well (simplified here with direct ID stage signals)
    MEM_WB_reg MEM_WB (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_load_data(load_data_MEM),
        .i_alu_result(EX_MEM_alu_result),
        .i_pc_plus_4(EX_MEM_pc_plus_4),
        .i_instruction(EX_MEM_instruction),
        .i_rd_addr(EX_MEM_rd_addr),
        // These need to be passed down from ID stage through the pipeline
        .i_rs1_addr(ID_EX_rs1_addr),  // Need to add these signals to ID_EX and EX_MEM
        .i_rs2_addr(ID_EX_rs2_addr),
        .i_rs1_rdata(ID_EX_rs1_rdata),
        .i_rs2_rdata(ID_EX_rs2_rdata),
        .i_pc(ID_EX_pc),
        .i_RegWrite(EX_MEM_RegWrite),
        .i_MemtoReg(EX_MEM_MemtoReg),
        .i_Jump(EX_MEM_Jump),
        // Outputs
        .o_load_data(MEM_WB_load_data),
        .o_alu_result(MEM_WB_alu_result),
        .o_pc_plus_4(MEM_WB_pc_plus_4),
        .o_instruction(MEM_WB_instruction),
        .o_rd_addr(MEM_WB_rd_addr),
        .o_rs1_addr(MEM_WB_rs1_addr),
        .o_rs2_addr(MEM_WB_rs2_addr),
        .o_rs1_rdata(MEM_WB_rs1_rdata),
        .o_rs2_rdata(MEM_WB_rs2_rdata),
        .o_pc(MEM_WB_pc),
        .o_RegWrite(MEM_WB_RegWrite),
        .o_MemtoReg(MEM_WB_MemtoReg),
        .o_Jump(MEM_WB_Jump)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // WB Stage: Writeback Data Selection
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] wb_data;
    assign wb_data = 
        (MEM_WB_Jump) ? MEM_WB_pc_plus_4 :
        (~MEM_WB_MemtoReg) ? MEM_WB_alu_result :
        MEM_WB_load_data;

    ////////////////////////////////////////////////////////////////////////////////
    // PC Update Logic - Branch Decision Completed in EX Stage
    ////////////////////////////////////////////////////////////////////////////////
    wire        pc_src;
    wire        branch_taken;
    wire [31:0] next_pc;
    
    // Branch decision
    assign branch_taken = EX_MEM_is_bne ? ~EX_MEM_branch_condition : EX_MEM_branch_condition;
    assign pc_src = (EX_MEM_Branch & branch_taken) | EX_MEM_Jump;
    
    // Calculate next_pc (considering JALR LSB clearing)
    wire [31:0] jump_target;
    assign jump_target = (EX_MEM_Jump & ~EX_MEM_instruction[3]) ? 
                         {EX_MEM_alu_result[31:1], 1'b0} :  // JALR
                         EX_MEM_alu_result;                  // JAL (alu_result = pc + imm)
    
    assign next_pc = o_retire_halt ? o_imem_raddr :
                     pc_src ? (EX_MEM_Jump ? jump_target : EX_MEM_branch_target) :
                     o_imem_raddr + 32'd4;
    
    pc PC (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_next_pc(next_pc),
        .o_pc(o_imem_raddr),
        .o_retire_valid(o_retire_valid)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Retire Outputs - From MEM/WB Stage
    ////////////////////////////////////////////////////////////////////////////////
    assign o_retire_inst = MEM_WB_instruction;
    assign o_retire_pc = MEM_WB_pc;
    assign o_retire_next_pc = MEM_WB_Jump ? MEM_WB_pc_plus_4 :
                              o_imem_raddr + 32'd4;  // Simplified version
    assign o_retire_rs1_raddr = MEM_WB_rs1_addr;
    assign o_retire_rs2_raddr = MEM_WB_rs2_addr;
    assign o_retire_rs1_rdata = MEM_WB_rs1_rdata;
    assign o_retire_rs2_rdata = MEM_WB_rs2_rdata;
    assign o_retire_rd_waddr = (MEM_WB_RegWrite) ? MEM_WB_rd_addr : 5'd0;
    assign o_retire_rd_wdata = wb_data;

    ////////////////////////////////////////////////////////////////////////////////
    // Trap Detection - Using MEM Stage Data
    ////////////////////////////////////////////////////////////////////////////////
    trap Trap(
        .i_inst(EX_MEM_instruction),
        .i_dmem_addr(EX_MEM_alu_result),
        .i_imem_addr(EX_MEM_branch_target),  // Or use other appropriate PC value
        .o_trap(o_retire_trap)
    );

endmodule
```

---

## Part III: Key Notes

### 1. **Register File Bypassing**
For Step 1, set `BYPASS_EN = 0`:
```verilog
rf #(.BYPASS_EN(0)) rf (
```

### 2. **Additional Signals to Pass Through Pipeline**
To correctly output retire signals, you need to add to ID_EX and EX_MEM registers:
- `rs1_addr`
- `rs2_addr`
- `rs1_rdata`
- `rs2_rdata`
- `pc`

### 3. **JAL Instruction Handling**
JAL branch target calculation is completed in EX stage:
```verilog
// ALU inputs should be PC and immediate
// JAL: target = PC + immediate
```

### 4. **Remember to Insert NOPs in Test Programs**
Based on the earlier analysis, insert 2 NOPs between dependent instructions.

---

Would you like me to:
1. Fully modify ID_EX and EX_MEM registers to propagate signals needed for retire?
2. Draw a complete modified datapath diagram?
3. Provide specific test program examples?