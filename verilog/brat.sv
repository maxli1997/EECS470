/////////////////////////////////////////////////////////////////////////
//                                                                     //
//  Modulename :  BRAT.sv                                              //
//                                                                     //
//  Description :  Branch Register Renaming Table                      //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __BRAT_SV__
`define __BRAT_SV__

`timescale 1ns/100ps
`define DEBUG_BRAT

module brat(
    input                       clock, reset,
    /* inputs from dispatch stage */
    // if dispatched inst is branch then need to backup rat
    input                       valid1_in, valid2_in,
    input                       fu1_in, fu2_in,

    /* inputs from rat */
    input  [`AR_SIZE-1:0][`PR_LEN-1:0]   rat_arr_in1, rat_arr_in2,
    /* inputs from freelist */
    input  [`PR_SIZE-1:0]       freelist_in1, freelist_in2,
    /* inputs from rob */
    input                       mispred1, mispred2,
    // cdb send brat sequence for retire
    input                       cdb1_en,
    input                       cdb1_is_branch,
    input   [`BRAT_SIZE-1:0]    cdb1_vector,
    input                       cdb2_en,
    input                       cdb2_is_branch,
    input   [`BRAT_SIZE-1:0]    cdb2_vector,
	input   ROB_RETIRE_PACKET	retire_pkt_1, retire_pkt_2,


    /* outputs */
    // output to rob to indicate which brat in use
    // remains unchanged if dispatched inst is not branch
    // same cycle
    output logic [`BRAT_SIZE-1:0]   brat_in_use1, brat_in_use2,
    // output to rat to recover from mispred
    // same cycle
    output logic                             brat_en,
    output logic [`AR_SIZE-1:0][`PR_LEN-1:0] brat_arr_out,
    output logic  [`PR_SIZE-1:0]	    b_freelist_out,    
    // output to freelist to recover from mispred
    // add b_freelist change with retired inst
    output  [1:0]              full,
    // output to rs when squash and when correctly pred
    // same cycle
    output logic [`BRAT_SIZE-1:0]    brat_mis,
    output                      c_valid1_out, c_valid2_out,
    output logic [`BRAT_LEN-1:0]     correct_index1, correct_index2,
    // might need whole brat as output
    output logic [`BRAT_SIZE-1:0][`AR_SIZE-1:0][`PR_LEN-1:0]      brat_out,
    output logic [`BRAT_SIZE-1:0][`PR_SIZE-1:0]    brat_freelist_out
    `ifdef DEBUG_BRAT
    , output [`BRAT_SIZE-1:0][`BRAT_LEN-1:0] brat_sequence_out,
    output [`BRAT_SIZE-1:0]                  brat_valid_out
    `endif
); 

    logic c_valid1, c_valid2;
    logic [`BRAT_SIZE-1:0][`AR_SIZE-1:0][`PR_LEN-1:0]     brat_arr;
    logic [`BRAT_SIZE-1:0][`PR_SIZE-1:0]    brat_freelist;
    logic [`BRAT_SIZE-1:0]                  brat_valid;
    logic [`BRAT_SIZE-1:0][`BRAT_LEN-1:0]   brat_sequence;
    logic [`BRAT_SIZE-1:0]                  brat_valid_next,brat_valid_temp,brat_valid_temp2,brat_valid_temp3,brat_valid_temp4;
    logic [`BRAT_SIZE-1:0][`BRAT_LEN-1:0]   brat_sequence_next,brat_sequence_temp,brat_sequence_temp2,brat_sequence_temp3;
    logic [`BRAT_LEN-1:0]    mispred_brat;
    logic [`BRAT_LEN-1:0]    crepred_brat;
    logic [`BRAT_LEN-1:0]    empty_slot;
    logic [`BRAT_LEN-1:0]    empty_brat;
    logic [`BRAT_LEN-1:0]    empty_slot_plus1;
    logic                    two_cred;

    logic                    mispred;
    // rob_vector can be achieved from cdb_vector
    logic [`BRAT_SIZE-1:0]   rob_vector;

    `ifdef DEBUG_BRAT
    assign brat_sequence_out = brat_sequence;
    assign brat_valid_out = brat_valid;
    `endif
    assign c_valid1_out = c_valid1;
    assign c_valid2_out = c_valid2;
    assign mispred = (mispred1 | mispred2);

    assign full = (brat_valid_temp4[0]) ? 2'b11 : 
            (brat_valid_temp4[1]) ? 2'b10 : 2'b00;

    /* re */
    always_comb begin
        // if (reset) begin
        //     brat_arr = 0;
        //     brat_freelist = 0;
        // end
        brat_freelist = brat_freelist_out;
        brat_arr = brat_out;
        brat_en = 0;
        c_valid1 = 0;
        c_valid2 = 0;
        empty_brat = 0;
        empty_slot_plus1 = 0;
        brat_valid_next = brat_valid;
        brat_valid_temp = brat_valid;
        brat_sequence_temp = brat_sequence;
        brat_sequence_next = brat_sequence;
        rob_vector = 0;
        // if no branch inst then the vector should be unchanged
        brat_in_use1 = brat_valid;
        brat_in_use2 = brat_valid;
        two_cred = 0;
        // first update freelist wrt retired insts
        // every bfreelist should be update since retired inst must be before all unsolved branches
        // for newly dispatched inst this should be handled by freelist
        for (int i = `BRAT_SIZE-1; i >= 0; i = i - 1) begin
            if (!brat_valid[i])
                break;
            if (retire_pkt_1.retire_valid)
                brat_freelist[brat_sequence[i]][retire_pkt_1.prev_phy_reg] = 0;
            if (retire_pkt_2.retire_valid)
                brat_freelist[brat_sequence[i]][retire_pkt_2.prev_phy_reg] = 0;
        end
        // updates valid vector and permutation vector
        // first cosider mispred then dispatch
        // find which vector to use
        if (mispred1 & mispred2) begin
            if (cdb1_vector < cdb2_vector)
                rob_vector = cdb1_vector;
            else
                rob_vector = cdb2_vector;
        end
        else if (mispred1)
            rob_vector = cdb1_vector;
        else if (mispred2)
            rob_vector = cdb2_vector;
        // if mispred find the brat and squash brats afterward
        if (mispred) begin
            // find the corresponding brat to recover
            mispred_brat = 0;
            for (int i = `BRAT_SIZE-1; i >= 0; i = i - 1) begin
                if (!rob_vector[i]) begin
                    mispred_brat = i+1;
                    break;
                end
            end
            // // $display("mispred at time %d, sequence %d", $time, brat_sequence[mispred_brat]);
            brat_arr_out = brat_out[brat_sequence[mispred_brat]];
            b_freelist_out = brat_freelist[brat_sequence[mispred_brat]];
            brat_en = 1;
            // squash brats behind
            for (int i = `BRAT_SIZE-1; i >= 0; i = i - 1) begin
                if (i <= mispred_brat)
                    brat_valid_next[i] = 0;
            end
            brat_mis = brat_valid_next;
            // $display("rob_vector: %d mispred_brat: %d, brat_sequence[mispred_brat]: %d at time %d, brat_vec %d", rob_vector, mispred_brat, brat_sequence[mispred_brat], $time, brat_mis);
        end
        // for correctly predicted branch, need to reform valid vector
        brat_valid_temp = brat_valid_next;
        brat_sequence_temp = brat_sequence_next;
        if (cdb1_en && cdb1_is_branch && !mispred1) begin
            // if this inst is after a mispred inst, than it has been squashed
            if (!(mispred && (cdb1_vector > rob_vector))) begin
                // find the matching brat num
                crepred_brat = 0;
                for (int i = `BRAT_SIZE-1; i >= 0; i = i - 1) begin
                    if (!cdb1_vector[i]) begin
                        crepred_brat = i+1;
                        break;
                    end
                end
                correct_index1 = crepred_brat;
                c_valid1 = 1;
                // the afterward brat will be move forward
                for (int i = `BRAT_SIZE-1; i > 0; i = i - 1) begin
                    if (i <= crepred_brat) begin
                        brat_valid_temp[i] = brat_valid_next[i-1];
                        brat_sequence_temp[i] = brat_sequence_next[i-1];
                    end
                end
                // the rightmost entry is the matching brat and set to invalid
                brat_valid_temp[0] = 0;
                brat_sequence_temp[0] = brat_sequence[crepred_brat];
                two_cred = 1;
            end
        end
        brat_valid_temp2 = brat_valid_temp;
        brat_sequence_temp2 = brat_sequence_temp;
        if (cdb2_en && cdb2_is_branch && !mispred2) begin
            // if this inst is after a mispred inst, than it has been squashed
            if (!(mispred && (cdb2_vector > rob_vector))) begin
                // find the matching brat num
                crepred_brat = 0;
                for (int i = `BRAT_SIZE-1; i >= 0; i = i - 1) begin
                    if (!cdb2_vector[i]) begin
                        crepred_brat = i+1;
                        break;
                    end
                end
                if (two_cred) begin
                    if (crepred_brat < correct_index1) begin
                        // iff this correct index is less than the first correct idx,
                        // we count for the idx shift here
                        crepred_brat = crepred_brat+1;
                    end
                end
                correct_index2 = crepred_brat;
                // $display("correct idx2 %d at %d cdb2_vector %d crepred_brat %d", correct_index2, $time, cdb2_vector, crepred_brat);
                c_valid2 = 1;
                // the afterward brat will be move forward
                for (int i = `BRAT_SIZE-1; i > 0; i = i - 1) begin
                    if (i <= crepred_brat) begin
                        brat_valid_temp2[i] = brat_valid_temp[i-1];
                        brat_sequence_temp2[i] = brat_sequence_temp[i-1];
                    end
                end
                // the rightmost entry is the matching brat and set to invalid
                brat_valid_temp2[0] = 0;
                brat_sequence_temp2[0] = brat_sequence_temp[crepred_brat];
            end
        end
        brat_valid_temp3 = brat_valid_temp2;
        brat_sequence_temp3 = brat_sequence_temp2;
        brat_valid_temp4 = brat_valid_temp3;
        // if not mispred then inst came this cycle is valid
        if (!mispred) begin
            // find an empty slot
            if (valid1_in || valid2_in) begin
                for (int i = `BRAT_SIZE-1; i >= 0; i = i - 1) begin
                    if (brat_valid_temp2[i] == 0) begin
                    empty_slot = i;
                    break;
                    end
                end
            end
            if (valid1_in && fu1_in == 1) begin
                empty_brat = brat_sequence_temp2[empty_slot];
                brat_arr[empty_brat] = rat_arr_in1;
                brat_freelist[empty_brat] = freelist_in1;
                brat_valid_temp3[empty_slot] = 1;
                empty_slot_plus1 = empty_slot-1;
                brat_valid_temp4 = brat_valid_temp3;
            end
            else begin
                empty_slot_plus1 = empty_slot;
            end
            brat_in_use1 = brat_valid_temp3;
            if (valid2_in && fu2_in == 1) begin
                brat_arr[brat_sequence_temp2[empty_slot_plus1]] = rat_arr_in2;
                brat_freelist[brat_sequence_temp2[empty_slot_plus1]] = freelist_in2;
                brat_valid_temp4[empty_slot_plus1] = 1;
            end
            brat_in_use2 = brat_valid_temp4;
        end

    end

    /* Sequential Logic */
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            brat_out <= `SD 0;
            brat_freelist_out <= `SD 0;
            brat_valid <= `SD 0;
            //brat_sequence   <= `SD 0;
            // initial set all valid to 0 and sequence to 0123...
            for (int i = 0; i < `BRAT_SIZE; i = i + 1) begin
                brat_valid[i] <= `SD 0;
                brat_sequence[i] <= `SD i;

            end
        end
        else begin
            brat_out <= `SD brat_arr;
            brat_freelist_out <= `SD brat_freelist;
            brat_valid <= `SD brat_valid_temp4;
            brat_sequence <= `SD brat_sequence_temp3;

        end
    end

endmodule

`endif