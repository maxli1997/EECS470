
module MSHR_ENTRY (
    input                       clock, reset, clear,
    input   MSHR_ENTRY_PACKET   pkt_in,

    output  MSHR_ENTRY_PACKET   pkt_out
);

MSHR_ENTRY_PACKET mshr_pkt;

assign pkt_out = mshr_pkt;

// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
    if (reset | clear) begin
        mshr_pkt <= `SD '{0, 0, 0, 0, 0, 0, 0, 0};
    end else if (pkt_in.valid) begin
        mshr_pkt <= `SD pkt_in;
    end else begin
        mshr_pkt <= `SD mshr_pkt;
    end
end

endmodule

module MSHR (
    input                                       clock, reset,
    input   MSHR_ENTRY_PACKET                   pkt_in,
    
    input   [3:0]                               mem2proc_response,
    input   [63:0]                              mem2proc_data,
    input   [3:0]                               mem2proc_tag,
    // msg from dcache, getting a hit store this cycle, don't retire 
    // contain the fresh addr of this cycle's load
    input [`XLEN-1:0]                           load_addr, 


    // tell the dcache controller there are pending stores to this load
    // and dcache content might not be the newest
    output  logic                               load_addr_conflict,
    output  logic [`MSHRLEN-1:0]                HEAD, TAIL, SEND,
    output  MSHR_ENTRY_PACKET [`MSHRSIZE-1:0]   mshr_arr_out,


    output  logic                               full,                   // inform lsq of whether the mshr is
                                                                        // saturated
    output logic                                empty,                  // system cannot halt if empty
    output  MSHR_ENTRY_PACKET                   retire_pkt,
    output logic                                retire_pkt_valid,

    output logic [1:0]                          proc2mem_command,
    output logic [31:0]                         proc2mem_addr,
    output logic [63:0]                         proc2mem_data
    
);

    logic [`MSHRLEN-1:0]    HEAD, TAIL, SEND;
    logic [`MSHRLEN-1:0]    NEXT_HEAD, NEXT_TAIL, NEXT_SEND;
    logic                   retire_valid, head_store_retire;
    logic [`MSHRSIZE-1:0]   clear_arr;
    MSHR_ENTRY_PACKET [`MSHRSIZE-1:0]   mshr_arr;
    MSHR_ENTRY_PACKET [`MSHRSIZE-1:0]   mshr_arr_out;
    MSHR_ENTRY_PACKET   mshr_packet_in;
    MSHR_ENTRY_PACKET   retire_pkt;

    MSHR_ENTRY mshrs [`MSHRSIZE-1:0] (
        .clock(clock), .reset(reset),
        .clear(clear_arr),
        .pkt_in(mshr_arr), 
        .pkt_out(mshr_arr_out) 
    );
    
    assign empty = (HEAD==TAIL) && (SEND==HEAD) && (!mshr_arr_out[HEAD].valid);

    assign retire_valid        = mshr_arr_out[HEAD].done & mshr_arr_out[HEAD].valid;
    assign head_store_retire   = retire_valid & mshr_arr_out[HEAD].typ;                   // load data by default and
        // if head is store, we send a store request to mem and cache when it retires

    always_comb begin
        mshr_packet_in      = pkt_in;
        mshr_arr            = mshr_arr_out;
        retire_pkt          = mshr_arr_out[HEAD];
        // retire_valid        = mshr_arr_out[HEAD].done & mshr_arr_out[HEAD].valid;
        
        // head_store_retire   = retire_valid & mshr_arr_out[HEAD].typ;                   // load data by default and
        // if head is store, we send a store request to mem and cache when it retires
        proc2mem_command    = head_store_retire ? BUS_STORE :                            
                            ((mshr_arr_out[SEND].valid && !mshr_arr_out[SEND].send_wait) ? BUS_LOAD : BUS_NONE);                  
                                                                                        
        // if (proc2mem_command != BUS_NONE)
        //     // $display("send memory request addr %d at time %d", mshr_arr_out[SEND].addr, $time);
        proc2mem_addr       = head_store_retire ? {mshr_arr_out[HEAD].addr[`XLEN-1:3], 3'b0} : 
                                                {mshr_arr_out[SEND].addr[`XLEN-1:3], 3'b0};
        proc2mem_data       = head_store_retire ? mshr_arr_out[HEAD].data : 0;          // matters only when it is 
                                                                                        // writing to mem anyway

        // check if there is unfinshed stores and compare with the current load addr,
        // if equals, output conflict and invalidate cache hit
        load_addr_conflict = 0;
        for (int i=0; i<`MSHRSIZE; i++) begin
            if (mshr_arr_out[i].valid & mshr_arr_out[i].typ 
                    & mshr_arr_out[i].addr[31:2] == load_addr[31:2]) begin
                load_addr_conflict = 1;
            end
        end

        // if a regular sending is successful, update the mem tag
        if ((mem2proc_response != 0 && mshr_arr_out[SEND].valid && !mshr_arr_out[SEND].send_wait) 
                && !head_store_retire) begin
            mshr_arr[SEND].mem_tag = mem2proc_response;
        end

        if (mem2proc_tag != 0) begin
            for (int i = 0; i < `MSHRSIZE; i++) begin
                if (mshr_arr_out[i].valid && mshr_arr_out[i].mem_tag == mem2proc_tag) begin
                    // match tag, the memory response for one reuquest
                    mshr_arr[i].done = 1;
                    if (!mshr_arr_out[i].typ) begin
                        mshr_arr[i].data = mem2proc_data;
                    end else begin
                        // for store operation, assembe the data
                        mshr_arr[i].data = mshr_arr_out[i].data;
                        if (mshr_arr_out[i].wr_size == 2'b00) begin
                            if (mshr_arr_out[i].addr[2:0] == 3'b000)
                                mshr_arr[i].data[63:8] = mem2proc_data[63:8];
                            else if (mshr_arr_out[i].addr[2:0] == 3'b001) begin
                                mshr_arr[i].data[63:16] = mem2proc_data[63:16];
                                mshr_arr[i].data[7:0] = mem2proc_data[7:0];
                            end
                            else if (mshr_arr_out[i].addr[2:0] == 3'b010) begin
                                mshr_arr[i].data[63:24] = mem2proc_data[63:24];
                                mshr_arr[i].data[15:0] = mem2proc_data[15:0];
                            end
                            else if (mshr_arr_out[i].addr[2:0] == 3'b011) begin
                                mshr_arr[i].data[63:32] = mem2proc_data[63:32];
                                mshr_arr[i].data[23:0] = mem2proc_data[23:0];
                            end
                            else if (mshr_arr_out[i].addr[2:0] == 3'b100) begin
                                mshr_arr[i].data[63:40] = mem2proc_data[63:40];
                                mshr_arr[i].data[31:0] = mem2proc_data[31:0];
                            end
                            else if (mshr_arr_out[i].addr[2:0] == 3'b101) begin
                                mshr_arr[i].data[63:48] = mem2proc_data[63:48];
                                mshr_arr[i].data[39:0] = mem2proc_data[39:0];
                            end
                            else if (mshr_arr_out[i].addr[2:0] == 3'b110) begin
                                mshr_arr[i].data[63:56] = mem2proc_data[63:56];
                                mshr_arr[i].data[47:0] = mem2proc_data[47:0];
                            end
                            else begin
                                mshr_arr[i].data[55:0] = mem2proc_data[55:0];
                            end
                        end
                        if (mshr_arr_out[i].wr_size == 2'b01) begin
                            if (mshr_arr_out[i].addr[2:1] == 2'b00)
                                mshr_arr[i].data[63:16] = mem2proc_data[63:16];
                            else if (mshr_arr_out[i].addr[2:1] == 2'b01) begin
                                mshr_arr[i].data[63:32] = mem2proc_data[63:32];
                                mshr_arr[i].data[15:0] = mem2proc_data[15:0];
                            end
                            else if (mshr_arr_out[i].addr[2:1] == 2'b10) begin
                                mshr_arr[i].data[63:48] = mem2proc_data[63:48];
                                mshr_arr[i].data[31:0] = mem2proc_data[31:0];
                            end
                            else begin
                                mshr_arr[i].data[47:0] = mem2proc_data[47:0];
                            end
                        end
                        else begin
                            if (mshr_arr_out[i].addr[2] == 0)
                                mshr_arr[i].data[63:32] = mem2proc_data[63:32];
                            else begin
                                mshr_arr[i].data[31:0] = mem2proc_data[31:0];
                            end
                        end
                    end
                    for (int j=1; j<`MSHRSIZE; j++) begin
                        // if (i+j < `MSHRSIZE && (mshr_arr_out[i+j].addr == mshr_arr_out[i].addr)
                        //     && mshr_arr_out[i+j].send_wait)
                        if (i < TAIL && (mshr_arr_out[i+j].addr[31:3] == mshr_arr_out[i].addr[31:3]) 
                            && mshr_arr_out[i+j].send_wait && i+j < TAIL) begin
                            mshr_arr[i+j].send_wait = 0;
                            if (mshr_arr_out[i+j].typ) begin
                                // if this is a store to same addr, break
                                break;
                            end
                        end else if (i >= TAIL) begin
                            if (i+j < `MSHRSIZE && (mshr_arr_out[i+j].addr[31:3] == mshr_arr_out[i].addr[31:3]) 
                                && mshr_arr_out[i+j].send_wait) begin
                                mshr_arr[i+j].send_wait = 0;
                                if (mshr_arr_out[i+j].typ) begin
                                    // if this is a store to same addr, break
                                    break;
                                end
                            end 
                            else if (i+j >= `MSHRSIZE && (mshr_arr_out[i+j-`MSHRSIZE].addr[31:3] == mshr_arr_out[i].addr[31:3]) 
                                && mshr_arr_out[i+j-`MSHRSIZE].send_wait && i+j-`MSHRSIZE < TAIL) begin
                                mshr_arr[i+j-`MSHRSIZE].send_wait = 0;
                                if (mshr_arr_out[i+j-`MSHRSIZE].typ) begin
                                    // if this is a store to same addr, break
                                    break;
                                end
                            end
                        end
                    end
                end
            end
        end

        // if (!mshr_packet_in.typ) begin
        // need to check if there's a store to the same
        // addr in front of me
        for (int i=0; i<`MSHRSIZE; i++) begin
            if (HEAD+i >= `MSHRSIZE && mshr_arr[HEAD+i-`MSHRSIZE].typ 
                    && (mshr_arr[HEAD+i-`MSHRSIZE].addr[31:3] == mshr_packet_in.addr[31:3]) 
                    && mshr_arr[HEAD+i-`MSHRSIZE].valid && !mshr_arr[HEAD+i-`MSHRSIZE].done) begin
                // if (mshr_packet_in.typ | (!mshr_packet_in.typ && (mshr_arr[HEAD+i-`MSHRSIZE].addr[31:2] == mshr_packet_in.addr[31:2])))
                    mshr_packet_in.send_wait = 1;
                // mshr_packet_in.send_wait = 1;
            end
            else if (HEAD+i < `MSHRSIZE && mshr_arr[HEAD+i].typ 
                    && (mshr_arr[HEAD+i].addr[31:3] == mshr_packet_in.addr[31:3]) 
                    && mshr_arr[HEAD+i].valid && !mshr_arr[HEAD+i].done) begin
                // if (mshr_packet_in.typ | (!mshr_packet_in.typ && (mshr_arr[HEAD+i].addr[31:2] == mshr_packet_in.addr[31:2])))
                    mshr_packet_in.send_wait = 1;
            end
        end
        // end

        mshr_arr[TAIL]      = mshr_packet_in;
        if (HEAD == `MSHRSIZE-1) begin
            NEXT_HEAD = 0;
        end else begin
            NEXT_HEAD = HEAD + 1;
        end

        if (TAIL == `MSHRSIZE-1) begin
            NEXT_TAIL = 0;
        end else begin
            NEXT_TAIL = TAIL + 1;
        end

        if (SEND == `MSHRSIZE-1) begin
            NEXT_SEND = 0;
        end else begin
            NEXT_SEND = SEND + 1;
        end

        // retire valid means valid to retire but the retire might not be successful,
        // retire_pkt_valid means the retire is sucessful and the data in the packet
        // can be used for later calculation.
        retire_pkt_valid = retire_valid && !(head_store_retire && mem2proc_response == 0); 
        clear_arr       = 0;                                                            // clear entry on retire
        if (retire_pkt_valid) begin
            clear_arr[HEAD] = 1'b1;
        end
        full = (NEXT_TAIL == HEAD);
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        // $display("head %d next head %d retirevalid %b headstore retire %b mem2proc res %b",HEAD,NEXT_HEAD,retire_valid,head_store_retire,mem2proc_response);
        if (reset) begin
            HEAD <= `SD 0;
            TAIL <= `SD 0;
            SEND <= `SD 0;
        end else begin
            // retire HEAD if head is done, when head is write, we have to make sure
            // the write command is done properly as well.
            if (retire_pkt_valid) begin
                HEAD <= `SD NEXT_HEAD;
            end
            // mark entry as sent if mem accept the write request. note that we send
            // a request only when SEND is valid and we are not retiring a store.
            if (((mem2proc_response != 0 && mshr_arr_out[SEND].valid) && !head_store_retire 
                && !mshr_arr_out[SEND].send_wait)) begin
                SEND <= `SD NEXT_SEND;
            end
            // add a new entry if the input packet is valid. assume that no valid packet
            // will be fed when full

            // a problem is, a packet is considered valid to enter MSHR only when it misses in cache
            // so if we simply require not to feed more request, we are introducing structural hazard
            if (mshr_packet_in.valid) begin
                TAIL <= `SD NEXT_TAIL;
            end
            
        end
    end


endmodule