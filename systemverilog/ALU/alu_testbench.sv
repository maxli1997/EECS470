`timescale 1ns/100ps

module testbench;
    logic                       clock, reset;
    logic [`BRAT_SIZE-1:0]      brat_idx_1, brat_idx_2, brat_mis;
    ID_EX_PACKET                issue_pkt_in_1;
    ID_EX_PACKET                issue_pkt_in_2;
    EX_PACKET                   ex_packet_out_1_non_mul;
    EX_PACKET                   ex_packet_out_1_mul;
    EX_PACKET                   ex_packet_out_2_non_mul;
    EX_PACKET                   ex_packet_out_2_mul;
    logic                       mul_will_done_1, mul_will_done_2, mul_done_1, mul_done_2;
    INST                        inst;
    logic                       issue_valid_1, issue_valid_2, brat_mis_valid;
    logic  [`BRAT_LEN-1:0]      correct_index1, correct_index2;         // the correct shift index
    logic                       index1_valid, index2_valid;
    ex_stage ex (
        .clock(clock),
        .reset(reset),
        .brat_idx_1(brat_idx_1),
        .brat_idx_2(brat_idx_2),
        .brat_mis(brat_mis),
        .issue_pkt_in_1(issue_pkt_in_1),
        .issue_pkt_in_2(issue_pkt_in_2),
        .issue_valid_1(issue_valid_1),
        .issue_valid_2(issue_valid_2),
        .brat_mis_valid(brat_mis_valid),
        .correct_index1(correct_index1),
        .correct_index2(correct_index2),
        .index1_valid(index1_valid),
        .index2_valid(index2_valid),

        .ex_packet_out_1_mul(ex_packet_out_1_mul),
        .ex_packet_out_1_non_mul(ex_packet_out_1_non_mul),
        .ex_packet_out_2_mul(ex_packet_out_2_mul),
        .ex_packet_out_2_non_mul(ex_packet_out_2_non_mul),
        .mul_done_1(mul_done_1),
        .mul_done_2(mul_done_2),
        .mul_will_done_1(mul_will_done_1),
        .mul_will_done_2(mul_will_done_2)
    );

    always begin
        #5 clock=~clock;    
    end

    task print_helper;
        input EX_PACKET pkt;
        begin
            if (pkt.valid) begin
                $write("%8d", pkt.result);
            end else begin
                $write("      NA");
            end
        end
    endtask

    task print_ex_packet;
        input EX_PACKET pkt1;
        input EX_PACKET pkt1_mul;
        input EX_PACKET pkt2;
        input EX_PACKET pkt2_mul;
        begin
            $write("@@@ ");
            print_helper(pkt1);
            print_helper(pkt1_mul);
            print_helper(pkt2);
            print_helper(pkt2_mul);
            $write("\n");
        end
    endtask
    
    initial begin
        // The 2 ALUs are independent, so we focus on only one of them in test
        issue_valid_1 = 1;                          // set input_pkt_1 as valid
        issue_valid_2 = 0;                          // and input_pkt_2 as invalid
        issue_pkt_in_1.opa_select = OPA_IS_RS1;     // handled by decoder. here test r type instructions only for
                                                    // simplicity
        issue_pkt_in_1.opb_select = OPB_IS_RS2; 
        
        brat_idx_1 = 1;
        brat_mis = 0;
        brat_mis_valid = 0;

        reset = 1;                                  
        clock = 0;

        index1_valid = 0;
        index2_valid = 0;

        @(negedge clock);
        @(negedge clock);
        reset = 0;
        issue_pkt_in_1.rs1_value = 2;
        issue_pkt_in_1.rs2_value = 3;
        issue_pkt_in_1.alu_func = ALU_MUL;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        issue_pkt_in_1.alu_func = ALU_ADD;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        issue_pkt_in_1.rs1_value = 1;
        issue_pkt_in_1.rs2_value = 2;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        issue_pkt_in_1.rs1_value = 3;
        issue_pkt_in_1.rs2_value = 3;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        issue_pkt_in_1.alu_func = ALU_MUL;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        issue_pkt_in_1.rs1_value = 0;
        issue_pkt_in_1.rs2_value = 0;
        issue_pkt_in_1.alu_func = ALU_ADD;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        issue_pkt_in_1.rs1_value = 1;
        issue_pkt_in_1.rs2_value = 0;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        issue_pkt_in_1.rs1_value = 2;
        issue_pkt_in_1.rs2_value = 0;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        issue_pkt_in_1.rs1_value = 3;
        issue_pkt_in_1.rs2_value = 0;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        issue_pkt_in_1.rs1_value = 7;
        issue_pkt_in_1.rs2_value = 1;
        issue_pkt_in_1.alu_func = ALU_MUL;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        issue_pkt_in_1.rs1_value = 4;
        issue_pkt_in_1.rs2_value = 0;
        issue_pkt_in_1.alu_func = ALU_ADD;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        issue_pkt_in_1.rs1_value = 5;
        issue_pkt_in_1.rs2_value = 0;
        brat_mis_valid = 1;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        brat_mis_valid = 0;
        issue_pkt_in_1.rs1_value = 5;
        issue_pkt_in_1.rs2_value = 0;
        issue_pkt_in_1.alu_func = ALU_MUL;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        issue_pkt_in_1.alu_func = ALU_ADD;
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        @(negedge clock);
        print_ex_packet(ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul);
        $finish;
    end

endmodule