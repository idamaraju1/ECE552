`default_nettype none
module alu_ctrl(
    input  wire [1:0]  i_ALUop,        // 00:R, 01:I-imm, 10:Mem/U/J/JALR, 11:Branch
    input  wire [2:0]  i_funct3,       // pass inst[14:12] at instantiation
    input wire         i_funct7_bit5,

    // 4'b0000: add
    // 4'b0001: sub
    // 4'b0010: rs1 << rs2[4:0]
    // 4'b0011: rs1 << rs2(imm)[4:0]
    // 4'b0100: set < signed
    // 4'b0101: set >= signed
    // 4'b0110: set < unsigned
    // 4'b0111: set >= unsigned
    // 4'b1000: rs1 ^ rs2
    // 4'b1001: set ==
    // 4'b1010: rs1 >> rs2[4:0]
    // 4'b1011: rs1 >>> rs2[4:0]
    // 4'b1100: rs1 | rs2
    // 4'b1101: rs1 >> rs2(imm)[4:0]
    // 4'b1110: rs1 & rs2
    // 4'b1111: rs1 >>> rs2(imm)[4:0]
    output reg  [3:0]  o_alu_ctrl,
    output reg         o_is_bne        // only used to invert BEQ into BNE
);

always @(*) begin
    case (i_ALUop)
        2'b00: begin // If R-type
            o_alu_ctrl = {i_funct3, i_funct7_bit5};
            // default (for other values of funct3/7 which isn't encoded in R-type): o_alu_ctrl = {i_funct3, i_funct7_bit5};
                // Since any mismatch between funct3 and funct7 is detected in trap.v
                // which set o_retire_trap if an illegal instruction is detected,
                // this default branch will never be reached in practice.
            o_is_bne = 1'b0;
        end
        2'b01: begin // If I-type (immediate arithmetic)
            case (i_funct3)
                3'b000: o_alu_ctrl = 4'b0000; 
                3'b001: o_alu_ctrl = 4'b0011; 
                3'b010: o_alu_ctrl = 4'b0100; 
                3'b011: o_alu_ctrl = 4'b0110; 
                3'b100: o_alu_ctrl = 4'b1000; 
                3'b101: begin
                    if(i_funct7_bit5) begin
                        o_alu_ctrl = 4'b1111;
                    end else begin
                        o_alu_ctrl = 4'b1101;
                    end
                end
                3'b110: o_alu_ctrl = 4'b1100;
                3'b111: o_alu_ctrl = 4'b1110;
                default: o_alu_ctrl = {i_funct3, i_funct7_bit5}; // for other values of funct3/7 which isn't encoded in I-type
                    // Since any mismatch between funct3 and funct7 is detected in trap.v
                    // which set o_retire_trap if an illegal instruction is detected,
                    // this default branch will never be reached in practice.
            endcase
            o_is_bne = 1'b0;
        end
        2'b10: begin // If I-type (load) or S-type (store) or U-type or J-type or jalr
            o_alu_ctrl = 4'b0000; // add
            o_is_bne = 1'b0;
        end
        2'b11: begin // If B-type (branch)
            case (i_funct3)
                3'b000: begin // beq
                    o_alu_ctrl = 4'b1001; // set ==
                    o_is_bne = 1'b0;
                end
                3'b001: begin // bne
                    o_alu_ctrl = 4'b1001; // set ==
                    o_is_bne = 1'b1;
                end
                3'b100: begin // blt
                    o_alu_ctrl = 4'b0100; // set < signed
                    o_is_bne = 1'b0;
                end
                3'b101: begin // bge
                    o_alu_ctrl = 4'b0101; // set >= signed
                    o_is_bne = 1'b0;
                    // Botao : set to 0
                    // o_is_bne = 1'b1;
                end
                3'b110: begin // bltu
                    o_alu_ctrl = 4'b0110; // set < unsigned
                    o_is_bne = 1'b0;
                end
                3'b111: begin // bgeu
                    o_alu_ctrl = 4'b0111; // set >= unsigned
                    o_is_bne = 1'b0;
                end
                default: begin // for other values of funct3/7 which isn't encoded in B-type
                    o_alu_ctrl = 4'b0000;
                    o_is_bne = 1'b0;
                    // Since any mismatch between funct3 and funct7 is detected in trap.v
                    // which set o_retire_trap if an illegal instruction is detected,
                    // this default branch will never be reached in practice.
                end
            endcase
        end
    endcase 
end

// Botao: delete blank always
// always @(*)

endmodule
`default_nettype wire