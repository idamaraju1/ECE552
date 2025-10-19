`default_nettype none
module ctrl (
    input  wire [31:0] i_inst,
    input  wire        i_o_retire_trap, // from trap.v, only used to affect o_retire_halt
    // Output control signals:
    output reg        o_RegWrite,
    output reg [5:0]  o_inst_format,
    output reg        o_ALUSrc1,
    output reg        o_ALUSrc2,
    output reg [1:0]  o_ALUop,
    output reg        o_lui,
    output reg        o_dmem_ren,
    output reg [3:0]  o_dmem_mask,
    output reg        o_MemtoReg,
    output reg        o_Jump,
    output reg        o_Branch
    output wire        o_retire_halt
);
    always @(*) begin
        case(i_inst[6:0])
            7'b0110011: begin // R-type
                o_inst_format = 6'b000001;
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b0;
                o_ALUop = 2'b00;
                o_lui = 1'b0;
                o_dmem_ren = 1'b1;
                o_dmem_mask = 4'b0000;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
            end
            7'b0010011: begin // I-type (immediate arithmetic)
                o_inst_format = 6'b000010;
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b01;
                o_lui = 1'b0;
                o_dmem_ren = 1'b1;
                o_dmem_mask = 4'b0000;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
            end
            7'b0000011: begin // I-type (load)
                o_inst_format = 6'b000010;
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b1;
                o_dmen_mask = 4'b0000;
                o_MemtoReg = 1'b1;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
            end
            7'b0100011: begin // S-type (store)
                o_inst_format = 6'b000100;
                o_RegWrite = 1'b0;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b0;
                o_dmem_mask = (i_inst[14:12] == 3'b000) ? 4'b0001 : // SB
                              (i_inst[14:12] == 3'b001) ? 4'b0011 : // SH
                                                          4'b1111 ; // SW
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
            end
            7'b1100011: begin // B-type (branch)
                o_inst_format = 6'b001000; 
                o_RegWrite = 1'b0;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b0;
                o_ALUop = 2'b11;
                o_lui = 1'b0;
                o_dmem_ren = 1'b1;
                o_dmem_mask = 4'b0000;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b1;
            end
            7'b0110111: begin // U-type (LUI)
                o_inst_format = 6'b010000; 
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b1;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b10;
                o_lui = 1'b1;
                o_dmem_ren = 1'b1;
                o_dmem_mask = 4'b0000;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
            end
            7'b0010111: begin // U-type (LUI)
                o_inst_format = 6'b010000; 
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b1;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b1;
                o_dmem_mask = 4'b0000;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
            end
            7'b1101111: begin // J-type (JAL)
                o_inst_format = 6'b100000;
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b1;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b1;
                o_dmem_mask = 4'b0000;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b1;
                o_Branch = 1'b0;
            end
            7'b1100111: begin // I-type (JALR)
                o_inst_format = 6'b000010;
                o_RegWrite = 1'b1;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b1;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b1;
                o_dmem_mask = 4'b0000;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b1;
                o_Branch = 1'b0;
            end
            7'b1110011: begin // EBREAK
                o_inst_format = 6'b000000;
                o_RegWrite = 1'b0;
                o_ALUSrc1 = 1'b0;
                o_ALUSrc2 = 1'b0;
                o_ALUop = 2'b10;
                o_lui = 1'b0;
                o_dmem_ren = 1'b1;
                o_dmem_mask = 4'b0000;
                o_MemtoReg = 1'b0;
                o_Jump = 1'b0;
                o_Branch = 1'b0;
            end
            default: o_inst_format = 6'b000000;
        endcase
    end

    // o_retire_halt is high when EBREAK is executed or trap is detected
    assign o_retire_halt = (o_inst_format == 6'b000000) || i_o_retire_trap;

endmodule
`default_nettype wire