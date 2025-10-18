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
    // [0] R-type, or e-break (don't-care, see below)
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

                        // If I-type
    assign o_immediate = (i_format[1]) ? { {21{i_inst[31]}}, i_inst[30:20] } :
        // If S-type
        (i_format[2]) ? { {21{i_inst[31]}}, i_inst[30:25], i_inst[11:7] } :
        // If B-type
        (i_format[3]) ? {{20{i_inst[31]}}, i_inst[7], i_inst[30:25], i_inst[11:8], 1'b0} :
        // If U-type
        (i_format[4]) ? {i_inst[31:12], 12'd0} :
        // If J-type
        (i_format[5]) ? {{12{i_inst[31]}}, i_inst[19:12], i_inst[20], i_inst[30:21], 1'b0} :
        // If R-type, or e-break, or Default case (should not occur)
        32'd0;

endmodule

`default_nettype wire
