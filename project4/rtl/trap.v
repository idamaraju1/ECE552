`default_nettype none
module trap(
    input  wire [31:0] i_inst,
    input  wire [31:0] dmem_addr, // need to check if it's an unaligned data memory access
    input  wire [31:0] imem_addr, // need to check if it's an unaligned instruction address on a taken branch or jump
    output wire        o_trap
);
    wire [6:0] opcode = i_inst[6:0];
    wire [2:0] funct3 = i_inst[14:12];
    wire [6:0] funct7 = i_inst[31:25];

    // illegal opcode detection
    wire illegal_opcode;
    assign illegal_opcode = ~(
        (opcode == 7'b0110011) || // R-type
        (opcode == 7'b0010011) || // I-type Immediate arithmetic
        (opcode == 7'b0000011) || // I-type Load
        (opcode == 7'b0100011) || // S-type Store
        (opcode == 7'b1100011) || // B-type Branch
        (opcode == 7'b1101111) || // J-type JAL
        (opcode == 7'b1100111) || // I-type JALR
        (opcode == 7'b0110111) || // U-type LUI
        (opcode == 7'b0010111)    // U-type AUIPC
    );

    // R-type funct3/funct7 checking: funct3 and funct7 must match valid combinations
    wire illegal_rtype;
    assign illegal_rtype = (opcode == 7'b0110011) && ~(
        (funct3 == 3'b000 && (funct7 == 7'b0000000 || funct7 == 7'b0100000)) || // ADD, SUB
        (funct3 == 3'b001 && funct7 == 7'b0000000) || // SLL
        (funct3 == 3'b010 && funct7 == 7'b0000000) || // SLT
        (funct3 == 3'b011 && funct7 == 7'b0000000) || // SLTU
        (funct3 == 3'b100 && funct7 == 7'b0000000) || // XOR
        (funct3 == 3'b101 && (funct7 == 7'b0000000 || funct7 == 7'b0100000)) || // SRL, SRA
        (funct3 == 3'b110 && funct7 == 7'b0000000) || // OR
        (funct3 == 3'b111 && funct7 == 7'b0000000)    // AND
    );

    // I-type immediate arithmetic funct3/funct7 checking
    wire illegal_itype_imm;
    assign illegal_itype_imm = (opcode == 7'b0010011) && ~(
        (funct3 == 3'b000) || // ADDI
        (funct3 == 3'b001 && funct7 == 7'b0000000) || // SLLI
        (funct3 == 3'b010) || // SLTI
        (funct3 == 3'b011) || // SLTIU
        (funct3 == 3'b100) || // XORI
        (funct3 == 3'b101 && (funct7 == 7'b0000000 || funct7 == 7'b0100000)) || // SRLI, SRAI
        (funct3 == 3'b110) || // ORI
        (funct3 == 3'b111)    // ANDI
    );

    // I-type load funct3 checking
    wire illegal_itype_load;
    assign illegal_itype_load = (opcode == 7'b0000011) && ~(
        (funct3 == 3'b000) || // LB
        (funct3 == 3'b001) || // LH
        (funct3 == 3'b010) || // LW
        (funct3 == 3'b100) || // LBU
        (funct3 == 3'b101)    // LHU
    );

    // S-type store funct3 checking
    wire illegal_stype_store;
    assign illegal_stype_store = (opcode == 7'b0100011) && ~(
        (funct3 == 3'b000) || // SB
        (funct3 == 3'b001) || // SH
        (funct3 == 3'b010)    // SW
    );

    // B-type branch funct3 checking
    wire illegal_btype_branch;
    assign illegal_btype_branch = (opcode == 7'b1100011) && ~(
        (funct3 == 3'b000) || // BEQ
        (funct3 == 3'b001) || // BNE
        (funct3 == 3'b100) || // BLT
        (funct3 == 3'b101) || // BGE
        (funct3 == 3'b110) || // BLTU
        (funct3 == 3'b111)    // BGEU
    );

    // unaligned data memory access checking
    wire unaligned_dmem_access;
    assign unaligned_dmem_access = (opcode == 7'b0000011) && (dmem_addr[1:0] != 2'b00);

    // unaligned instruction address on a taken branch or jump
    wire unaligned_imem_access;
    assign unaligned_imem_access = (imem_addr[1:0] != 2'b00);

    assign o_trap = illegal_opcode 
        || illegal_rtype || illegal_itype_imm || illegal_itype_load || illegal_stype_store || illegal_btype_branch 
        || unaligned_dmem_access || unaligned_imem_access;
endmodule
`default_nettype wire