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
    // same values are used (and consistent with the project specification)
    // Cache parameters
    localparam O = 4;            // 4 bit offset => 16 byte cache line
    localparam S = 5;            // 5 bit set index => 32 sets
    localparam DEPTH = 2 ** S;   // 32 sets
    localparam W = 2;            // 2 way set associative, NMRU
    localparam T = 32 - O - S;   // 23 bit tag
    localparam D = 2 ** O / 4;   // 4 words per line

    // Cache storage arrays - flattened for Verilog compatibility
    reg [31:0] datas0 [DEPTH * D - 1:0];
    reg [31:0] datas1 [DEPTH * D - 1:0];
    reg [T - 1:0] tags0  [DEPTH - 1:0];
    reg [T - 1:0] tags1  [DEPTH - 1:0];
    reg [1:0] valid [DEPTH - 1:0]; // valid[i][0] = way0, valid[i][1] = way1
    reg       lru   [DEPTH - 1:0]; // 0 = way0 is LRU, 1 = way1 is LRU

    // FSM States (Verilog localparams instead of enum)
    localparam [2:0] IDLE        = 3'b000;
    localparam [2:0] COMPARE     = 3'b001;
    localparam [2:0] READ_MISS   = 3'b010;
    localparam [2:0] WRITE_MISS  = 3'b011;
    localparam [2:0] HIT         = 3'b100;
    localparam [2:0] WRITE_BACK  = 3'b101;
    localparam [2:0] WAIT        = 3'b110;

    reg [2:0] state, next_state;

    // Address decomposition
    wire [T-1:0] req_tag;
    wire [S-1:0] req_set;
    wire [O-1:0] req_offset;
    wire [1:0]   req_word_sel;
    
    assign req_tag      = i_req_addr[31:O+S];
    assign req_set      = i_req_addr[O+S-1:O];
    assign req_offset   = i_req_addr[O-1:0];
    assign req_word_sel = i_req_addr[O-1:2];
    
    // Saved address decomposition (for use during cache operations)
    wire [T-1:0] saved_tag;
    wire [S-1:0] saved_set;
    wire [1:0]   saved_word_sel;
    
    assign saved_tag      = saved_addr[31:O+S];
    assign saved_set      = saved_addr[O+S-1:O];
    assign saved_word_sel = saved_addr[O-1:2];

    // Hit/Miss detection for incoming request (IDLE state - immediate)
    wire hit_way0, hit_way1, cache_hit;
    wire [1:0] valid_bits;
    
    assign valid_bits = valid[req_set];
    assign hit_way0 = valid_bits[0] && (tags0[req_set] == req_tag);
    assign hit_way1 = valid_bits[1] && (tags1[req_set] == req_tag);
    assign cache_hit = hit_way0 || hit_way1;

    // Hit/Miss detection for saved address (used during cache fill completion)
    wire saved_hit_way0, saved_hit_way1, saved_cache_hit;
    wire [1:0] saved_valid_bits;
    
    assign saved_valid_bits = valid[saved_set];
    assign saved_hit_way0 = saved_valid_bits[0] && (tags0[saved_set] == saved_tag);
    assign saved_hit_way1 = saved_valid_bits[1] && (tags1[saved_set] == saved_tag);
    assign saved_cache_hit = saved_hit_way0 || saved_hit_way1;

    // Which way to use - based on current request in IDLE, saved way otherwise
    wire way_select;  // 0 = way0, 1 = way1
    wire way_select_immediate;  // For immediate hits in IDLE
    
    assign way_select_immediate = hit_way1 ? 1'b1 : 
                                 (hit_way0 ? 1'b0 : lru[req_set]);
    // In IDLE state, use immediate computation; otherwise use saved way from miss
    assign way_select = (state == IDLE) ? way_select_immediate : saved_way;

    // Memory interface for cache line fills
    reg [1:0] word_counter;  // For reading 4 words during cache fill
    reg [31:0] saved_addr;
    reg saved_wen;
    reg [31:0] saved_wdata;
    reg [3:0] saved_mask;
    reg saved_way;  // Which way we're using for this operation
    
    // Read data from cache (uses current address in IDLE, saved otherwise)
    wire [31:0] cache_line_word;
    wire [31:0] cache_word_immediate;  // For immediate reads in IDLE
    
    assign cache_word_immediate = way_select_immediate ? 
                                 datas1[req_set * D + req_word_sel] :
                                 datas0[req_set * D + req_word_sel];
    
    assign cache_line_word = (state == IDLE) ? cache_word_immediate :
                            (way_select ? 
                            datas1[saved_set * D + saved_word_sel] :
                            datas0[saved_set * D + saved_word_sel]);

    // Apply byte mask to read data
    wire [31:0] masked_rdata;
    wire [3:0] active_mask;
    
    assign active_mask = (state == IDLE) ? i_req_mask : saved_mask;
    
    assign masked_rdata = {
        active_mask[3] ? cache_line_word[31:24] : 8'h00,
        active_mask[2] ? cache_line_word[23:16] : 8'h00,
        active_mask[1] ? cache_line_word[15:8]  : 8'h00,
        active_mask[0] ? cache_line_word[7:0]   : 8'h00
    };

    assign o_res_rdata = masked_rdata;

    // FSM Outputs (Mealy - depend on state and inputs)
    reg busy, mem_ren, mem_wen;
    reg [31:0] mem_addr, mem_wdata;

    assign o_busy = busy;
    assign o_mem_ren = mem_ren;
    assign o_mem_wen = mem_wen;
    assign o_mem_addr = mem_addr;
    assign o_mem_wdata = mem_wdata;

    // State register
    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic (Mealy machine)
    always @(*) begin
        // Default values
        next_state = state;
        busy = 1'b0;
        mem_ren = 1'b0;
        mem_wen = 1'b0;
        mem_addr = 32'h0;
        mem_wdata = 32'h0;

        case (state)
            IDLE: begin
                busy = 1'b0;
                if (i_req_ren || i_req_wen) begin
                    if (cache_hit) begin
                        // Cache hit - handle immediately
                        if (i_req_wen) begin
                            // Write hit - need to write through
                            next_state = WRITE_BACK;
                            busy = 1'b1;
                        end else begin
                            // Read hit - data available combinationally, stay in IDLE
                            next_state = IDLE;
                            busy = 1'b0;
                        end
                    end else begin
                        // Cache miss - need to fetch from memory
                        next_state = i_req_wen ? WRITE_MISS : READ_MISS;
                        busy = 1'b1;
                    end
                end
            end

            COMPARE: begin
                // After cache fill, check if the filled line hits
                busy = 1'b0;
                if (saved_cache_hit) begin
                    next_state = HIT;
                end else begin
                    // Should not happen - we just filled this line
                    next_state = IDLE;
                end
            end

            HIT: begin
                // Complete operation after cache fill
                busy = 1'b0;
                if (saved_wen) begin
                    next_state = WRITE_BACK;
                end else begin
                    next_state = IDLE;
                end
            end

            READ_MISS: begin
                busy = 1'b1;
                mem_ren = 1'b1;
                mem_addr = {saved_addr[31:O], word_counter, 2'b00};
                if (i_mem_ready) begin
                    next_state = WAIT;
                end
            end

            WRITE_MISS: begin
                busy = 1'b1;
                mem_ren = 1'b1;
                mem_addr = {saved_addr[31:O], word_counter, 2'b00};
                if (i_mem_ready) begin
                    next_state = WAIT;
                end
            end

            WRITE_BACK: begin
                busy = 1'b1;
                mem_wen = 1'b1;
                mem_addr = saved_addr;
                // Write the full cache word (not just saved_wdata)
                // This includes both masked and non-masked bytes
                mem_wdata = cache_line_word;
                if (i_mem_ready) begin
                    next_state = IDLE;
                end
            end

            WAIT: begin
                busy = 1'b1;
                if (i_mem_valid) begin
                    if (word_counter == 2'b11) begin
                        // Cache line fill complete, go to HIT to complete operation
                        // We know it will hit since we just filled the line
                        next_state = HIT;
                    end else begin
                        // Continue filling cache line
                        next_state = saved_wen ? WRITE_MISS : READ_MISS;
                    end
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic for cache updates and bookkeeping
    integer i;
    always @(posedge i_clk) begin
        if (i_rst) begin
            word_counter <= 2'b00;
            saved_addr <= 32'h0;
            saved_wen <= 1'b0;
            saved_wdata <= 32'h0;
            saved_mask <= 4'h0;
            saved_way <= 1'b0;
            
            // Initialize valid bits to 0
            for (i = 0; i < DEPTH; i = i + 1) begin
                valid[i] <= 2'b00;
                lru[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (i_req_ren || i_req_wen) begin
                        if (cache_hit) begin
                            // Immediate hit handling
                            // Update LRU immediately
                            lru[req_set] <= ~way_select_immediate;
                            
                            if (i_req_wen) begin
                                // Write hit - update cache and save for write-through
                                saved_addr <= i_req_addr;
                                saved_wen <= i_req_wen;
                                saved_wdata <= i_req_wdata;
                                saved_mask <= i_req_mask;
                                saved_way <= way_select_immediate;
                                
                                if (way_select_immediate) begin
                                    // Write to way 1 with byte masking
                                    if (i_req_mask[0]) datas1[req_set * D + req_word_sel][7:0]   <= i_req_wdata[7:0];
                                    if (i_req_mask[1]) datas1[req_set * D + req_word_sel][15:8]  <= i_req_wdata[15:8];
                                    if (i_req_mask[2]) datas1[req_set * D + req_word_sel][23:16] <= i_req_wdata[23:16];
                                    if (i_req_mask[3]) datas1[req_set * D + req_word_sel][31:24] <= i_req_wdata[31:24];
                                end else begin
                                    // Write to way 0 with byte masking
                                    if (i_req_mask[0]) datas0[req_set * D + req_word_sel][7:0]   <= i_req_wdata[7:0];
                                    if (i_req_mask[1]) datas0[req_set * D + req_word_sel][15:8]  <= i_req_wdata[15:8];
                                    if (i_req_mask[2]) datas0[req_set * D + req_word_sel][23:16] <= i_req_wdata[23:16];
                                    if (i_req_mask[3]) datas0[req_set * D + req_word_sel][31:24] <= i_req_wdata[31:24];
                                end
                            end
                            // For read hits, no sequential logic needed - data is combinational
                        end else begin
                            // Cache miss - save request info and way selection for later
                            saved_addr <= i_req_addr;
                            saved_wen <= i_req_wen;
                            saved_wdata <= i_req_wdata;
                            saved_mask <= i_req_mask;
                            saved_way <= way_select_immediate;  // Save which way to evict/fill
                            word_counter <= 2'b00;
                        end
                    end
                end

                HIT: begin
                    // Update LRU after cache fill completion (use saved_way)
                    lru[saved_set] <= ~saved_way;
                    
                    // For write hits after cache fill, update cache using saved_way
                    if (saved_wen) begin
                        if (saved_way) begin
                            // Write to way 1 with byte masking
                            if (saved_mask[0]) datas1[saved_set * D + saved_word_sel][7:0]   <= saved_wdata[7:0];
                            if (saved_mask[1]) datas1[saved_set * D + saved_word_sel][15:8]  <= saved_wdata[15:8];
                            if (saved_mask[2]) datas1[saved_set * D + saved_word_sel][23:16] <= saved_wdata[23:16];
                            if (saved_mask[3]) datas1[saved_set * D + saved_word_sel][31:24] <= saved_wdata[31:24];
                        end else begin
                            // Write to way 0 with byte masking
                            if (saved_mask[0]) datas0[saved_set * D + saved_word_sel][7:0]   <= saved_wdata[7:0];
                            if (saved_mask[1]) datas0[saved_set * D + saved_word_sel][15:8]  <= saved_wdata[15:8];
                            if (saved_mask[2]) datas0[saved_set * D + saved_word_sel][23:16] <= saved_wdata[23:16];
                            if (saved_mask[3]) datas0[saved_set * D + saved_word_sel][31:24] <= saved_wdata[31:24];
                        end
                    end
                end

                WAIT: begin
                    if (i_mem_valid) begin
                        // Fill cache line word by word using saved_way
                        if (saved_way) begin
                            datas1[saved_set * D + word_counter] <= i_mem_rdata;
                            if (word_counter == 2'b11) begin
                                tags1[saved_set] <= saved_tag;
                                // Set valid bit for way1, preserve way0's valid bit
                                valid[saved_set] <= {1'b1, valid[saved_set][0]};
                                lru[saved_set] <= 1'b0; // Mark way1 as MRU (way0 is LRU)
                            end
                        end else begin
                            datas0[saved_set * D + word_counter] <= i_mem_rdata;
                            if (word_counter == 2'b11) begin
                                tags0[saved_set] <= saved_tag;
                                // Set valid bit for way0, preserve way1's valid bit
                                valid[saved_set] <= {valid[saved_set][1], 1'b1};
                                lru[saved_set] <= 1'b1; // Mark way0 as MRU (way1 is LRU)
                            end
                        end
                        word_counter <= word_counter + 1;
                    end
                end
            endcase
        end
    end

endmodule

`default_nettype wire