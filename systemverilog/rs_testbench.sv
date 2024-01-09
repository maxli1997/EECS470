`timescale 1ns/100ps
`define DEBUG_RS

module testbench;

    logic                  clock, reset;
    // dispatch's instructions is valid or not
    //TODO: input: id_ex_packet
    //      output: id_ex_packet
    //      function: change relevant values in id_ex_packet
    ID_EX_PACKET    id_ex_packet_in1, id_ex_packet_in2;
    logic                   valid1_in, valid2_in;
    logic   [`PC_LEN-1:0]   pc1_in, pc2_in;                         
    logic   [`FU_LEN-1:0]   fu1_in, fu2_in;

    /* inputs from cdb */
    logic                   cdb1_valid_in, cdb2_valid_in;
    // rob  number
    logic   [`ROB_LEN-1:0]  cdb1_tag_in, cdb2_tag_in;
    logic   [`VALUE_SIZE-1:0]               cdb1_value, cdb2_value;
    logic                           rat11_valid, rat12_valid, rat21_valid, rat22_valid;
    logic   [`VALUE_SIZE-1:0]       rat11_value, rat12_value, rat21_value, rat22_value;
    logic   [`PR_LEN-1:0]           regNum1, regNum2;
    logic   [`BRAT_LEN-1:0]         correct_index1, correct_index2;
    logic   [`BRAT_SIZE-1:0]        brat_mis;
    logic   [`BRAT_SIZE-1:0]        brat_in_use1, brat_in_use2;
    logic   [`RS_LEN-1:0]           rs_empty_idx1, rs_empty_idx2;
    logic                           mul_in_use1, mul_in_use2;

    ID_EX_PACKET   issue_packet1, issue_packet2;
    logic  [1:0]           full;
    RS_ENTRY_PACKET [`RS_SIZE-1:0] rs_arr_out;
    logic   [10:0] cnt;

    rs r (
        clock, reset,
        id_ex_packet_in1,id_ex_packet_in2,
        valid1_in,valid2_in,
        pc1_in, pc2_in,
        fu1_in, fu2_in,
        mul_in_use1, mul_in_use2,
        cdb1_valid_in, cdb2_valid_in,
        cdb1_tag_in, cdb2_tag_in,
        cdb1_value, cdb2_value,
        rat11_valid, rat12_valid, rat21_valid, rat22_valid,
        rat11_value, rat12_value, rat21_value, rat22_value,
        regNum1, regNum2,
        correct_index1, correct_index2,
        brat_mis,
        brat_in_use1, brat_in_use2,
        issue_packet1, issue_packet2,
        full,
        rs_arr_out,
        rs_empty_idx1, rs_empty_idx2
    );

    always begin
        #5 clock = ~clock;
    end    
    task show_rs_entries;
            input RS_ENTRY_PACKET [`RS_SIZE-1:0] rs_arr_out;
            input [1:0] full;
            input [10:0] cycle_num;
            begin
                // $display("head is at %d", head);
                // $display("head is valid? %d", rob_arr[head].valid);
                $display("@@@\t\tCycle %d", cycle_num);
                $display("@@@\t\tvalid\t\tRS#\t\tPC\t\tFU\t\tTAG\t\tTAG1\t\tTAG1_RDY\t\tTAG2\t\tTAG2_RDY");
                for (int i = 0; i < `RS_SIZE; i++) begin
                    //if (rs_arr_out[i].valid) begin
                        $display("@@@\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t%d\t\t", 
                        rs_arr_out[i].valid, i, rs_arr_out[i].pc, rs_arr_out[i].fu, rs_arr_out[i].tag,
                        rs_arr_out[i].tag1, rs_arr_out[i].tag1_rdy, rs_arr_out[i].tag2,
                        rs_arr_out[i].tag2_rdy);
                    //end else begin
                    //    $display("@@@\t\t%d\t\t\t\t\t\t\t\t\t\t\t\t\t\t", i;
                    //end
                end
                $display("@@@\t\tfull: %d", full);
                $display("@@@\t\tempty1, empty2: %d, %d", rs_empty_idx1, rs_empty_idx2);
                $display("@@@");
            end
    endtask  // show_rob_entries

    initial begin
    cnt = 0;
        clock = 0;
        reset = 1;
        cdb1_valid_in = 0;
        cdb2_valid_in = 0;
        valid1_in = 0;
        valid2_in = 0;
        id_ex_packet_in1 = '{
				{`XLEN{1'b0}},
				{`XLEN{1'b0}}, 
				{`XLEN{1'b0}}, 
				{`XLEN{1'b0}}, 
                5'b0,
                5'b0,
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0, //valid
                1'b0,
                4'b0
			};

        id_ex_packet_in2 = '{
				{`XLEN{1'b0}},
				{`XLEN{1'b0}}, 
				{`XLEN{1'b0}}, 
				{`XLEN{1'b0}}, 
                5'b0,
                5'b0,
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0, //valid
                1'b0,
                4'b0
			};

        pc1_in = 0;
        pc2_in = 0;
        fu1_in = 0;
        fu2_in = 0;
        cdb1_tag_in = 0;
        cdb2_tag_in = 0;
        rat11_valid = 0;
        rat11_value = 0;
        rat12_valid = 0;
        rat12_value = 0;
        rat21_valid = 0;
        rat21_value = 0;
        rat22_valid = 0;
        rat22_value = 0;
        regNum1 = 0;
        regNum2 = 0;
        correct_index1 = 0;
        correct_index2 = 0;
        brat_mis = 0;
        
    show_rs_entries(rs_arr_out, full, cnt);
    @(negedge clock)
    reset = 0;
    show_rs_entries(rs_arr_out, full, cnt);
    @(negedge clock)
    show_rs_entries(rs_arr_out, full, cnt);
    valid1_in = 1;
    valid2_in = 1;
    pc1_in = 1;
    pc2_in = 2;
    fu1_in = 3;
    fu2_in = 4;
    @(negedge clock)
    show_rs_entries(rs_arr_out, full, cnt);
    @(negedge clock)
    show_rs_entries(rs_arr_out, full, cnt);
    $finish;
    end
endmodule
