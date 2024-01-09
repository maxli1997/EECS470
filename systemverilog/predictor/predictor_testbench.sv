`timescale 1ns/100ps

`define DEBUG_LSQ

module testbench;
    logic	clock, reset;
    // Inputs from DISPATCH
    logic [`PC_LEN-1:0]			pc1, pc2;
	logic						pc1_valid, pc2_valid;
	// updating the predicted address
	ROB_RETIRE_PACKET		    retire_pkt_1, retire_pkt_2;
	
	logic						taken1,taken2;
	logic [`PC_LEN-1:0]		    location1,location2;
    logic [`BTB_SIZE-1:0][1:0]	predictor_states;

    predictor p(
        .clock, .reset,
        .pc1, .pc2,
        .pc1_valid, .pc2_valid,
        .retire_pkt_1, .retire_pkt_2,
        .taken1, .taken2,
        .location1, .location2,
        .predictor_states
    );



    always begin
        #5 clock=~clock;
    end

    task show_predictor_output;
        input [`PC_LEN-1:0]         pc1, pc2;		
        input                       taken1,taken2;
        input [`PC_LEN-1:0]		    location1,location2;
        $display("predict for pc1: %h is taken? %d, location: %d", pc1, taken1, location1);
        $display("predict for pc2: %h is taken? %d, location: %d", pc2, taken2, location2);         
    endtask

    task show_predictor;        
        input [`BTB_SIZE-1:0][1:0]	predictor_states;
        input [10:0]                      cnt;
        begin
            $display("@@@\t\tCycle %d", cnt);
            $display("@@@predictor state:");
            
            // print lq
            $display("@@@\tindex#\tstate");
            for (int i = 0; i < `LSQ_SIZE; i++) begin
                $display("@@@%9d%9d",
                    i, predictor_states[i]);
            end

            $display("@@@");
        end
    endtask  // show_lsq


    initial begin
        clock = 0;
        reset = 1;
        pc1_valid = 0;
        pc2_valid = 0;
        retire_pkt_1 = '{
            {`AR_LEN{1'b0}},
            {`PR_LEN{1'b0}},
            {`PR_LEN{1'b0}},
            {`PC_LEN{1'b0}},
            {`FU_LEN{1'b0}},
            1'b0, 1'b0,
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
				1'b0,  //pred_taken
				{`BRAT_SIZE{1'b0}},
				{`ROB_LEN{1'b0}}
			}
        };
        retire_pkt_2 = '{
            {`AR_LEN{1'b0}},
            {`PR_LEN{1'b0}},
            {`PR_LEN{1'b0}},
            {`PC_LEN{1'b0}},
            {`FU_LEN{1'b0}},
            1'b0, 1'b0,
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
				1'b0,  //pred_taken
				{`BRAT_SIZE{1'b0}},
				{`ROB_LEN{1'b0}}
			}
        };

		@(negedge clock)
		reset = 0;
        pc1_valid = 1;
        pc2_valid = 1;
        pc1 = 0;
        pc2 = 4;
        // write to btb with pc 8 target 16
        retire_pkt_1.retire_valid = 1;
        retire_pkt_1.pc = 32'h00000008; // tag 010
        retire_pkt_1.decoded_packet.cond_branch = 1;
        retire_pkt_1.branch_rst = 1;
        retire_pkt_1.decoded_packet.NPC = 32'h00000010;
        // taken 1&2 not true, location doesn't matter
        // don't have anything yet
        show_predictor_output(pc1, pc2, taken1, taken2, location1, location2);
        @(negedge clock)
        // retire_pkt_1.retire_valid = 0;
        pc1 = 8;
        // taken 1&2 not true, location found but predict not taken (weakly not taken)
        show_predictor_output(pc1, pc2, taken1, taken2, location1, location2);
        show_predictor(predictor_states, $time);
        @(negedge clock)
        // overwrite the old btb entry
        retire_pkt_1.retire_valid = 1;
        retire_pkt_1.pc = 32'h00000028;   // 101000
        pc1 = 8;
        // taken 1 should be true, 10 (weakly taken)
        show_predictor_output(pc1, pc2, taken1, taken2, location1, location2);
        show_predictor(predictor_states, $time);

		@(negedge clock)
        retire_pkt_1.retire_valid = 0;
		pc1 = 8;
		pc2 = 8;
        // taken should be false again because btb has overwrite its entry
        show_predictor_output(pc1, pc2, taken1, taken2, location1, location2);
        show_predictor(predictor_states, $time);
        $display("@@@ PASSED!");
        $finish;
    end


endmodule