`define PREFETCH_DEPTH      4                           // capacity of each stream buffer
`define PREFETCH_DEPTH_LEN  3

typedef struct packed {
    logic [3:0]             mem_tag;  
    logic [2*`XLEN-1:0]     data;                       // the data received from mem
    logic                   valid;                      // whether the data stored is correct
} STREAM_BUFFER_PACKET;

module buffer_block (
    input                               clock, reset, clear,
    input   STREAM_BUFFER_PACKET        pkt_in,
    
    output  STREAM_BUFFER_PACKET        pkt_out
);

    STREAM_BUFFER_PACKET    pkt;

    assign pkt_out = pkt;

    always_ff (@posedge clock) begin
        if (reset | clear) begin
            pkt <= `SD '{0, 0, 0};
        end else begin
            pkt <= `SD pkt_in;
        end
    end

endmodule

module stream_buffer (
    input   clock, reset,
    input   start,                                      // initiate the buffering of all blocks
    input   [`XLEN-1:0]                 addr_in,        // the address that this buffer starts with (miss pos + 1)
    input   [`XLEN-1:0]                 addr_query,     // the addr to look up
    input   [3:0]                       mem2proc_response,
    input   [63:0]                      mem2proc_data,
    input   [3:0]                       mem2proc_tag,

    output  logic                           hit,            // if the queried addr is found
    output  STREAM_BUFFER_PACKET            pkt_out,        // the data of queried addr if found
    output  logic [`PREFETCH_DEPTH_LEN-1:0] actual_depth,   // the actual number of the buffer's blocks in use
                                                            // if 0, then this buffer is not in use and the
                                                            // addr is not valid 
    output  logic [1:0]                 proc2mem_command,
    output  logic [31:0]                proc2mem_addr
);

    logic                   [`PREFETCH_DEPTH_LEN-1:0]   dept_sent;          // similar to TAIL
    logic                   [`PREFETCH_DEPTH_LEN-1:0]   dept_recieved;      // similar to DONE
    logic                   [`XLEN-1:0]                 addr;
    logic                                               clear_buffer;
    STREAM_BUFFER_PACKET    [`PREFETCH_DEPTH-1:0]       buffer_arr;
    STREAM_BUFFER_PACKET    [`PREFETCH_DEPTH-1:0]       buffer_arr_out;

    logic   mem_access_success;
    logic   mem_return_success;
    logic   in_use;

    buffer_block buffers [`PREFETCH_DEPTH-1:0] (
        .clock(clock), .reset(reset),
        .clear(clear_buffer),
        .packet_in(buffer_arr), 
        .packet_out(buffer_arr_out) 
    );

    always_comb begin
        addr_out = addr;
        actual_depth = dept_recieved;

        // decide if there is a hit and output the found pkt if hit
        if (in_use && addr_query >= addr && addr_query < addr + (dept_recieved << 3)) begin
            hit = 1;
        end else begin
            hit = 0;
        end
        pkt_out = '{0, 0, 0};
        if (hit) begin 
            pkt_out = buffer_arr_out[(addr_query - addr) >> 3];
        end

        buffer_arr = buffer_arr_out;
        // ask for next memory addr if in use but not full
        if ((in_use && dept_sent == `PREFETCH_DEPTH) || !in_use) begin
            proc2mem_command = BUS_NONE;
            proc2mem_addr = 0;
            mem_access_success = 0;
        end else begin
            proc2mem_command = BUS_LOAD;
            proc2mem_addr = addr + (dept_sent << 3);
            mem_access_success = (mem2proc_response != 0);
        end
        // update mem_tag info when access to mem successed
        if (mem_access_success) begin    
            buffer_arr[dept_sent].mem_tag = mem2proc_response;
        end

        // parse in-comming data from mem to see if a block has its data resolved
        // if so, update its value and mark it as valid.
        mem_return_success = 0;
        if (mem2proc_tag) begin
            for (int i = 0; i < dept_sent; i++) begin
                if (buffer_arr_out[i] == mem2proc_tag) begin
                    mem_return_success = 1;
                    buffer_arr[i].data = mem2proc_data;
                    buffer_arr[i].valid = 1;
                end
            end
        end

        clear_buffer = 0;
        if (start) begin
            // when start, the cache misses and request is sent to mem, so the bus
            // must not be free. In this next cycle, it will request the address
            proc2mem_command = BUS_NONE;
            proc2mem_addr = 0;
            mem_access_success = 0;
            clear_buffer = 1;
        end
    end

    always_ff (@posedge clock) begin
        if (reset) begin
            dept_sent       <= `SD 0;
            dept_recieved   <= `SD 0;
            addr            <= `SD 0;
            in_use          <= `SD 0;
        end else if (start) begin
            dept_sent       <= `SD 0;
            dept_recieved   <= `SD 0;
            addr            <= `SD addr_in;
            in_use          <= `SD 1;
        end else begin
            if (mem_access_success) begin
                dept_sent <= `SD dept_sent + 1;
            end
            if (mem_return_success) begin
                dept_recieved <= `SD dept_recieved + 1;
            end
        end
    end

endmodule

module prefetcher (
    input   miss,                                                       // whether the instruction cache observes a miss
    input   [`XLEN - 1:0]   addr,                                       // the addr of next block of the missed instruction
    input   [`XLEN - 1:0]   addr_query,                                 // addr to query
    input   [3:0]           mem2proc_response,
    input   [63:0]          mem2proc_data,
    input   [3:0]           mem2proc_tag,

    output  hit,                                                        // whether the inquired addr is stored in buffer
    output  [`XLEN-1:0]     val,                                        // the value that comes with this addr
    output  [1:0]           proc2mem_command,
    output  [31:0]          proc2mem_addr
);

    STREAM_BUFFER_PACKET pkt_out;
    logic   [`PREFETCH_DEPTH_LEN-1:0]   actual_depth;

    stream_buffer buffer (
            .clock(clock), 
            .reset(reset),
            .start(miss), 
            .addr_in(((addr>>3)+1)<<3),
            .addr_query(addr_query),
            .mem2proc_response(mem2proc_response),
            .mem2proc_data(mem2proc_data),
            .mem2proc_tag(mem2proc_tag),

            .hit(hit),
            .pkt_out(pkt_out),
            .actual_depth(actual_depth),
            .proc2mem_command(proc2mem_command),
            .proc2mem_addr(proc2mem_command),
            .proc2mem_data(proc2mem_data)
    );

    always_comb begin
        if (addr[2]) begin
            val = pkt_out.data[`XLEN-1:0];
        end else begin
            val = pkt_out.data[2*`XLEN-1:`XLEN];
        end
    end
endmodule