`default_nettype none

module if_id (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_flush,         
    input  wire        i_stall,         
    input  wire        i_valid,
    
    // Inputs from IF stage
    input  wire [31:0] i_pc,
    input  wire [31:0] i_instruction,
    input  wire [31:0] i_pc_plus_4,
    
    // Outputs to ID stage
    output reg  [31:0] o_pc,
    output reg  [31:0] o_instruction,
    output reg  [31:0] o_pc_plus_4,
    output reg         o_valid
);

    // reg first_cycle;

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_pc <= 32'h00000000;
            o_instruction <= 32'h00000013;
            o_pc_plus_4 <= 32'h00000004;
            o_valid <= 1'b0;
        end else if (i_flush) begin
            o_pc         <= 32'h00000000;
            o_instruction <= 32'h00000013;
            o_pc_plus_4  <= 32'h00000004;
            o_valid <= 1'b0;
        end else if (~i_stall) begin
            o_pc         <= i_pc;
            o_instruction <= i_instruction;
            o_pc_plus_4  <= i_pc_plus_4;
            o_valid <= i_valid;
        end else begin
            // hold values
        end
    end

endmodule

`default_nettype wire