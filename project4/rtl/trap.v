`default_nettype none
module trap(
    input  wire [31:0] i_inst,
    input  wire [31:0] i_dmem_addr, // effective data address for load/store
    input  wire [31:0] i_imem_addr, // branch/jump target address when taken
    output wire        o_trap
);
    // basic fields
    wire [6:0] opcode = i_inst[6:0];
    wire [2:0] funct3 = i_inst[14:12];
    wire [6:0] funct7 = i_inst[31:25];

    // -----------------------
    // 1) LEGAL OPCODES (+ EBREAK)
    // -----------------------
    // EBREAK (opcode == 7'b1110011, funct3=000, imm12=1, rs1=0, rd=0) -> allowed & handled elsewhere (halt)
    wire is_ebreak  = (opcode == 7'b1110011)
                    && (funct3 == 3'b000)
                    && (i_inst[31:20] == 12'h001)   // imm12 = 1
                    && (i_inst[19:15] == 5'd0)      // rs1 = x0
                    && (i_inst[11:7]  == 5'd0);     // rd  = x0
    wire legal_opcode = (opcode == 7'b0110011) // R
                     || (opcode == 7'b0010011) // I (arith imm)
                     || (opcode == 7'b0000011) // I (load)
                     || (opcode == 7'b0100011) // S (store)
                     || (opcode == 7'b1100011) // B (branch)
                     || (opcode == 7'b1101111) // JAL
                     || (opcode == 7'b1100111) // JALR
                     || (opcode == 7'b0110111) // LUI
                     || (opcode == 7'b0010111) // AUIPC
                     ||  is_ebreak;            // SYSTEM: EBREAK is legal (halt), not a trap
    wire illegal_opcode = ~legal_opcode;

    // -----------------------
    // 2) FIELD CONSISTENCY CHECKS
    // -----------------------
    // R-type (funct3/funct7 combos)
    wire illegal_rtype = (opcode == 7'b0110011) && ~(
        (funct3 == 3'b000 && (funct7 == 7'b0000000 || funct7 == 7'b0100000)) || // ADD, SUB
        (funct3 == 3'b001 && funct7 == 7'b0000000) || // SLL
        (funct3 == 3'b010 && funct7 == 7'b0000000) || // SLT
        (funct3 == 3'b011 && funct7 == 7'b0000000) || // SLTU
        (funct3 == 3'b100 && funct7 == 7'b0000000) || // XOR
        (funct3 == 3'b101 && (funct7 == 7'b0000000 || funct7 == 7'b0100000)) || // SRL, SRA
        (funct3 == 3'b110 && funct7 == 7'b0000000) || // OR
        (funct3 == 3'b111 && funct7 == 7'b0000000)    // AND
    );

    // I-type arithmetic (shift-immediates must encode upper bits as per spec)
    wire illegal_itype_imm = (opcode == 7'b0010011) && ~(
        (funct3 == 3'b000) || // ADDI
        (funct3 == 3'b001 && funct7 == 7'b0000000) || // SLLI
        (funct3 == 3'b010) || // SLTI
        (funct3 == 3'b011) || // SLTIU
        (funct3 == 3'b100) || // XORI
        (funct3 == 3'b101 && (funct7 == 7'b0000000 || funct7 == 7'b0100000)) || // SRLI, SRAI
        (funct3 == 3'b110) || // ORI
        (funct3 == 3'b111)    // ANDI
    );

    // I-type load funct3
    wire illegal_itype_load = (opcode == 7'b0000011) && ~(
        (funct3 == 3'b000) || // LB
        (funct3 == 3'b001) || // LH
        (funct3 == 3'b010) || // LW
        (funct3 == 3'b100) || // LBU
        (funct3 == 3'b101)    // LHU
    );

    // S-type store funct3
    wire illegal_stype_store = (opcode == 7'b0100011) && ~(
        (funct3 == 3'b000) || // SB
        (funct3 == 3'b001) || // SH
        (funct3 == 3'b010)    // SW
    );

    // B-type branch funct3
    wire illegal_btype_branch = (opcode == 7'b1100011) && ~(
        (funct3 == 3'b000) || // BEQ
        (funct3 == 3'b001) || // BNE
        (funct3 == 3'b100) || // BLT
        (funct3 == 3'b101) || // BGE
        (funct3 == 3'b110) || // BLTU
        (funct3 == 3'b111)    // BGEU
    );

    // -----------------------
    // 3) ALIGNMENT CHECKS (WISC-F25 requires aligned accesses)
    // -----------------------
 
    // load misalign by width
    wire mis_ld = (opcode == 7'b0000011) && (
        ((funct3 == 3'b010) && (i_dmem_addr[1:0] != 2'b00)) || // LW
        ((funct3 == 3'b001) && (i_dmem_addr[0]   != 1'b0 )) || // LH
        ((funct3 == 3'b101) && (i_dmem_addr[0]   != 1'b0 ))    // LHU
        // LB/LBU: no alignment restriction
    );

    // store misalign by width
    wire mis_st = (opcode == 7'b0100011) && (
        ((funct3 == 3'b010) && (i_dmem_addr[1:0] != 2'b00)) || // SW
        ((funct3 == 3'b001) && (i_dmem_addr[0]   != 1'b0 ))    // SH
        // SB: no alignment restriction
    );

    // instruction address misalign: JAL/JALR must be aligned; branches should be checked only when taken (ensure upstream supplies the target only when taken).
    wire is_jal  = (opcode == 7'b1101111);
    wire is_jalr = (opcode == 7'b1100111);
    wire mis_imem = ((is_jal | is_jalr) && (i_imem_addr[1:0] != 2'b00));
    // If HART feeds imem_addr only when a branch is taken, this naturally covers B-type as well.

    // -----------------------
    // 4) FINAL TRAP
    // -----------------------
    assign o_trap = illegal_opcode
                 || illegal_rtype || illegal_itype_imm || illegal_itype_load
                 || illegal_stype_store || illegal_btype_branch
                 || mis_ld || mis_st || mis_imem;
endmodule
`default_nettype wire
