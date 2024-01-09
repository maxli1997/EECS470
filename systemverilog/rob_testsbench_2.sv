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
    logic                   [`ROB_LEN-1:0]      tail_out, head_out;
    ROB_RETIRE_PACKET                           retire_pkt_1, retire_pkt_2;
    ROB_ENTRY_PACKET        [`ROB_SIZE-1:0]     rob_arr;
    logic                   [10:0]              cnt;

    rob r (
        clock, reset,
        valid1_in, valid2_in,
        arch_reg1_in, arch_reg2_in,
        phy_reg1_in, phy_reg2_in,
        pc1_in, pc2_in,
        fu1_in, fu2_in,
        pred_taken1_in, pred_taken2_in,
        cdb1_valid_in, cdb2_valid_in,
        cdb1_tag_in, cdb2_tag_in,
        cdb1_branch_rst_in, cdb2_branch_rst_in,
        mispred_out1, mispred_out2,
        full,                               
        tail_out, head_out,
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
        input [`FU_LEN-1:0] correct_fu;
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
                if (rob_entry.fu != correct_fu) begin
                    $display("@@@ Incorrect at time %4.0f", $time);
                    $display("@@@ The fu of rob_entry is not correct! Wanted: %d, get: %d", correct_fu, rob_entry.fu);
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
                $display("@@@\t\tROB#\t\tPC\t\tFU\t\tPRED_TAKEN\t\tARG#\t\tPRG#\t\tDONE\t\tBRRST");
                for (int i = 0; i < `ROB_SIZE; i++) begin
                    if (rob_arr[i].valid) begin
                        if (head == i && head == tail) begin
                            $display("@@@\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\tHEAD,TAIL", 
                            i, rob_arr[i].pc, rob_arr[i].fu, rob_arr[i].pred_taken,
                            rob_arr[i].arch_reg, rob_arr[i].phy_reg, rob_arr[i].done,
                            rob_arr[i].branch_rst);
                        end
                        else if (head == i) begin
                            // $display("@@@ Head is at %d", head);
                            $display("@@@\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\tHEAD", 
                            i, rob_arr[i].pc, rob_arr[i].fu, rob_arr[i].pred_taken,
                            rob_arr[i].arch_reg, rob_arr[i].phy_reg, rob_arr[i].done,
                            rob_arr[i].branch_rst);
                        end else if (tail == i) begin
                            $display("@@@\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\tTAIL", 
                            i, rob_arr[i].pc, rob_arr[i].fu, rob_arr[i].pred_taken,
                            rob_arr[i].arch_reg, rob_arr[i].phy_reg, rob_arr[i].done,
                            rob_arr[i].branch_rst);
                        end else begin
                            $display("@@@\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d", 
                            i, rob_arr[i].pc, rob_arr[i].fu, rob_arr[i].pred_taken,
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
	cnt=cnt+1;
    show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
    @(negedge clock)
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
    @(negedge clock)
    // h 1 2 t
	cnt=cnt+1;
    valid1_in = 1;
    valid2_in = 1;
    show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
    @(negedge clock)
    // h 1 2 3 4 t
	cnt=cnt+1;
    pc1_in = 3;
    pc2_in = 4;
    show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
    @(negedge clock)
    // h 1 2 3 4 5 6 t
	cnt=cnt+1;
    pc1_in = 5;
    pc2_in = 6;
    arch_reg1_in = 3;
    arch_reg2_in = 4;
    phy_reg1_in = 5; 
    phy_reg2_in = 6;
    fu1_in = 0;
    fu2_in = 0;
    pred_taken1_in = 0;
    pred_taken2_in = 0;
    show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
    @(negedge clock)
    cnt =cnt +1;
    // h 1 2 3 4 5 6 7 8 t
    pc1_in = 7;
    pc2_in = 8;
    arch_reg1_in = 5;
    arch_reg2_in = 6;
    phy_reg1_in = 7; 
    phy_reg2_in = 8;
    fu1_in = 1;
    fu2_in = 1;
    pred_taken1_in = 0;
    pred_taken2_in = 0;
    @(negedge clock)
    // / / h 3 4 5 6 7 8 t
	cnt=cnt+1;
    valid1_in = 0;
    valid2_in = 0;
    cdb1_valid_in = 1;
    cdb2_valid_in = 1;
    cdb1_tag_in = 0;
    cdb2_tag_in = 1;
    cdb1_branch_rst_in = 1;
    cdb2_branch_rst_in = 1;
    show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
    @(negedge clock)
    cnt =cnt +1;
    cdb1_valid_in = 0;
    cdb2_valid_in = 0;
    show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
    @(negedge clock)
    // 9 10 t h 3 4 5 6 7 8
    cnt=cnt+1;
    valid1_in = 1;
    valid2_in = 1;
    pc1_in = 9;
    pc2_in = 10;
    arch_reg1_in = 5;
    arch_reg2_in = 6;
    phy_reg1_in = 7; 
    phy_reg2_in = 8;
    fu1_in = 1;
    fu2_in = 1;
    cdb1_valid_in = 1;
    cdb2_valid_in = 1;
    pred_taken1_in = 0;
    pred_taken2_in = 0;
    show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
    // 9 10 t h 3* 4 5* 6 7 8
    @(negedge clock);
    cnt =cnt +1;
    valid1_in = 0;
    valid2_in = 0;
    cdb1_valid_in = 1;
    cdb2_valid_in = 1;
    cdb1_tag_in = 4;
    cdb2_tag_in = 2;
    show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
    @(negedge clock);
    cnt =cnt +1;
    cdb1_valid_in = 0;
    cdb2_valid_in = 0;
    show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
    // 9 10 t / h 4* 5* 6* 7 8
    @(negedge clock);
    cnt =cnt +1;
    cdb1_valid_in = 1;
    cdb2_valid_in = 1;
    cdb1_tag_in = 3;
    cdb2_tag_in = 5;
    show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
    // retire ROB# 0 and 1 valid dispatch
    @(negedge clock)
	cnt=cnt+1;
    cdb2_valid_in = 1;
    cdb2_tag_in = 7;
    show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
    @(negedge clock)
    cnt =cnt +1;
    cdb1_valid_in = 0;
    cdb2_valid_in = 0;
    show_rob_entries(rob_arr, full, head_out, tail_out, cnt);
    $finish;
end


endmodule