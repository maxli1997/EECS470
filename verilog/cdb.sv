/////////////////////////////////////////////////////////////////////////
//                                                                     //
//  Modulename :  cdb.sv                                               //
//                                                                     //
//  Description :  This module creates the common data bus.            // 
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __CDB_SV__
`define __CDB_SV__

`timescale 1ns/100ps

// TODO: need to broadcast the bit vector of the BRAT dependency !!
//          also squash the unneeded cdb values (so hard ----)

// For now, assuming that the cbd never has structual hazard because 
// it has the same capacity as the rob


module cdb_quque_entry(
    input                       clock, reset,
    input                       clear,
    input                       ld_address,
    input   EX_PACKET           ex_pkt,
    output  CDB_RETIRE_PACKET   packet_out                
);
    logic [`PR_LEN-1:0]     dest_phy_reg;
    logic [`XLEN-1:0]       dest_result;
    logic [`XLEN-1:0]       NPC;
    logic                   valid;
    logic [`ROB_LEN-1:0]    cdb_tag;                // rob_num
    logic                   branch_rst;             // take_branch
    logic [`BRAT_SIZE-1:0]  brat_vec;
    logic					cond_branch;
	logic					uncond_branch;
    logic                   rd_mem, wr_mem;
    logic                   halt, illegal, csr_op;
    logic [`XLEN-1:0]       rs2_value;
    logic                   ld_addr;

    assign packet_out.valid = valid;
    assign packet_out.result = dest_result;
    assign packet_out.take_branch = branch_rst;
    assign packet_out.dest_phy_reg = dest_phy_reg;
    assign packet_out.rob_num = cdb_tag;
    assign packet_out.brat_vec = brat_vec;
    assign packet_out.cond_branch = cond_branch;
    assign packet_out.uncond_branch = uncond_branch;
    assign packet_out.NPC = NPC;
    assign packet_out.rd_mem = rd_mem;
    assign packet_out.wr_mem = wr_mem;
    assign packet_out.halt = halt;
    assign packet_out.illegal = illegal;
    assign packet_out.csr_op = csr_op;
    assign packet_out.rs2_value = rs2_value;
    assign packet_out.lsq_valid = ld_addr;

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset || clear) begin
            valid <= `SD 0;
            dest_phy_reg <= `SD 0;
            dest_result <= `SD 0;
            cdb_tag <= `SD 0;
            branch_rst  <= `SD 0;
            cond_branch <= `SD 0;
            uncond_branch <= `SD 0;
            brat_vec <= `SD {`BRAT_SIZE{1'b0}};
            NPC      <= `SD 0;
            rd_mem      <= `SD 0;
            wr_mem      <= `SD 0;
            halt        <= `SD 0;
            illegal     <= `SD 0;
            csr_op      <= `SD 0;
            rs2_value   <= `SD 0;
            ld_addr     <= `SD 0;
        end
        else if (ex_pkt.valid) begin
            valid           <= `SD 1;
            dest_result     <= `SD ex_pkt.result;
            dest_phy_reg    <= `SD ex_pkt.dest_phy_reg;
            cdb_tag         <= `SD ex_pkt.rob_num;
            branch_rst      <= `SD ex_pkt.take_branch;
            brat_vec        <= `SD ex_pkt.brat_vec;
            cond_branch     <= `SD ex_pkt.cond_branch;
            uncond_branch   <= `SD ex_pkt.uncond_branch;
            NPC             <= `SD ex_pkt.NPC;
            rd_mem          <= `SD ex_pkt.rd_mem;
            wr_mem          <= `SD ex_pkt.wr_mem;
            halt            <= `SD ex_pkt.halt;
            illegal         <= `SD ex_pkt.illegal;
            csr_op          <= `SD ex_pkt.csr_op;
            rs2_value       <= `SD ex_pkt.rs2_value;
            if (ld_address)
                ld_addr     <= `SD 1;                   // this is a broadcast of load address (not value)
            else 
                ld_addr     <= `SD 0;
        end
    end

endmodule

module cdb #(parameter buf_len = 5, parameter buf_size = 32) (
    input                       clock, reset,
    input   EX_PACKET           alu1_pkt, alu2_pkt,
    input   EX_PACKET           mult1_pkt, mult2_pkt,
    input                       mispredict,                             // mispredict from rob
    input   [`BRAT_SIZE-1:0]    brat_mis,                               // the mispredict brat vector
    input   [`BRAT_LEN-1:0]     correct_index1, correct_index2,         // the correct shift index
    input                       index1_valid, index2_valid,       
    input   EX_PACKET           ld_commit_pkt1, ld_commit_pkt2,      
    output                      cdb1_valid, cdb2_valid,
    output  [`ROB_LEN-1:0]      cdb1_tag, cdb2_tag,                     // rob number to update           
    output  [`PR_LEN-1:0]       cdb1_phy_reg, cdb2_phy_reg,             // used to update PRF entry
    output                      cdb1_branch_rst, cdb2_branch_rst,       // valid when cdb valid is high
    output                      cdb1_is_branch, cdb2_is_branch,
    output  [`XLEN-1:0]         cdb1_data, cdb2_data,                   // valid when cdb valid is high
    output  [`BRAT_SIZE-1:0]    cdb1_brat_vec, cdb2_brat_vec,
    output  CDB_RETIRE_PACKET [buf_size-1:0] retire_packet,
    output  [buf_len-1:0]       head_out, tail_out, head_plus1_out
    /* slots_left contains how many free space in cdb queue, maximum 4, minimum 0 */
    // ,output  [buf_len-1:0]       slots_left                                  
);

    logic [buf_len-1:0] head, tail;     // tail points to the first buffer that is empty
    logic [buf_len-1:0] head_plus1, head_plus2;
    logic [buf_len-1:0] tail_plus1, tail_plus2, tail_plus3, tail_plus4, tail_plus5, tail_plus6;
    logic [buf_len-1:0] tail_minus1;
    logic [buf_len-1:0] next_head, next_tail;
    logic [2:0] valid_inputs;
    logic retire_one, retire_two;
    logic [buf_len-1:0] n_head;
    logic [buf_len-1:0] current_tail_ptr;
    logic [buf_len-1:0] temp1, temp2, temp3, temp4, temp5;

    // indicate which entry will be cleared next cycle
    logic [buf_size-1:0] clear_arr;
    logic [buf_size-1:0] load_addr_arr;
    EX_PACKET ex_input [buf_size-1:0];

    // the cdb queue module
    cdb_quque_entry cbd_buffer [buf_size-1:0] (
        .clock(clock), .reset(reset),
        .clear(clear_arr),
        .ld_address(load_addr_arr),
        .ex_pkt(ex_input),
        .packet_out(retire_packet)
    );


    assign head_out = head;
    assign head_plus1_out = head_plus1;
    assign tail_out = tail;

    assign head_plus1   = (head == buf_size-1) ? 0 : (head+1);
    assign head_plus2   = (head_plus1 == buf_size-1) ? 0 : (head_plus1+1);
    assign tail_plus1   = (tail == buf_size-1) ? 0 : (tail+1);
    assign tail_plus2   = (tail_plus1 == buf_size-1) ? 0 : (tail_plus1+1);
    assign tail_plus3   = (tail_plus2 == buf_size-1) ? 0 : (tail_plus2+1);
    assign tail_plus4   = (tail_plus3 == buf_size-1) ? 0 : (tail_plus3+1);
    assign tail_plus5   = (tail_plus4 == buf_size-1) ? 0 : (tail_plus4+1);
    assign tail_plus6   = (tail_plus5 == buf_size-1) ? 0 : (tail_plus5+1);
    assign tail_minus1  = (tail == 0) ? (buf_size-1) : (tail-1);

    
    assign retire_one = retire_packet[head].valid;
    assign retire_two = retire_one && retire_packet[head_plus1].valid;
    /* CDB broadcast values */
    assign cdb1_valid       = retire_packet[head].valid && !retire_packet[head].lsq_valid;
    assign cdb1_tag         = retire_packet[head].rob_num;
    assign cdb1_phy_reg     = retire_packet[head].dest_phy_reg;
    assign cdb1_branch_rst  = retire_packet[head].take_branch;
    assign cdb1_data        = retire_packet[head].result;
    assign cdb1_brat_vec    = retire_packet[head].brat_vec;
    assign cdb1_is_branch   = retire_packet[head].cond_branch | retire_packet[head].uncond_branch;

    assign cdb2_valid       = retire_packet[head_plus1].valid && !retire_packet[head_plus1].lsq_valid;
    assign cdb2_tag         = retire_packet[head_plus1].rob_num;
    assign cdb2_phy_reg     = retire_packet[head_plus1].dest_phy_reg;
    assign cdb2_branch_rst  = retire_packet[head_plus1].take_branch;
    assign cdb2_data        = retire_packet[head_plus1].result;
    assign cdb2_brat_vec    = retire_packet[head_plus1].brat_vec;
    assign cdb2_is_branch   = retire_packet[head_plus1].cond_branch | retire_packet[head_plus1].uncond_branch;
    
    assign next_head    =   n_head; 
    assign next_tail    =   (valid_inputs==6 ? tail_plus6 :
                            (valid_inputs==5 ? tail_plus5 :
                            (valid_inputs==4 ? tail_plus4 : 
                            (valid_inputs==3 ? tail_plus3 : 
                            (valid_inputs==2 ? tail_plus2 : 
                            (valid_inputs==1 ? tail_plus1 : tail))))));


    /* combinational for logic, whenever any instruction finish execution, pass it to the buffer*/
    always_comb begin
        clear_arr = {(buf_size){1'b0}};
        load_addr_arr = {(buf_size){1'b0}};
        ex_input = '{
            (buf_size){'{
                    {`XLEN{1'b0}},      // result
                    {`XLEN{1'b0}},      // NPC
                    1'b0,               // take_branch
                    1'b0,               // cond_branch
                    1'b0,               // uncond_branch
                    {`BRAT_SIZE{1'b0}}, // brat vector
                    {`XLEN{1'b0}},      
                    1'b0, 1'b0,         // rd_mem, wr_mem
                    {`PR_LEN{1'b0}},    // dest_phy_reg
                    {`ROB_LEN{1'b0}},  // rob_num
                    1'b0, 1'b0, 1'b0, 1'b0,
                    3'b0               // mem_size,
                }}
        };
        /* handle the retire cdb broadcast */
        if (retire_two) begin
            clear_arr[head_plus1] = 1;
            clear_arr[head] = 1;
        end
        else if (retire_one) begin
            clear_arr[head] = 1;
        end

        /* When a mispredict happens, clear all the entry with brat_vec > brat_mis*/
        if (mispredict) begin
            // $display("mispredict happens at %d, brat_mis :%b", $time, brat_mis);
            for (int i=0; i<buf_size; i++) begin
                if (retire_packet[i].brat_vec > brat_mis)
                    clear_arr[i] = 1;
            end      
        end

        /* find the next head */
        /* invariant: head must be valid or equal to tail (empty)*/
        n_head = retire_two ? head_plus2 :
                 retire_one ? head_plus1 : head;
        /* skip the invalid packets (got cleared because of mispredict) */
        if (head < tail) begin
            for (int i=buf_size-1; i>0; i--) begin
                if (i > head && i < tail && retire_packet[i].valid && !clear_arr[i]) begin
                    n_head = i;
                end
            end
        end else begin
            if (tail != 0) begin
                for (int i=buf_size-1; i>=0; i--) begin
                    if (i <= tail_minus1 && retire_packet[i].valid && !clear_arr[i]) begin
                        n_head = i;
                    end
                end
            end
            for (int i=buf_size-1; i>=0; i--) begin
                if (i > head && retire_packet[i].valid && !clear_arr[i]) begin
                    n_head = i;
                end   
            end
        end
        if (clear_arr[n_head] && n_head != tail) begin
            n_head = tail;  
        end

        /* When a branch correctly resolved, shift the bits in all brat_vec*/
        if (index1_valid) begin
            // $display("index1 valid, %d, time %d", correct_index1, $time);
            for (int i=0; i<buf_size; i++) begin
                ex_input[i] = retire_packet[i];
                if (correct_index1 == `BRAT_SIZE - 1) begin
                    // shifts
                    ex_input[i].brat_vec = {
                        retire_packet[i].brat_vec[`BRAT_SIZE-2:0],
                        1'b0
                    };
                end 
                else if (correct_index1 == 0) begin
                    ex_input[i].brat_vec = {
                        retire_packet[i].brat_vec[`BRAT_SIZE-1:1],
                        1'b0
                    };
                end
                else begin
                    // shifts
                    for (int j=`BRAT_SIZE-1; j>0; j--) begin
                        if (j <= correct_index1) 
                            ex_input[i].brat_vec[j] = retire_packet[i].brat_vec[j-1];
                    end
                    ex_input[i].brat_vec[0] = 0;
                end
            end           
        end

        if (index2_valid) begin
            // $display("index2 valid, %d, time %d", correct_index2, $time);
            if (index1_valid) begin
                for (int i=0; i<buf_size; i++) begin
                    if (correct_index2 == `BRAT_SIZE-1) begin
                        // shifts
                        ex_input[i].brat_vec = {
                            ex_input[i].brat_vec[`BRAT_SIZE-2:0],
                            1'b0
                        };
                    end 
                    else if (correct_index2 == 0) begin
                        // this should not happen.. because if index1 get shifted, index2 should at least be 1
                        ex_input[i].brat_vec = {
                            ex_input[i].brat_vec[`BRAT_SIZE-1:1],
                            1'b0
                        };
                    end
                    else begin
                        // shifts
                        for (int j=`BRAT_SIZE-1; j>0; j--) begin
                            if (j <= correct_index2) begin
                                ex_input[i].brat_vec[j] = ex_input[i].brat_vec[j-1];
                            end
                        end
                        ex_input[i].brat_vec[0] = 0;
                    end
                end               
            end
            else begin
                //  just index2 
                for (int i=0; i<buf_size; i++) begin
                    ex_input[i] = retire_packet[i];
                    if (correct_index2 == `BRAT_SIZE-1) begin
                        // shifts
                        ex_input[i].brat_vec = {
                            retire_packet[i].brat_vec[`BRAT_SIZE-2:0],
                            1'b0
                        };
                    end 
                    else if (correct_index2 == 0) begin
                        ex_input[i].brat_vec = {
                            retire_packet[i].brat_vec[`BRAT_SIZE-1:1],
                            1'b0
                        };
                    end
                    else begin
                        // shifts
                        for (int j=`BRAT_SIZE-1; j>0; j--) begin
                            if (j <= correct_index2) begin
                                ex_input[i].brat_vec[j] = ex_input[i].brat_vec[j-1];
                            end
                        end
                        ex_input[i].brat_vec[0] = 0;
                    end
                end  
            end 
        end

        /* count valid inputs from function unit, place each of them in correct place */
        valid_inputs = alu1_pkt.valid + alu2_pkt.valid + mult1_pkt.valid + mult2_pkt.valid 
                        + ld_commit_pkt1.valid + ld_commit_pkt2.valid;
        current_tail_ptr = tail;
        if (alu1_pkt.valid) begin
            ex_input[tail] = alu1_pkt;
            if (alu1_pkt.rd_mem)
                load_addr_arr[tail] = 1;
            current_tail_ptr = current_tail_ptr+1;
        end
        if (alu2_pkt.valid) begin
            temp1 = current_tail_ptr;
            ex_input[temp1] = alu2_pkt;
            if (alu2_pkt.rd_mem)
                load_addr_arr[temp1] = 1;
            current_tail_ptr = current_tail_ptr+1;
        end
        if (mult1_pkt.valid) begin
            temp2 = current_tail_ptr;
            ex_input[temp2] = mult1_pkt;
            current_tail_ptr = current_tail_ptr+1;
        end
        if (mult2_pkt.valid) begin
            temp3 = current_tail_ptr;
            ex_input[temp3] = mult2_pkt;
            current_tail_ptr = current_tail_ptr + 1;
        end
        if (ld_commit_pkt1.valid) begin
            temp4 = current_tail_ptr;
            ex_input[temp4] = ld_commit_pkt1;
            current_tail_ptr = current_tail_ptr + 1;
        end
        if (ld_commit_pkt2.valid) begin
            temp5 = current_tail_ptr;
            ex_input[temp5] = ld_commit_pkt2;
            current_tail_ptr = current_tail_ptr + 1;
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
