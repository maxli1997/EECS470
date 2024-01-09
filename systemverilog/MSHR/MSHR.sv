typedef struct packed {
	logic [`XLEN-1:0]       addr;       // address to access
    logic                   type;       // 0:load or 1:store
    logic [`MSHRLEN-1:0]    mem_tag;    // could be shorter depending on the maximum
                                        // request mem can take at a time
    logic                   done;       // idicating if the mem access has done, mshr
                                        // retire entries pretty much the same as rob
    logic [`XLEN-1:0]       data;       // the data received from mem
    logic                   valid;      // whether this packet is in use
} MSHR_ENTRY_PACKET;

module MSHR_ENTRY (
    input                       clock, reset, clear,
    input   MSHR_ENTRY_PACKET   pkt_in,

    output  MSHR_ENTRY_PACKET   pkt_out
);

MSHR_ENTRY_PACKET mshr_pkt;

assign pkt_out = mshr_pkt;

always_ff (@posedge clock) begin
    if (reset | clear) begin
        mshr_pkt <= `SD '{0, 0, 0, 0, 0, 0};
    end else begin
        mshr_pkt <= `SD pkt_in;
    end
end

endmodule

module MSHR (
    input                                       clock, reset,
    input   MSHR_ENTRY_PACKET                   pkt_in,
    
    input   [3:0]                               mem2proc_response,
    input   [63:0]                              mem2proc_data,
    input   [3:0]                               mem2proc_tag,

    `ifdef DEBUG
    output  logic [`MSHRLEN-1:0]                HEAD, TAIL, SEND,
    output  MSHR_ENTRY_PACKET [`MSHRSIZE-1:0]   mshr_arr_out,
    `endif

    output  logic [`MSHRLEN-1:0]                NEXT_TAIL,              // inform lsq of the tag to allocate
    output  logic                               full,                   // inform lsq of whether the mshr is
                                                                        // saturated
    output  MSHR_ENTRY_PACKET                   retire_pkt,
    output                                      retire_pkt_valid,

    output logic [1:0]                          proc2mem_command,
    output logic [31:0]                         proc2mem_addr,
    output logic [31:0]                         proc2mem_data
    
);

    logic [`MSHRLEN-1:0]    HEAD, TAIL, SEND;
    logic [`MSHRLEN-1:0]    NEXT_HEAD, NEXT_TAIL, NEXT_SEND;
    logic [`MSHRSIZE-1:0]   clear_arr;
    MSHR_ENTRY_PACKET   mshr_arr        [`MSHRSIZE-1:0];
    MSHR_ENTRY_PACKET   mshr_arr_out    [`MSHRSIZE-1:0];
    MSHR_ENTRY_PACKET   retire_pkt;

    MSHR_ENTRY mshrs [`MSHRSIZE-1:0] (
        .clock(clock), .reset(reset),
        .clear(clear_arr),
        .packet_in(mshr_arr), 
        .packet_out(mshr_arr_out) 
    );

    always_comb begin
        mshr_arr            = mshr_arr_out;
        mshr_arr[TAIL]      = pkt_in;
        retire_pkt          = mshr_arr_out[HEAD];
        retire_valid        = mshr_arr_out[HEAD].done & mshr_arr_out[HEAD].valid;
        
        head_store_retire   = retire_valid & mshr_arr_out[HEAD].type;                   // load data by default and
        proc2mem_command    = head_store_retire ? BUS_STORE : mshr_arr_out[SEND].valid  // if head is store, we send
                                                ? BUS_LOAD : BUS_NONE;                  // a store request to mem
                                                                                        // and cache when it retires
        proc2mem_addr       = head_store_retire ? mshr_arr_out[HEAD].addr : 
                                                mshr_arr_out[SEND].addr;
        proc2mem_data       = mshr_arr_out[HEAD].data                                   // matters only when it is 
                                                                                        // writing to mem anyway

        clear_arr       = 0;                                                            // clear entry on retire
        if (retire_valid) begin
            clear_arr[HEAD] = 1'b1;
        end

        // if a regular sending is successful, update the mem tag
        if ((mem2proc_response != 0 && mshr_arr_out[SEND].valid) && !head_store_retire) begin
            mshr_arr[SEND].mem_tag = mem2proc_response;
        end

        if (mem2proc_tag != 0) begin
            for (int i = 0; i < `MSHRSIZE; i++) begin
                if (mshr_arr_out[i].valid && mshr_arr_out[i].mem_tag == mem2proc_tag) begin
                    mshr_arr[i].data = mem2proc_data;
                end
            end
        end

        if (HEAD == `MSHRSIZE-1) begin
            NEXT_HEAD = 0;
        end else begin
            NEXT_HEAD = HEAD + 1;
        end

        if (TAIL == `MSHRSIZE-1) begin
            NEXT_TAIL = 0;
        end else begin
            NEXT_TAIL = HEAD + 1;
        end

        if (SEND == `MSHRSIZE-1) begin
            NEXT_SEND = 0;
        end else begin
            NEXT_SEND = HEAD + 1;
        end

        // retire valid means valid to retire but the retire might not be successful,
        // retire_pkt_valid means the retire is sucessful and the data in the packet
        // can be used for later calculation.
        retire_pkt_valid = retire_valid && !(head_store_retire && mem2proc_response != 0);
        full = (NEXT_TAIL == HEAD);
    end

    always_ff (@posedge clock) begin
        if (reset) begin
            HEAD <= `SD 0;
            TAIL <= `SD 0;
            SEND <= `SD 0;
        end else begin
            // retire HEAD if head is done, when head is write, we have to make sure
            // the write command is done properly as well.
            if (retire_valid && !(head_store_retire && mem2proc_response != 0)) begin
                HEAD <= `SD NEXT_HEAD;
            end
            // mark entry as sent if mem accept the write request. note that we send
            // a request only when SEND is valid and we are not retiring a store.
            if ((mem2proc_response != 0 && mshr_arr_out[SEND].valid) && !head_store_retire) begin
                SEND <= `SD NEXT_SEND;
            end
            // add a new entry if the input packet is valid. assume that no valid packet
            // will be fed when full

            // a problem is, a packet is considered valid to enter MSHR only when it misses in cache
            // so if we simply require not to feed more request, we are introducing structural hezard
            if (pkt_in.valid) begin
                TAIL <= `SD NEXT_TAIL;
            end
        end
    end


endmodule