`default_nettype none

// The immediate generator is responsible for decoding the 32-bit
// sign-extended immediate from the incoming instruction word. It is a purely
// combinational block that is expected to be embedded in the instruction
// decoder.
module imm (
    // Input instruction word. This is used to extract the relevant immediate
    // bits and assemble them into the final immediate.
    input  wire [31:0] i_inst,
    // Instruction format, determined by the instruction decoder based on the
    // opcode. This is one-hot encoded according to the following format:
    // [0] R-type (don't-care, see below)
    // [1] I-type
    // [2] S-type
    // [3] B-type
    // [4] U-type
    // [5] J-type
    input  wire [ 5:0] i_format,
    // Output 32-bit immediate, sign-extended from the immediate bitstring.
    // Because the R-type format does not have an immediate, the output
    // immediate can be treated as a don't-care under this case. It is
    // included for completeness.
    output wire [31:0] o_immediate
);
    // Fill in your implementation here.
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    // I-type: imm[11:0] = inst[31:20]
    assign imm_i = {{21{i_inst[31]}}, i_inst[30:20]};
    
    // S-type: imm[11:5] = inst[31:25], imm[4:0] = inst[11:7]  
    assign imm_s = {{21{i_inst[31]}}, i_inst[30:25], i_inst[11:7]};
    
    // B-type: imm[12|10:5|4:1|11] = inst[31|30:25|11:8|7], LSB is always 0
    assign imm_b = {{20{i_inst[31]}}, i_inst[7], i_inst[30:25], i_inst[11:8], 1'b0};
    
    // U-type: imm[31:12] = inst[31:12], lower 12 bits are 0
    assign imm_u = {i_inst[31:12], 12'd0};
    
    // J-type: imm[20|19:12|11|10:1] = inst[31|19:12|20|30:21], LSB is always 0  
    assign imm_j = {{12{i_inst[31]}}, i_inst[19:12], i_inst[20], i_inst[30:21], 1'b0};

    // Mux to select the appropriate immediate based on one-hot encoded format
    assign o_immediate = (i_format[1]) ? imm_i :  // I-type
                         (i_format[2]) ? imm_s :  // S-type
                         (i_format[3]) ? imm_b :  // B-type
                         (i_format[4]) ? imm_u :  // U-type
                         (i_format[5]) ? imm_j :  // J-type
                         32'd0;  // Default case (R-type or format[0])

endmodule

`default_nettype wire
