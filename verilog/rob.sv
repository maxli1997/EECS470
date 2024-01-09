/////////////////////////////////////////////////////////////////////////
//                                                                     //
//  Modulename :  ROB.sv                                               //
//                                                                     //
//  Description :  This module creates the reorder buffer entry and    // 
//                 reorder buffer.                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __ROB_SV__
`define __ROB_SV__

`timescale 1ns/100ps

module rob_entry(
    input                       clock, reset,
    input                       clear,
    input   ROB_ENTRY_PACKET    packet_in,

    output  ROB_ENTRY_PACKET    packet_out                           
);

    logic                   valid;
    logic [`AR_LEN-1:0]     arch_reg;
    logic [`PR_LEN-1:0]     phy_reg;
    logic [`PR_LEN-1:0]     prev_phy_reg;
    logic [`PC_LEN-1:0]     pc;
    logic                   pred_taken, branch_rst, done;
    ID_EX_PACKET			decoded_packet;

    assign packet_out.valid = valid;
    assign packet_out.arch_reg = arch_reg;
    assign packet_out.phy_reg = phy_reg;
    assign packet_out.prev_phy_reg = prev_phy_reg;
    assign packet_out.pc = pc;
    assign packet_out.pred_taken = pred_taken;
    assign packet_out.branch_rst = branch_rst;
    assign packet_out.done = done;
    assign packet_out.decoded_packet = decoded_packet;

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset || clear) begin
            valid           <= `SD 0;
            arch_reg        <= `SD 0;
            phy_reg         <= `SD 0;
            prev_phy_reg    <= `SD 0;
            pc              <= `SD 0;
            pred_taken      <= `SD 0;
            branch_rst      <= `SD 0;
            done            <= `SD 0;
            decoded_packet  <= `SD '{
				{`XLEN{1'b0}},
				{`XLEN{1'b0}}, 
				{`XLEN{1'b0}}, 
				{`XLEN{1'b0}}, 
				{`AR_LEN{1'b0}},
				{`AR_LEN{1'b0}},
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				{`PR_LEN{1'b0}},
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0, //valid
				1'b0, //pred_taken,
				{`BRAT_SIZE{1'b0}},
                {`ROB_LEN{1'b0}}
			}; 
        end 
        else if (packet_in.valid) begin
            valid           <= `SD 1;
            arch_reg        <= `SD packet_in.arch_reg;
            phy_reg         <= `SD packet_in.phy_reg;
            prev_phy_reg    <= `SD packet_in.prev_phy_reg;
            pc              <= `SD packet_in.pc;
            pred_taken      <= `SD packet_in.pred_taken;
            decoded_packet  <= `SD packet_in.decoded_packet;
            done            <= `SD 0;
            branch_rst      <= `SD 0;
        end
        else if (packet_in.done) begin
            done        <= `SD 1;
            branch_rst  <= `SD ((decoded_packet.cond_branch | decoded_packet.uncond_branch) ? packet_in.branch_rst : 0);
            decoded_packet.NPC <= `SD packet_in.decoded_packet.NPC;
        end
    end

endmodule

module rob(
    input                   clock, reset,
    // dispatch's instructions is valid or not
    input                   valid1_in, valid2_in,
    input   [`AR_LEN-1:0]   arch_reg1_in, arch_reg2_in,
    input   [`PR_LEN-1:0]   phy_reg1_in, phy_reg2_in,
    input   [`PC_LEN-1:0]   pc1_in, pc2_in,
    input   ID_EX_PACKET    decode_pkt_1_in, decode_pkt_2_in,
    input                   pred_taken1_in, pred_taken2_in,

    /* inputs from rat, contain prev_phy_reg */
    input   [`PR_LEN-1:0]   pr1_evict, pr2_evict, 
    input                   pr1_valid, pr2_valid,

    /* inputs from cdb */
    input                   cdb1_valid_in, cdb2_valid_in,
    // rob number
    input   [`ROB_LEN-1:0]  cdb1_tag_in, cdb2_tag_in,
    // if it's a branch, the result of it
    input                   cdb1_branch_rst_in, cdb2_branch_rst_in,
    input   [`XLEN-1:0]     cdb1_data, cdb2_data,
    input                   mshr_full,
    /* outputs for branches */
    output                  mispred_out1, mispred_out2,
    
    // check the next two slots, get high this cycle if met
    // 10 --> completely full, 01 --> one slot left, 00 --> at least two slots empty
    output  [1:0]           full,                               

    // used for mispredicted branch resoution
    output [`ROB_LEN-1:0]   tail_out, tail_plus1_out, head_out, head_plus1_out,
    // only retire if the retire_valid bit in packets is set
    output ROB_RETIRE_PACKET retire_pkt_1, retire_pkt_2
    `ifdef DEBUG_ROB
    , output ROB_ENTRY_PACKET [`ROB_SIZE-1:0] rob_arr_out
    `endif
);
    
    /* Tail points to the first entry that is empty */
    logic   [`ROB_LEN-1:0]  head, tail;
    /* The next intended head & tail */
    logic   [`ROB_LEN-1:0]  next_head, next_tail;
    logic   [`ROB_LEN-1:0]  next_tail_plus1;
    logic   [`ROB_LEN-1:0]  head_plus1, head_plus2, tail_plus1, tail_plus2;
    logic                   rob_retire1, rob_retire2;
    // logic                   discard_retire2;
    logic   [`ROB_LEN-1:0]  first_mispredicted_rob;
    logic   [`ROB_LEN-1:0]  first_mispredicted_rob_plus1;
    logic   [`ROB_SIZE-1:0] clear_arr;
    /* contain the rob_entry to insert the dispatched inst */
    // logic   [`ROB_LEN-1:0]  insert_position1, insert_position2;
    logic   [`PR_LEN-1:0]   prev_pr1, prev_pr2;         // indicate two registers that should be freed at retire


    ROB_ENTRY_PACKET rob_arr [`ROB_SIZE-1:0];
    ROB_ENTRY_PACKET rob_arr_out [`ROB_SIZE-1:0];

    // this is the main part of the rob
    rob_entry rob_body [`ROB_SIZE-1:0] (
        .clock(clock), .reset(reset),
        .clear(clear_arr),
        .packet_in(rob_arr), 
        .packet_out(rob_arr_out) 
    );

    assign prev_pr1 = (pr1_valid) ? pr1_evict : 0;
    assign prev_pr2 = (pr2_valid) ? pr2_evict : 0;

    assign head_plus1 = (head == `ROB_SIZE-1) ? 0 : (head + 1);  
    assign head_plus2 = (head_plus1 == `ROB_SIZE-1) ? 0 : (head_plus1 + 1);
    assign tail_plus1 = (tail == `ROB_SIZE-1) ? 0 : (tail + 1);  
    assign tail_plus2 = (tail_plus1 == `ROB_SIZE-1) ? 0 : (tail_plus1 + 1);
    
    assign full[1] = rob_arr_out[next_tail].valid & !rob_arr_out[next_tail].done;
    assign full[0] = !full[1] & (
                (rob_arr_out[next_tail].valid & rob_arr_out[next_tail].done & !rob_arr_out[next_tail_plus1].done) | 
                (!rob_arr_out[next_tail].valid & rob_arr_out[next_tail_plus1].valid & !rob_arr_out[next_tail_plus1].done));



    // retire the rob if the instruction at the head is done
    // if the first one is a store and mshr full, cannot retire because lsq might lose track
    assign rob_retire1 = rob_arr_out[head].done && !(mshr_full && retire_pkt_1.decoded_packet.wr_mem);
    // retire the second instruction if the first one retired
    // and the second is done, for now, we cannot retire two stores in one cycle...
    //
    assign rob_retire2 = rob_retire1 && rob_arr_out[head_plus1].done && !(retire_pkt_1.decoded_packet.wr_mem && retire_pkt_2.decoded_packet.wr_mem)
                        && !(mshr_full && retire_pkt_2.decoded_packet.wr_mem);
    
    /* commit packet 1 when rob_retire1 is 1 */
    assign retire_pkt_1.arch_reg        = rob_arr_out[head].arch_reg;
    assign retire_pkt_1.phy_reg         = rob_arr_out[head].phy_reg;
    assign retire_pkt_1.prev_phy_reg    = rob_arr_out[head].prev_phy_reg;
    assign retire_pkt_1.pc              = rob_arr_out[head].pc;
    assign retire_pkt_1.decoded_packet  = rob_arr_out[head].decoded_packet;
    assign retire_pkt_1.branch_rst      = rob_arr_out[head].branch_rst;
    assign retire_pkt_1.retire_valid    = rob_retire1;

    /* commit packet 2 when rob_retire2 is 1 */
    assign retire_pkt_2.arch_reg        = rob_arr_out[head_plus1].arch_reg;
    assign retire_pkt_2.phy_reg         = rob_arr_out[head_plus1].phy_reg;
    assign retire_pkt_2.prev_phy_reg    = rob_arr_out[head_plus1].prev_phy_reg;
    assign retire_pkt_2.pc              = rob_arr_out[head_plus1].pc;
    assign retire_pkt_2.decoded_packet  = rob_arr_out[head_plus1].decoded_packet;
    assign retire_pkt_2.branch_rst      = rob_arr_out[head_plus1].branch_rst;
    // if the first retire inst is a wfi, ignore the second retire inst...
    assign retire_pkt_2.retire_valid    = rob_retire2 & !(rob_retire1 & retire_pkt_1.decoded_packet.halt);

    // if a mispredict happens, move tail to first_mispredicted_rob_plus1
    assign next_tail =  (mispred_out1 | mispred_out2) ?  (first_mispredicted_rob_plus1) : valid2_in ? 
                                                                            tail_plus2  : valid1_in ? 
                                                                            tail_plus1  : tail;
    assign next_tail_plus1 = (next_tail == `ROB_SIZE-1) ? 0 : (next_tail+1);
    assign next_head =  rob_retire2 ? head_plus2 :
                        rob_retire1 ? head_plus1 : head;
    
    // mispredicted is high when fu is branch and prediction mismatches
    assign mispred_out1 = (rob_arr_out[cdb1_tag_in].decoded_packet.cond_branch | rob_arr_out[cdb1_tag_in].decoded_packet.uncond_branch)
                            && (cdb1_branch_rst_in ^ rob_arr_out[cdb1_tag_in].pred_taken) && cdb1_valid_in;
    assign mispred_out2 = (rob_arr_out[cdb2_tag_in].decoded_packet.cond_branch | rob_arr_out[cdb2_tag_in].decoded_packet.uncond_branch)
        && (cdb2_branch_rst_in ^ rob_arr_out[cdb2_tag_in].pred_taken) && cdb2_valid_in;

    assign tail_out = tail;
    assign head_out = head;
    assign head_plus1_out = head_plus1;
    assign tail_plus1_out = tail_plus1;

    /* Logic determine if and where a mispredict happens */
    always_comb begin
        if (mispred_out1 && mispred_out2) begin
        // early branch resolution, need to clear 
        // the instructions after the misprediction
            if (head < tail)
                first_mispredicted_rob = (cdb1_tag_in <= cdb2_tag_in) ? cdb1_tag_in : cdb2_tag_in;
            else if (head == tail) begin
                // rob is full
                if ((cdb1_tag_in >= head && cdb2_tag_in >= head) || (cdb1_tag_in < head && cdb2_tag_in < head)) 
                    first_mispredicted_rob = (cdb1_tag_in <= cdb2_tag_in) ? cdb1_tag_in : cdb2_tag_in;
                else 
                    first_mispredicted_rob = (cdb1_tag_in <= cdb2_tag_in) ? cdb2_tag_in : cdb1_tag_in;
            end
            else if (cdb1_tag_in >= head && cdb2_tag_in >= head)
                first_mispredicted_rob = (cdb1_tag_in <= cdb2_tag_in) ? cdb1_tag_in : cdb2_tag_in;
            else if (cdb1_tag_in <= tail && cdb2_tag_in <= tail)
                first_mispredicted_rob = (cdb1_tag_in <= cdb2_tag_in) ? cdb1_tag_in : cdb2_tag_in;
            else
                first_mispredicted_rob = cdb1_tag_in > cdb2_tag_in ? cdb1_tag_in : cdb2_tag_in;
        end
        else if (mispred_out1) begin
            first_mispredicted_rob = cdb1_tag_in;
        end
        else if (mispred_out2) begin
            first_mispredicted_rob = cdb2_tag_in;
        end
        else
            // if no mispredict, set first_mispredicted_rob = tail (the next slot which is empty)
            // if a mispredict happens, (mispred_out1 | mispred_out2) indicate a branch mispredict
            // this is useless
            first_mispredicted_rob = tail;
    end
    assign first_mispredicted_rob_plus1 = (first_mispredicted_rob == `ROB_SIZE-1) ? 0 : (first_mispredicted_rob+1);

    /* Logic determine the dispatch/mispredict/commit/execution_finish of each rob entry */
    always_comb begin
        clear_arr = {(`ROB_SIZE){1'b0}};
        rob_arr = '{
            (`ROB_SIZE) {'{
            {`AR_LEN{1'b0}},
            {`PR_LEN{1'b0}},
            {`PR_LEN{1'b0}},
            {`PC_LEN{1'b0}},
            '{
				{`XLEN{1'b0}},
				{`XLEN{1'b0}}, 
				{`XLEN{1'b0}}, 
				{`XLEN{1'b0}}, 
				{`AR_LEN{1'b0}},
				{`AR_LEN{1'b0}},
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				{`PR_LEN{1'b0}},
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0, //valid
				1'b0, //pred_taken,
				{`BRAT_SIZE{1'b0}},
                {`ROB_LEN{1'b0}}
			},
            1'b0,
            1'b0,
            1'b0,
            1'b0
        }}};
        // When mispredict, squash!!!
        if (first_mispredicted_rob < tail) begin
            // squash from first_mispredicted_rob+1 to tail
            for (int i=0; i<tail; i++) begin
                if (i >= first_mispredicted_rob_plus1) clear_arr[i] = 1;
            end
        end 
        else if (first_mispredicted_rob > tail) begin
            for (int i=0; i<tail; i++) begin
                clear_arr[i] = 1;
            end
            if (first_mispredicted_rob != `ROB_SIZE-1) begin
                for (int i=0; i<`ROB_SIZE; i++) begin
                    if (i >= first_mispredicted_rob_plus1) clear_arr[i] = 1;
                end
            end
        end else if (tail == head && (mispred_out1 | mispred_out2)) begin
            // the very first entry mispredict, squash all but the first entry
            clear_arr = {(`ROB_SIZE){1'b1}};
            clear_arr[head] = 1'b0;
        end

        // instruction retire
        if (rob_retire1) begin
            clear_arr[head] = 1;
        end
        if (rob_retire2) begin
            clear_arr[head_plus1] = 1;
        end

        // dispatch
        if (valid1_in) begin
            clear_arr[tail] = 1'b0;
            if ((mispred_out1 | mispred_out2)) begin
                clear_arr[tail] = 1'b1;
            end
            rob_arr[tail] = '{
                arch_reg1_in,
                phy_reg1_in,
                prev_pr1,                          // the previous phy reg retire at commit
                pc1_in,
                decode_pkt_1_in,
                pred_taken1_in,                     //pred_taken
                1'b0,                               //branch_rst
                1'b0,                               //done
                1'b1                                //valid
            };
        end
        if (valid2_in) begin
            clear_arr[tail_plus1] = 1'b0;
            if ((mispred_out1 | mispred_out2)) begin
                clear_arr[tail_plus1] = 1'b1;
            end
            rob_arr[tail_plus1] = '{
                arch_reg2_in,
                phy_reg2_in,
                prev_pr2,                           // the previous phy reg retire at commit
                pc2_in,
                decode_pkt_2_in,
                pred_taken2_in,                     //pred_taken
                1'b0,                               //branch_rst
                1'b0,                               //done
                1'b1                                //valid
            };
        end           
        // execution finished
        if (cdb1_valid_in & rob_arr_out[cdb1_tag_in].valid) begin
            rob_arr[cdb1_tag_in].done = 1'b1;
            rob_arr[cdb1_tag_in].branch_rst = cdb1_branch_rst_in;
            if (cdb1_branch_rst_in)
                rob_arr[cdb1_tag_in].decoded_packet.NPC = cdb1_data;
            else 
                rob_arr[cdb1_tag_in].decoded_packet.NPC = rob_arr_out[cdb1_tag_in].decoded_packet.NPC;
        end
        if (cdb2_valid_in & rob_arr_out[cdb2_tag_in].valid) begin
            rob_arr[cdb2_tag_in].done = 1'b1;
            rob_arr[cdb2_tag_in].branch_rst = cdb2_branch_rst_in;
            if (cdb2_branch_rst_in)
                rob_arr[cdb2_tag_in].decoded_packet.NPC = cdb2_data;
            else
                rob_arr[cdb2_tag_in].decoded_packet.NPC = rob_arr_out[cdb2_tag_in].decoded_packet.NPC;
        end

    end


    /* Sequential Logic */
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            head <= `SD 0;
            tail <= `SD 0;
        end
        else begin
            head <= `SD next_head;
            tail <= `SD next_tail;           
        end
    end

endmodule

`endif