`timescale 1ns/100ps


module testbench;
    logic                   clock, reset;
    /* inputs from dispatch stage */
    logic                   valid1_in, valid2_in;
    logic                    fu1_in, fu2_in;
    /* inputs from rat */
    logic   [`AR_SIZE-1:0][`PR_LEN-1:0]   rat_arr_in1, rat_arr_in2;
    /* inputs from freelist */
    logic  [`PR_SIZE-1:0]       freelist_in1, freelist_in2;
    /* inputs from rob */
    logic                       mispred1, mispred2;
    // cdb send brat sequence for retire
    logic                       cdb1_en;
    logic                       cdb1_is_branch;
    logic   [`BRAT_SIZE-1:0]    cdb1_vector;
    logic                       cdb2_en;
    logic                       cdb2_is_branch;
    logic   [`BRAT_SIZE-1:0]    cdb2_vector;
	ROB_RETIRE_PACKET	retire_pkt_1, retire_pkt_2;
    logic [`BRAT_SIZE-1:0][`PR_SIZE-1:0]    brat_freelist_out;
    
    /* outputs */
    /* outputs */
    // output to rob to indicate which brat in use
    // remains unchanged if dispatched inst is not branch
    // same cycle
    logic  [`BRAT_SIZE-1:0]   brat_in_use1, brat_in_use2;
    // output to rat to recover from mispred
    // same cycle
    logic                              brat_en;
    logic  [`AR_SIZE-1:0][`PR_LEN-1:0] brat_arr_out;
    logic  [`PR_SIZE-1:0]	            b_freelist_out; 
    // output to freelist to recover from mispred
    // add b_freelist change with retired inst
    logic  [1:0]              full;
    // output to rs when squash and when correctly pred
    // same cycle
    logic  [`BRAT_SIZE-1:0]    brat_mis;
    logic                      c_valid1_out, c_valid2_out;
    logic  [`BRAT_LEN-1:0]     correct_index1, correct_index2;
    // might need whole brat as output
    logic  [`BRAT_SIZE-1:0][`AR_SIZE-1:0][`PR_LEN-1:0]      brat_out;
    logic   [`BRAT_SIZE-1:0][`BRAT_LEN-1:0] brat_sequence_out;
    logic   [`BRAT_SIZE-1:0]                  brat_valid_out;
    logic   [10:0]                      cnt;
    logic  [`AR_SIZE-1:0][`PR_LEN-1:0] c_brat_arr_out;
    logic  [`PR_SIZE-1:0]	            c_b_freelist_out; 
    brat br(
        .clock, .reset, 
        .valid1_in, .valid2_in, 
        .fu1_in, .fu2_in,
        .rat_arr_in1, .rat_arr_in2,
        .freelist_in1, .freelist_in2,
        .mispred1, .mispred2,
        .cdb1_en, .cdb1_is_branch, .cdb1_vector,
        .cdb2_en, .cdb2_is_branch, .cdb2_vector,
        .retire_pkt_1, .retire_pkt_2,
        .brat_in_use1, .brat_in_use2,
        .brat_en, .brat_arr_out,
        .b_freelist_out,
        .full,
        .brat_mis,
        .c_valid1_out, .c_valid2_out,
        .correct_index1, .correct_index2,
        .brat_out,
        .brat_freelist_out,
        .brat_sequence_out,
        .brat_valid_out
        
    );


    always begin
        #5 clock=~clock;
    end

    task check_rat_output;
        // test vector for new inst
        input   inst1_valid, inst2_valid;
	    input   [`BRAT_SIZE-1:0]   brat_in_use1, brat_in_use2;
        // test mispred recovery
        input                              brat_en;
        input  [`AR_SIZE-1:0][`PR_LEN-1:0] brat_arr_out;
        input  [`PR_SIZE-1:0]	            b_freelist_out;   
        // test capacity
        input  [1:0]              full;
        // test for discovering mispred or crepred
        input  [`BRAT_SIZE-1:0]    brat_mis;
        input                      valid1_out, valid2_out;
        input  [`BRAT_LEN-1:0]     index1, index2;
        // test for brat entry
        input  [`BRAT_SIZE-1:0][`AR_SIZE-1:0][`PR_LEN-1:0]      brat_out;

        // test vector for new inst
        input   c_inst1_valid, c_inst2_valid;
	    input   [`BRAT_SIZE-1:0]   c_brat_in_use1, c_brat_in_use2;
        // test mispred recovery
        input                              c_brat_en;
        input  [`AR_SIZE-1:0][`PR_LEN-1:0] c_brat_arr_out;
        input  [`PR_SIZE-1:0]	            c_b_freelist_out;   
        // test capacity
        input  [1:0]              c_full;
        // test for discovering mispred or crepred
        input  [`BRAT_SIZE-1:0]    c_brat_mis;
        input                      c_valid1_out, c_valid2_out;
        input  [`BRAT_LEN-1:0]     c_index1, c_index2;
        // test for brat entry
        input  [`BRAT_SIZE-1:0][`AR_SIZE-1:0][`PR_LEN-1:0]      c_brat_out;
        // test brat vector for new insts
        if (brat_in_use1 != c_brat_in_use1 && c_inst1_valid) begin
            $display("@@@ Wrong brat_in_use1, expected: %b, got: %b", c_brat_in_use1, brat_in_use1);
            $display("@@@ Failed");
            $finish;
        end
        if (brat_in_use2 != c_brat_in_use2 && c_inst2_valid) begin
            $display("@@@ Wrong brat_in_use2, expected: %b, got: %b", c_brat_in_use2, brat_in_use2);
            $display("@@@ Failed");
            $finish;
        end
        // test mispred recovery
        if (brat_en != c_brat_en) begin
            $display("@@@ Wrong brat_en expected: %b", c_brat_en);
            $display("@@@ Failed");
            $finish;
        end
        if (c_brat_en && brat_arr_out != c_brat_arr_out) begin
            $display("@@@ Wrong brat_arr_out");
            $display("@@@ Failed");
            $finish;
        end
        if (c_brat_en && b_freelist_out != c_b_freelist_out) begin
            $display("@@@ Wrong b_freelist_out");
            $display("@@@ Failed");
            $finish;
        end
        // test if brat is full
        if (full != c_full) begin
            $display("@@@ Wrong full, expected: %d, got: %d", c_full, full);
            $display("@@@ Failed");
            $finish;
        end
        // test output to rs
        if (c_brat_en && brat_mis != c_brat_mis) begin
            $display("@@@ Wrong brat_mis, expected: %b, got: %b", c_brat_mis, brat_mis);
            $display("@@@ Failed");
            $finish;
        end
        if (valid1_out != c_valid1_out) begin
            $display("@@@ Wrong valid1_out, expected: %b", c_valid1_out);
            $display("@@@ Failed");
            $finish;
        end
        if (valid2_out != c_valid2_out) begin
            $display("@@@ Wrong valid2_out, expected: %b", c_valid2_out);
            $display("@@@ Failed");
            $finish;
        end
        if (c_valid1_out && index1 != c_index1) begin
            $display("@@@ Wrong correct_index1, expected: %d, got: %d", c_index1, index1);
            $display("@@@ Failed");
            $finish;
        end
        if (c_valid2_out && index2 != c_index2) begin
            $display("@@@ Wrong correct_index2, expected: %d, got: %d", c_index2, index2);
            $display("@@@ Failed");
            $finish;
        end                       
    endtask
    task show_brat;
	    
        input                              brat_en;
        input  [`AR_SIZE-1:0][`PR_LEN-1:0] brat_arr_out;
        input  [`PR_SIZE-1:0]	            b_freelist_out;   
        input  [1:0]              full;
        input  [`BRAT_SIZE-1:0][`AR_SIZE-1:0][`PR_LEN-1:0]  brat_out;
        input  [`BRAT_SIZE-1:0][`BRAT_LEN-1:0] brat_sequence_out;
        input  [`BRAT_SIZE-1:0]                  brat_valid_out;
        input   [10:0] cycle_num;
        input   valid1_in, valid2_in;
        input  [`BRAT_SIZE-1:0]  brat_in_use1, brat_in_use2;
        input [`BRAT_SIZE-1:0][`PR_SIZE-1:0]    brat_freelist; 
        begin
            $display("@@@\t\tCycle %d", cycle_num);
            $display("@@@brat is full? : %b", full);
            $display("@@@updated brat from last cycle:");
            $display("@@@updated brat valid: %b", brat_valid_out);
            $display("@@@updated brat sequence: ");
            for (int i = `BRAT_SIZE-1; i >= 0; i = i-1) begin
                $display("@@@ %d", brat_sequence_out[i]);
            end
            for (int i = `BRAT_SIZE-1; i >= 0; i = i-1) begin
                if (!brat_valid_out[i]) 
                    break;
                $display("@@@brat entry: %d", brat_sequence_out[i]);
                $display("@@@\t\tAR#\t\t\t\t\t\tPR#");
                for (int j = 0; j < `AR_SIZE; j = j+1)  begin
                    $display("@@@\t%d\t\t\t\t\t\t%d", j, brat_out[brat_sequence_out[i]][j]);
                end
                $display("@@@bfreelist entry: %d", brat_sequence_out[i]);
                $display("@@@\t\tAR#\t\t\t\t\t\tUSED");
                for (int j = 0; j < `PR_SIZE; j = j+1)  begin
                    $display("@@@\t%d\t\t\t\t\t\t%d", j, brat_freelist[brat_sequence_out[i]][j]);
                end
            end
            if (brat_en) begin
                $display("@@@mispred brat");
                $display("@@@\t\tAR#\t\t\t\t\t\tPR#");
                for (int j = 0; j < `AR_SIZE; j = j+1)  begin
                    $display("@@@\t%d\t\t\t\t\t\t%d", j, brat_arr_out[j]);
                end
                $display("@@@mispred bfreelist");
                $display("@@@\t\tPR#\t\t\t\t\t\tUSED");
                for (int j = 0; j < `PR_SIZE; j = j+1)  begin
                    $display("@@@\t%d\t\t\t\t\t\t%b", j, b_freelist_out[j]);
                end
            end
            else begin
                if (valid1_in) begin
                    $display("@@@first inst is valid");
                    $display("@@@corresponding brat vector: %b", brat_in_use1);
                end
                if (valid2_in) begin
                    $display("@@@second inst is valid");
                    $display("@@@corresponding brat vector: %b", brat_in_use2);
                end
            end
            $display("@@@");
        end
    endtask  // show_rat


    initial begin
        // Initiate to all zero except reset
        cnt = 0;
        clock = 0;
        reset = 1;
        //dispatched insts
        valid1_in = 0;
        valid2_in = 0;
        fu1_in = 0;
        fu2_in = 0;
        //freelist assignments
        cdb1_en = 0;
        cdb2_en = 0;
        // mispred case brat being reversed order
        @(negedge clock)
        reset = 0;

        // cycle 0 just check reset, nothing will be done in cycle 0
        @(posedge clock)
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

        // cycle 1 just one branch in no mispred no retire no crepred
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 1;
        fu1_in = 1;
        for (int i=0;i<`AR_SIZE;i++) begin
            rat_arr_in1[i] = 0;
        end
        rat_arr_in1[1] = 5;
        for (int i=0;i<`PR_SIZE;i++) begin
            freelist_in1[i] = 0;
        end
        freelist_in1[5] = 1;
        mispred1 = 0;
        mispred2 = 0;
        retire_pkt_1 = '{
				{`AR_LEN{1'b0}},
				{`PR_LEN{1'b0}}, 
				{`PR_LEN{1'b0}}, 
				{`PC_LEN{1'b0}}, 
				{`FU_LEN{1'b0}}, 
                1'b0,
                1'b0
			};
        retire_pkt_2 = retire_pkt_1;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            1, 0, 4'b1000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        
        //cycle 2 two valid inst first non branch test valid vector
        @(posedge clock)
        cnt = cnt+1;
        valid2_in = 1;
        fu1_in = 0;
        fu2_in = 1;
        rat_arr_in2 = rat_arr_in1;
        rat_arr_in2[2] = 6;
        freelist_in2 = freelist_in1;
        freelist_in2[6] = 1;
        mispred1 = 0;
        mispred2 = 0;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            1, 1, 4'b1000, 4'b1100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        
        //cycle 3 two valid branch test valid and full
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 1;
        fu1_in = 1;
        rat_arr_in1 = rat_arr_in2;
        rat_arr_in1[3] = 7;
        rat_arr_in2 = rat_arr_in1;
        rat_arr_in2[4] = 8;
        freelist_in1 = freelist_in2;
        freelist_in1[7] = 1;
        freelist_in2 = freelist_in1;
        freelist_in2[8] = 1;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            1, 1, 4'b1110, 4'b1111, 0, 0, 0, 2'b11, 0, 0, 0, 0, 0, 0);

        //cycle 4 no valid input two retiring packets test update freelist
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 0;
        valid2_in = 0;
        retire_pkt_1.retire_valid = 1;
        retire_pkt_1.prev_phy_reg = 5;
        retire_pkt_2.retire_valid = 1;
        retire_pkt_2.prev_phy_reg = 6;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            0, 0, 0,0, 0, 0, 0, 2'b11, 0, 0, 0, 0, 0, 0);
        
        //cycle 5 only one mispred
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 0;
        valid2_in = 0;
        retire_pkt_1.retire_valid = 0;
        retire_pkt_2.retire_valid = 0;
        mispred2 = 1;
        cdb2_en = 1;
        cdb2_vector = 4'b1111;
        for (int i=0;i<`AR_SIZE;i++) begin
            c_brat_arr_out[i] = 0;
        end
        c_brat_arr_out[1] = 5;
        c_brat_arr_out[2] = 6;
        c_brat_arr_out[3] = 7;
        c_brat_arr_out[4] = 8;
        for (int i=0;i<`PR_SIZE;i++) begin
            c_b_freelist_out[i] = 0;
        end
        c_b_freelist_out[7] = 1;
        c_b_freelist_out[8] = 1;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            0, 0, 0,0, 1, c_brat_arr_out, c_b_freelist_out, 2'b10, 4'b1110, 0, 0, 0, 0, 0);
        
        //cycle 6 only one mispred but new inst comes in should ignore
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 1;
        valid2_in = 1;
        for (int i=0;i<`AR_SIZE;i++) begin
            rat_arr_in1[i] = i;
        end
        for (int i=0;i<`AR_SIZE;i++) begin
            rat_arr_in2[i] = 2;
        end
        mispred1 = 1;
        mispred2 = 0;
        cdb1_en = 1;
        cdb2_en = 0;
        cdb1_vector = 4'b1110;
        for (int i=0;i<`AR_SIZE;i++) begin
            c_brat_arr_out[i] = 0;
        end
        c_brat_arr_out[1] = 5;
        c_brat_arr_out[2] = 6;
        c_brat_arr_out[3] = 7;
        for (int i=0;i<`PR_SIZE;i++) begin
            c_b_freelist_out[i] = 0;
        end
        c_b_freelist_out[7] = 1;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            0, 0, 0,0, 1, c_brat_arr_out, c_b_freelist_out, 0, 4'b1100, 0, 0, 0, 0, 0);

        //cycle 7 two mispred but mispred2 is the earlier one
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 0;
        valid2_in = 0;
        mispred1 = 1;
        cdb1_en = 1;
        cdb1_vector = 4'b1100;
        mispred2 = 1;
        cdb2_en = 1;
        cdb2_vector = 4'b1000;
        for (int i=0;i<`PR_SIZE;i++) begin
            c_b_freelist_out[i] = 0;
        end
        for (int i=0;i<`AR_SIZE;i++) begin
            c_brat_arr_out[i] = 0;
        end
        c_brat_arr_out[1] = 5;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            0, 0, 0,0, 1, c_brat_arr_out, c_b_freelist_out, 0, 4'b0000, 0, 0, 0, 0, 0);

        //cycle 8 refill brat for future test
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 1;
        for (int i=0;i<`AR_SIZE;i++) begin
            rat_arr_in1[i] = i;
        end
        valid2_in = 1;
        rat_arr_in2 = rat_arr_in1;
        rat_arr_in2[0] = `AR_SIZE;
        for (int i=0;i<`AR_SIZE;i++) begin
            freelist_in1[i] = 1;
        end
        freelist_in2 = freelist_in1;
        freelist_in2[`AR_SIZE] = 1;
        mispred1 = 0;
        cdb1_en = 0;
        mispred2 = 0;
        cdb2_en = 0;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            1, 1, 4'b1000,4'b1100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        
        //cycle 9 refill brat for future test
        @(posedge clock)
        cnt = cnt+1;
        rat_arr_in1 = rat_arr_in2;
        rat_arr_in1[1] = `AR_SIZE + 1;
        rat_arr_in2 = rat_arr_in1;
        rat_arr_in2[2] = `AR_SIZE + 2;
        freelist_in1 = freelist_in2;
        freelist_in1[`AR_SIZE+1] = 1;
        freelist_in2 = freelist_in1;
        freelist_in2[`AR_SIZE+2] = 1;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            1, 1, 4'b1110,4'b1111, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0);
        
        //cycle 10 one crepred at 1100
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 0;
        valid2_in = 0;
        cdb2_en = 1;
        cdb2_is_branch = 1;
        cdb2_vector = 4'b1100;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            0, 0, 0,0, 0, 0, 0, 2, 0, 0, 1, 0, 2, 0);

        //cycle 11 one crepred at 1100 and two insts come in
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 1;
        valid2_in = 1;
        rat_arr_in1 = rat_arr_in2;
        rat_arr_in1[3] = `AR_SIZE + 3;
        rat_arr_in2 = rat_arr_in1;
        rat_arr_in2[4] = `AR_SIZE + 4;
        freelist_in1 = freelist_in2;
        freelist_in1[`AR_SIZE+3] = 1;
        freelist_in2 = freelist_in1;
        freelist_in2[`AR_SIZE+4] = 1;
        cdb1_en = 1;
        cdb2_en = 0;
        cdb1_is_branch = 1;
        cdb1_vector = 4'b1100;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            1, 1, 4'b1110,4'b1111, 0, 0, 0, 3, 0, 1, 0, 2, 0, 0);

        //cycle 12 two crepred at 1000 and 1110 3021->0213->0132
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 0;
        valid2_in = 0;
        cdb1_en = 1;
        cdb2_en = 1;
        cdb1_is_branch = 1;
        cdb1_vector = 4'b1000;
        cdb2_is_branch = 1;
        cdb2_vector = 4'b1110;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            0, 0, 0,0, 0, 0, 0, 0, 0, 1, 1, 3, 2, 0);

        //cycle 13 refill two inst
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 1;
        valid2_in = 1;
        cdb1_en = 0;
        cdb2_en = 0;
        rat_arr_in1 = rat_arr_in2;
        rat_arr_in1[5] = `AR_SIZE + 5;
        rat_arr_in2 = rat_arr_in1;
        rat_arr_in2[6] = `AR_SIZE + 6;
        freelist_in1 = freelist_in2;
        freelist_in1[`AR_SIZE+5] = 1;
        freelist_in2 = freelist_in1;
        freelist_in2[`AR_SIZE+6] = 1;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            1, 1, 4'b1110,4'b1111, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0);

        //cycle 14 one mispred 1110 one crepred 1111 ->1100
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 0;
        valid2_in = 0;
        mispred2 = 1;
        cdb1_en = 1;
        cdb2_en = 1;
        cdb1_is_branch = 1;
        cdb1_vector = 4'b1111;
        cdb2_is_branch = 1;
        cdb2_vector = 4'b1110;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            0, 0, 0,0, 1, rat_arr_in1, freelist_in1, 0, 4'b1100, 0, 0, 0, 0, 0);
        
        //cycle 15 refill two inst
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 1;
        valid2_in = 1;
        mispred2 = 0;
        cdb1_en = 0;
        cdb2_en = 0;
        rat_arr_in1 = rat_arr_in2;
        rat_arr_in1[7] = `AR_SIZE + 7;
        rat_arr_in2 = rat_arr_in1;
        rat_arr_in2[8] = `AR_SIZE + 8;
        freelist_in1 = freelist_in2;
        freelist_in1[`AR_SIZE+7] = 1;
        freelist_in2 = freelist_in1;
        freelist_in2[`AR_SIZE+8] = 1;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            1, 1, 4'b1110,4'b1111, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0);
        
        //cycle 16 one mispred 1110 one crepred 1000 0132->1320 1111->1100->1000
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 0;
        valid2_in = 0;
        mispred1 = 1;
        cdb1_en = 1;
        cdb2_en = 1;
        cdb1_vector = 4'b1110;
        cdb2_vector = 4'b1000;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        check_rat_output(valid1_in, valid2_in, brat_in_use1, brat_in_use2, brat_en, brat_arr_out, 
            b_freelist_out, full, brat_mis, c_valid1_out, c_valid2_out, correct_index1, correct_index2, brat_out,
            0, 0, 0,0, 1, rat_arr_in1, freelist_in1, 0, 4'b1100, 0, 1, 0, 3, 0);

        //cycle 17 check final output
        @(posedge clock)
        cnt = cnt+1;
        valid1_in = 0;
        valid2_in = 0;
        mispred1 = 0;
        cdb1_en = 0;
        cdb2_en = 0;
        #2
        show_brat(brat_en, brat_arr_out, b_freelist_out, full, brat_out,
            brat_sequence_out, brat_valid_out, cnt, valid1_in,valid2_in,brat_in_use1,brat_in_use2,brat_freelist_out);
        $display("@@@ PASSED!");
        $finish;
    end


endmodule