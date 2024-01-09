`timescale 1ns/100ps

module testbench;

    logic                                       clock, reset;
    logic                                       valid1_in, valid2_in;
    logic                   [`AR_LEN-1:0]       arch_reg1_in, arch_reg2_in;
    logic                   [`PR_LEN-1:0]       phy_reg1_in, phy_reg2_in;
    logic                   [`PC_LEN-1:0]       pc1_in, pc2_in;
    logic                   [`FU_LEN-1:0]       fu1_in, fu2_in;
    logic                                       pred_taken1_in, pred_taken2_in;
    logic                                       cdb1_valid_in, cdb2_valid_in;
    logic                   [`ROB_LEN-1:0]      cdb1_tag_in, cdb2_tag_in;
    logic                                       cdb1_branch_rst_in, cdb2_branch_rst_in;
    logic                                       mispred_out1, mispred_out2;
    logic                   [1:0]               full;                           
    logic                   [`ROB_LEN-1:0]      tail_out, tail_plus1_out, head_out;
    ROB_RETIRE_PACKET                           retire_pkt_1, retire_pkt_2;
    ROB_ENTRY_PACKET        [`ROB_SIZE-1:0]     rob_arr;
    logic                   [10:0]              cnt;
    ID_EX_PACKET    decode_pkt_1_in, decode_pkt_2_in;
    logic   [`PR_LEN-1:0]   pr1_evict, pr2_evict;
    logic pr1_valid, pr2_valid;

    rob r (
        clock, reset,
        valid1_in, valid2_in,
        arch_reg1_in, arch_reg2_in,
        phy_reg1_in, phy_reg2_in,
        pc1_in, pc2_in,
        decode_pkt_1_in, decode_pkt_2_in,
        pred_taken1_in, pred_taken2_in,
        pr1_evict, pr2_evict, 
        pr1_valid, pr2_valid,
        cdb1_valid_in, cdb2_valid_in,
        cdb1_tag_in, cdb2_tag_in,
        cdb1_branch_rst_in, cdb2_branch_rst_in,
        mispred_out1,  mispred_out2,
        full,                               
        tail_out, tail_plus1_out, head_out,
        retire_pkt_1, retire_pkt_2,
        rob_arr
    );

    always begin
        #5 clock=~clock;
    end

    task check_rob_entry;
        input ROB_ENTRY_PACKET rob_entry;
        input correct_valid;
        input [`PC_LEN-1:0] correct_pc;
        input correct_pred_taken;
        input [`AR_LEN-1:0] correct_arg;
        input [`PR_LEN-1:0] correct_prg;
        input correct_done;
        input correct_brst;
        begin
            if (rob_entry.valid != correct_valid) begin
                $display("@@@ Incorrect at time %4.0f", $time);
                $display("@@@ The valid bit of rob_entry is not correct! Wanted: %d, get: %d", correct_valid, rob_entry.valid);
                $display("Test Failed!");
                $finish;
            end
            else if (correct_valid != 0) begin
                if (rob_entry.pc != correct_pc) begin
                $display("@@@ Incorrect at time %4.0f", $time);
                $display("@@@ The pc of rob_entry is not correct! Wanted: %d, get: %d", correct_pc, rob_entry.pc);
                $display("Test Failed!");
                $finish;
                end
                if (rob_entry.pred_taken != correct_pred_taken) begin
                    $display("@@@ Incorrect at time %4.0f", $time);
                    $display("@@@ The predict bit of rob_entry is not correct! Wanted: %d, get: %d", correct_pred_taken, rob_entry.pred_taken);
                    $display("Test Failed!");
                    $finish;
                end
                if (rob_entry.arch_reg != correct_arg) begin
                    $display("@@@ Incorrect at time %4.0f", $time);
                    $display("@@@ The arch reg of rob_entry is not correct! Wanted: %d, get: %d", correct_arg, rob_entry.arch_reg);
                    $display("Test Failed!");
                    $finish;
                end  
                if (rob_entry.phy_reg != correct_prg) begin
                    $display("@@@ Incorrect at time %4.0f", $time);
                    $display("@@@ The phy reg of rob_entry is not correct! Wanted: %d, get: %d", correct_prg, rob_entry.phy_reg);
                    $display("Test Failed!");
                    $finish;
                end  
                if (rob_entry.done != correct_done) begin
                    $display("@@@ Incorrect at time %4.0f", $time);
                    $display("@@@ The done bit of rob_entry is not correct! Wanted: %d, get: %d", correct_done, rob_entry.done);
                    $display("Test Failed!");
                    $finish;
                end      
                if (rob_entry.branch_rst != correct_brst) begin
                    $display("@@@ Incorrect at time %4.0f", $time);
                    $display("@@@ The branch_result of rob_entry is not correct! Wanted: %d, get: %d", correct_brst, rob_entry.branch_rst);
                    $display("Test Failed!");
                    $finish;
                end
            end              
        end
    endtask

    task show_rob_entries;
            input ROB_ENTRY_PACKET [`ROB_SIZE-1:0] rob_arr;
            input [1:0] full;
            input [`ROB_LEN-1:0] head;
            input [`ROB_LEN-1:0] tail;
            input [10:0] cycle_num;
            begin
                // $display("head is at %d", head);
                // $display("head is valid? %d", rob_arr[head].valid);
                $display("@@@\t\tCycle %d", cycle_num);
                $display("@@@\t\tROB#\t\tPC\t\tPRED_TAKEN\t\tARG#\t\tPRG#\t\tDONE\t\tBRRST");
                for (int i = 0; i < `ROB_SIZE; i++) begin
                    if (rob_arr[i].valid) begin
                        if (head == i && head == tail) begin
                            $display("@@@\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%dHEAD,TAIL", 
                            i, rob_arr[i].pc, rob_arr[i].pred_taken,
                            rob_arr[i].arch_reg, rob_arr[i].phy_reg, rob_arr[i].done,
                            rob_arr[i].branch_rst);
                        end
                        else if (head == i) begin
                            // $display("@@@ Head is at %d", head);
                            $display("@@@\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%dHEAD", 
                            i, rob_arr[i].pc, rob_arr[i].pred_taken,
                            rob_arr[i].arch_reg, rob_arr[i].phy_reg, rob_arr[i].done,
                            rob_arr[i].branch_rst);
                        end else if (tail == i) begin
                            $display("@@@\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\tTAIL", 
                            i, rob_arr[i].pc, rob_arr[i].pred_taken,
                            rob_arr[i].arch_reg, rob_arr[i].phy_reg, rob_arr[i].done,
                            rob_arr[i].branch_rst);
                        end else begin
                            $display("@@@\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d", 
                            i, rob_arr[i].pc, rob_arr[i].pred_taken,
                            rob_arr[i].arch_reg, rob_arr[i].phy_reg, rob_arr[i].done,
                            rob_arr[i].branch_rst);
                        end
                    end else begin
                        if (head == tail && i == head) begin
                            $display("@@@\t\t%d\t\t\t\t\t\t\t\t\t\t\t\t\t\tHEAD,TAIL", i);
                        end else if (i == tail) begin
                            $display("@@@\t\t%d\t\t\t\t\t\t\t\t\t\t\t\t\t\tTAIL", i);
                        end else begin
                            $display("@@@\t\t%d", i);
                        end
                    end
                end
                $display("@@@\t\tfull: %d", full);
                $display("@@@");
            end
        endtask  // show_rob_entries

    initial
    begin
        // Initiate to all zero except reset
        cnt = 0;
        clock = 0;
        reset = 1;
        valid1_in = 0;
        valid2_in = 0;
        arch_reg1_in = 0;
        arch_reg2_in = 0;
        phy_reg1_in = 0; 
        phy_reg2_in = 0;
        pc1_in = 0; 
        pc2_in = 0;
        fu1_in = 0;
        fu2_in = 0;
        pred_taken1_in = 0;
        pred_taken2_in = 0;
        cdb1_valid_in = 0;
        cdb2_valid_in = 0;
        cdb1_tag_in = 0;
        cdb2_tag_in = 0;
        cdb1_branch_rst_in = 0;
        cdb2_branch_rst_in = 0;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        @(negedge clock)
        // cycle 1
        cnt=cnt+1;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        assert (head_out == 0 && tail_out == 0) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end
        for (int i=0; i<`ROB_SIZE; i++) begin
            check_rob_entry(rob_arr[i], 0, 0, 0, 0, 0, 0, 0);
        end
        @(negedge clock)
        // cycle 2
        // No valid dispatch
        cnt=cnt+1;
        reset = 0;
        pc1_in = 1;
        pc2_in = 2;
        arch_reg1_in = 1;
        arch_reg2_in = 2;
        phy_reg1_in = 3; 
        phy_reg2_in = 4;
        fu1_in = 1;
        fu2_in = 2;
        pred_taken1_in = 0;
        pred_taken2_in = 0;
        cdb1_valid_in = 0;
        cdb2_valid_in = 0;
        cdb1_tag_in = 1;
        cdb2_tag_in = 2;
        cdb1_branch_rst_in = 0;
        cdb2_branch_rst_in = 1;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        assert (head_out == 0 && tail_out == 0) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end
        for (int i=0; i<`ROB_SIZE; i++) begin
            check_rob_entry(rob_arr[i], 0, 0, 0, 0, 0, 0, 0);
        end
        @(negedge clock)
        // cycle 3
        // Only 1 valid dispatch
        cnt=cnt+1;
        valid1_in = 1;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        assert (head_out == 0 && tail_out == 0) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end   
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end   
        for (int i=0; i<`ROB_SIZE; i++) begin
            check_rob_entry(rob_arr[i], 0, 0, 0, 0, 0, 0, 0);
        end
        @(negedge clock)
        // cycle 4
        // 2 valid dispatch untill full
        cnt=cnt+1;
        valid2_in = 1;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        check_rob_entry(rob_arr[0], 1, 1, 0, 1, 3, 0, 0);
        assert (head_out == 0 && tail_out == 1) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end       
        for (int i=1; i<`ROB_SIZE; i++) begin
            check_rob_entry(rob_arr[i], 0, 0, 0, 0, 0, 0, 0);
        end
        @(negedge clock)
        // cycle 5
        // 2 valid dispatch untill full
        cnt=cnt+1;
        pc1_in = 3;
        pc2_in = 4;
        arch_reg1_in = 3;
        arch_reg2_in = 4;
        phy_reg1_in = 5; 
        phy_reg2_in = 6;
        fu1_in = 3;
        fu2_in = 0;
        pred_taken1_in = 0;
        pred_taken2_in = 1;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        assert (head_out == 0 && tail_out == 3) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end
        check_rob_entry(rob_arr[0], 1, 1, 0, 1, 3, 0, 0);
        check_rob_entry(rob_arr[1], 1, 1, 0, 1, 3, 0, 0);
        check_rob_entry(rob_arr[2], 1, 2, 0, 2, 4, 0, 0);
        for (int i=3; i<`ROB_SIZE; i++) begin
            check_rob_entry(rob_arr[i], 0, 0, 0, 0, 0, 0, 0);
        end
        @(negedge clock)
        // cycle 6
        // 2 valid dispatch untill full
        cnt=cnt+1;
        pc1_in = 5;
        pc2_in = 6;
        arch_reg1_in = 5;
        arch_reg2_in = 6;
        phy_reg1_in = 7; 
        phy_reg2_in = 8;
        fu1_in = 1;
        fu2_in = 3;
        pred_taken1_in = 1;
        pred_taken2_in = 1;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        assert (head_out == 0 && tail_out == 5) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end
        check_rob_entry(rob_arr[0], 1, 1, 0, 1, 3, 0, 0);
        check_rob_entry(rob_arr[1], 1, 1, 0, 1, 3, 0, 0);
        check_rob_entry(rob_arr[2], 1, 2, 0, 2, 4, 0, 0);
        check_rob_entry(rob_arr[3], 1, 3, 0, 3, 5, 0, 0);
        check_rob_entry(rob_arr[4], 1, 4, 1, 4, 6, 0, 0);
        for (int i=5; i<`ROB_SIZE; i++) begin
            check_rob_entry(rob_arr[i], 0, 0, 0, 0, 0, 0, 0);
        end
        @(negedge clock)
        // cycle 7
        // 2 cdb_in, 1 mis_pred at ROB# 3
        cnt=cnt+1;
        valid1_in = 0;
        valid2_in = 0;
        cdb1_valid_in = 1;
        cdb2_valid_in = 1;
        cdb1_tag_in = 3;
        cdb2_tag_in = 2;
        cdb1_branch_rst_in = 1;
        cdb2_branch_rst_in = 1;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);

        assert (head_out == 0 && tail_out == 7) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end   
        // assert (full == 2'b10) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end     
        check_rob_entry(rob_arr[0], 1, 1, 0, 1, 3, 0, 0);
        check_rob_entry(rob_arr[1], 1, 1, 0, 1, 3, 0, 0);
        check_rob_entry(rob_arr[2], 1, 2, 0, 2, 4, 0, 0);
        check_rob_entry(rob_arr[3], 1, 3, 0, 3, 5, 0, 0);
        check_rob_entry(rob_arr[4], 1, 4, 1, 4, 6, 0, 0);
        check_rob_entry(rob_arr[5], 1, 5, 1, 5, 7, 0, 0);
        check_rob_entry(rob_arr[6], 1, 6, 1, 6, 8, 0, 0);
        check_rob_entry(rob_arr[7], 0, 0, 0, 0, 0, 0, 0);
        #1
        assert (mispred_out1 | mispred_out2) 
        else begin
            $error("Something wrong with mispredict!, got %d %d", mispred_out1, mispred_out2);
            $finish;
        end
        // 2 valid dispatch, cdb_in at ROB# 0
        @(negedge clock);
        // cycle 8
        cnt=cnt+1;
        cdb1_valid_in = 1;
        cdb2_valid_in = 0;
        cdb1_tag_in = 0;
        valid1_in = 1;
        valid2_in = 1;
        pc1_in = 1;
        pc2_in = 2;
        arch_reg1_in = 1;
        arch_reg2_in = 2;
        phy_reg1_in = 1; 
        phy_reg2_in = 2;
        fu1_in = 3;
        fu2_in = 3;
        pred_taken1_in = 0;
        pred_taken2_in = 1;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        assert (head_out == 0 && tail_out == 4) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end   
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end    
        check_rob_entry(rob_arr[0], 1, 1, 0, 1, 3, 0, 0);
        check_rob_entry(rob_arr[1], 1, 1, 0, 1, 3, 0, 0);
        check_rob_entry(rob_arr[2], 1, 2, 0, 2, 4, 1, 0);
        check_rob_entry(rob_arr[3], 1, 3, 0, 3, 5, 1, 1);
        check_rob_entry(rob_arr[4], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[5], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[6], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[7], 0, 0, 0, 0, 0, 0, 0);
        #1
        assert (!(mispred_out1 | mispred_out2)) 
        else begin
            $error("Something wrong with mispredict!, got %d %d", mispred_out1, mispred_out2);
            $finish;
        end
        // retire ROB# 0 and 1 valid dispatch
        @(negedge clock)
        // cycle 9
        cnt=cnt+1;
        cdb1_valid_in = 0;
        cdb2_valid_in = 0;
        valid1_in = 1;
        valid2_in = 0;
        pc1_in = 1;
        pc2_in = 2;
        arch_reg1_in = 3;
        phy_reg1_in = 3; 
        fu1_in = 3;
        pred_taken1_in = 1;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        assert (head_out == 0 && tail_out == 6) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end  
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end   
        check_rob_entry(rob_arr[0], 1, 1, 0, 1, 3, 1, 0);
        check_rob_entry(rob_arr[1], 1, 1, 0, 1, 3, 0, 0);
        check_rob_entry(rob_arr[2], 1, 2, 0, 2, 4, 1, 0);
        check_rob_entry(rob_arr[3], 1, 3, 0, 3, 5, 1, 1);
        check_rob_entry(rob_arr[4], 1, 1, 0, 1, 1, 0, 0);
        check_rob_entry(rob_arr[5], 1, 2, 1, 2, 2, 0, 0);
        check_rob_entry(rob_arr[6], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[7], 0, 0, 0, 0, 0, 0, 0);       
        @(negedge clock)
        // cycle 10
        // 2 valid dispatch, 1 cdb_in at ROB# 1
        cnt=cnt+1;
        valid2_in = 1;
        pc2_in = 2;
        arch_reg2_in = 3;
        phy_reg2_in = 3; 
        fu2_in = 3;
        pred_taken2_in = 1;
        cdb1_valid_in = 1;
        cdb1_tag_in = 1;
        cdb2_valid_in = 1;
        cdb2_tag_in = 6;
        cdb2_branch_rst_in = 0;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        assert (head_out == 1 && tail_out == 7) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end 
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end       
        check_rob_entry(rob_arr[0], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[1], 1, 1, 0, 1, 3, 0, 0);
        check_rob_entry(rob_arr[2], 1, 2, 0, 2, 4, 1, 0);
        check_rob_entry(rob_arr[3], 1, 3, 0, 3, 5, 1, 1);
        check_rob_entry(rob_arr[4], 1, 1, 0, 1, 1, 0, 0);
        check_rob_entry(rob_arr[5], 1, 2, 1, 2, 2, 0, 0);
        check_rob_entry(rob_arr[6], 1, 1, 1, 3, 3, 0, 0);
        check_rob_entry(rob_arr[7], 0, 0, 0, 0, 0, 0, 0);  
        @(negedge clock)
        // cycle 11
        // retire ROB# 1&2 and 1 valid dispatch
        cnt=cnt+1;
        cdb1_valid_in = 0;
        cdb2_valid_in = 0;
        valid1_in = 1;
        valid2_in = 0;
        pc1_in = 5;
        arch_reg1_in = 3;
        phy_reg1_in = 3; 
        fu1_in = 3;
        pred_taken1_in = 1;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        assert (head_out == 1 && tail_out == 7) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end   
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end     
        check_rob_entry(rob_arr[0], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[1], 1, 1, 0, 1, 3, 1, 0);
        check_rob_entry(rob_arr[2], 1, 2, 0, 2, 4, 1, 0);
        check_rob_entry(rob_arr[3], 1, 3, 0, 3, 5, 1, 1);
        check_rob_entry(rob_arr[4], 1, 1, 0, 1, 1, 0, 0);
        check_rob_entry(rob_arr[5], 1, 2, 1, 2, 2, 0, 0);
        check_rob_entry(rob_arr[6], 1, 1, 1, 3, 3, 1, 0);
        check_rob_entry(rob_arr[7], 0, 0, 0, 0, 0, 0, 0); 
        @(negedge clock)
        // cycle 12
        // 2 valid dispatch
        cnt=cnt+1;
        valid1_in = 1;
        valid2_in = 1;
        pc1_in = 2;
        pc2_in = 3;
        arch_reg1_in = 4;
        arch_reg2_in = 5;
        phy_reg1_in = 0; 
        phy_reg2_in = 1; 
        fu1_in = 3;
        fu2_in = 3;
        pred_taken1_in = 1;
        pred_taken2_in = 0;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        assert (head_out == 3 && tail_out == 0) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end    
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end    
        check_rob_entry(rob_arr[0], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[1], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[2], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[3], 1, 3, 0, 3, 5, 1, 1);
        check_rob_entry(rob_arr[4], 1, 1, 0, 1, 1, 0, 0);
        check_rob_entry(rob_arr[5], 1, 2, 1, 2, 2, 0, 0);
        check_rob_entry(rob_arr[6], 1, 1, 1, 3, 3, 1, 0);
        check_rob_entry(rob_arr[7], 1, 5, 1, 3, 3, 0, 0); 
        @(negedge clock)
        // cycle 13
        // 2 cdb_in, 2 mis_predict
        cnt=cnt+1;
        cdb1_valid_in = 1;
        cdb2_valid_in = 1;
        cdb1_tag_in = 5;
        cdb2_tag_in = 0;
        cdb1_branch_rst_in = 0;
        cdb2_branch_rst_in = 0;
        valid1_in = 0;
        valid2_in = 0;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        assert (head_out == 4 && tail_out == 2) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end   
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end     
        check_rob_entry(rob_arr[0], 1, 2, 1, 4, 0, 0, 0);
        check_rob_entry(rob_arr[1], 1, 3, 0, 5, 1, 0, 0);
        check_rob_entry(rob_arr[2], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[3], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[4], 1, 1, 0, 1, 1, 0, 0);
        check_rob_entry(rob_arr[5], 1, 2, 1, 2, 2, 0, 0);
        check_rob_entry(rob_arr[6], 1, 1, 1, 3, 3, 1, 0);
        check_rob_entry(rob_arr[7], 1, 5, 1, 3, 3, 0, 0);
        @(negedge clock)
        // cycle 14
        // check the effect if we have two mispredict in one cycle
        cnt=cnt+1;
        cdb1_valid_in = 0;
        cdb2_valid_in = 0;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        assert (head_out == 4 && tail_out == 6) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end  
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end      
        check_rob_entry(rob_arr[0], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[1], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[2], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[3], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[4], 1, 1, 0, 1, 1, 0, 0);
        check_rob_entry(rob_arr[5], 1, 2, 1, 2, 2, 1, 0);
        check_rob_entry(rob_arr[6], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[7], 0, 0, 0, 0, 0, 0, 0);      
        @(negedge clock)
        // cycle 15
        // fill the rob until full
        cnt=cnt+1;
        pc1_in = 199;
        pc2_in = 200;
        valid1_in = 1;
        valid2_in = 1;
        arch_reg1_in = 15;
        arch_reg2_in = 24;
        phy_reg1_in = 33; 
        phy_reg2_in = 30;
        fu1_in = 1;
        fu2_in = 2;
        pred_taken1_in = 0;
        pred_taken2_in = 0;
        cdb1_valid_in = 0;
        cdb2_valid_in = 0;
        cdb1_tag_in = 1;
        cdb2_tag_in = 2;
        cdb1_branch_rst_in = 0;
        cdb2_branch_rst_in = 1; 
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        @(negedge clock)
        // cycle 16
        cnt=cnt+1;
        pc1_in = 204;
        pc2_in = 208;
        valid1_in = 1;
        valid2_in = 1;
        arch_reg1_in = 15;
        arch_reg2_in = 24;
        phy_reg1_in = 33; 
        phy_reg2_in = 30;
        fu1_in = 3;
        fu2_in = 0;
        pred_taken1_in = 1;
        pred_taken2_in = 1;
        cdb1_valid_in = 0;
        cdb2_valid_in = 0;
        cdb1_tag_in = 1;
        cdb2_tag_in = 2;
        cdb1_branch_rst_in = 0;
        cdb2_branch_rst_in = 1; 
        assert (head_out == 4 && tail_out == 0) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end  
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end      
        check_rob_entry(rob_arr[0], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[1], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[2], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[3], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[4], 1, 1, 0, 1, 1, 0, 0);
        check_rob_entry(rob_arr[5], 1, 2, 1, 2, 2, 1, 0);
        check_rob_entry(rob_arr[6], 1, 199, 0, 15, 33, 0, 0);
        check_rob_entry(rob_arr[7], 1, 200, 0, 24, 30, 0, 0);
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        @(negedge clock)
        // cycle 17
        cnt=cnt+1;
        pc1_in = 212;
        pc2_in = 216;
        valid1_in = 1;
        valid2_in = 1;
        arch_reg1_in = 16;
        arch_reg2_in = 25;
        phy_reg1_in = 33; 
        phy_reg2_in = 30;
        fu1_in = 3;
        fu2_in = 3;
        pred_taken1_in = 0;
        pred_taken2_in = 1;
        cdb1_valid_in = 0;
        cdb2_valid_in = 1;
        cdb1_tag_in = 1;
        cdb2_tag_in = 1;
        cdb1_branch_rst_in = 0;
        cdb2_branch_rst_in = 1; 
        assert (head_out == 4 && tail_out == 2) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end  
        // assert (full == 2'b00) 
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end      
        check_rob_entry(rob_arr[0], 1, 204, 1, 15, 33, 0, 0);
        check_rob_entry(rob_arr[1], 1, 208, 1, 24, 30, 0, 0);
        check_rob_entry(rob_arr[2], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[3], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[4], 1, 1, 0, 1, 1, 0, 0);
        check_rob_entry(rob_arr[5], 1, 2, 1, 2, 2, 1, 0);
        check_rob_entry(rob_arr[6], 1, 199, 0, 15, 33, 0, 0);
        check_rob_entry(rob_arr[7], 1, 200, 0, 24, 30, 0, 0);
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
        @(negedge clock)
        // cycle 18
        cnt=cnt+1;
        pc1_in = 212;
        pc2_in = 216;
        valid1_in = 0;
        valid2_in = 0;
        arch_reg1_in = 16;
        arch_reg2_in = 25;
        phy_reg1_in = 33; 
        phy_reg2_in = 30;
        fu1_in = 3;
        fu2_in = 3;
        pred_taken1_in = 0;
        pred_taken2_in = 1;
        cdb1_valid_in = 1;
        cdb2_valid_in = 0;
        cdb1_tag_in = 2;
        cdb2_tag_in = 4;
        cdb1_branch_rst_in = 0;
        cdb2_branch_rst_in = 1; 
        assert (head_out == 4 && tail_out == 4) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end  
        // assert (full == 2'b11) // should be full
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end 
        check_rob_entry(rob_arr[0], 1, 204, 1, 15, 33, 0, 0);
        check_rob_entry(rob_arr[1], 1, 208, 1, 24, 30, 1, 0);
        check_rob_entry(rob_arr[2], 1, 212, 0, 16, 33, 0, 0);
        check_rob_entry(rob_arr[3], 1, 216, 1, 25, 30, 0, 0);
        check_rob_entry(rob_arr[4], 1, 1, 0, 1, 1, 0, 0);
        check_rob_entry(rob_arr[5], 1, 2, 1, 2, 2, 1, 0);
        check_rob_entry(rob_arr[6], 1, 199, 0, 15, 33, 0, 0);
        check_rob_entry(rob_arr[7], 1, 200, 0, 24, 30, 0, 0);
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);  
        @(negedge clock)
        // cycle 19
        // correct prediction
        cnt=cnt+1;
        pc1_in = 228;
        pc2_in = 232;
        valid1_in = 0;
        valid2_in = 0;
        arch_reg1_in = 16;
        arch_reg2_in = 25;
        phy_reg1_in = 33; 
        phy_reg2_in = 30;
        fu1_in = 3;
        fu2_in = 3;
        pred_taken1_in = 0;
        pred_taken2_in = 1;
        cdb1_valid_in = 1;
        cdb2_valid_in = 1;
        cdb1_tag_in = 5;
        cdb2_tag_in = 4;
        cdb1_branch_rst_in = 1;
        cdb2_branch_rst_in = 1; 
        assert (head_out == 4 && tail_out == 4) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end  
        // assert (full == 2'b11) // should be full
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end 
        check_rob_entry(rob_arr[0], 1, 204, 1, 15, 33, 0, 0);
        check_rob_entry(rob_arr[1], 1, 208, 1, 24, 30, 1, 0);
        check_rob_entry(rob_arr[2], 1, 212, 0, 16, 33, 1, 0);
        check_rob_entry(rob_arr[3], 1, 216, 1, 25, 30, 0, 0);
        check_rob_entry(rob_arr[4], 1, 1, 0, 1, 1, 0, 0);
        check_rob_entry(rob_arr[5], 1, 2, 1, 2, 2, 1, 0);
        check_rob_entry(rob_arr[6], 1, 199, 0, 15, 33, 0, 0);
        check_rob_entry(rob_arr[7], 1, 200, 0, 24, 30, 0, 0);
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);   
        @(negedge clock)
        // cycle 20
        // mispredict at HEAD, need to squalsh entire ROB
        cnt=cnt+1;
        cdb1_valid_in = 0;
        cdb2_valid_in = 0;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);  
        assert (head_out == 4 && tail_out == 5) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end  
        // assert (full == 2'b00) // should not be full
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end 
        check_rob_entry(rob_arr[0], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[1], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[2], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[3], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[4], 1, 1, 0, 1, 1, 1, 1);
        check_rob_entry(rob_arr[5], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[6], 0, 0, 0, 0, 0, 0, 0);
        check_rob_entry(rob_arr[7], 0, 0, 0, 0, 0, 0, 0);  
        @(negedge clock)
        // cycle 20 
        // the only remaining inst retire, rob empty
        cnt=cnt+1;
        show_rob_entries(rob_arr, full, head_out, tail_out, cnt);  
        assert (head_out == 5 && tail_out == 5) 
        else begin  
            $error("Something wrong with HEAD/TAIL!");
            $finish;
        end  
        // assert (full == 2'b00) // should not be full
        // else begin
        //     $error("Something wrong with FULL!");
        //     $finish;
        // end 
        for (int i=1; i<`ROB_SIZE; i++) begin
            check_rob_entry(rob_arr[i], 0, 0, 0, 0, 0, 0, 0);
        end
        $display("@@@ PASSED!");
        $finish;
    end


endmodule