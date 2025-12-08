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

    // FSM states
    localparam [1:0] IDLE       = 2'd0,
                     READ_MISS  = 2'd1,
                     WRITE_MISS = 2'd2,
                     WRITE_MEM  = 2'd3;

    // =========================================================================
    // Storage Arrays
    // =========================================================================
    // Backing memory, modeled as two separate ways.
    reg [   31:0] datas0 [DEPTH - 1:0][D - 1:0];
    reg [   31:0] datas1 [DEPTH - 1:0][D - 1:0];
    reg [T - 1:0] tags0  [DEPTH - 1:0];
    reg [T - 1:0] tags1  [DEPTH - 1:0];
    reg [1:0] valid [DEPTH - 1:0];
    reg       lru   [DEPTH - 1:0];

    // =========================================================================
    // Address Decomposition
    // =========================================================================
    // Current request address breakdown
    wire [T-1:0] req_tag        = i_req_addr[31 : O+S];
    wire [S-1:0] req_set        = i_req_addr[O+S-1 : O];
    wire [1:0]   req_word       = i_req_addr[3:2];
    
    // Latched request address breakdown (for miss handling)
    wire [T-1:0] latched_tag    = latched_addr[31 : O+S];
    wire [S-1:0] latched_set    = latched_addr[O+S-1 : O];
    wire [1:0]   latched_word   = latched_addr[3:2];
    wire [31:0]  line_base_addr = {latched_addr[31:O], {O{1'b0}}};

    // =========================================================================
    // Hit Detection
    // =========================================================================
    wire hit_way0   = valid[req_set][0] && (tags0[req_set] == req_tag);
    wire hit_way1   = valid[req_set][1] && (tags1[req_set] == req_tag);
    wire cache_hit  = hit_way0 || hit_way1;
    wire req_active = i_req_ren || i_req_wen;

    // =========================================================================
    // Read Data Path
    // =========================================================================
    wire [31:0] way0_data = datas0[req_set][req_word];
    wire [31:0] way1_data = datas1[req_set][req_word];
    wire [31:0] hit_data  = hit_way1 ? way1_data : way0_data;
    
    // Apply read mask (zero out masked bytes)
    assign o_res_rdata = {
        i_req_mask[3] ? hit_data[31:24] : 8'h00,
        i_req_mask[2] ? hit_data[23:16] : 8'h00,
        i_req_mask[1] ? hit_data[15:8]  : 8'h00,
        i_req_mask[0] ? hit_data[7:0]   : 8'h00
    };

    // =========================================================================
    // FSM State & Control Registers
    // =========================================================================
    reg [1:0]  state, next_state;
    reg [1:0]  word_cnt;              // Current word being fetched (0-3)
    reg        req_pending;           // Memory request in flight for current word
    reg        victim_way;            // Which way to fill (latched at miss start)
    reg [31:0] latched_addr;          // Latched request address
    reg [31:0] latched_wdata;         // Latched write data
    reg [3:0]  latched_mask;          // Latched byte mask

    // Busy when processing a miss OR when a new request misses
    assign o_busy = (state != IDLE) || (req_active && !cache_hit);

    // =========================================================================
    // Byte-Masked Write Data Computation
    // =========================================================================
    // For write-miss: merge new data with data just fetched into cache
    wire [31:0] cache_data_for_merge = (victim_way == 1'b0) 
                                     ? datas0[latched_set][latched_word]
                                     : datas1[latched_set][latched_word];
    
    wire [31:0] merged_write_data = {
        latched_mask[3] ? latched_wdata[31:24] : cache_data_for_merge[31:24],
        latched_mask[2] ? latched_wdata[23:16] : cache_data_for_merge[23:16],
        latched_mask[1] ? latched_wdata[15:8]  : cache_data_for_merge[15:8],
        latched_mask[0] ? latched_wdata[7:0]   : cache_data_for_merge[7:0]
    };

    // For write-hit: merge new data with existing cache data
    wire [31:0] way0_merged = {
        i_req_mask[3] ? i_req_wdata[31:24] : way0_data[31:24],
        i_req_mask[2] ? i_req_wdata[23:16] : way0_data[23:16],
        i_req_mask[1] ? i_req_wdata[15:8]  : way0_data[15:8],
        i_req_mask[0] ? i_req_wdata[7:0]   : way0_data[7:0]
    };
    
    wire [31:0] way1_merged = {
        i_req_mask[3] ? i_req_wdata[31:24] : way1_data[31:24],
        i_req_mask[2] ? i_req_wdata[23:16] : way1_data[23:16],
        i_req_mask[1] ? i_req_wdata[15:8]  : way1_data[15:8],
        i_req_mask[0] ? i_req_wdata[7:0]   : way1_data[7:0]
    };

    // =========================================================================
    // Memory Interface
    // =========================================================================
    reg [31:0] mem_addr;
    reg        mem_ren, mem_wen;
    reg [31:0] mem_wdata;
    
    assign o_mem_addr  = mem_addr;
    assign o_mem_ren   = mem_ren;
    assign o_mem_wen   = mem_wen;
    assign o_mem_wdata = mem_wdata;

    always @(*) begin
        mem_addr  = 32'h0;
        mem_ren   = 1'b0;
        mem_wen   = 1'b0;
        mem_wdata = 32'h0;

        case (state)
            READ_MISS, WRITE_MISS: begin
                // Fetch cache line: base address + word offset
                mem_addr = line_base_addr + {28'b0, word_cnt, 2'b00};
                mem_ren  = i_mem_ready && !req_pending;
            end
            
            WRITE_MEM: begin
                // Write-through to memory
                mem_addr  = latched_addr;
                mem_wen   = i_mem_ready;
                mem_wdata = merged_write_data;
            end
        endcase
    end

    // =========================================================================
    // FSM Next State Logic
    // =========================================================================
    reg [1:0] next_word_cnt;
    wire      line_fill_done = (word_cnt == 2'd3) && i_mem_valid;
    
    always @(*) begin
        next_state    = state;
        next_word_cnt = word_cnt;

        case (state)
            IDLE: begin
                if (req_active && !cache_hit) begin
                    next_state    = i_req_ren ? READ_MISS : WRITE_MISS;
                    next_word_cnt = 2'b00;
                end
            end

            READ_MISS: begin
                if (i_mem_valid) begin
                    next_word_cnt = word_cnt + 1'b1;
                    if (line_fill_done) begin
                        next_state    = IDLE;
                        next_word_cnt = 2'b00;
                    end
                end
            end

            WRITE_MISS: begin
                if (i_mem_valid) begin
                    next_word_cnt = word_cnt + 1'b1;
                    if (line_fill_done) begin
                        next_state    = WRITE_MEM;
                        next_word_cnt = 2'b00;
                    end
                end
            end

            WRITE_MEM: begin
                // Write accepted - return to idle
                if (i_mem_ready)
                    next_state = IDLE;
            end
        endcase
    end

    // =========================================================================
    // FSM State Register & Request Tracking
    // =========================================================================
    always @(posedge i_clk) begin
        if (i_rst) begin
            state       <= IDLE;
            word_cnt    <= 2'b00;
            req_pending <= 1'b0;
        end else begin
            state    <= next_state;
            word_cnt <= next_word_cnt;
            
            // Track in-flight memory requests to prevent duplicates
            if (state == IDLE || state == WRITE_MEM)
                req_pending <= 1'b0;
            else if ((state == READ_MISS || state == WRITE_MISS) && i_mem_ready && !req_pending)
                req_pending <= 1'b1;
            else if (i_mem_valid)
                req_pending <= 1'b0;
        end
    end

    // =========================================================================
    // Latch Request on Miss
    // =========================================================================
    always @(posedge i_clk) begin
        if (i_rst) begin
            latched_addr  <= 32'h0;
            latched_wdata <= 32'h0;
            latched_mask  <= 4'h0;
            victim_way    <= 1'b0;
        end else if (state == IDLE && req_active && !cache_hit) begin
            latched_addr  <= i_req_addr;
            latched_wdata <= i_req_wdata;
            latched_mask  <= i_req_mask;
            victim_way    <= lru[req_set];  // Latch before LRU updates
        end
    end

    // =========================================================================
    // Cache Update Logic
    // =========================================================================
    integer i, j;
    
    always @(posedge i_clk) begin
        if (i_rst) begin
            // Reset all metadata (data arrays don't need reset)
            for (i = 0; i < DEPTH; i = i + 1) begin
                valid[i] <= 2'b00;
                lru[i]   <= 1'b0;
                tags0[i] <= {T{1'b0}};
                tags1[i] <= {T{1'b0}};
                for (j = 0; j < D; j = j + 1) begin
                    datas0[i][j] <= 32'h0;
                    datas1[i][j] <= 32'h0;
                end
            end
        end else begin
            
            // -----------------------------------------------------------------
            // Cache Hit Handling
            // -----------------------------------------------------------------
            if (state == IDLE && cache_hit) begin
                // Update LRU: mark accessed way as MRU
                lru[req_set] <= hit_way0;  // If hit way0, next victim is way1 (lru=1)
                
                // Write hit: update cache with masked data
                if (i_req_wen) begin
                    if (hit_way0)
                        datas0[req_set][req_word] <= way0_merged;
                    else
                        datas1[req_set][req_word] <= way1_merged;
                end
            end

            // -----------------------------------------------------------------
            // Cache Line Fill (READ_MISS or WRITE_MISS)
            // -----------------------------------------------------------------
            if ((state == READ_MISS || state == WRITE_MISS) && i_mem_valid) begin
                if (victim_way == 1'b0) begin
                    datas0[latched_set][word_cnt] <= i_mem_rdata;
                    if (line_fill_done) begin
                        tags0[latched_set]        <= latched_tag;
                        valid[latched_set][0]     <= 1'b1;
                        lru[latched_set]          <= 1'b1;  // Way 0 is MRU, evict way 1 next
                    end
                end else begin
                    datas1[latched_set][word_cnt] <= i_mem_rdata;
                    if (line_fill_done) begin
                        tags1[latched_set]        <= latched_tag;
                        valid[latched_set][1]     <= 1'b1;
                        lru[latched_set]          <= 1'b0;  // Way 1 is MRU, evict way 0 next
                    end
                end
            end

            // -----------------------------------------------------------------
            // Write-Through to Cache (after line fill completes)
            // -----------------------------------------------------------------
            if (state == WRITE_MEM && i_mem_ready) begin
                if (victim_way == 1'b0)
                    datas0[latched_set][latched_word] <= merged_write_data;
                else
                    datas1[latched_set][latched_word] <= merged_write_data;
            end
            
        end
    end

endmodule

`default_nettype wire
