`default_nettype none

module cache (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // External memory interface. See hart interface for details. This
    // interface is nearly identical to the phase 5 memory interface, with the
    // exception that the byte mask (`o_mem_mask`) has been removed. This is
    // no longer needed as the cache will only access the memory at word
    // granularity, and implement masking internally.
    input  wire        i_mem_ready,
    output wire [31:0] o_mem_addr,
    output wire        o_mem_ren,
    output wire        o_mem_wen,
    output wire [31:0] o_mem_wdata,
    input  wire [31:0] i_mem_rdata,
    input  wire        i_mem_valid,
    // Interface to CPU hart. This is nearly identical to the phase 5 hart memory
    // interface, but includes a stall signal (`o_busy`), and the input/output
    // polarities are swapped for obvious reasons.
    //
    // The CPU should use this as a stall signal for both instruction fetch
    // (IF) and memory (MEM) stages, from the instruction or data cache
    // respectively. If a memory request is made (`i_req_ren` for instruction
    // cache, or either `i_req_ren` or `i_req_wen` for data cache), this
    // should be asserted *combinationally* if the request results in a cache
    // miss.
    //
    // In case of a cache miss, the CPU must stall the respective pipeline
    // stage and deassert ren/wen on subsequent cycles, until the cache
    // deasserts `o_busy` to indicate it has serviced the cache miss. However,
    // the CPU must keep the other request lines constant. For example, the
    // CPU should not change the request address while stalling.
    output wire        o_busy,
    // 32-bit read/write address to access from the cache. This should be
    // 32-bit aligned (i.e. the two LSBs should be zero). See `i_req_mask` for
    // how to perform half-word and byte accesses to unaligned addresses.
    input  wire [31:0] i_req_addr,
    // When asserted, the cache should perform a read at the aligned address
    // specified by `i_req_addr` and return the 32-bit word at that address,
    // either immediately (i.e. combinationally) on a cache hit, or
    // synchronously on a cache miss. It is illegal to assert this and
    // `i_dmem_wen` on the same cycle.
    input  wire        i_req_ren,
    // When asserted, the cache should perform a write at the aligned address
    // specified by `i_req_addr` with the 32-bit word provided in
    // `o_req_wdata` (specified by the mask). This is necessarily synchronous,
    // but may either happen on the next clock edge (on a cache hit) or after
    // multiple cycles of latency (cache miss). As the cache is write-through
    // and write-allocate, writes must be applied to both the cache and
    // underlying memory.
    // It is illegal to assert this and `i_dmem_ren` on the same cycle.
    input  wire        i_req_wen,
    // The memory interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    input  wire [ 3:0] i_req_mask,
    // The 32-bit word to write to memory, if the request is a write
    // (i_req_wen is asserted). Only the bytes corresponding to set bits in
    // the mask should be written into the cache (and to backing memory).
    input  wire [31:0] i_req_wdata,
    // THe 32-bit data word read from memory on a read request.
    output wire [31:0] o_res_rdata
);
    // These parameters are equivalent to those provided in the project
    // 6 specification. Feel free to use them, but hardcoding these numbers
    // rather than using the localparams is also permitted, as long as the
    // same values are used (and consistent with the project specification).
    //
    // 32 sets * 2 ways per set * 16 bytes per way = 1K cache
    localparam O = 4;            // 4 bit offset => 16 byte cache line
    localparam S = 5;            // 5 bit set index => 32 sets
    localparam DEPTH = 2 ** S;   // 32 sets
    localparam W = 2;            // 2 way set associative, NMRU
    localparam T = 32 - O - S;   // 23 bit tag
    localparam D = 2 ** O / 4;   // 16 bytes per line / 4 bytes per word = 4 words per line

    // The following memory arrays model the cache structure. As this is
    // an internal implementation detail, you are *free* to modify these
    // arrays as you please.

    // Backing memory, modeled as two separate ways.
    reg [   31:0] datas0 [DEPTH - 1:0][D - 1:0];
    reg [   31:0] datas1 [DEPTH - 1:0][D - 1:0];
    reg [T - 1:0] tags0  [DEPTH - 1:0];
    reg [T - 1:0] tags1  [DEPTH - 1:0];
    reg [1:0] valid [DEPTH - 1:0];
    reg       lru   [DEPTH - 1:0];

    // FSM States
    localparam IDLE = 3'd0;
    localparam READ_MISS = 3'd1;
    localparam WRITE_MISS = 3'd2;
    localparam WRITE_MEM = 3'd3;

    reg [2:0] state, next_state;
    reg [1:0] word_cnt, next_word_cnt;
    reg [31:0] req_addr_reg;
    reg [31:0] req_wdata_reg;
    reg [3:0] req_mask_reg;
    reg req_is_write;
    reg victim_way_reg;  // Latched victim way at start of miss

    // Address decomposition
    wire [T-1:0] tag = i_req_addr[31:O+S];
    wire [S-1:0] set_idx = i_req_addr[O+S-1:O];
    wire [1:0] word_offset = i_req_addr[3:2];

    wire [T-1:0] tag_reg = req_addr_reg[31:O+S];
    wire [S-1:0] set_idx_reg = req_addr_reg[O+S-1:O];
    wire [1:0] word_offset_reg = req_addr_reg[3:2];

    // Cache hit detection
    wire hit0 = valid[set_idx][0] && (tags0[set_idx] == tag);
    wire hit1 = valid[set_idx][1] && (tags1[set_idx] == tag);
    wire cache_hit = hit0 || hit1;
    wire hit_way = hit1;

    // victim_way_reg is latched when miss starts (see req latch logic above)
    // This prevents LRU updates during fill from changing which way we write to

    // Read data selection with byte masking
    wire [31:0] raw_data0 = datas0[set_idx][word_offset];
    wire [31:0] raw_data1 = datas1[set_idx][word_offset];
    wire [31:0] hit_data = hit1 ? raw_data1 : raw_data0;

    // Apply byte mask to read data
    wire [31:0] masked_rdata;
    assign masked_rdata[7:0]   = i_req_mask[0] ? hit_data[7:0]   : 8'h00;
    assign masked_rdata[15:8]  = i_req_mask[1] ? hit_data[15:8]  : 8'h00;
    assign masked_rdata[23:16] = i_req_mask[2] ? hit_data[23:16] : 8'h00;
    assign masked_rdata[31:24] = i_req_mask[3] ? hit_data[31:24] : 8'h00;

    assign o_res_rdata = masked_rdata;

    // Memory interface
    reg [31:0] mem_addr_reg;
    reg mem_ren_reg, mem_wen_reg;
    reg [31:0] mem_wdata_reg;

    assign o_mem_addr = mem_addr_reg;
    assign o_mem_ren = mem_ren_reg;
    assign o_mem_wen = mem_wen_reg;
    assign o_mem_wdata = mem_wdata_reg;

    // Busy signal
    assign o_busy = (state != IDLE) || 
                    ((i_req_ren || i_req_wen) && !cache_hit);

    // FSM state transition
    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= IDLE;
            word_cnt <= 2'b00;
        end else begin
            state <= next_state;
            word_cnt <= next_word_cnt;
        end
    end

    // Latch request on miss (including victim way selection)
    always @(posedge i_clk) begin
        if (i_rst) begin
            req_addr_reg <= 32'h0;
            req_wdata_reg <= 32'h0;
            req_mask_reg <= 4'h0;
            req_is_write <= 1'b0;
            victim_way_reg <= 1'b0;
        end else if (state == IDLE && (i_req_ren || i_req_wen) && !cache_hit) begin
            req_addr_reg <= i_req_addr;
            req_wdata_reg <= i_req_wdata;
            req_mask_reg <= i_req_mask;
            req_is_write <= i_req_wen;
            // Latch victim way NOW before LRU gets updated during the fill
            victim_way_reg <= lru[set_idx];
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_word_cnt = word_cnt;

        case (state)
            IDLE: begin
                if ((i_req_ren || i_req_wen) && !cache_hit) begin
                    if (i_req_ren) begin
                        next_state = READ_MISS;
                        next_word_cnt = 2'b00;
                    end else begin
                        next_state = WRITE_MISS;
                        next_word_cnt = 2'b00;
                    end
                end
            end

            READ_MISS: begin
                if (i_mem_valid) begin
                    if (word_cnt == 2'd3) begin
                        next_state = IDLE;
                        next_word_cnt = 2'b00;
                    end else begin
                        next_word_cnt = word_cnt + 1;
                    end
                end
            end

            WRITE_MISS: begin
                if (i_mem_valid) begin
                    if (word_cnt == 2'd3) begin
                        next_state = WRITE_MEM;
                        next_word_cnt = 2'b00;
                    end else begin
                        next_word_cnt = word_cnt + 1;
                    end
                end
            end

            WRITE_MEM: begin
                if (i_mem_valid) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Compute merged write data for WRITE_MEM (after miss - cache has filled data)
    wire [31:0] cache_word_data = (victim_way_reg == 1'b0) ? 
                                   datas0[set_idx_reg][word_offset_reg] : 
                                   datas1[set_idx_reg][word_offset_reg];
    wire [31:0] merged_miss_wdata;
    assign merged_miss_wdata[7:0]   = req_mask_reg[0] ? req_wdata_reg[7:0]   : cache_word_data[7:0];
    assign merged_miss_wdata[15:8]  = req_mask_reg[1] ? req_wdata_reg[15:8]  : cache_word_data[15:8];
    assign merged_miss_wdata[23:16] = req_mask_reg[2] ? req_wdata_reg[23:16] : cache_word_data[23:16];
    assign merged_miss_wdata[31:24] = req_mask_reg[3] ? req_wdata_reg[31:24] : cache_word_data[31:24];

    // Memory control signals
    always @(*) begin
        mem_addr_reg = 32'h0;
        mem_ren_reg = 1'b0;
        mem_wen_reg = 1'b0;
        mem_wdata_reg = 32'h0;

        case (state)
            READ_MISS, WRITE_MISS: begin
                mem_addr_reg = {req_addr_reg[31:O], word_cnt, 2'b00};
                mem_ren_reg = i_mem_ready;
                mem_wen_reg = 1'b0;
            end

            WRITE_MEM: begin
                mem_addr_reg = req_addr_reg;
                mem_ren_reg = 1'b0;
                mem_wen_reg = i_mem_ready;
                mem_wdata_reg = merged_miss_wdata;
            end
        endcase
    end

    // Cache update logic
    integer i, j;
    always @(posedge i_clk) begin
        if (i_rst) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                valid[i] <= 2'b00;
                lru[i] <= 1'b0;
                tags0[i] <= {T{1'b0}};
                tags1[i] <= {T{1'b0}};
                for (j = 0; j < D; j = j + 1) begin
                    datas0[i][j] <= 32'h0;
                    datas1[i][j] <= 32'h0;
                end
            end
        end else begin
            // Handle cache hits
            if (state == IDLE && cache_hit) begin
                // Update LRU - accessed way becomes MRU, so OTHER way becomes victim
                // If hit0, way 0 is MRU, so way 1 (lru=1) is next victim
                // If hit1, way 1 is MRU, so way 0 (lru=0) is next victim
                lru[set_idx] <= hit0;

                // Handle writes on hit
                if (i_req_wen) begin
                    if (hit0) begin
                        datas0[set_idx][word_offset] <= 
                            {i_req_mask[3] ? i_req_wdata[31:24] : datas0[set_idx][word_offset][31:24],
                             i_req_mask[2] ? i_req_wdata[23:16] : datas0[set_idx][word_offset][23:16],
                             i_req_mask[1] ? i_req_wdata[15:8]  : datas0[set_idx][word_offset][15:8],
                             i_req_mask[0] ? i_req_wdata[7:0]   : datas0[set_idx][word_offset][7:0]};
                    end else begin
                        datas1[set_idx][word_offset] <= 
                            {i_req_mask[3] ? i_req_wdata[31:24] : datas1[set_idx][word_offset][31:24],
                             i_req_mask[2] ? i_req_wdata[23:16] : datas1[set_idx][word_offset][23:16],
                             i_req_mask[1] ? i_req_wdata[15:8]  : datas1[set_idx][word_offset][15:8],
                             i_req_mask[0] ? i_req_wdata[7:0]   : datas1[set_idx][word_offset][7:0]};
                    end
                end
            end

            // Handle read miss - fill cache line
            if (state == READ_MISS && i_mem_valid) begin
                if (victim_way_reg == 1'b0) begin
                    datas0[set_idx_reg][word_cnt] <= i_mem_rdata;
                    if (word_cnt == 2'd3) begin
                        tags0[set_idx_reg] <= tag_reg;
                        valid[set_idx_reg][0] <= 1'b1;
                        // Way 0 is now MRU, so way 1 is next victim (lru=1)
                        lru[set_idx_reg] <= 1'b1;
                    end
                end else begin
                    datas1[set_idx_reg][word_cnt] <= i_mem_rdata;
                    if (word_cnt == 2'd3) begin
                        tags1[set_idx_reg] <= tag_reg;
                        valid[set_idx_reg][1] <= 1'b1;
                        // Way 1 is now MRU, so way 0 is next victim (lru=0)
                        lru[set_idx_reg] <= 1'b0;
                    end
                end
            end

            // Handle write miss - fill cache line then write
            if (state == WRITE_MISS && i_mem_valid) begin
                if (victim_way_reg == 1'b0) begin
                    datas0[set_idx_reg][word_cnt] <= i_mem_rdata;
                    if (word_cnt == 2'd3) begin
                        tags0[set_idx_reg] <= tag_reg;
                        valid[set_idx_reg][0] <= 1'b1;
                        // Way 0 is now MRU, so way 1 is next victim (lru=1)
                        lru[set_idx_reg] <= 1'b1;
                    end
                end else begin
                    datas1[set_idx_reg][word_cnt] <= i_mem_rdata;
                    if (word_cnt == 2'd3) begin
                        tags1[set_idx_reg] <= tag_reg;
                        valid[set_idx_reg][1] <= 1'b1;
                        // Way 1 is now MRU, so way 0 is next victim (lru=0)
                        lru[set_idx_reg] <= 1'b0;
                    end
                end
            end

            // Apply the write after filling the line
            if (state == WRITE_MEM && i_mem_valid) begin
                if (victim_way_reg == 1'b0) begin
                    datas0[set_idx_reg][word_offset_reg] <= 
                        {req_mask_reg[3] ? req_wdata_reg[31:24] : datas0[set_idx_reg][word_offset_reg][31:24],
                         req_mask_reg[2] ? req_wdata_reg[23:16] : datas0[set_idx_reg][word_offset_reg][23:16],
                         req_mask_reg[1] ? req_wdata_reg[15:8]  : datas0[set_idx_reg][word_offset_reg][15:8],
                         req_mask_reg[0] ? req_wdata_reg[7:0]   : datas0[set_idx_reg][word_offset_reg][7:0]};
                end else begin
                    datas1[set_idx_reg][word_offset_reg] <= 
                        {req_mask_reg[3] ? req_wdata_reg[31:24] : datas1[set_idx_reg][word_offset_reg][31:24],
                         req_mask_reg[2] ? req_wdata_reg[23:16] : datas1[set_idx_reg][word_offset_reg][23:16],
                         req_mask_reg[1] ? req_wdata_reg[15:8]  : datas1[set_idx_reg][word_offset_reg][15:8],
                         req_mask_reg[0] ? req_wdata_reg[7:0]   : datas1[set_idx_reg][word_offset_reg][7:0]};
                end
            end
        end
    end

endmodule

`default_nettype wire