module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002003`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the write-back stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);
    //////////////////////////////////////////////////////////////////////////////
    // Decide if instruction is illegal (for trap signal)
    //////////////////////////////////////////////////////////////////////////////
    trap Trap(
        .i_inst(i_imem_rdata),
        .i_dmem_addr(o_dmem_addr),
        .i_imem_addr(o_imem_raddr),
        .o_trap(o_retire_trap)
    );

    ////////////////////////////////////////////////////////////////////////////////
    // Generate control signals 
    ////////////////////////////////////////////////////////////////////////////////
    wire       RegWrite;
    wire [5:0] inst_format;
    wire       ALUSrc1;
    wire       ALUSrc2;
    wire [1:0] ALUop;
    wire       lui;
    wire       MemtoReg;
    wire       Jump;
    wire       Branch;
    ctrl Control (
        // inputs
        .i_inst(i_imem_rdata[31:0]),
        .i_o_retire_trap(o_retire_trap),
        // outputs
        .o_RegWrite(RegWrite),
        .o_inst_format(inst_format),
        .o_ALUSrc1(ALUSrc1),
        .o_ALUSrc2(ALUSrc2),
        .o_ALUop(ALUop),
        .o_lui(lui),
        .o_dmem_ren(o_dmem_ren),
        .o_dmem_mask(o_dmem_mask),
        .o_MemtoReg(MemtoReg),
        .o_Jump(Jump),
        .o_Branch(Branch),
        .o_retire_halt(o_retire_halt)
    );
    assign o_dmem_wen = ~o_dmem_ren;
    
    //////////////////////////////////////////////////////////////////////////////
    // RegisterFile
    ////////////////////////////////////////////////////////////////////////////////
    assign o_retire_rs1_rdata = i_imem_rdata[19:15]; // rs1
    assign o_retire_rs2_rdata = i_imem_rdata[24:20]; // rs2
    assign o_retire_rd_waddr = i_imem_rdata[11:7];  // rd
    rf #(.BYPASS_EN(0)) RegisterFile (
        .i_clk(i_clk),
        .i_rst(i_rst),
        // read port
        .i_rs1_raddr(o_retire_rs1_raddr),
        .o_rs1_rdata(o_retire_rs1_rdata),
        .i_rs2_raddr(o_retire_rs2_raddr),
        .o_rs2_rdata(o_retire_rs2_rdata),
        // write port
        .i_rd_wen(RegWrite),
        .i_rd_waddr(o_retire_rd_waddr),
        .i_rd_wdata(o_retire_rd_wdata)
    );
    assign o_retire_rd_wdata = 
        (Jump) ? o_imem_raddr + 32'd4 :
                 (~MemtoReg) ? alu_result :
                              (i_imem_rdata[13]) ? i_dmem_rdata :
                                                   ((i_imem_rdata[14] & i_imem_rdata[12]) ? { 16'd0, i_dmem_rdata[15:0]} : // lhu
                                                    (i_imem_rdata[14] & ~i_imem_rdata[12]) ? { 24'd0, i_dmem_rdata[7:0]} : // lbu
                                                    (~i_imem_rdata[14] & i_imem_rdata[12]) ? {{16{i_dmem_rdata[15]}}, i_dmem_rdata[15:0]} : // lh
                                                        {{24{i_dmem_rdata[7]}}, i_dmem_rdata[7:0]}); // lb


    //////////////////////////////////////////////////////////////////////////////
    // Immediate Generator
    ////////////////////////////////////////////////////////////////////////////////
    wire [31:0] immediate;
    imm ImmGen (
        .i_inst(i_imem_rdata),
        .i_format(inst_format),
        .o_immediate(immediate)
    );

    //////////////////////////////////////////////////////////////////////////////
    // ALU control
    ////////////////////////////////////////////////////////////////////////////////
    wire [3:0] alu_ctrl;
    wire       is_bne;
    alu_ctrl ALU_control (
        .i_alu_op(ALUop),
        .i_funct3(i_imem_rdata[14:12]),
        .i_funct7_bit5(i_imem_rdata[30]),
        .o_alu_ctrl(alu_ctrl),
        .o_is_bne(is_bne)
    );

    ///////////////////////////////////////////////////////////////////////////////
    // ALU
    ///////////////////////////////////////////////////////////////////////////////
    wire [31:0] alu_result;
    wire        branch_condition;
    alu ALU (
        .i_rs1(ALUSrc1 ? (lui ? 32'd0 : o_imem_raddr) : o_retire_rs1_rdata),
        .i_rs2(ALUSrc2 ? immediate : o_retire_rs2_rdata),
        .i_opsel(alu_ctrl),
        .i_is_bne(is_bne),
        .o_result(alu_result),
        .o_branch_condition(branch_condition)
    );

    //////////////////////////////////////////////////////////////////////////////
    // Memory
    //////////////////////////////////////////////////////////////////////////////
    assign o_dmem_addr = alu_result;
    assign o_dmem_wdata = o_retire_rs2_rdata;

    //////////////////////////////////////////////////////////////////////////////
    // PC
    /////////////////////////////////////////////////////////////////////////////
    wire [31:0] next_pc;
    assign next_pc = 
        (Jump) ? ((~i_imem_rdata[3]) ? {alu_result[31:1], 1'b0} : alu_result) :
                 (Branch & branch_condition) ? (o_imem_raddr + immediate) :
                                                (o_imem_raddr + 32'd4);
    assign o_retire_next_pc = o_retire_halt ? o_imem_raddr : next_pc;
    pc PC (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_next_pc(o_retire_next_pc),
        .o_pc(o_imem_raddr),
        .o_retire_valid(o_retire_valid)
    );


endmodule

`default_nettype wire
