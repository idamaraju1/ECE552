`default_nettype none

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. This ALU is a purely combinational block, so
// you should not attempt to add any registers or pipeline it in phase 3.
module alu (
    // Major operation selection.
    // NOTE: In order to simplify instruction decoding in phase 4, both 3'b010
    // and 3'b011 are used for set less than (they are equivalent).
    // Unsigned comparison is controlled through the `i_unsigned` signal.
    //
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010,
    // 3'b011: set less than/unsigned if `i_unsigned` asserted
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
    input  wire [ 2:0] i_opsel,
    // When asserted, addition operations should subtract instead.
    // This is only used for `i_opsel == 3'b000` (addition/subtraction).
    input  wire        i_sub,
    // When asserted, comparison operations should be treated as unsigned.
    // This is only used for branch comparisons and set less than.
    // For branch operations, the ALU result is not used, only the comparison
    // results.
    input  wire        i_unsigned,
    // When asserted, right shifts should be treated as arithmetic instead of
    // logical. This is only used for `i_opsel == 3'b011` (shift right).
    input  wire        i_arith,
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // 32-bit output result. Any carry out (from addition) should be ignored.
    output wire [31:0] o_result,
    // Equality result. This is used downstream to determine if a
    // branch should be taken.
    output wire        o_eq,
    // Set less than result. This is used downstream to determine if a
    // branch should be taken.
    output wire        o_slt
);
    // Fill in your implementation here.
    
    // Internal wires for different operations
    wire [31:0] add_sub_result;
    wire [31:0] sll_result;
    wire [31:0] slt_result;
    wire [31:0] xor_result;
    wire [31:0] srl_sra_result;
    wire [31:0] or_result;
    wire [31:0] and_result;
    
    // Addition/Subtraction using structural approach (no + operator allowed)
    wire [31:0] op2_processed;
    wire [31:0] adder_result;
    wire [32:0] carry_chain;
    
    // Process op2 for subtraction (invert for two's complement)
    assign op2_processed = i_sub ? ~i_op2 : i_op2;
    
    // Ripple carry adder implementation (structural)
    assign carry_chain[0] = i_sub; // carry_in = 1 for subtraction
    
    genvar j;
    generate
        for (j = 0; j < 32; j = j + 1) begin : full_adder
            assign adder_result[j] = i_op1[j] ^ op2_processed[j] ^ carry_chain[j];
            assign carry_chain[j+1] = (i_op1[j] & op2_processed[j]) | 
                                      (carry_chain[j] & (i_op1[j] ^ op2_processed[j]));
        end
    endgenerate
    
    assign add_sub_result = adder_result;
    
    // Shift left logical
    assign sll_result = i_op1 << i_op2[4:0];
    
    // Set less than logic - need to compute op1 < op2
    wire slt_signed_val, slt_unsigned_val;
    wire op1_sign, op2_sign, signs_different;
    wire [31:0] sub_result;
    wire sub_carry_out;
    
    assign op1_sign = i_op1[31];
    assign op2_sign = i_op2[31];
    assign signs_different = op1_sign ^ op2_sign;
    
    // Perform subtraction op1 - op2 to check ordering
    wire [31:0] sub_op2_inv;
    wire [32:0] sub_carry;
    assign sub_op2_inv = ~i_op2;
    assign sub_carry[0] = 1'b1; // carry_in for subtraction
    
    genvar k;
    generate
        for (k = 0; k < 32; k = k + 1) begin : subtractor
            assign sub_result[k] = i_op1[k] ^ sub_op2_inv[k] ^ sub_carry[k];
            assign sub_carry[k+1] = (i_op1[k] & sub_op2_inv[k]) | 
                                    (sub_carry[k] & (i_op1[k] ^ sub_op2_inv[k]));
        end
    endgenerate
    
    assign sub_carry_out = sub_carry[32];
    
    // Signed comparison: if signs different, negative is smaller
    // If signs same, use subtraction result sign
    assign slt_signed_val = signs_different ? op1_sign : sub_result[31];
    
    // Unsigned comparison: op1 < op2 if subtraction has no carry out
    assign slt_unsigned_val = ~sub_carry_out;
    
    assign slt_result = {31'b0, i_unsigned ? slt_unsigned_val : slt_signed_val};
    
    // XOR operation
    assign xor_result = i_op1 ^ i_op2;
    
    // Shift right operations
    wire [31:0] srl_result_wire, sra_result_wire;
    wire [4:0] shift_amt;
    wire sign_bit;
    
    assign shift_amt = i_op2[4:0];
    assign sign_bit = i_op1[31];
    
    // Logical right shift
    assign srl_result_wire = i_op1 >> shift_amt;
    
    // Arithmetic right shift - case based approach for simplicity
    wire [31:0] sra_base;
    assign sra_base = i_op1 >> shift_amt;
    assign sra_result_wire = sign_bit ? 
                            (sra_base | (~(32'hFFFFFFFF >> shift_amt))) : 
                            sra_base;
    
    assign srl_sra_result = i_arith ? sra_result_wire : srl_result_wire;
    
    // OR operation
    assign or_result = i_op1 | i_op2;
    
    // AND operation
    assign and_result = i_op1 & i_op2;
    
    // Output multiplexer based on operation select
    assign o_result = (i_opsel == 3'b000) ? add_sub_result :
                      (i_opsel == 3'b001) ? sll_result :
                      (i_opsel == 3'b010) ? slt_result :
                      (i_opsel == 3'b011) ? slt_result :
                      (i_opsel == 3'b100) ? xor_result :
                      (i_opsel == 3'b101) ? srl_sra_result :
                      (i_opsel == 3'b110) ? or_result :
                      and_result; // Default case (3'b111)
    
    // Equality check: XOR all bits and check if result is zero
    wire [31:0] xor_eq;
    assign xor_eq = i_op1 ^ i_op2;
    assign o_eq = ~(|xor_eq); // NOR reduction - true if all bits are 0
    
    // Set less than output
    assign o_slt = i_unsigned ? slt_unsigned_val : slt_signed_val;

endmodule

`default_nettype wire
