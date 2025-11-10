`default_nettype none
module ctrl (
    input  wire [31:0] i_inst,
    // Output control signals:
    output reg        o_RegWrite,
    output reg [5:0]  o_inst_format,
    output reg        o_ALUSrc1,
    output reg        o_ALUSrc2,
    output reg [1:0]  o_ALUop,
    output reg        o_lui,
    output reg        o_dmem_ren,
    output reg        o_dmem_wen,
    output reg        o_MemtoReg,
    output reg        o_Jump,
    output reg        o_Branch,
    output reg        o_retire_halt     // only ebreak halts
);
    always @(*) begin
        // Default values - prevent X propagation
        o_inst_format = 6'b000010;
        o_RegWrite = 1'b0;
        o_ALUSrc1 = 1'b0;
        o_ALUSrc2 = 1'b0;
        o_ALUop = 2'b10;
        o_lui = 1'b0;
        o_dmem_ren = 1'b0;
        o_dmem_wen = 1'b0;
        o_MemtoReg = 1'b0;
        o_Jump = 1'b0;
        o_Branch = 1'b0;
        o_retire_halt = 1'b0;

        case(i_inst[6:0])
            7'b0110011: begin // R-type
                o_inst_format = 6'b000001;
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b0;
                o_ALUop = 2'b00;
                o_lui = 1'b0;
                o_dmem_ren = 1'b0;
                o_dmem_wen = 1'b0;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
                o_retire_halt = 1'b0;
            end
            7'b0010011: begin // I-type (immediate arithmetic)
                o_inst_format = 6'b000010;
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b01;
                o_lui = 1'b0;
                o_dmem_ren = 1'b0;
                o_dmem_wen = 1'b0;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
                o_retire_halt = 1'b0;
            end
            7'b0000011: begin // I-type (load)
                o_inst_format = 6'b000010;
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b1;
                o_dmem_wen = 1'b0;
                o_MemtoReg = 1'b1;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
                o_retire_halt = 1'b0;
            end
            7'b0100011: begin // S-type (store)
                o_inst_format = 6'b000100;
                o_RegWrite = 1'b0;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b0;
                o_dmem_wen = 1'b1;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
                o_retire_halt = 1'b0;
            end
            7'b1100011: begin // B-type (branch)
                o_inst_format = 6'b001000; 
                o_RegWrite = 1'b0;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b0;
                o_ALUop = 2'b11;
                o_lui = 1'b0;
                o_dmem_ren = 1'b0;
                o_dmem_wen = 1'b0;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b1;
                o_retire_halt = 1'b0;
            end
            7'b0110111: begin // U-type (lui)
                o_inst_format = 6'b010000; 
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b1;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b10;
                o_lui = 1'b1;
                o_dmem_ren = 1'b0;
                o_dmem_wen = 1'b0;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
                o_retire_halt = 1'b0;
            end
            7'b0010111: begin // U-type (auipc)
                o_inst_format = 6'b010000; 
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b1;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b0;
                o_dmem_wen = 1'b0;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
                o_retire_halt = 1'b0;
            end
            7'b1101111: begin // J-type (JAL)
                o_inst_format = 6'b100000;
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b1;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b0;
                o_dmem_wen = 1'b0;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b1;
                o_Branch = 1'b0;
                o_retire_halt = 1'b0;
            end
            7'b1100111: begin // I-type (JALR)
                o_inst_format = 6'b000010;
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b0;
                o_dmem_wen = 1'b0;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b1;
                o_Branch = 1'b0;
                o_retire_halt = 1'b0;
            end
            7'b1110011: begin // EBREAK and other system instructions
                o_inst_format = 6'b000010;  // Changed: treat as I-type format
                o_RegWrite = 1'b0;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b0;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b0;
                o_dmem_wen = 1'b0;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
                // Check if it's specifically EBREAK
                o_retire_halt = (i_inst == 32'h00100073) ? 1'b1 : 1'b0;
            end
            default: begin
                // Default case for unrecognized instructions
                // Treat as NOP (don't write to register file, don't access memory)
                o_inst_format = 6'b000010;  // Changed: use I-type format instead of 000000
                o_RegWrite = 1'b0;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b0;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b0;
                o_dmem_wen = 1'b0;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
                o_retire_halt = 1'b0;
            end
        endcase
    end

endmodule
`default_nettype wire