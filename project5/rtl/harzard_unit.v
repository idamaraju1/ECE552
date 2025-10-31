`default_nettype none
module hazard_unit (
    input  wire [4:0] i_id_rs1,
    input  wire [4:0] i_id_rs2,
    input  wire [6:0] i_id_opcode,
    input  wire [4:0] i_ex_rd,
    input  wire       i_ex_reg_write,
    input  wire [4:0] i_mem_rd,
    input  wire       i_mem_reg_write,
    output wire       o_pc_write,
    output wire       o_if_id_write,
    output wire       o_id_ex_flush
);
    reg need_rs1, need_rs2;
    always @(*) begin
        case (i_id_opcode)
            7'b0110011: begin // R
                need_rs1 = 1'b1;
                need_rs2 = 1'b1;
            end
            7'b0010011: begin // I-imm
                need_rs1 = 1'b1;
                need_rs2 = 1'b0;
            end
            7'b0000011: begin // LOAD
                need_rs1 = 1'b1;
                need_rs2 = 1'b0;
            end
            7'b0100011: begin // STORE
                need_rs1 = 1'b1;
                need_rs2 = 1'b1;
            end
            7'b1100011: begin // BRANCH
                need_rs1 = 1'b1;
                need_rs2 = 1'b1;
            end
            7'b1100111: begin // JALR
                need_rs1 = 1'b1;
                need_rs2 = 1'b0;
            end
            default: begin
                need_rs1 = 1'b0;
                need_rs2 = 1'b0;
            end
        endcase
    end

    // if write in ex/mem
    wire ex_will_write  = i_ex_reg_write  && (i_ex_rd  != 5'd0);
    wire mem_will_write = i_mem_reg_write && (i_mem_rd != 5'd0);

    // ID.rs1 vs EX.rd
    wire hazard_ex_rs1  = need_rs1 && (i_id_rs1 != 5'd0) && ex_will_write  && (i_id_rs1 == i_ex_rd);
    // ID.rs2 vs EX.rd
    wire hazard_ex_rs2  = need_rs2 && (i_id_rs2 != 5'd0) && ex_will_write  && (i_id_rs2 == i_ex_rd);
    // ID.rs1 vs MEM.rd
    wire hazard_mem_rs1 = need_rs1 && (i_id_rs1 != 5'd0) && mem_will_write && (i_id_rs1 == i_mem_rd);
    // ID.rs2 vs MEM.rd
    wire hazard_mem_rs2 = need_rs2 && (i_id_rs2 != 5'd0) && mem_will_write && (i_id_rs2 == i_mem_rd);

    // stall when hazard
    wire stall = hazard_ex_rs1 | hazard_ex_rs2 | hazard_mem_rs1 | hazard_mem_rs2;

    assign o_pc_write    = ~stall;
    assign o_if_id_write = ~stall;
    assign o_id_ex_flush =  stall;
endmodule
`default_nettype wire
