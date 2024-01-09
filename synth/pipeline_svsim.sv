`ifndef SYNTHESIS

//
// This is an automatically generated file from 
// dc_shell Version O-2018.06 -- May 21, 2018
//

// For simulation only. Do not modify.

module pipeline_svsim (

	input         				clock,                    		input         				reset,                    		input [3:0]   				mem2proc_response,        		input [63:0]  				mem2proc_data,            		input [3:0]   				mem2proc_tag,             		
	output logic [1:0]  		proc2mem_command,    		output logic [32-1:0] 	proc2mem_addr,      		output logic [63:0] 		proc2mem_data,      		 
	output logic [3:0]  		pipeline_completed_insts,
	output EXCEPTION_CODE   	pipeline_error_status,
	output logic [4:0]  		pipeline_commit_wr_idx,
	output logic [32-1:0] 	pipeline_commit_wr_data,
	output logic        		pipeline_commit_wr_en,
	output logic [32-1:0] 	pipeline_commit_NPC,
	output logic [4:0] 			pipeline_commit_wr_idx2,
	output logic [32-1:0] 	pipeline_commit_wr_data2,
	output logic        		pipeline_commit_wr_en2,
	output logic [32-1:0] 	pipeline_commit_NPC2,	
	
				
	
		output logic [32-1:0] 	if_NPC_out1, if_NPC_out2,
	output logic [31:0] 		if_IR_out1, if_IR_out2,
	output logic        		if_valid_inst_out1, if_valid_inst_out2,
	
		output logic [32-1:0] 	if_id_NPC1, if_id_NPC2,
	output logic [31:0] 		if_id_IR1, if_id_IR2,
	output logic        		if_id_valid_inst1, if_id_valid_inst2,
	
	
		output logic [32-1:0] 	id_ex_NPC1, id_ex_NPC2,
	output logic [31:0] 		id_ex_IR1, id_ex_IR2,
	output logic        		id_ex_valid_inst1, id_ex_valid_inst2,
	
	
		output logic [32-1:0]	is_ex_NPC1, is_ex_NPC2,
	output logic [31:0]			is_ex_IR1, is_ex_IR2,
	output logic				is_ex_valid_inst1, is_ex_valid_inst2,

			output RS_ENTRY_PACKET [8-1:0] 	rs_arr_out,
	output ID_EX_PACKET 					issue_packet1, issue_packet2,
	output logic [3-1:0]   			rs_empty_idx1, rs_empty_idx2,
		output					rat_inst1_valid, rat_inst2_valid,
	output [6-1:0]	rat_inst1_reg1, rat_inst1_reg2, rat_inst2_reg1, rat_inst2_reg2,
	output [32-1:0][6-1:0] rat_out1, rat_out2,
	output [32-1:0][6-1:0] rat_arr_out,
	output [5-1:0]   	ar1_out, ar2_out,
	output [6-1:0]   	pr1_out, pr2_out,
	output					pr1_valid, pr2_valid,
		output [64-1:0][32-1:0] registerFile,
	output [64-1:0] validOut,
		output [64-1:0]	listOut,
	output [64-1:0]	brat_listOut1, brat_listOut2,
		output [1:0] rob_full,
	output [4-1:0]   tail_out,head_out,head_plus1_out,
	output ROB_ENTRY_PACKET [16-1:0]  rob_arr_out,
		output CDB_RETIRE_PACKET [31:0] 	retire_packet,
	output [4:0]    cdb_head_out, cdb_head_plus1_out, cdb_tail_out,
		output [1:0] 	brat_full,
	output			brat_copy_enable,
	output [32-1:0][6-1:0] 						brat_arr_out,
	output [64-1:0]	            					b_freelist_out,
	output [4-1:0][32-1:0][6-1:0]		brat_out,
	output [4-1:0] brat_in_use1, brat_in_use2,
	output [4-1:0][64-1:0]   brat_freelist_out,
	output [4-1:0][2-1:0] 	brat_sequence_out,
	output [4-1:0]                 brat_valid_out

);

		

  pipeline pipeline( {>>{ clock }}, {>>{ reset }}, {>>{ mem2proc_response }}, 
        {>>{ mem2proc_data }}, {>>{ mem2proc_tag }}, {>>{ proc2mem_command }}, 
        {>>{ proc2mem_addr }}, {>>{ proc2mem_data }}, 
        {>>{ pipeline_completed_insts }}, {>>{ pipeline_error_status }}, 
        {>>{ pipeline_commit_wr_idx }}, {>>{ pipeline_commit_wr_data }}, 
        {>>{ pipeline_commit_wr_en }}, {>>{ pipeline_commit_NPC }}, 
        {>>{ pipeline_commit_wr_idx2 }}, {>>{ pipeline_commit_wr_data2 }}, 
        {>>{ pipeline_commit_wr_en2 }}, {>>{ pipeline_commit_NPC2 }}, 
        {>>{ if_NPC_out1 }}, {>>{ if_NPC_out2 }}, {>>{ if_IR_out1 }}, 
        {>>{ if_IR_out2 }}, {>>{ if_valid_inst_out1 }}, 
        {>>{ if_valid_inst_out2 }}, {>>{ if_id_NPC1 }}, {>>{ if_id_NPC2 }}, 
        {>>{ if_id_IR1 }}, {>>{ if_id_IR2 }}, {>>{ if_id_valid_inst1 }}, 
        {>>{ if_id_valid_inst2 }}, {>>{ id_ex_NPC1 }}, {>>{ id_ex_NPC2 }}, 
        {>>{ id_ex_IR1 }}, {>>{ id_ex_IR2 }}, {>>{ id_ex_valid_inst1 }}, 
        {>>{ id_ex_valid_inst2 }}, {>>{ is_ex_NPC1 }}, {>>{ is_ex_NPC2 }}, 
        {>>{ is_ex_IR1 }}, {>>{ is_ex_IR2 }}, {>>{ is_ex_valid_inst1 }}, 
        {>>{ is_ex_valid_inst2 }}, {>>{ rs_arr_out }}, {>>{ issue_packet1 }}, 
        {>>{ issue_packet2 }}, {>>{ rs_empty_idx1 }}, {>>{ rs_empty_idx2 }}, 
        {>>{ rat_inst1_valid }}, {>>{ rat_inst2_valid }}, 
        {>>{ rat_inst1_reg1 }}, {>>{ rat_inst1_reg2 }}, {>>{ rat_inst2_reg1 }}, 
        {>>{ rat_inst2_reg2 }}, {>>{ rat_out1 }}, {>>{ rat_out2 }}, 
        {>>{ rat_arr_out }}, {>>{ ar1_out }}, {>>{ ar2_out }}, {>>{ pr1_out }}, 
        {>>{ pr2_out }}, {>>{ pr1_valid }}, {>>{ pr2_valid }}, 
        {>>{ registerFile }}, {>>{ validOut }}, {>>{ listOut }}, 
        {>>{ brat_listOut1 }}, {>>{ brat_listOut2 }}, {>>{ rob_full }}, 
        {>>{ tail_out }}, {>>{ head_out }}, {>>{ head_plus1_out }}, 
        {>>{ rob_arr_out }}, {>>{ retire_packet }}, {>>{ cdb_head_out }}, 
        {>>{ cdb_head_plus1_out }}, {>>{ cdb_tail_out }}, {>>{ brat_full }}, 
        {>>{ brat_copy_enable }}, {>>{ brat_arr_out }}, {>>{ b_freelist_out }}, 
        {>>{ brat_out }}, {>>{ brat_in_use1 }}, {>>{ brat_in_use2 }}, 
        {>>{ brat_freelist_out }}, {>>{ brat_sequence_out }}, 
        {>>{ brat_valid_out }} );
endmodule
`endif
