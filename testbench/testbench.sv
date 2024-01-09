/////////////////////////////////////////////////////////////////////////
//                                                                     //
//                                                                     //
//   Modulename :  testbench.sv                                        //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline;       //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

extern void print_header(string str);
extern void print_cycles();
extern void print_stage(string div, int inst, int npc, int valid_inst);
extern void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
                      int wb_reg_wr_idx_out, int wb_reg_wr_en_out);
extern void print_membus(int proc2mem_command, int mem2proc_response,
                         int proc2mem_addr_hi, int proc2mem_addr_lo,
                         int proc2mem_data_hi, int proc2mem_data_lo);
extern void print_close();

	task show_rs_entries;
		input RS_ENTRY_PACKET [`RS_SIZE-1:0] rs_arr_out;
		// input [1:0] full;
		input [31:0] cycle_num;
		input [`RS_LEN-1:0]   rs_empty_idx1, rs_empty_idx2;
		input ID_EX_PACKET   issue_packet1, issue_packet2;
		begin
			$display("@@Cycle %9d", cycle_num);
			$display("@@    valid       RS#      PC      TAG     TAG1   TAG1_RDY    TAG2  TAG2_RDY   OPA_SEL   OPB_SEL   ROB_NUM     Brat_vec");
			for (int i = 0; i < `RS_SIZE; i++) begin
				//if (rs_arr_out[i].valid) begin
					$display("@@%9d%9d	%8h%6d%9d%9d%9d%9d%9d%9d%9d             %4b", 
					rs_arr_out[i].valid, i, rs_arr_out[i].pc, rs_arr_out[i].tag,
					rs_arr_out[i].tag1, rs_arr_out[i].tag1_rdy, rs_arr_out[i].tag2,
					rs_arr_out[i].tag2_rdy, rs_arr_out[i].id_ex_packet.opa_select, 
					rs_arr_out[i].id_ex_packet.opb_select, rs_arr_out[i].rob_num, rs_arr_out[i].brat_vec);
			end
			// $display("@@full: %9d", full);
			$display("@@empty1, empty2: %9d, %9d", rs_empty_idx1, rs_empty_idx2);
			$display("@@issue pakcet valid: %d pc: %h, issue packet valid: %d pc %h", 
						issue_packet1.valid, issue_packet1.PC, issue_packet2.valid, issue_packet2.PC);
			$display("@@");
		end
    endtask 
	 
	task show_rat;
        input   rat1_valid, rat2_valid;
	    input   [`PR_LEN-1:0]   rat11_reg, rat12_reg, rat21_reg, rat22_reg;
        input   [`AR_SIZE-1:0][`PR_LEN-1:0] rat_out1, rat_out2;
        input   [`AR_SIZE-1:0][`PR_LEN-1:0] rat_arr_out;
        input   [`AR_LEN-1:0]               ar1_out, ar2_out;
        input   [`PR_LEN-1:0]               pr1_out, pr2_out;
        input   pr1_valid, pr2_valid;
        input   [31:0] cycle_num;
        begin
            $display("@@Cycle %9d", cycle_num);
            $display("@@updated rat from last cycle:");
            $display("@@     AR#     PR#");
            for (int i = 0; i < `AR_SIZE; i++) begin
                $display("@@%9d%9d", i, rat_arr_out[i]);
            end
            if (rat1_valid) begin
                $display("@@inst#1 opa uses pr %9d opb uses pr %9d", rat11_reg, rat12_reg);
                $display("@@inst#1 modify ar %9d which now is used? %9b mapping to pr %9d", ar1_out, pr1_valid, pr1_out);
                $display("@@brat for first inst:");
                $display("@@AR#PR#");
                for (int i = 0; i < `AR_SIZE; i++) begin
                    $display("@@%9d%9d", i, rat_out1[i]);
                end
            end
            else begin
                $display("@@inst#1 is not valid");
            end
            if (rat2_valid) begin
                $display("@@inst#2 opa uses pr %9d opb uses pr %9d", rat21_reg, rat22_reg);
                $display("@@inst#2 modify ar %9d which now is used? %9b mapping to pr %9d", ar2_out, pr2_valid, pr2_out);
                $display("@@brat for second inst:");
                $display("@@AR#PR#");
                for (int i = 0; i < `AR_SIZE; i++) begin
                    $display("@@%9d%9d", i, rat_out2[i]);
                end
            end
            else begin
                $display("@@inst#2 is not valid");
            end
            $display("@@");
        end
    endtask  // show_rat

	task show_prf;
		input [`PR_SIZE-1:0][`VALUE_SIZE-1:0] 	registerFile;
		input [`AR_SIZE-1:0][`PR_LEN-1:0] 		rat_arr_out;
		input [`PR_SIZE-1:0]					valid;
		input [31:0] cycle_num;
		begin
		$display("@@REG FILE");
		$display("@@Cycle %9d", cycle_num);
		$display("@@PR#		Value");
			for (int i = 0; i< `PR_SIZE; i++) begin
				$display("@@%9d%15d valid: %d", i, registerFile[i], valid[i]);
			end
		$display("@@");
		end
	endtask

	task show_free_list;
		input [`PR_SIZE-1:0] listOut;
		input [`PR_SIZE-1:0] listOut1, listOut2;
		input [31:0] cycle_num;
		begin
			$display("@@ Free List       /     ListOut1  /      ListOut2");
			$display("@@ Cycle %9d", cycle_num);
			for (int i=0; i<`PR_SIZE; i++) begin
				$display("%9d%9d%9d%9d",i, listOut[i], listOut1[i], listOut2[i]);
			end
		end
		$display("@@");
	endtask
	task show_rob_entries;
            input ROB_ENTRY_PACKET [`ROB_SIZE-1:0] rob_arr;
            input [1:0] full;
            input [`ROB_LEN-1:0] head;
            input [`ROB_LEN-1:0] tail;
            input [31:0] cycle_num;
            begin
                $display("@@Cycle %9d", cycle_num);
                $display("@@      ROB#      PC     PREV   PRED_TAKEN  ARG#     PRG#     DONE    BRRST");
                for (int i = 0; i < `ROB_SIZE; i++) begin
                    if (rob_arr[i].valid) begin
                        if (head == i && head == tail) begin
                            $display("@@%9d%9d%9d%9d%9d%9d%9d %9d  HEAD,TAIL", 
                            i, rob_arr[i].pc, rob_arr[i].prev_phy_reg, rob_arr[i].pred_taken,
                            rob_arr[i].arch_reg, rob_arr[i].phy_reg, rob_arr[i].done,
                            rob_arr[i].branch_rst);
                        end
                        else if (head == i) begin
                            $display("@@%9d%9d%9d%9d%9d%9d%9d%9d  HEAD", 
                            i, rob_arr[i].pc, rob_arr[i].prev_phy_reg, rob_arr[i].pred_taken,
                            rob_arr[i].arch_reg, rob_arr[i].phy_reg, rob_arr[i].done,
                            rob_arr[i].branch_rst);
                        end else if (tail == i) begin
                            $display("@@%9d%9d%9d%9d%9d%9d%9d%9d  TAIL", 
                            i, rob_arr[i].pc, rob_arr[i].prev_phy_reg, rob_arr[i].pred_taken,
                            rob_arr[i].arch_reg, rob_arr[i].phy_reg, rob_arr[i].done,
                            rob_arr[i].branch_rst);
                        end else begin
                            $display("@@%9d%9d%9d%9d%9d%9d%9d%9d", 
                            i, rob_arr[i].pc, rob_arr[i].prev_phy_reg, rob_arr[i].pred_taken,
                            rob_arr[i].arch_reg, rob_arr[i].phy_reg, rob_arr[i].done,
                            rob_arr[i].branch_rst);
                        end
                    end else begin
                        if (head == tail && i == head) begin
                            $display("@@%9d HEAD,TAIL", i);
                        end else if (i == tail) begin
                            $display("@@%9d TAIL", i);
                        end else begin
                            $display("@@%9d", i);
                        end
                    end
                end
                $display("@@full: %9d", full);
                $display("@@");
            end
        endtask  // show_rob_entries
	
	task show_cdb_entries;
			input CDB_RETIRE_PACKET [32-1:0] retire_packet;
			input [5-1:0] head, tail;
			input [31:0] cycle_num;
            begin
				$display("@@Cycle %9d", cycle_num);
                $display("@@     CDB#    result   valid   dest_phy_reg  rob#  condb   uncondb   taken   brat_vec	rs2_val		  lsq_valid");
                for (int i = 0; i < 32; i++) begin
                    if (retire_packet[i].valid) begin
                        if (head == i && head == tail) begin
                            $display("@@%9d %8h%9d%9d%9d%9d%9d%9d    %4b		%9h%9d  HEAD,TAIL", 
                            i, retire_packet[i].result, retire_packet[i].valid, retire_packet[i].dest_phy_reg,
							retire_packet[i].rob_num, retire_packet[i].cond_branch, retire_packet[i].uncond_branch, retire_packet[i].take_branch, retire_packet[i].brat_vec, retire_packet[i].rs2_value,
							retire_packet[i].lsq_valid);
                        end
                        else if (head == i) begin
                            $display("@@%9d %8h%9d%9d%9d%9d%9d%9d    %4b		%9h%9d HEAD", 
                            i, retire_packet[i].result, retire_packet[i].valid, retire_packet[i].dest_phy_reg,
							retire_packet[i].rob_num, retire_packet[i].cond_branch, retire_packet[i].uncond_branch, retire_packet[i].take_branch, retire_packet[i].brat_vec, retire_packet[i].rs2_value,
							retire_packet[i].lsq_valid);
                        end else if (tail == i) begin
                            $display("@@%9d %8h%9d%9d%9d%9d%9d%9d    %4b		%9h%9d  TAIL", 
                            i, retire_packet[i].result, retire_packet[i].valid, retire_packet[i].dest_phy_reg,
							retire_packet[i].rob_num, retire_packet[i].cond_branch, retire_packet[i].uncond_branch, retire_packet[i].take_branch, retire_packet[i].brat_vec, retire_packet[i].rs2_value,
							retire_packet[i].lsq_valid);
                        end else begin
                            $display("@@%9d %8h%9d%9d%9d%9d%9d%9d    %4b	%9h%9d", 
                            i, retire_packet[i].result, retire_packet[i].valid, retire_packet[i].dest_phy_reg,
							retire_packet[i].rob_num, retire_packet[i].cond_branch, retire_packet[i].uncond_branch, retire_packet[i].take_branch, retire_packet[i].brat_vec, retire_packet[i].rs2_value,
							retire_packet[i].lsq_valid);
                        end
                    end else begin
                        if (head == tail && i == head) begin
                            $display("@@%9d HEAD,TAIL", i);
                        end else if (i == tail) begin
                            $display("@@%9d TAIL", i);
                        end else begin
                            $display("@@%9d", i);
                        end
                    end
                end
                $display("@@");
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
        input   [31:0] cycle_num;
        input   valid1_in, valid2_in;
        input  [`BRAT_SIZE-1:0]  brat_in_use1, brat_in_use2;
        input [`BRAT_SIZE-1:0][`PR_SIZE-1:0]    brat_freelist; 
        begin
            $display("@@\t\tCycle %d", cycle_num);
            $display("@@brat is full? : %b", full);
            $display("@@updated brat from last cycle:");
            $display("@@updated brat valid: %b", brat_valid_out);
            $display("@@updated brat sequence: ");
            for (int i = `BRAT_SIZE-1; i >= 0; i = i-1) begin
                $display("@@ %d", brat_sequence_out[i]);
            end
            for (int i = `BRAT_SIZE-1; i >= 0; i = i-1) begin
                if (!brat_valid_out[i]) 
                    break;
                $display("@@brat entry: %d", brat_sequence_out[i]);
                $display("@@\t\tAR#\t\t\t\t\t\tPR#");
                for (int j = 0; j < `AR_SIZE; j = j+1)  begin
                    $display("@@\t%d\t\t\t\t\t\t%d", j, brat_out[brat_sequence_out[i]][j]);
                end
                $display("@@bfreelist entry: %d", brat_sequence_out[i]);
                $display("@@\t\tAR#\t\t\t\t\t\tUSED");
                for (int j = 0; j < `PR_SIZE; j = j+1)  begin
                    $display("@@\t%d\t\t\t\t\t\t%d", j, brat_freelist[brat_sequence_out[i]][j]);
                end
            end
            if (brat_en) begin
                $display("@@mispred brat");
                $display("@@\t\tAR#\t\t\t\t\t\tPR#");
                for (int j = 0; j < `AR_SIZE; j = j+1)  begin
                    $display("@@\t%d\t\t\t\t\t\t%d", j, brat_arr_out[j]);
                end
                $display("@@mispred bfreelist");
                $display("@@\t\tPR#\t\t\t\t\t\tUSED");
                for (int j = 0; j < `PR_SIZE; j = j+1)  begin
                    $display("@@\t%d\t\t\t\t\t\t%b", j, b_freelist_out[j]);
                end
            end
            else begin
                if (valid1_in) begin
                    $display("@@first inst is valid");
                    $display("@@corresponding brat vector: %b", brat_in_use1);
                end
                if (valid2_in) begin
                    $display("@@second inst is valid");
                    $display("@@corresponding brat vector: %b", brat_in_use2);
                end
            end
            $display("@@");
        end
    endtask  // show_rat

module testbench;

	// variables used in the testbench
	logic        clock;
	logic        reset;
	logic [31:0] clock_count;
	logic [31:0] instr_count;
	int          wb_fileno;
	
	logic [1:0]  proc2mem_command;
	logic [`XLEN-1:0] proc2mem_addr;
	logic [63:0] proc2mem_data;
	logic  [3:0] mem2proc_response;
	logic [63:0] mem2proc_data;
	logic  [3:0] mem2proc_tag;
