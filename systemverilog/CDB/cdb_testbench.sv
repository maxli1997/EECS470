`timescale 1ns/100ps

module testbench;

    logic                                       clock, reset;
    EX_PACKET                                   alu1_pkt, alu2_pkt;
    EX_PACKET                                   mult1_pkt, mult2_pkt;
    logic                                       mispredict;
    logic                   [`BRAT_SIZE-1:0]    brat_mis;
    logic                   [`BRAT_LEN-1:0]     correct_index1, correct_index2;
    logic                                       index1_valid, index2_valid;

    logic                                       cdb1_valid, cdb2_valid;
    logic                   [`ROB_LEN-1:0]      cdb1_tag, cdb2_tag;
    logic                   [`PR_LEN-1:0]       cdb1_phy_reg, cdb2_phy_reg;
    logic                                       cdb1_branch_rst, cdb2_branch_rst;
    logic                   [`PC_LEN-1:0]       cdb1_data, cdb2_data;
    logic                   [`BRAT_SIZE-1:0]    cdb1_brat_vec, cdb2_brat_vec;
    logic                   [10:0]              cnt;
    CDB_RETIRE_PACKET       [31:0]               retire_packet;
    logic                   [4:0]               head_out, tail_out;
    cdb c(
        .clock, .reset, 
        .alu1_pkt, .alu2_pkt, 
        .mult1_pkt, .mult2_pkt,
        .mispredict, .brat_mis,
        .correct_index1, .correct_index2,
        .index1_valid, .index2_valid,
        .cdb1_valid, .cdb2_valid, 
        .cdb1_tag, .cdb2_tag, 
        .cdb1_phy_reg, .cdb2_phy_reg,
        .cdb1_branch_rst, .cdb2_branch_rst,
        .cdb1_brat_vec, .cdb2_brat_vec,
        .cdb1_data, .cdb2_data,
        .retire_packet,
        .head_out, .tail_out
    );


    always begin
        #5 clock=~clock;
    end

    task check_cbd_output;
        input                   valid1, valid2;
        input [`ROB_LEN-1:0]    tag1, tag2;
        input [`PR_LEN-1:0]     phy_reg1, phy_reg2;
        input                   branch_rst1, branch_rst2;
        input [`PC_LEN-1:0]     data1, data2;
        input                   correct_valid1, correct_valid2;
        input [`ROB_LEN-1:0]    correct_tag1, correct_tag2;
        input [`PR_LEN-1:0]     correct_phy_reg1, correct_phy_reg2;
        input                   correct_branch1, correct_branch2;
        input [`PC_LEN-1:0]     correct_data1, correct_data2;
        if (valid1 != correct_valid1) begin
            $display("@@@ Wrong valid 1, expected: %d", correct_valid1);
            $display("@@@ Failed");
            $finish;
        end
        if (valid2 != correct_valid2) begin
            $display("@@@ Wrong valid 2, expected: %d", correct_valid2);
            $display("@@@ Failed");
            $finish;
        end
        if (tag1 != correct_tag1 && correct_valid1) begin
            $display("@@@ Wrong tag 1, expected: %d, got: %d", correct_tag1, tag1);
            $display("@@@ Failed");
            $finish;
        end
        if (tag2 != correct_tag2 && correct_valid2) begin
            $display("@@@ Wrong tag 2, expected: %d, got: %d", correct_tag2, tag2);
            $display("@@@ Failed");
            $finish;
        end
        if (phy_reg1 != correct_phy_reg1 && correct_valid1) begin
            $display("@@@ Wrong phy reg 1, expected: %d, got: %d", correct_phy_reg1, phy_reg1);
            $display("@@@ Failed");
            $finish;
        end 
        if (phy_reg2 != correct_phy_reg2 && correct_valid2) begin
            $display("@@@ Wrong phy reg 2, expected: %d, got: %d", correct_phy_reg2, phy_reg2);
            $display("@@@ Failed");
            $finish;
        end
        if (branch_rst1 != correct_branch1 && correct_valid1) begin
            $display("@@@ Wrong branch 1, expected: %d, got: %d", correct_branch1, branch_rst1);
            $display("@@@ Failed");
            $finish;
        end
        if (branch_rst2 != correct_branch2 && correct_valid2) begin
            $display("@@@ Wrong branch 2, expected: %d, got: %d", correct_branch2, branch_rst2);
            $display("@@@ Failed");
            $finish;
        end
        if (data1 != correct_data1 && correct_valid1) begin
            $display("@@@ Wrong data 1, expected: %d, got: %d", correct_data1, data1);
            $display("@@@ Failed");
            $finish;
        end    
        if (data2 != correct_data2 && correct_valid2) begin
            $display("@@@ Wrong data 2, expected: %d, got: %d", correct_data2, data2);
            $display("@@@ Failed");
            $finish;
        end                               
    endtask



    // task show_rob_entries;
  
    //     endtask  // show_rob_entries

    initial begin
        // Initiate to all zero except reset
        cnt = 0;
        clock = 0;
        reset = 1;
        alu1_pkt = '{
                    {`XLEN{1'b0}},      // result
                    {`XLEN{1'b0}},      // NPC
                    1'b0,               // take_branch
                    {`BRAT_SIZE{1'b0}}, // brat vector
                    {`XLEN{1'b0}},      
                    1'b0, 1'b0,         // rd_mem, wr_mem
                    {`PR_LEN{1'b0}},    // dest_phy_reg
                    {`ROB_LEN{1'b0}},  // rob_num
                    1'b0, 1'b0, 1'b0, 1'b0,
                    3'b0                // mem_size
                };
        alu2_pkt = '{
                    {`XLEN{1'b0}},      // result
                    {`XLEN{1'b0}},      // NPC
                    1'b0,               // take_branch
                    {`BRAT_SIZE{1'b0}}, // brat vector
                    {`XLEN{1'b0}},      
                    1'b0, 1'b0,         // rd_mem, wr_mem
                    {`PR_LEN{1'b0}},    // dest_phy_reg
                    {`ROB_LEN{1'b0}},  // rob_num
                    1'b0, 1'b0, 1'b0, 1'b0,
                    3'b0                // mem_size
                };

        mult1_pkt = '{
                    {`XLEN{1'b0}},      // result
                    {`XLEN{1'b0}},      // NPC
                    1'b0,               // take_branch
                    {`BRAT_SIZE{1'b0}}, // brat vector
                    {`XLEN{1'b0}},      
                    1'b0, 1'b0,         // rd_mem, wr_mem
                    {`PR_LEN{1'b0}},    // dest_phy_reg
                    {`ROB_LEN{1'b0}},  // rob_num
                    1'b0, 1'b0, 1'b0, 1'b0,
                    3'b0                // mem_size
                };
        mult2_pkt = '{
                    {`XLEN{1'b0}},      // result
                    {`XLEN{1'b0}},      // NPC
                    1'b0,               // take_branch
                    {`BRAT_SIZE{1'b0}}, // brat vector
                    {`XLEN{1'b0}},      
                    1'b0, 1'b0,         // rd_mem, wr_mem
                    {`PR_LEN{1'b0}},    // dest_phy_reg
                    {`ROB_LEN{1'b0}},  // rob_num
                    1'b0, 1'b0, 1'b0, 1'b0,
                    3'b0                // mem_size
                };
        
        @(negedge clock)
        // cycle 1
        // two valid alu
        cnt += 1;
        reset = 0;
        alu1_pkt.valid = 1;
        alu2_pkt.valid = 1;
        alu1_pkt.result = 10;
        alu1_pkt.take_branch = 0;
        alu1_pkt.rob_num = 1;
        alu1_pkt.dest_phy_reg = 5;
        alu2_pkt.result = 2;
        alu2_pkt.take_branch = 0;
        alu2_pkt.rob_num = 4;
        alu2_pkt.dest_phy_reg = 5;
        mispredict = 0;
        brat_mis = {`BRAT_SIZE{1'b0}};
        index1_valid = 0;
        index2_valid = 0;

        @(negedge clock)
        // cycle 2
        // four valid inputs, two gets queued
        cnt += 1;
        mult1_pkt.valid = 1;
        mult2_pkt.valid = 1;
        mult1_pkt.result = 1010;
        mult2_pkt.result = 999;
        mult1_pkt.rob_num = 2;
        mult2_pkt.rob_num = 3;
        mult1_pkt.dest_phy_reg = 3;
        mult2_pkt.dest_phy_reg = 2;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        check_cbd_output(cdb1_valid, cdb2_valid, cdb1_tag, cdb2_tag, cdb1_phy_reg, cdb2_phy_reg, cdb1_branch_rst, cdb2_branch_rst,
            cdb1_data, cdb2_data, 1, 1, 1, 4, 5, 5, 0, 0, 10, 2);
        @(negedge clock)
        // cycle 3
        // broadcast the first two results
        alu1_pkt.valid = 0;
        alu2_pkt.valid = 0;
        mult1_pkt.valid = 0;
        mult2_pkt.valid = 0;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        check_cbd_output(cdb1_valid, cdb2_valid, cdb1_tag, cdb2_tag, cdb1_phy_reg, cdb2_phy_reg, cdb1_branch_rst, cdb2_branch_rst,
            cdb1_data, cdb2_data, 1, 1, 1, 4, 5, 5, 0, 0, 10, 2);
        @(negedge clock)
        // broadcast the last two results
        // one alu pkt and mult pkt
        alu1_pkt.valid = 1;
        mult1_pkt.valid = 1;
        alu1_pkt.result = 5;
        alu1_pkt.take_branch = 1;
        alu1_pkt.rob_num = 5;
        alu1_pkt.dest_phy_reg = 3;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        check_cbd_output(cdb1_valid, cdb2_valid, cdb1_tag, cdb2_tag, cdb1_phy_reg, cdb2_phy_reg, cdb1_branch_rst, cdb2_branch_rst,
            cdb1_data, cdb2_data, 1, 1, 2, 3, 3, 2, 0, 0, 1010, 999);
        @(negedge clock)
        alu1_pkt.valid = 0;
        alu2_pkt.valid = 0;
        mult1_pkt.valid = 0;
        mult2_pkt.valid = 0;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        check_cbd_output(cdb1_valid, cdb2_valid, cdb1_tag, cdb2_tag, cdb1_phy_reg, cdb2_phy_reg, cdb1_branch_rst, cdb2_branch_rst,
            cdb1_data, cdb2_data, 1, 1, 5, 2, 3, 3, 1, 0, 5, 1010);
        @(negedge clock)
        // 1, 3, 4 three inputs
        alu1_pkt.valid = 1;
        mult1_pkt.valid = 1;
        mult2_pkt.valid = 1;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        assert (head_out == tail_out && head_out == 8)
        else begin
            $error("wrong head and tail!");
            $finish;
        end
        @(negedge clock)
        alu1_pkt.valid = 0;
        alu2_pkt.valid = 0;
        mult1_pkt.valid = 0;
        mult2_pkt.valid = 0;
        assert (tail_out == 11 && head_out == 8)
        else begin
            $error("wrong head and tail!");
            $finish;
        end
        $display("head is at: %d, tail: %d", head_out, tail_out);
        check_cbd_output(cdb1_valid, cdb2_valid, cdb1_tag, cdb2_tag, cdb1_phy_reg, cdb2_phy_reg, cdb1_branch_rst, cdb2_branch_rst,
            cdb1_data, cdb2_data, 1, 1, 5, 2, 3, 3, 1, 0, 5, 1010);
        @(negedge clock)
        // broadcast only one
        // 1, 2, 4 three inputs
        alu1_pkt.valid = 1;
        alu2_pkt.valid = 1;
        mult1_pkt.valid = 0;
        mult2_pkt.valid = 1;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        check_cbd_output(cdb1_valid, cdb2_valid, cdb1_tag, cdb2_tag, cdb1_phy_reg, cdb2_phy_reg, cdb1_branch_rst, cdb2_branch_rst,
            cdb1_data, cdb2_data, 1, 0, 3, 2, 2, 3, 0, 0, 999, 1010);
        @(negedge clock)
        // clear cdb
        alu1_pkt.valid = 0;
        alu2_pkt.valid = 0;
        mult1_pkt.valid = 1;
        mult2_pkt.valid = 0;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        check_cbd_output(cdb1_valid, cdb2_valid, cdb1_tag, cdb2_tag, cdb1_phy_reg, cdb2_phy_reg, cdb1_branch_rst, cdb2_branch_rst,
            cdb1_data, cdb2_data, 1, 1, 5, 4, 3, 5, 1, 0, 5, 2);
        @(negedge clock) 
        // 2, 3, 4 three inputs 
        alu1_pkt.valid = 0;
        alu2_pkt.valid = 1;
        mult1_pkt.valid = 1;
        mult2_pkt.valid = 1;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        check_cbd_output(cdb1_valid, cdb2_valid, cdb1_tag, cdb2_tag, cdb1_phy_reg, cdb2_phy_reg, cdb1_branch_rst, cdb2_branch_rst,
            cdb1_data, cdb2_data, 1, 1, 3, 2, 2, 3, 0, 0, 999, 1010);
        @(negedge clock)
        // 1, 2, 3 three inputs
        alu1_pkt.valid = 1;
        alu2_pkt.valid = 1;
        mult1_pkt.valid = 1;
        mult2_pkt.valid = 0;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        check_cbd_output(cdb1_valid, cdb2_valid, cdb1_tag, cdb2_tag, cdb1_phy_reg, cdb2_phy_reg, cdb1_branch_rst, cdb2_branch_rst,
            cdb1_data, cdb2_data, 1, 1, 4, 2, 5, 3, 0, 0, 2, 1010); 
        @(negedge clock)
        // clear cdb
        alu1_pkt.valid = 0;
        alu2_pkt.valid = 0;
        mult1_pkt.valid = 0;
        mult2_pkt.valid = 0;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        check_cbd_output(cdb1_valid, cdb2_valid, cdb1_tag, cdb2_tag, cdb1_phy_reg, cdb2_phy_reg, cdb1_branch_rst, cdb2_branch_rst,
            cdb1_data, cdb2_data, 1, 1, 3, 5, 2, 3, 0, 1, 999, 5); 
        @(negedge clock)
        // two inputs
        alu1_pkt.valid = 0;
        alu2_pkt.valid = 1;
        mult1_pkt.valid = 1;
        mult2_pkt.valid = 0;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        check_cbd_output(cdb1_valid, cdb2_valid, cdb1_tag, cdb2_tag, cdb1_phy_reg, cdb2_phy_reg, cdb1_branch_rst, cdb2_branch_rst,
            cdb1_data, cdb2_data, 1, 1, 4, 2, 5, 3, 0, 0, 2, 1010); 
        @(negedge clock)
        alu1_pkt.valid = 0;
        alu2_pkt.valid = 0;
        mult1_pkt.valid = 0;
        mult2_pkt.valid = 0;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        check_cbd_output(cdb1_valid, cdb2_valid, cdb1_tag, cdb2_tag, cdb1_phy_reg, cdb2_phy_reg, cdb1_branch_rst, cdb2_branch_rst,
            cdb1_data, cdb2_data, 1, 1, 4, 2, 5, 3, 0, 0, 2, 1010); 
        @(negedge clock)
        alu1_pkt.valid = 1;
        alu2_pkt.valid = 1;
        mult1_pkt.valid = 1;
        mult2_pkt.valid = 1;
        alu1_pkt.brat_vec = 4'b1000;
        alu2_pkt.brat_vec = 4'b1100;
        mult1_pkt.brat_vec = 4'b1000;
        mult2_pkt.brat_vec = 4'b1000;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        mispredict = 1;
        brat_mis = 4'b0000;
        alu1_pkt.brat_vec = 4'b0000;
        alu2_pkt.brat_vec = 4'b0000;
        mult1_pkt.brat_vec = 4'b0000;
        mult2_pkt.brat_vec = 4'b0000;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        alu1_pkt.valid = 0;
        alu2_pkt.valid = 0;
        mult1_pkt.valid = 0;
        mult2_pkt.valid = 0;
        mispredict = 0;
        brat_mis = 4'b0000;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        alu1_pkt.valid = 1;
        alu2_pkt.valid = 1;
        mult1_pkt.valid = 1;
        mult2_pkt.valid = 1;
        alu1_pkt.brat_vec = 4'b1000;
        alu2_pkt.brat_vec = 4'b1100;
        mult1_pkt.brat_vec = 4'b0000;
        mult2_pkt.brat_vec = 4'b1000;
        $display("head is at: %d, tail: %d", head_out, tail_out);

        @(negedge clock)
        mispredict = 0;
        brat_mis = 4'b1000;
        alu1_pkt.brat_vec = 4'b1100;
        alu2_pkt.brat_vec = 4'b1100;
        mult1_pkt.brat_vec = 4'b1100;
        mult2_pkt.brat_vec = 4'b1000;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        mispredict = 1;
        brat_mis = 4'b1000;
        alu1_pkt.valid = 0;
        alu2_pkt.valid = 0;
        mult1_pkt.valid = 0;
        mult2_pkt.valid = 0;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)   
        mispredict = 0;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)    
        alu1_pkt.valid = 1;
        alu2_pkt.valid = 1;
        mult1_pkt.valid = 1;
        mult2_pkt.valid = 1;    
        alu1_pkt.brat_vec = 4'b1000;
        alu2_pkt.brat_vec = 4'b1000;
        mult1_pkt.brat_vec = 4'b0000;
        mult2_pkt.brat_vec = 4'b1000;        
        $display("head is at: %d, tail: %d", head_out, tail_out);
        /* test for update the brat_vec in cdb */
        @(negedge clock)
        alu1_pkt.brat_vec = 4'b1110;
        alu2_pkt.brat_vec = 4'b1110;
        mult1_pkt.brat_vec = 4'b1110;
        mult2_pkt.brat_vec = 4'b1100;   
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        alu1_pkt.valid = 0;
        alu2_pkt.valid = 0;
        mult1_pkt.valid = 0;
        mult2_pkt.valid = 0;
        index1_valid = 1;
        correct_index1 = 3;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        index1_valid = 0;
        alu1_pkt.valid = 1;
        alu2_pkt.valid = 1;
        mult1_pkt.valid = 1;
        mult2_pkt.valid = 1;    
        alu1_pkt.brat_vec = 4'b1110;
        alu2_pkt.brat_vec = 4'b1110;
        mult1_pkt.brat_vec = 4'b1110;
        mult2_pkt.brat_vec = 4'b1110; 
        $display("head brat_vec: %b", retire_packet[head_out].brat_vec);
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        alu1_pkt.valid = 0;
        alu2_pkt.valid = 0;
        mult1_pkt.valid = 0;
        mult2_pkt.valid = 0;
        index1_valid = 1;
        correct_index1 = 2;
        index2_valid = 1;
        correct_index2 = 1;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        alu1_pkt.valid = 1;
        alu2_pkt.valid = 1;
        mult1_pkt.valid = 1;
        mult2_pkt.valid = 1;
        index1_valid = 0;
        index2_valid = 0;
        // should be 1000
        $display("head brat_vec: %b", retire_packet[head_out].brat_vec);
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        index1_valid = 1;
        correct_index1 = 2;
        index2_valid = 1;
        correct_index2 = 3;
        $display("head is at: %d, tail: %d", head_out, tail_out);
        @(negedge clock)
        $display("brat_vec: %b", retire_packet[29].brat_vec);
        $display("@@@ PASSED!");
        $finish;
    end


endmodule