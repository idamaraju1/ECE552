`default_nettype none

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. This ALU is a purely combinational block, so
// you should not attempt to add any registers or pipeline it in phase 3.
module alu (
    input  wire [ 3:0] i_opsel,
    // Major operation selection:
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
    input  wire        i_is_bne, // whether the operation is bne (branch not equal)
    input  wire [31:0] i_op1,
    input  wire [31:0] i_op2, 

    output reg  [31:0] o_result,           // Any carry out (from addition) should be ignored.
    output reg         o_jump_condition    // whether the jump/branch condition is met
);
    // 4'b0000: add
    wire [31:0] add_result;
    assign add_result = i_op1 + i_op2;
    
    // 4'b0001: sub
    wire [31:0] sub_result;
    assign sub_result = i_op1 - i_op2;

    // 4'b0010: rs1 << rs2[4:0]
    // 4'b0011: rs1 << rs2(imm)[4:0]
    wire [31:0] sl_result;
    wire [31:0] sl_1, sl_2, sl_3, sl_4, sl_5;
    assign sl_1 = (i_op2[0]) ? {i_op1[30:0], 1'b0} : i_op1; // 1
    assign sl_2 = (i_op2[1]) ? {sl_1[29:0], 2'b00} : sl_1; // 2
    assign sl_3 = (i_op2[2]) ? {sl_2[27:0], 4'b0000} : sl_2; // 4
    assign sl_4 = (i_op2[3]) ? {sl_3[23:0], 8'b0000_0000} : sl_3; // 8
    assign sl_5 = (i_op2[4]) ? {sl_4[15:0], 16'b0000_0000_0000_0000} : sl_4; // 16
    assign sl_result = sl_5;

    // 4'b0100: set < signed
    wire slt_signed_result;
    assign slt_signed_result = ( i_op1[31] & ~i_op2[31] ) ? 1'b1 :
        ( ~i_op1[31] & i_op2[31] ) ? 1'b0 :
        ( i_op1[31] & i_op2[31] & ((~i_op1+32'd1) > (~i_op2+32'd1)) ) ? 1'b1 :
        ( ~i_op1[31] & ~i_op2[31] & (i_op1[30:0] < i_op2[30:0]) ) ? 1'b1 : 1'b0;
    // 4'b0101: set >= signed
    wire sge_signed_result;
    assign sge_signed_result = ~slt_signed_result;

    // 4'b0110: set < unsigned
    wire slt_unsigned_result;
    assign slt_unsigned_result = (i_op1 < i_op2) ? 1'b1 : 1'b0;
    // 4'b0111: set >= unsigned
    wire sge_unsigned_result;
    assign sge_unsigned_result = ~slt_unsigned_result;

    // 4'b1000: rs1 ^ rs2
    wire [31:0] xor_result;
    assign xor_result = i_op1 ^ i_op2;

    // 4'b1001: set ==
    wire eq_result;
    assign eq_result = (i_op1 == i_op2) ? 1'b1 : 1'b0;

    // 4'b1010: rs1 >> rs2[4:0]
    // 4'b1101: rs1 >> rs2(imm)[4:0]
    wire [31:0] srl_result;
    wire [31:0] srl_1, srl_2, srl_3, srl_4, srl_5;
    assign srl_1 = (i_op2[0]) ? {1'b0, i_op1[31:1]} : i_op1; // 1
    assign srl_2 = (i_op2[1]) ? {2'b00, srl_1[31:2]} : srl_1; // 2
    assign srl_3 = (i_op2[2]) ? {4'b0000, srl_2[31:4]} : srl_2; // 4
    assign srl_4 = (i_op2[3]) ? {8'b0000_0000, srl_3[31:8]} : srl_3; // 8
    assign srl_5 = (i_op2[4]) ? {16'b0000_0000_0000_0000, srl_4[31:16]} : srl_4; // 16
    assign srl_result = srl_5;

    // 4'b1011: rs1 >>> rs2[4:0]
    // 4'b1111: rs1 >>> rs2(imm)[4:0]
    wire [31:0] sra_result;
    wire [31:0] sra_1, sra_2, sra_3, sra_4, sra_5;
    assign sra_1 = (i_op2[0]) ? {i_op1[31], i_op1[31:1]} : i_op1; // 1
    assign sra_2 = (i_op2[1]) ? { {2{i_op1[31]}}, sra_1[31:2]} : sra_1; // 2
    assign sra_3 = (i_op2[2]) ? { {4{i_op1[31]}}, sra_2[31:4]} : sra_2; // 4
    assign sra_4 = (i_op2[3]) ? { {8{i_op1[31]}}, sra_3[31:8]} : sra_3; // 8
    assign sra_5 = (i_op2[4]) ? { {16{i_op1[31]}}, sra_4[31:16]} : sra_4; // 16
    assign sra_result = sra_5;

    // 4'b1100: rs1 | rs2
    wire [31:0] or_result;
    assign or_result = i_op1 | i_op2;
    
    // 4'b1110: rs1 & rs2
    wire [31:0] and_result;
    assign and_result = i_op1 & i_op2;

    // Output result selection
    always @(*) begin
        // Botao: default assignments to avoid latches / X-propagation
        o_result         = 32'b0;
        o_jump_condition = 1'b0;

        case (i_opsel)
            4'b0000: begin
                o_result = add_result;
                o_jump_condition = 1'b0;
            end
            4'b0001: begin
                o_result = sub_result;
                o_jump_condition = 1'b0;
            end
            4'b0010: begin
                o_result = sl_result;
                o_jump_condition = 1'b0;
            end
            4'b0011: begin
                o_result = sl_result;
                o_jump_condition = 1'b0;
            end
            4'b0100: begin
                o_result = {31'd0, slt_signed_result};
                o_jump_condition = slt_signed_result;
            end
            4'b0101: begin
                o_result = {31'd0, sge_signed_result};
                o_jump_condition = sge_signed_result;
            end
            4'b0110: begin
                o_result = {31'd0, slt_unsigned_result};
                o_jump_condition = slt_unsigned_result;
            end
            4'b0111: begin
                o_result = {31'd0, sge_unsigned_result};
                o_jump_condition = sge_unsigned_result;
            end
            4'b1000: begin
                o_result = xor_result;
                o_jump_condition = 1'b0;
            end
            4'b1001: begin
                o_result = {31'd0, eq_result};
                o_jump_condition = i_is_bne ? ~eq_result : eq_result;
            end
            4'b1010: begin
                o_result = srl_result;
                o_jump_condition = 1'b0;
            end
            4'b1011: begin
                o_result = sra_result;
                o_jump_condition = 1'b0;
            end
            4'b1100: begin
                o_result = or_result;
                o_jump_condition = 1'b0;
            end
            4'b1101: begin
                o_result = srl_result;
                o_jump_condition = 1'b0;
            end
            4'b1110: begin
                o_result = and_result;
                o_jump_condition = 1'b0;
            end
            4'b1111: begin
                o_result = sra_result;
                o_jump_condition = 1'b0;
            end
            // no default case since all 4'b0000~4'b1111 are covered
        endcase
    end

endmodule

`default_nettype wire