`ifndef CACHE_MODE
	MEM_SIZE     proc2mem_size;
`endif
	logic  [3:0] pipeline_completed_insts;
	EXCEPTION_CODE   pipeline_error_status;
	logic  [4:0] pipeline_commit_wr_idx;
	logic [`XLEN-1:0] pipeline_commit_wr_data;
	logic        pipeline_commit_wr_en;
	logic [`XLEN-1:0] pipeline_commit_NPC;
	logic  [4:0] pipeline_commit_wr_idx2;
	logic [`XLEN-1:0] pipeline_commit_wr_data2;
	logic        pipeline_commit_wr_en2;
	logic [`XLEN-1:0] pipeline_commit_NPC2;
	
	
	logic [`XLEN-1:0] if_NPC_out1;
	logic [`XLEN-1:0] if_NPC_out2;
	logic [31:0] if_IR_out;
	logic [31:0] if_IR_out1;
	logic [31:0] if_IR_out2;
	logic        if_valid_inst_out1;
	logic 		 if_valid_inst_out2;
	logic [`XLEN-1:0] if_id_NPC1;
	logic [`XLEN-1:0] if_id_NPC2;
	logic [31:0] if_id_IR1;
	logic [31:0] if_id_IR2;
	logic        if_id_valid_inst1;
	logic        if_id_valid_inst2;
	logic [`XLEN-1:0] id_ex_NPC1;
	logic [`XLEN-1:0] id_ex_NPC2;
	logic [31:0] id_ex_IR1;
	logic [31:0] id_ex_IR2;
	logic        id_ex_valid_inst1;
	logic        id_ex_valid_inst2;
	logic [`XLEN-1:0] ex_mem_NPC;
	logic [31:0] ex_mem_IR;
	logic        ex_mem_valid_inst;
	logic [`XLEN-1:0] mem_wb_NPC;
	logic [31:0] mem_wb_IR;
	logic        mem_wb_valid_inst;
	logic [`XLEN-1:0]	is_ex_NPC1, is_ex_NPC2;
	logic [31:0]		is_ex_IR1, is_ex_IR2;
	logic				is_ex_valid_inst1, is_ex_valid_inst2;

	RS_ENTRY_PACKET [`RS_SIZE-1:0] 	rs_arr_out;
	ID_EX_PACKET 					issue_packet1, issue_packet2;
	logic [`RS_LEN-1:0]   			rs_empty_idx1, rs_empty_idx2;

	logic					rat_inst1_valid, rat_inst2_valid;
	logic [`PR_LEN-1:0]		rat_inst1_reg1, rat_inst1_reg2, rat_inst2_reg1, rat_inst2_reg2;
	logic [`AR_SIZE-1:0][`PR_LEN-1:0] rat_out1, rat_out2;
	logic [`AR_SIZE-1:0][`PR_LEN-1:0] rat_arr_out;
	logic [`AR_LEN-1:0]   	ar1_out, ar2_out;
	logic [`PR_LEN-1:0]   	pr1_out, pr2_out;
	logic					pr1_valid, pr2_valid;
	logic [`PR_SIZE-1:0][`VALUE_SIZE-1:0] registerFile;
	logic [`PR_SIZE-1:0] validOut;
	logic [`PR_SIZE-1:0]	listOut;
	logic [`PR_SIZE-1:0]	brat_listOut1, brat_listOut2;  
	logic [1:0] rob_full;
	logic [`ROB_LEN-1:0]   tail_out, head_out, head_plus1_out;
	ROB_ENTRY_PACKET [`ROB_SIZE-1:0] rob_arr_out;
	CDB_RETIRE_PACKET [31:0] 	retire_packet;
	logic [4:0]       			cdb_head_out, cdb_head_plus1_out, cdb_tail_out;
	logic [1:0] brat_full; 				
	logic		brat_copy_enable; 
	logic [`AR_SIZE-1:0][`PR_LEN-1:0] 						brat_arr_out; 
	logic [`PR_SIZE-1:0]	            					b_freelist_out;
	logic [`BRAT_SIZE-1:0][`AR_SIZE-1:0][`PR_LEN-1:0]		brat_out;
	logic [`BRAT_SIZE-1:0] brat_in_use1, brat_in_use2;
	logic [`BRAT_SIZE-1:0][`PR_SIZE-1:0]    brat_freelist_out;
	logic [`BRAT_SIZE-1:0][`BRAT_LEN-1:0] brat_sequence_out;
	logic [`BRAT_SIZE-1:0]                  brat_valid_out;

    //counter used for when pipeline infinite loops, forces termination
    logic [63:0] debug_counter;


	// Instantiate the Pipeline
	`DUT(pipeline) core(
		// Inputs
		.clock             (clock),
		.reset             (reset),
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag),
		
		
		// Outputs
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),
`ifndef CACHE_MODE
		.proc2mem_size     (proc2mem_size),
`endif
		.pipeline_completed_insts(pipeline_completed_insts),
		.pipeline_error_status(pipeline_error_status),
		.pipeline_commit_wr_data(pipeline_commit_wr_data),
		.pipeline_commit_wr_idx(pipeline_commit_wr_idx),
		.pipeline_commit_wr_en(pipeline_commit_wr_en),
		.pipeline_commit_NPC(pipeline_commit_NPC),
		.pipeline_commit_wr_data2(pipeline_commit_wr_data2),
		.pipeline_commit_wr_idx2(pipeline_commit_wr_idx2),
		.pipeline_commit_wr_en2(pipeline_commit_wr_en2),
		.pipeline_commit_NPC2(pipeline_commit_NPC2),
		
		.if_NPC_out1(if_NPC_out1),
		.if_NPC_out2(if_NPC_out2),
		.if_IR_out1(if_IR_out1),
		.if_IR_out2(if_IR_out2),
		.if_valid_inst_out1(if_valid_inst_out1),
		.if_valid_inst_out2(if_valid_inst_out2),
		.if_id_NPC1(if_id_NPC1),
		.if_id_NPC2(if_id_NPC2),
		.if_id_IR1(if_id_IR1),
		.if_id_IR2(if_id_IR2),
		.if_id_valid_inst1(if_id_valid_inst1),
		.if_id_valid_inst2(if_id_valid_inst2),
		.id_ex_NPC1(id_ex_NPC1),
		.id_ex_NPC2(id_ex_NPC2),
		.id_ex_IR1(id_ex_IR1),
		.id_ex_IR2(id_ex_IR2),
		.id_ex_valid_inst1(id_ex_valid_inst1),
		.id_ex_valid_inst2(id_ex_valid_inst2),
		.is_ex_NPC1(is_ex_NPC1),
		.is_ex_NPC2(is_ex_NPC2),
		.is_ex_IR1(is_ex_IR1),
		.is_ex_IR2(is_ex_IR2),
		.is_ex_valid_inst1(is_ex_valid_inst1),
		.is_ex_valid_inst2(is_ex_valid_inst2),
		.rs_arr_out(rs_arr_out), .issue_packet1(issue_packet1), .issue_packet2(issue_packet2),
		.rs_empty_idx1(rs_empty_idx1), .rs_empty_idx2(rs_empty_idx2),
		.rat_inst1_valid(rat_inst1_valid), .rat_inst2_valid(rat_inst2_valid),	
		.rat_inst1_reg1(rat_inst1_reg1), .rat_inst1_reg2(rat_inst1_reg2), 
		.rat_inst2_reg1(rat_inst2_reg1), .rat_inst2_reg2(rat_inst2_reg2),	
		.rat_out1(rat_out1), .rat_out2(rat_out2),	
		.rat_arr_out(rat_arr_out),
		.ar1_out(ar1_out), .ar2_out(ar2_out),
		.pr1_out(pr1_out), .pr2_out(pr2_out),
		.pr1_valid(pr1_valid), .pr2_valid(pr2_valid),
		.registerFile(registerFile),
		.validOut(validOut),
		.listOut(listOut),
		.brat_listOut1(brat_listOut1), .brat_listOut2(brat_listOut2),
		.rob_full(rob_full),
		.tail_out(tail_out), .head_out(head_out),
		.rob_arr_out(rob_arr_out),
		.retire_packet(retire_packet),
		.cdb_head_out(cdb_head_out), .cdb_tail_out(cdb_tail_out),
		.brat_in_use1(brat_in_use1), .brat_in_use2(brat_in_use2),
		.brat_copy_enable(brat_copy_enable),
		.brat_arr_out(brat_arr_out),
		.b_freelist_out(b_freelist_out),    
		.brat_full(brat_full),
    	.brat_out(brat_out),
		.brat_freelist_out(brat_freelist_out),
		.brat_sequence_out(brat_sequence_out),
		.brat_valid_out(brat_valid_out),
		.head_plus1_out(head_plus1_out),
		.cdb_head_plus1_out(cdb_head_plus1_out)
	);
	
	
	// Instantiate the Data Memory
	mem memory (
		// Inputs
		.clk               (clock),
		.proc2mem_command  (proc2mem_command),
		.proc2mem_addr     (proc2mem_addr),
		.proc2mem_data     (proc2mem_data),
`ifndef CACHE_MODE
		.proc2mem_size     (proc2mem_size),
`endif

		// Outputs

		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);
	
	// Generate System Clock
	always begin
		#(`VERILOG_CLOCK_PERIOD/2.0);
		clock = ~clock;
	end
	
	// Task to display # of elapsed clock edges
	task show_clk_count;
		real cpi;
		
		begin
			cpi = (clock_count + 1.0) / instr_count;
			$display("@@!  %0d cycles / %0d instrs = %f CPI\n@@!",
			          clock_count+1, instr_count, cpi);
			$display("@@!  %4.2f ns total time to execute\n@@!\n",
			          clock_count*`VERILOG_CLOCK_PERIOD);
		end
	endtask  // task show_clk_count 
	
	// Show contents of a range of Unified Memory, in both hex and decimal
	task show_mem_with_decimal;
		input [31:0] start_addr;
		input [31:0] end_addr;
		int showing_data;
		begin
			$display("@@@");
			showing_data=0;
			for(int k=start_addr;k<=end_addr; k=k+1)
				if (memory.unified_memory[k] != 0) begin
					$display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k], 
				                                            memory.unified_memory[k]);
					showing_data=1;
				end else if(showing_data!=0) begin
					$display("@@@");
					showing_data=0;
				end
			$display("@@@");
		end
	endtask  // task show_mem_with_decimal
	
	initial begin
	
		clock = 1'b0;
		reset = 1'b0;
		
		// Pulse the reset signal
		$display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
		reset = 1'b1;
		@(posedge clock);
		@(posedge clock);
		
		$readmemh("program.mem", memory.unified_memory);
		
		@(posedge clock);
		@(posedge clock);
		`SD;
		// This reset is at an odd time to avoid the pos & neg clock edges
		
		reset = 1'b0;
		$display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);
		
		wb_fileno = $fopen("writeback.out");
		
		//Open header AFTER throwing the reset otherwise the reset state is displayed
		print_header("                                                                            D-MEM Bus &\n");
		print_header("Cycle:      IF1     |     IF2     |    ID1      |    ID2      |    DP1      |    DP2      |     IS1     |     IS2     |     Reg Result");
	end


	// Count the number of posedges and number of instructions completed
	// till simulation ends
	always @(posedge clock) begin
		if(reset) begin
			clock_count <= `SD 0;
			instr_count <= `SD 0;
		end else begin
			clock_count <= `SD (clock_count + 1);
			instr_count <= `SD (instr_count + pipeline_completed_insts);
		end
	end  
	
	
	always @(negedge clock) begin
        if(reset) begin
			$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
			         $realtime);
            debug_counter <= 0;
        end else begin
			`SD;
			`SD;
			// $display("requesting memory addr: %h with command %d, data %h", proc2mem_addr, proc2mem_command, proc2mem_data);
			// $display("memory respond with %d", mem2proc_response);
			//  show_prf(registerFile, rat_arr_out, validOut, $time);
			//  show_free_list(listOut, brat_listOut1, brat_listOut2, $time);
			//  show_rat(rat_inst1_valid, rat_inst2_valid, rat_inst1_reg1, rat_inst1_reg2, rat_inst2_reg1, rat_inst2_reg2, rat_out1, rat_out2,
		 	//  	rat_arr_out, ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid, $time);
			//  show_brat(brat_copy_enable, brat_arr_out, b_freelist_out, brat_full, brat_out, brat_sequence_out, brat_valid_out, $time, 
			//  	id_ex_valid_inst1, id_ex_valid_inst2, brat_in_use1, brat_in_use2, brat_freelist_out);
			//  show_rs_entries(rs_arr_out, $time, rs_empty_idx1, rs_empty_idx2, issue_packet1, issue_packet2);
			//  show_rob_entries(rob_arr_out, rob_full, head_out, tail_out, $time);
			//  show_cdb_entries(retire_packet, cdb_head_out, cdb_tail_out, $time);
			 // print the piepline stuff via c code to the pipeline.out
			 print_cycles();
			 print_stage("|", if_IR_out1, if_NPC_out1[31:0], {31'b0,if_valid_inst_out1});
			 print_stage("|", if_IR_out2, if_NPC_out2[31:0], {31'b0,if_valid_inst_out2});
			 print_stage("|", if_id_IR1, if_id_NPC1[31:0], {31'b0,if_id_valid_inst1});
			 print_stage("|", if_id_IR2, if_id_NPC2[31:0], {31'b0,if_id_valid_inst2});
			 print_stage("|", id_ex_IR1, id_ex_NPC1[31:0], {31'b0,id_ex_valid_inst1});
			 print_stage("|", id_ex_IR2, id_ex_NPC2[31:0], {31'b0,id_ex_valid_inst2});
			 print_stage("|", is_ex_IR1, is_ex_NPC1[31:0], {31'b0,is_ex_valid_inst1});
			 print_stage("|", is_ex_IR2, is_ex_NPC2[31:0], {31'b0,is_ex_valid_inst2});
			//  print_stage("|", ex_mem_IR, ex_mem_NPC[31:0], {31'b0,ex_mem_valid_inst});
			//  print_stage("|", mem_wb_IR, mem_wb_NPC[31:0], {31'b0,mem_wb_valid_inst});
			//  print_reg(32'b0, pipeline_commit_wr_data[31:0],
			// 	{27'b0,pipeline_commit_wr_idx}, {31'b0,pipeline_commit_wr_en});
			//  print_membus({30'b0,proc2mem_command}, {28'b0,mem2proc_response},
			// 	32'b0, proc2mem_addr[31:0],
			// 	proc2mem_data[63:32], proc2mem_data[31:0]);
			
			
			 // print the writeback information to writeback.out
			if(pipeline_completed_insts == 1) begin
				if(pipeline_commit_wr_en)
					$fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
						pipeline_commit_NPC,
						pipeline_commit_wr_idx,
						pipeline_commit_wr_data);
				else
					$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC);
			end
			else if (pipeline_completed_insts == 2) begin
				if(pipeline_commit_wr_en) begin
					$fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
						pipeline_commit_NPC,
						pipeline_commit_wr_idx,
						pipeline_commit_wr_data);
				end
				else
					$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC);
				if (pipeline_commit_wr_en2)
					$fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
						pipeline_commit_NPC2,
						pipeline_commit_wr_idx2,
						pipeline_commit_wr_data2); 
				else
					$fdisplay(wb_fileno, "PC=%x, ---",pipeline_commit_NPC2);
			end



			
			// deal with any halting conditions
			if(pipeline_error_status != NO_ERROR || debug_counter > 50000000) begin
				$display("program finished on time %d", $time);
				$display("@@@ Unified Memory contents hex on left, decimal on right: ");
				show_mem_with_decimal(0,`MEM_64BIT_LINES - 1); 
				// 8Bytes per line, 16kB total
				
				$display("@@  %t : System halted\n@@", $realtime);
				
				case(pipeline_error_status)
					LOAD_ACCESS_FAULT:  
						$display("@@@ System halted on memory error");
					HALTED_ON_WFI:          
						$display("@@@ System halted on WFI instruction");
					ILLEGAL_INST:
						$display("@@@ System halted on illegal instruction");
					default: 
						$display("@@@ System halted on unknown error code %x", 
							pipeline_error_status);
				endcase
				$display("@@@\n@@");
				show_clk_count;
				print_close(); // close the pipe_print output file
				$fclose(wb_fileno);
				#100 $finish;
			end
            debug_counter <= debug_counter + 1;
		end  // if(reset)   
	end 

endmodule  // module testbench

