/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  pipeline.v                                          //
//                                                                     //
//  Description :  Top-level module of the verisimple pipeline;        //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline togeather.                      //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __PIPELINE_V__
`define __PIPELINE_V__

`timescale 1ns/100ps

	
	task show_lsq;
        input [`LSQ_SIZE-1:0]						lq_valid;
	    input [`LSQ_SIZE-1:0][`XLEN-1:0]			lq_dest_addr;
	    input [`LSQ_SIZE-1:0][`PR_LEN-1:0]			lq_dest_regs;
        input [`LSQ_SIZE-1:0]						lq_addr_valid;
        input [`LSQ_SIZE-1:0]						lq_need_mem;
        input [`LSQ_SIZE-1:0]						lq_need_store;
        input [`LSQ_SIZE-1:0]						lq_done;
        input [`LSQ_SIZE-1:0][`BRAT_SIZE-1:0]		lq_brat_vec;
        input [`LSQ_SIZE-1:0][`ROB_LEN-1:0]			lq_rob_nums;
        input [`LSQ_SIZE-1:0][`LSQ_LEN-1:0]			lq_age;
        input [`LSQ_SIZE-1:0][`XLEN-1:0]			lq_value;
        input [`LSQ_SIZE-1:0][3:0]                  lq_tags;
        input [`LSQ_SIZE-1:0]                       lq_issued;
        input [1:0]									lq_full;
        input [`LSQ_LEN-1:0]						sq_head;
        input [`LSQ_LEN-1:0]						sq_tail;
        input [`LSQ_SIZE-1:0]						sq_valid;
        input [`LSQ_SIZE-1:0][`XLEN-1:0]			sq_dest_addr;
        input [`LSQ_SIZE-1:0][`XLEN-1:0]			sq_value;
        input [`LSQ_SIZE-1:0]						sq_addr_done;
        input [`LSQ_SIZE-1:0]						sq_done;
        input [`LSQ_SIZE-1:0][`BRAT_SIZE-1:0]		sq_brat_vec;
        input [1:0]									sq_full;
        input [`LSQ_SIZE-1:0][`ROB_LEN-1:0]			sq_rob_nums;
        input [15:0][`LSQ_LEN-1:0]					map_lsq_num;
	    input [15:0]								map_valid;
		input [`LSQ_SIZE-1:0][2:0]					sq_mem_size;
        input [31:0]                      cnt;
        begin
            $display("@@\t\tCycle %d", cnt);
            $display("@@updated lsq from last cycle:");
            
            // print lq
            $display("@@\t		lq#\tvalid\tdest_addr  dest_reg  addr_valid  need_mem  need_store  done\t	brat_vec\trob#	  age     value   tags issued");
            for (int i = 0; i < `LSQ_SIZE; i++) begin
                //if (lq_tags[i] != 0) $display("lq has wrong tag %d", lq_tags[i]);
                $display("@@%9d%9d    %8h%9d%9d%9d   %9d%9d        %4b   %9d%9d    %8h%4d  %b",
                    i, lq_valid[i], lq_dest_addr[i], lq_dest_regs[i], lq_addr_valid[i], lq_need_mem[i],lq_need_store[i],lq_done[i],lq_brat_vec[i],lq_rob_nums[i],lq_age[i],lq_value[i],lq_tags[i],lq_issued[i]);
            end
            $display("@@lq_full: %b", lq_full);
            $display("@@");
            
            // print lq map
            $display("@@ lq map:   mem_tag     lq_idx    valid");
            for (int i=0; i<16; i++) begin
                $display("          %9d%9d%9d", i, map_lsq_num[i], map_valid[i]);
            end
            $display("@@");

            // print sq
            $display("@@\t		sq#\tvalid\tdest_addr      value\t addr_done\tdone\tbrat_vec\trob#   wr_size");
            for (int i = 0; i < `LSQ_SIZE; i++) begin
                if (sq_valid[i]) begin
                    if (sq_head == i && sq_head == sq_tail) begin
                        $display("@@%6d%9d      %8h     %8h   %9d%9d    %4b   %9d%9d  HEAD,TAIL", 
                        i, sq_valid[i],sq_dest_addr[i],sq_value[i],sq_addr_done[i],sq_done[i],sq_brat_vec[i],sq_rob_nums[i], sq_mem_size[i]);
                    end
                    else if (sq_head == i) begin
                        $display("@@%6d%9d      %8h     %8h   %9d%9d    %4b   %9d%9d  HEAD", 
                        i, sq_valid[i],sq_dest_addr[i],sq_value[i],sq_addr_done[i],sq_done[i],sq_brat_vec[i],sq_rob_nums[i], sq_mem_size[i]);
                    end else if (sq_tail == i) begin
                        $display("@@%6d%9d      %8h     %8h   %9d%9d    %4b   %9d%9d  TAIL", 
                        i, sq_valid[i],sq_dest_addr[i],sq_value[i],sq_addr_done[i],sq_done[i],sq_brat_vec[i],sq_rob_nums[i], sq_mem_size[i]);
                    end else begin
                        $display("@@%6d%9d      %8h     %8h   %9d%9d    %4b   %9d%9d ", 
                        i, sq_valid[i],sq_dest_addr[i],sq_value[i],sq_addr_done[i],sq_done[i],sq_brat_vec[i],sq_rob_nums[i], sq_mem_size[i]);
                    end
                end 
                else begin
                    if (sq_head == sq_tail && i == sq_head) begin
                        $display("@@%6d HEAD,TAIL", i);
                    end else if (i == sq_tail) begin
                        $display("@@%6d TAIL", i);
                    end else begin
                        $display("@@%6d", i);
                    end
                end
            end

            
            $display("@@sq_full: %b", sq_full);
            $display("@@");
        end
    endtask  
	
	

module pipeline (

	input         				clock,                    	// System clock
	input         				reset,                    	// System reset
	input [3:0]   				mem2proc_response,        	// Tag from memory about current request
	input [63:0]  				mem2proc_data,            	// Data coming back from memory
	input [3:0]   				mem2proc_tag,             	// Tag from memory about current reply
	
	output logic [1:0]  		proc2mem_command,    	// command sent to memory
	output logic [`XLEN-1:0] 	proc2mem_addr,      	// Address sent to memory
	output logic [63:0] 		proc2mem_data,      	// Data sent to memory
	`ifndef CACHE_MODE
	output MEM_SIZE 			proc2mem_size,          // data size sent to memory
	`endif
	output logic [3:0]  		pipeline_completed_insts,
	output EXCEPTION_CODE   	pipeline_error_status,
	output logic [4:0]  		pipeline_commit_wr_idx,
	output logic [`XLEN-1:0] 	pipeline_commit_wr_data,
	output logic        		pipeline_commit_wr_en,
	output logic [`XLEN-1:0] 	pipeline_commit_NPC,
	output logic [4:0] 			pipeline_commit_wr_idx2,
	output logic [`XLEN-1:0] 	pipeline_commit_wr_data2,
	output logic        		pipeline_commit_wr_en2,
	output logic [`XLEN-1:0] 	pipeline_commit_NPC2,	
	
	// testing hooks (these must be exported so we can test
	// the synthesized version) data is tested by looking at
	// the final values in memory
	
	
	// Outputs from IF-Stage 
	output logic [`XLEN-1:0] 	if_NPC_out1, if_NPC_out2,
	output logic [31:0] 		if_IR_out1, if_IR_out2,
	output logic        		if_valid_inst_out1, if_valid_inst_out2,
	
	// Outputs from IF/ID Pipeline Register
	output logic [`XLEN-1:0] 	if_id_NPC1, if_id_NPC2,
	output logic [31:0] 		if_id_IR1, if_id_IR2,
	output logic        		if_id_valid_inst1, if_id_valid_inst2,
	
	
	// Outputs from ID/Dispatch Pipeline Register
	output logic [`XLEN-1:0] 	id_ex_NPC1, id_ex_NPC2,
	output logic [31:0] 		id_ex_IR1, id_ex_IR2,
	output logic        		id_ex_valid_inst1, id_ex_valid_inst2,
	
	
	// Outputs from IS/EX Pipeline Register
	output logic [`XLEN-1:0]	is_ex_NPC1, is_ex_NPC2,
	output logic [31:0]			is_ex_IR1, is_ex_IR2,
	output logic				is_ex_valid_inst1, is_ex_valid_inst2,

	// Debug Outputs
	// Outputs to show RS
	output RS_ENTRY_PACKET [`RS_SIZE-1:0] 	rs_arr_out,
	output ID_EX_PACKET 					issue_packet1, issue_packet2,
	output logic [`RS_LEN-1:0]   			rs_empty_idx1, rs_empty_idx2,
	// Outputs to show RAT
	output					rat_inst1_valid, rat_inst2_valid,
	output [`PR_LEN-1:0]	rat_inst1_reg1, rat_inst1_reg2, rat_inst2_reg1, rat_inst2_reg2,
	output [`AR_SIZE-1:0][`PR_LEN-1:0] rat_out1, rat_out2,
	output [`AR_SIZE-1:0][`PR_LEN-1:0] rat_arr_out,
	output [`AR_LEN-1:0]   	ar1_out, ar2_out,
	output [`PR_LEN-1:0]   	pr1_out, pr2_out,
	output					pr1_valid, pr2_valid,
	// Outputs to show PRF
	output [`PR_SIZE-1:0][`VALUE_SIZE-1:0] registerFile,
	output [`PR_SIZE-1:0] validOut,
	// Outputs to show FREELIST
	output [`PR_SIZE-1:0]	listOut,
	output [`PR_SIZE-1:0]	brat_listOut1, brat_listOut2,
	// Outputs to show ROB
	output [1:0] rob_full,
	output [`ROB_LEN-1:0]   tail_out,head_out,head_plus1_out,
	output ROB_ENTRY_PACKET [`ROB_SIZE-1:0]  rob_arr_out,
	// Outputs to show CDB
	output CDB_RETIRE_PACKET [31:0] 	retire_packet,
	output [4:0]    cdb_head_out, cdb_head_plus1_out, cdb_tail_out,
	// Outputs to show BRAT
	output [1:0] 	brat_full,
	output			brat_copy_enable,
	output [`AR_SIZE-1:0][`PR_LEN-1:0] 						brat_arr_out,
	output [`PR_SIZE-1:0]	            					b_freelist_out,
	output [`BRAT_SIZE-1:0][`AR_SIZE-1:0][`PR_LEN-1:0]		brat_out,
	output [`BRAT_SIZE-1:0] brat_in_use1, brat_in_use2,
	output [`BRAT_SIZE-1:0][`PR_SIZE-1:0]   brat_freelist_out,
	output [`BRAT_SIZE-1:0][`BRAT_LEN-1:0] 	brat_sequence_out,
	output [`BRAT_SIZE-1:0]                 brat_valid_out

);

	// Pipeline register enables
	logic   if_id_enable, id_ex_enable;
	/* Important: stall and mispredict signal */
	logic	need_stall, mispredict;

	logic request_phy_reg1, request_phy_reg2;

	// Outputs from IF-Stage
	logic [`XLEN-1:0] proc2Imem_addr;
	IF_ID_PACKET if_packet;
	IF_ID_PACKET if_packet2;

	// Outputs from IF/ID Pipeline Register
	IF_ID_PACKET if_id_packet;
	IF_ID_PACKET if_id_packet2;

	// Outputs from ID stage, two packets (superscalar)
	ID_EX_PACKET id_packet;
	ID_EX_PACKET id_packet2;

	// Outputs from ID/Dispatch Pipeline Register
	ID_EX_PACKET id_dispatch_packet;
	ID_EX_PACKET id_dispatch_packet2;

	// Outputs from Issue/Ex Pipeline Register
	ID_EX_PACKET is_ex_packet;
	ID_EX_PACKET is_ex_packet2;
	

	EX_PACKET alu1_pkt, alu2_pkt, mult1_pkt, mult2_pkt, ld_commit_pkt1, ld_commit_pkt2;
	logic mult_will_done1, mult_will_done2;
	logic mult_done1, mult_done2;


	// Outputs from MEM-Stage
	logic [`XLEN-1:0] mem_result_out;
	// TODO: maybe pipeline the memory request later
	logic [`XLEN-1:0] proc2Dmem_addr;
	logic [2*`XLEN-1:0] proc2Dmem_data;
	logic [1:0]  proc2Dmem_command;
	// MEM_SIZE proc2Dmem_size;

	// Outputs to determine branches to take 
	logic        mem_wb_halt;
	logic        mem_wb_illegal;



	// Outputs from CDB
	logic 						cdb1_valid, cdb2_valid;
	logic [`ROB_LEN-1:0]  		cdb1_tag, cdb2_tag;
	logic [`PR_LEN-1:0]   		cdb1_phy_reg, cdb2_phy_reg;
	logic 						cdb1_branch_rst, cdb2_branch_rst;
	logic [`XLEN-1:0]     		cdb1_data, cdb2_data;
	logic						cdb1_is_branch, cdb2_is_branch;
	logic [`BRAT_SIZE-1:0]    	cdb1_brat_vec, cdb2_brat_vec;
	CDB_RETIRE_PACKET [31:0] 	retire_packet;
	logic [4:0]       			cdb_head_out, cdb_tail_out;

	// Outputs from ROB
	logic [1:0] rob_full;  // indicate whether the rob is full, 11 --> full, 10 --> one slot, 00 --> not full
	wire mispred_out1, mispred_out2;
	logic [`ROB_LEN-1:0]   tail_out, tail_plus1_out, head_out;
	ROB_RETIRE_PACKET retire_pkt_1, retire_pkt_2;
	ROB_ENTRY_PACKET [`ROB_SIZE-1:0] rob_arr_out;

	// Outputs from FreeList
	logic [`PR_SIZE-1:0]	listOut;
	logic [`PR_LEN-1:0]		free_preg1, free_preg2;						// The next avaiable free phy reg
	logic					free_preg1_valid, free_preg2_valid;
	logic [`PR_SIZE-1:0]	brat_listOut1, brat_listOut2;     	// outputs to brat to backup when branch dispatch

	// Outputs from Register Alias Table (RAT)
	logic					rat_inst1_valid, rat_inst2_valid;
	logic [`PR_LEN-1:0]		rat_inst1_reg1, rat_inst1_reg2, rat_inst2_reg1, rat_inst2_reg2;
	logic [`AR_SIZE-1:0][`PR_LEN-1:0] rat_out1, rat_out2;
	logic [`AR_SIZE-1:0][`PR_LEN-1:0] rat_arr_out;
	logic [`AR_LEN-1:0]   	ar1_out, ar2_out;
	logic [`PR_LEN-1:0]   	pr1_out, pr2_out;
	logic					pr1_valid, pr2_valid;
	
	// Special Inputs to PRF
	logic [`XLEN-1:0]	cdb1_prf_data, cdb2_prf_data;

	// Outputs from PRF, read values from RAT 
	logic 				rat11_valid, rat12_valid, rat21_valid, rat22_valid;
	logic [`XLEN-1:0] 	rat11_value, rat12_value, rat21_value, rat22_value;
	logic [`PR_SIZE-1:0][`VALUE_SIZE-1:0] registerFile;
	logic [`PR_SIZE-1:0] validOut;
	
	// Outputs from BRAT
	logic [1:0] brat_full; 				// if brat full, stall
	logic		brat_copy_enable; 		// used when mispredict, copy the brat to rat
	logic [`AR_SIZE-1:0][`PR_LEN-1:0] 						brat_arr_out; 	// the entire copy brat
	logic [`BRAT_SIZE-1:0]    								brat_mis;		// The brat mispredict vector
	logic [`BRAT_LEN-1:0]     								correct_index1, correct_index2;
	logic					 								correct_idx1_valid, correct_idx2_valid;
	logic [`PR_SIZE-1:0]	            					b_freelist_out;
	logic [`BRAT_SIZE-1:0][`AR_SIZE-1:0][`PR_LEN-1:0]		brat_out;
	/* Bit vector indicating which BRAT are in use */
	logic [`BRAT_SIZE-1:0] brat_in_use1, brat_in_use2;
	logic [`BRAT_SIZE-1:0][`PR_SIZE-1:0]    brat_freelist_out;
	logic [`BRAT_SIZE-1:0][`BRAT_LEN-1:0] brat_sequence_out;
	logic [`BRAT_SIZE-1:0]                  brat_valid_out;

	// Outputs from RS
	// ID_EX_PACKET 					issue_packet1, issue_packet2;
	logic [1:0]						rs_full;
	// RS_ENTRY_PACKET [`RS_SIZE-1:0] 	rs_arr_out;
	// logic [`RS_LEN-1:0]   			rs_empty_idx1, rs_empty_idx2;

	// Outputs from lsq
	//logic							mem2lsq_valid;
	logic [1:0]						lsq_full;
	logic [1:0]						lsq2mem_command;
	logic [`XLEN-1:0]				lsq2mem_addr;
	logic [`XLEN-1:0]				lsq2mem_data;
	logic [1:0]						lsq2mem_wr_size;
	// Outputs from lsq for debug
	logic [`LSQ_SIZE-1:0]						lq_valid;
	logic [`LSQ_SIZE-1:0][`XLEN-1:0]			lq_dest_addr;
	logic [`LSQ_SIZE-1:0][`PR_LEN-1:0]			lq_dest_regs;
	logic [`LSQ_SIZE-1:0]						lq_addr_valid;
	logic [`LSQ_SIZE-1:0]						lq_need_mem;
	logic [`LSQ_SIZE-1:0]						lq_need_store;
	logic [`LSQ_SIZE-1:0]						lq_done;
	logic [`LSQ_SIZE-1:0][`BRAT_SIZE-1:0]		lq_brat_vec;
	logic [`LSQ_SIZE-1:0][`ROB_LEN-1:0]			lq_rob_nums;
	logic [`LSQ_SIZE-1:0][`LSQ_LEN-1:0]			lq_age;
	logic [`LSQ_SIZE-1:0][`XLEN-1:0]			lq_value;
    logic [`LSQ_SIZE-1:0]                       lq_issued;
	logic [1:0]									lq_full;
    logic [`LSQ_LEN-1:0]						sq_head;
	logic [`LSQ_LEN-1:0]						sq_tail;
	logic [`LSQ_SIZE-1:0]						sq_valid;
	logic [`LSQ_SIZE-1:0][`XLEN-1:0]			sq_dest_addr;
	logic [`LSQ_SIZE-1:0][`XLEN-1:0]			sq_value;
	logic [`LSQ_SIZE-1:0]						sq_addr_done;
	logic [`LSQ_SIZE-1:0]						sq_done;
	logic [`LSQ_SIZE-1:0][`BRAT_SIZE-1:0]		sq_brat_vec;
	logic [1:0]									sq_full;
	logic [`LSQ_SIZE-1:0][`ROB_LEN-1:0]			sq_rob_nums;
    logic [`LSQ_SIZE-1:0][3:0]                  lq_tags;
    logic [15:0][`LSQ_LEN-1:0]					map_lsq_num;
	logic [15:0]								map_valid;
	logic [`LSQ_SIZE-1:0][2:0]					sq_mem_size;

	// Outputs from DCache
	logic							dcache2lsq_valid;
	logic [3:0]						dcache2lsq_tag;
	logic [`XLEN-1:0]				dcache2lsq_data;

	MSHR_ENTRY_PACKET [`MSHRSIZE-1:0] mshr_arr_out;
	MSHR_ENTRY_PACKET mshr_retire_pkt;
	logic retire_pkt_valid;
	logic [`MSHRLEN-1:0] mshr_head, mshr_send, mshr_tail;
	logic dcache_valid_out;
	logic [63:0] dcache_data_out;
	logic mshr_full, mshr_empty, halt_when_st, halt_when_st_next, sq_empty;

	// if a halt retire but mshr has not finish its store work,
	// remember that the system is essentially halted, and when
	// mshr is empty again, pass wfi to outside pipeline
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset)
			halt_when_st <= `SD 0;
		else
			halt_when_st <= `SD halt_when_st_next;
	end

	always_comb begin
		halt_when_st_next = halt_when_st;
		if (mem_wb_halt && (!mshr_empty || !sq_empty)) begin
			halt_when_st_next = 1;
			$display("halt when store!");
		end
	end

	// Memory responses
	// length should be log2(num_mem_tags)
	wire [3:0] 	Imem2proc_response;
	wire		Icache_wr_en;
	wire [4:0] 	Icache_wr_idx, Icache_rd_idx;
	wire [7:0] 	Icache_wr_tag, Icahce_rd_tag;
	wire [63:0] Icache_wr_data, Icache_rd_data;
	wire		Icache_rd_valid;
	wire [1:0]	proc2Imem_command;
	logic [`XLEN-1:0] proc2Icache_addr;
	wire [63:0]	Icache_data_out;
	wire		Icache_valid_out;

	// Logic to determine which branch to taken
	logic				taken_branch;				
	logic [`XLEN-1:0]	true_branch_target;

	// this is directly port to lsq, every tag from memory is going through lsq
	assign mem_wb_illegal = (retire_pkt_1.decoded_packet.illegal & retire_pkt_1.retire_valid) | (retire_pkt_2.decoded_packet.illegal & retire_pkt_2.retire_valid);
	assign mem_wb_halt	  = (retire_pkt_1.decoded_packet.halt & retire_pkt_1.retire_valid) | (retire_pkt_2.decoded_packet.halt & retire_pkt_2.retire_valid);

	assign pipeline_completed_insts = halt_when_st ? 0 : (retire_pkt_2.retire_valid) ? 2 : 
									  (retire_pkt_1.retire_valid) ? 1 : 0;
	

	assign pipeline_error_status =  mem_wb_illegal                ? ILLEGAL_INST :
	                                (mem_wb_halt & mshr_empty & sq_empty)    ? HALTED_ON_WFI :
									(mshr_empty & halt_when_st & sq_empty)	  ? HALTED_ON_WFI :
	                                NO_ERROR;
	
	// these are not used for now
	assign pipeline_commit_wr_idx = retire_pkt_1.arch_reg;
	assign pipeline_commit_wr_data = registerFile[retire_pkt_1.phy_reg];
	assign pipeline_commit_wr_en = (retire_pkt_1.retire_valid & (retire_pkt_1.arch_reg != 0)) ? 1 : 0;
	assign pipeline_commit_NPC = retire_pkt_1.pc;

	assign pipeline_commit_wr_idx2 = retire_pkt_2.arch_reg;
	assign pipeline_commit_wr_data2 = registerFile[retire_pkt_2.phy_reg];
	assign pipeline_commit_wr_en2 = (retire_pkt_2.retire_valid & (retire_pkt_2.arch_reg != 0)) ? 1 : 0;
	assign pipeline_commit_NPC2 = retire_pkt_2.pc;
	
	

	/* Only for milestone 2*/
	// assign proc2Dmem_command = BUS_NONE;
	
	// TODO: comment this out, always BUS_LOAD 
	assign proc2mem_command =
	     (proc2Dmem_command == BUS_NONE) ? proc2Imem_command : proc2Dmem_command;
	assign proc2mem_addr =
	     (proc2Dmem_command == BUS_NONE) ? proc2Imem_addr : proc2Dmem_addr;
	//if it's an instruction, then load a double word (64 bits)
	// assign proc2mem_size =
	//      (proc2Dmem_command == BUS_NONE) ? DOUBLE : proc2Dmem_size;
	assign proc2mem_data = proc2Dmem_data;
	assign Imem2proc_response = (proc2Dmem_command == BUS_NONE) ? mem2proc_response : 0;
	
	assign need_stall = (rob_full > 0) | (rs_full < 2'b11) | (brat_full > 0) | (lsq_full > 0);

	/* this is the instruction cache */
	cache icache(
		.clock(clock), .reset(reset),
		.wr1_en(Icache_wr_en),
		.wr1_idx(Icache_wr_idx), 
		.rd1_idx(Icache_rd_idx),
		.wr1_tag(Icache_wr_tag),
		.rd1_tag(Icahce_rd_tag),
		.wr1_data(mem2proc_data),
		.rd1_data(Icache_rd_data),
		.rd1_valid(Icache_rd_valid)
	);

	/* the instruction cache controller */
	icache icache_0(
		.clock(clock), .reset(reset),
		.Imem2proc_response(Imem2proc_response),
		.Imem2proc_data(mem2proc_data),
		.Imem2proc_tag(mem2proc_tag),
		.proc2Icache_addr(proc2Icache_addr), 
		.cachemem_data(Icache_rd_data),
		.cachemem_valid(Icache_rd_valid),
		// outputs
		.proc2Imem_command(proc2Imem_command),
		.proc2Imem_addr(proc2Imem_addr),
		.Icache_data_out(Icache_data_out),
		.Icache_valid_out(Icache_valid_out),
		.current_index(Icache_rd_idx),
		.current_tag(Icahce_rd_tag),
		.last_index(Icache_wr_idx),
    	.last_tag(Icache_wr_tag),
    	.data_write_enable(Icache_wr_en)
	);

//////////////////////////////////////////////////
//                                              //
//                  IF-Stage                    //
//                                              //
//////////////////////////////////////////////////

	//these are debug signals that are now included in the packet,
	//breaking them out to support the legacy debug modes
	assign if_NPC_out1        = if_packet.NPC;
	assign if_IR_out1         = if_packet.inst;
	assign if_valid_inst_out1 = if_packet.valid;
	assign if_NPC_out2		  = if_packet2.NPC;
	assign if_IR_out2	      = if_packet2.inst;
	assign if_valid_inst_out2 = if_packet2.valid;
	
	if_stage if_stage_0(
		// Inputs
		.clock (clock),
		.reset (reset),
		.stall(need_stall),
		.mispredict(mispredict),
		.ex_mem_take_branch(taken_branch),
		.ex_mem_target_pc(true_branch_target),  
		.Imem2proc_data(Icache_data_out),
		.Icache_valid(Icache_valid_out),
		.retire_pkt_1(retire_pkt_1),
		.retire_pkt_2(retire_pkt_2),
		// Outputs
		.proc2Imem_addr(proc2Icache_addr),
		.if_packet_out1(if_packet),
		.if_packet_out2(if_packet2)
	);


//////////////////////////////////////////////////
//                                              //
//            IF/ID Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	assign if_id_NPC1        = if_id_packet.NPC;
	assign if_id_IR1         = if_id_packet.inst;
	assign if_id_valid_inst1 = if_id_packet.valid;
	assign if_id_NPC2		 = if_id_packet2.NPC;
	assign if_id_IR2		 = if_id_packet2.inst;
	assign if_id_valid_inst2 = if_id_packet2.valid;

	assign if_id_enable = !need_stall; 
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		// $display("need_stall? reset? %9h %9h", need_stall, reset);
		if (reset | mispredict | halt_when_st) begin 
			if_id_packet.inst	<= `SD `NOP;
			if_id_packet.valid	<= `SD `FALSE;
            if_id_packet.NPC	<= `SD 0;
            if_id_packet.PC		<= `SD 0;
			if_id_packet2.inst	<= `SD `NOP;
			if_id_packet2.valid	<= `SD `FALSE;
			if_id_packet2.NPC	<= `SD 0;
			if_id_packet2.PC	<= `SD 0;
		end else begin// if (reset)
			if (if_id_enable) begin
				if_id_packet 	<= `SD if_packet; 
				if_id_packet2	<= `SD if_packet2;
			end // if (if_id_enable)
			else begin
				// stall, keep the current value
				if_id_packet 	<= `SD if_id_packet;
				if_id_packet2	<= `SD if_id_packet2;
			end
		end
		// $display("need_stall? reset? %9h %9h", need_stall, reset);
		if (retire_pkt_1.retire_valid) begin
			// $display("a valid packet1 retire! at time %d", $time);
		end
		if (retire_pkt_2.retire_valid) begin
			// $display("a valid packet2 retire! at time %d", $time);
		end
	end // always

   
//////////////////////////////////////////////////
//                                              //
//                  ID-Stage                    //
//                                              //
//////////////////////////////////////////////////
	
	id_stage id_stage_0 (// Inputs
		.clock(clock),
		.reset(reset),
		.if_id_packet1_in(if_id_packet),
		.if_id_packet2_in(if_id_packet2),
		
		// Outputs
		.id_packet1_out(id_packet),
		.id_packet2_out(id_packet2)
	);



//////////////////////////////////////////////////
//                                              //
//        ID/Dispatch Pipeline Register     	//
//                                              //
//////////////////////////////////////////////////

	assign id_ex_NPC1       	= id_dispatch_packet.NPC;
	assign id_ex_NPC2 			= id_dispatch_packet2.NPC;
	assign id_ex_IR1        	= id_dispatch_packet.inst;
	assign id_ex_IR2			= id_dispatch_packet2.inst;
	assign id_ex_valid_inst1	= id_dispatch_packet.valid;
	assign id_ex_valid_inst2	= id_dispatch_packet2.valid;

	assign id_ex_enable = 1'b1; // always enabled

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset | need_stall | mispredict | halt_when_st_next) begin
			id_dispatch_packet <= `SD '{
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
				1'b0, //pred_taken,
				{`BRAT_SIZE{1'b0}}, //brat_vec
				{`ROB_LEN{1'b0}}
			}; 
			id_dispatch_packet2 <= `SD '{
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
			}; 
		end 
		else begin // if (reset)
			if (id_ex_enable) begin
				id_dispatch_packet <= `SD id_packet;
				id_dispatch_packet2 <= `SD id_packet2;
			end // if	
		end // else: !if(reset)
		// $display("id_dispatch_packet valid :%9d", id_dispatch_packet.valid);
		// $display("id_dispatch_packet inst :%9h", id_dispatch_packet.inst);
		// $display("id_dispatch_packet source1 reg :%9d", id_dispatch_packet.inst.r.rs1);
		// $display("id_dispatch_packet source2 reg :%9d", id_dispatch_packet.inst.r.rs2);
		// $display("id_dispatch_packet dest reg :%9d", id_dispatch_packet.dest_reg_idx);
		// $display("id_dispatch_packet2 valid :%9d", id_dispatch_packet2.valid);
		// $display("id_dispatch_packet2 inst :%9h", id_dispatch_packet2.inst);
		// $display("id_dispatch_packet2 source1 reg :%9d", id_dispatch_packet2.inst.r.rs1);
		// $display("id_dispatch_packet2 source2 reg :%9d", id_dispatch_packet2.inst.r.rs2);
		// $display("id_dispatch_packet2 dest reg :%9d", id_dispatch_packet2.dest_reg_idx);
		// $display("rat11 rat12 rat21 rat22 value: %d %d %d %d",rat11_value,rat12_value,rat21_value,rat22_value);
		// $display("alu out rob num: %d %d %d",alu1_pkt.rob_num,alu2_pkt.rob_num,$time);
		// show_lsq(lq_valid, lq_dest_addr, lq_dest_regs, lq_addr_valid, lq_need_mem, lq_need_store, lq_done,
		// 		lq_brat_vec, lq_rob_nums, lq_age, lq_value, lq_tags, lq_issued, lq_full, sq_head, sq_tail, sq_valid, sq_dest_addr, sq_value, sq_addr_done,
		// 		sq_done, sq_brat_vec, sq_full, sq_rob_nums, map_lsq_num, map_valid,sq_mem_size, $time);
		
		// $display("rat21, rat22 valid :%9d%9d", rat21_valid, rat22_valid);
		// show_brat(brat_copy_enable, brat_arr_out, b_freelist_out, brat_full, brat_out, brat_sequence_out, brat_valid_out, $time, 
		//id_dispatch_packet.valid, id_dispatch_packet2.valid, brat_in_use1, brat_in_use2, brat_freelist_out);
	end // always

//////////////////////////////////////////////////
//                                              //
//             	Dispatch-Stage                  //
//                                              //
//////////////////////////////////////////////////

	/* Only request for phy regs if dest arch reg is not zero_reg */
	assign request_phy_reg1 = id_dispatch_packet.valid & (id_dispatch_packet.dest_reg_idx != `ZERO_REG);
	assign request_phy_reg2 = id_dispatch_packet2.valid & (id_dispatch_packet2.dest_reg_idx != `ZERO_REG);

	// initiate a freelist
	freelist free_list(
		.clock(clock), .reset(reset),
		.request1(request_phy_reg1), 		// request a free phy reg if ID/Dispatch stage has a valid packet
		.request2(request_phy_reg2),		// request a free phy reg if ID/Dispatch stage has a valid packet
		// retire packet from ROB
		.retire_pkt_1(retire_pkt_1), .retire_pkt_2(retire_pkt_2), 
		.mispredictSet(mispredict),
		.listIn(b_freelist_out), 		
		.success1(free_preg1_valid), .success2(free_preg2_valid),
		.regNum1_out(free_preg1), .regNum2_out(free_preg2),
		.listOut(listOut),
		.listOut1(brat_listOut1), .listOut2(brat_listOut2)
	);

	rat register_alias_table(
		.clock(clock), .reset(reset),
		.valid1_in(id_dispatch_packet.valid), .valid2_in(id_dispatch_packet2.valid),
		// source operands from instruction1
		.reg11_in(id_dispatch_packet.rs1_reg), .reg12_in(id_dispatch_packet.rs2_reg),
		// source operands from instruction2				
		.reg21_in(id_dispatch_packet2.rs1_reg), .reg22_in(id_dispatch_packet2.rs2_reg),							
		.dest_reg1_in(id_dispatch_packet.dest_reg_idx), 		// dest arch reg1
		.dest_reg2_in(id_dispatch_packet2.dest_reg_idx),		// dest arch reg2
		.regNum1(free_preg1), .regNum2(free_preg2),			// dest phy regs (from free list)
		.success1(free_preg1_valid), .success2(free_preg2_valid),
		.brat_en(brat_copy_enable), 	// indicate if mispredict, need from brat !!!
		.brat_arr_in(brat_arr_out),
		/* translation of the rat is valid for inst1, inst2 */
		.rat1_valid(rat_inst1_valid), .rat2_valid(rat_inst2_valid),	
		// the corresponding phy regs
		.rat11_reg(rat_inst1_reg1), .rat12_reg(rat_inst1_reg2), 
		.rat21_reg(rat_inst2_reg1), .rat22_reg(rat_inst2_reg2),	
		.rat_out1(rat_out1), .rat_out2(rat_out2),	
		.rat_arr_out(rat_arr_out),
		/* The evicted physical registers */
		.ar1_out(ar1_out), .ar2_out(ar2_out),
		.pr1_out(pr1_out), .pr2_out(pr2_out),
		.pr1_valid(pr1_valid), .pr2_valid(pr2_valid)
	);

	brat branch_rat(
		.clock(clock), .reset(reset),
		.valid1_in(id_dispatch_packet.valid), .valid2_in(id_dispatch_packet2.valid),
		.fu1_in(id_dispatch_packet.cond_branch | id_dispatch_packet.uncond_branch), 
		.fu2_in(id_dispatch_packet2.cond_branch | id_dispatch_packet2.uncond_branch),
		.rat_arr_in1(rat_out1), .rat_arr_in2(rat_out2),
		.freelist_in1(brat_listOut1), .freelist_in2(brat_listOut2),
		/* inputs from rob */
    	.mispred1(mispred_out1), .mispred2(mispred_out2),
    	// cdb send brat sequence for retire
    	.cdb1_en(cdb1_valid), .cdb2_en(cdb2_valid),
		.cdb1_is_branch(cdb1_is_branch), .cdb2_is_branch(cdb2_is_branch),
		.cdb1_vector(cdb1_brat_vec), .cdb2_vector(cdb2_brat_vec),
		.retire_pkt_1(retire_pkt_1), .retire_pkt_2(retire_pkt_2),
		/* outputs */
		// output to indicate which brat in use
		// remains unchanged if dispatched inst is not branch
		.brat_in_use1(brat_in_use1), .brat_in_use2(brat_in_use2),
		// output to rat to recover from mispred
		.brat_en(brat_copy_enable),
		.brat_arr_out(brat_arr_out),
		.b_freelist_out(b_freelist_out),    
		.full(brat_full),
    	// output to rs when squash and when correctly pred
    	// same cycle
    	.brat_mis(brat_mis),
    	.correct_index1(correct_index1), .correct_index2(correct_index2),
		.c_valid1_out(correct_idx1_valid), .c_valid2_out(correct_idx2_valid),
    	// might need whole brat as output
    	.brat_out(brat_out),
		.brat_freelist_out(brat_freelist_out),
		.brat_sequence_out(brat_sequence_out),
		.brat_valid_out(brat_valid_out)
	);

	// if cdb broadcast a taken branch, 
	assign cdb1_prf_data = cdb1_branch_rst ? retire_packet[cdb_head_out].NPC : cdb1_data;
	assign cdb2_prf_data = cdb2_branch_rst ? retire_packet[cdb_head_plus1_out].NPC : cdb2_data;
	prf physical_register_file(
		.clock(clock), .reset(reset),
		.rat1_valid(rat_inst1_valid), .rat2_valid(rat_inst2_valid),
		.rat11_reg(rat_inst1_reg1), .rat12_reg(rat_inst1_reg2), 
		.rat21_reg(rat_inst2_reg1), .rat22_reg(rat_inst2_reg2),
		.success1(free_preg1_valid), .success2(free_preg2_valid),
		.regNum1(free_preg1), .regNum2(free_preg2), 		// phy reg number from free list
		.cdb1_valid(cdb1_valid), .cdb2_valid(cdb2_valid),
		.cdb1_reg(cdb1_phy_reg), .cdb2_reg(cdb2_phy_reg),
		.cdb1_value(cdb1_prf_data), .cdb2_value(cdb2_prf_data),
		.retire_pkt_1(retire_pkt_1), .retire_pkt_2(retire_pkt_2),
		.mispredict(mispredict),
		.listIn(b_freelist_out),				
		// tell the RS if the read value was valid
		.rat11_valid(rat11_valid), .rat12_valid(rat12_valid), 
		.rat21_valid(rat21_valid), .rat22_valid(rat22_valid), 
		.rat11_value(rat11_value), .rat12_value(rat12_value), 
		.rat21_value(rat21_value), .rat22_value(rat22_value),
		.registerFile(registerFile),
		.validOut(validOut)
	);

	// initiate a rob instance
	rob reorder_buffer(
		.clock(clock), .reset(reset),
		.valid1_in(id_dispatch_packet.valid & !halt_when_st_next), 
		.valid2_in(id_dispatch_packet2.valid & !halt_when_st_next),
		.arch_reg1_in(id_dispatch_packet.dest_reg_idx), 
		.arch_reg2_in(id_dispatch_packet2.dest_reg_idx),
		.phy_reg1_in(free_preg1), .phy_reg2_in(free_preg2),
		.pc1_in(id_dispatch_packet.PC), .pc2_in(id_dispatch_packet2.PC),
		.decode_pkt_1_in(id_dispatch_packet), .decode_pkt_2_in(id_dispatch_packet2),
		// predict taken signal for two insts
		.pred_taken1_in(id_dispatch_packet.pred_taken), 
		.pred_taken2_in(id_dispatch_packet2.pred_taken),	
		.pr1_evict(pr1_out), .pr2_evict(pr2_out),
		.pr1_valid(pr1_valid), .pr2_valid(pr2_valid),							
		.cdb1_valid_in(cdb1_valid), .cdb2_valid_in(cdb2_valid),
		.cdb1_tag_in(cdb1_tag), .cdb2_tag_in(cdb2_tag),
		.cdb1_branch_rst_in(cdb1_branch_rst), .cdb2_branch_rst_in(cdb2_branch_rst),
		.mshr_full(mshr_full),
		.mispred_out1(mispred_out1), .mispred_out2(mispred_out2),
		.full(rob_full),
		.tail_out(tail_out), .tail_plus1_out(tail_plus1_out), .head_out(head_out), .head_plus1_out(head_plus1_out),
		.retire_pkt_1(retire_pkt_1), .retire_pkt_2(retire_pkt_2),
		.rob_arr_out(rob_arr_out),
		.cdb1_data(cdb1_data), .cdb2_data(cdb2_data)
	);

	lsq load_store_queue(
		.clock(clock), .reset(reset),
		.mshr_full(mshr_full),
		.halt_when_st(halt_when_st_next | halt_when_st),
		.id_dispatch_packet1(id_dispatch_packet), 
		.id_dispatch_packet2(id_dispatch_packet2),
		.brat_vec1(brat_in_use1), .brat_vec2(brat_in_use2),
		.dest_phy_reg1(free_preg1), .dest_phy_reg2(free_preg2),
		.rob_tail(tail_out), .rob_tail_plus1(tail_plus1_out),
		.rob_head(head_out), .rob_head_plus1(head_plus1_out),
		.retire1_valid(retire_pkt_1.retire_valid & !retire_pkt_1.decoded_packet.halt),
		.dcache2lsq_valid(dcache2lsq_valid),
		.mshr_tail(mshr_tail),
		.dcache2lsq_data(dcache2lsq_data),
		.retire_pkt_valid(retire_pkt_valid),
		.mshr_head(mshr_head),				// directly port from memory
		.retire_pkt(mshr_retire_pkt),			// directly port from memory 64-bit to 32 bit ? 
		.brat_en(brat_copy_enable), 
		.c_valid1(correct_idx1_valid), .c_valid2(correct_idx2_valid),
		.brat_mis(brat_mis), 
		.correct_index1(correct_index1), .correct_index2(correct_index2),
		.cdb1_valid(cdb1_valid), 
		.cdb2_valid(cdb2_valid),
		.cdb1_ld_addr_valid(retire_packet[cdb_head_out].lsq_valid),
		.cdb2_ld_addr_valid(retire_packet[cdb_head_plus1_out].lsq_valid),
		.cdb1_tag(cdb1_tag), .cdb2_tag(cdb2_tag),
		.cdb1_data(cdb1_data), .cdb2_data(cdb2_data),
		.cdb1_pkt(retire_packet[cdb_head_out]), 
		.cdb2_pkt(retire_packet[cdb_head_plus1_out]), 											
		.ld_commit_pkt1(ld_commit_pkt1), .ld_commit_pkt2(ld_commit_pkt2),
		.lsq2mem_command(lsq2mem_command),
		.lsq2mem_addr(lsq2mem_addr),
		.lsq2mem_data(lsq2mem_data),
		.lsq2mem_wr_size(lsq2mem_wr_size),
		.full(lsq_full),
		.sq_empty(sq_empty),
		// debug output
		.lq_valid(lq_valid),.lq_dest_addr(lq_dest_addr),
		.lq_dest_regs(lq_dest_regs),.lq_addr_valid(lq_addr_valid),
		.lq_need_mem(lq_need_mem),.lq_need_store(lq_need_store),
		.lq_done(lq_done),.lq_brat_vec(lq_brat_vec),.lq_rob_nums(lq_rob_nums),
		.lq_age(lq_age),.lq_value(lq_value), .lq_issued(lq_issued),
		.lq_full(lq_full),
		.lq_tags(lq_tags),
		.sq_head(sq_head),.sq_tail(sq_tail),
		.sq_valid(sq_valid),.sq_dest_addr(sq_dest_addr),
		.sq_value(sq_value),.sq_addr_done(sq_addr_done),
		.sq_done(sq_done),.sq_brat_vec(sq_brat_vec),
		.sq_full(sq_full),.sq_rob_nums(sq_rob_nums),
		.map_lsq_num(map_lsq_num), .map_valid(map_valid),
		.sq_mem_size(sq_mem_size)
	);

	/* Indicate that a mispredict happends */
	assign mispredict = mispred_out1 | mispred_out2;

	// need to specify which mispredict to take if two happens simutaneously

	// instantiate reservation station here
	rs reservation_station(
		.clock(clock), .reset(reset),
		.id_ex_packet_in1(id_dispatch_packet), .id_ex_packet_in2(id_dispatch_packet2),
		.valid1_in(id_dispatch_packet.valid), .valid2_in(id_dispatch_packet2.valid),
		.pc1_in(id_dispatch_packet.PC), .pc2_in(id_dispatch_packet2.PC),
		.mul_free1(mult_done1), .mul_free2(mult_done2),
		.cdb1_valid_in(cdb1_valid), .cdb2_valid_in(cdb2_valid),
		.cdb1_tag_in(cdb1_phy_reg), .cdb2_tag_in(cdb2_phy_reg),
		.cdb1_value(cdb1_data), .cdb2_value(cdb2_data),
		.rat11_valid(rat11_valid), .rat12_valid(rat12_valid),
		.rat21_valid(rat21_valid), .rat22_valid(rat22_valid),
		.rat11_value(rat11_value), .rat12_value(rat12_value), 
		.rat21_value(rat21_value), .rat22_value(rat22_value),
		.regNum1(free_preg1), .regNum2(free_preg2),
		.correct_index1(correct_index1), .correct_index2(correct_index2),
		.brat_mis(brat_mis),
		.brat_in_use1(brat_in_use1), .brat_in_use2(brat_in_use2),
		.rob_tail(tail_out), .rob_tail_plus1(tail_plus1_out),
		.issue_packet1(issue_packet1), .issue_packet2(issue_packet2),
		.full(rs_full),
		.rs_arr_out(rs_arr_out),
		.rs_empty_idx1(rs_empty_idx1), .rs_empty_idx2(rs_empty_idx2),
		.c_valid1(correct_idx1_valid), .c_valid2(correct_idx2_valid),
		.brat_en(brat_copy_enable)
	);

//////////////////////////////////////////////////
//                                              //
//             	Issue/EX-Stage                  //
//                                              //
//////////////////////////////////////////////////
	assign is_ex_NPC1 = is_ex_packet.NPC;
	assign is_ex_NPC2 = is_ex_packet2.NPC;
	assign is_ex_IR1 = is_ex_packet.inst;
	assign is_ex_IR2 = is_ex_packet2.inst;
	assign is_ex_valid_inst1 = is_ex_packet.valid;
	assign is_ex_valid_inst2 = is_ex_packet2.valid;

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			is_ex_packet	<= `SD 0;
			is_ex_packet2	<= `SD 0;
		end else begin
			// if (is_ex_packet.valid) begin
			// 	$display("issue a valid pkt1! %d at time %d", is_ex_packet.valid, $time);
			// 	$display("issue pkt1 rob_num %d", is_ex_packet.rob_num);
			// end else if (is_ex_packet2.valid) begin
			// 	$display("issue a valid pkt2! %d at time %d", is_ex_packet2.valid, $time);
			// 	$display("issue pkt2 rob_num %d", is_ex_packet2.rob_num);
			// end
			if (issue_packet1.valid) begin
				// $display("issue packet1 brat vec from is/ex reg :%b",issue_packet1.brat_vec);
				is_ex_packet	<= `SD issue_packet1;
			end else
				is_ex_packet	<= `SD 0;
			if (issue_packet2.valid) begin
				// $display("issue packet2 brat vec from is/ex reg :%b",issue_packet2.brat_vec);
				is_ex_packet2	<= `SD issue_packet2;
			end else begin
				is_ex_packet2	<= `SD 0;
			end		
		end

		$display("time: %d", $time);
		$display("MSHR head %d, send:%d, tail %d", mshr_head, mshr_send, mshr_tail);
		for (int i=0;i<`MSHRSIZE;i++) begin
			$display("addr: %h data: %h done:%b valid:%b typ:%b send_wait: %d mem_tag: %d",
			mshr_arr_out[i].addr,mshr_arr_out[i].data,mshr_arr_out[i].done,mshr_arr_out[i].valid,mshr_arr_out[i].typ
			, mshr_arr_out[i].send_wait, mshr_arr_out[i].mem_tag);
		end
	end



//////////////////////////////////////////////////
//                                              //
//                  EX-Stage                    //
//                                              //
//////////////////////////////////////////////////

	ex_stage ex_stage_0 (
		.clock(clock), .reset(reset),
		.brat_idx_1(is_ex_packet.brat_vec), .brat_idx_2(is_ex_packet2.brat_vec),
		.issue_pkt_in_1(is_ex_packet), .issue_pkt_in_2(is_ex_packet2),
		.issue_valid_1(is_ex_packet.valid), .issue_valid_2(is_ex_packet2.valid),
		.brat_mis(brat_mis),
		.brat_mis_valid(brat_copy_enable),
		.c_index1_valid(correct_idx1_valid), .c_index2_valid(correct_idx2_valid),
		.c_index1(correct_index1), .c_index2(correct_index2),
		.ex_packet_out_1_non_mul(alu1_pkt), .ex_packet_out_1_mul(mult1_pkt), 
		.ex_packet_out_2_non_mul(alu2_pkt), .ex_packet_out_2_mul(mult2_pkt),
		.mul_will_done_1(mult_will_done1), .mul_will_done_2(mult_will_done2),
		.mul_done_1(mult_done1), .mul_done_2(mult_done2)
	);

	

	// instantiate cdb here
	cdb cdb_instance(
		.clock(clock), .reset(reset),
		.alu1_pkt(alu1_pkt), .alu2_pkt(alu2_pkt),
		.mult1_pkt(mult1_pkt), .mult2_pkt(mult2_pkt),
		.mispredict(mispredict),
		.brat_mis(brat_mis),
		.correct_index1(correct_index1), .correct_index2(correct_index2),
		.index1_valid(correct_idx1_valid), .index2_valid(correct_idx2_valid),
		.ld_commit_pkt1(ld_commit_pkt1), .ld_commit_pkt2(ld_commit_pkt2),
		
		.cdb1_valid(cdb1_valid), .cdb2_valid(cdb2_valid),
		.cdb1_tag(cdb1_tag), .cdb2_tag(cdb2_tag),
		.cdb1_phy_reg(cdb1_phy_reg), .cdb2_phy_reg(cdb2_phy_reg),
		.cdb1_branch_rst(cdb1_branch_rst), .cdb2_branch_rst(cdb2_branch_rst),
		.cdb1_is_branch(cdb1_is_branch), .cdb2_is_branch(cdb2_is_branch),
		.cdb1_data(cdb1_data), .cdb2_data(cdb2_data),
		.cdb1_brat_vec(cdb1_brat_vec), .cdb2_brat_vec(cdb2_brat_vec),
		.retire_packet(retire_packet),
		.head_out(cdb_head_out), .tail_out(cdb_tail_out), .head_plus1_out(cdb_head_plus1_out)
	);

	dcache data_cache(
		.clock(clock), .reset(reset),
		.Dmem2proc_response(mem2proc_response),
		.Dmem2proc_data(mem2proc_data),
		.Dmem2proc_tag(mem2proc_tag),
		.proc2dcache_addr(lsq2mem_addr),
		.proc2dcache_data(lsq2mem_data),
		.proc2Dcache_command(lsq2mem_command),
		.wr_size(lsq2mem_wr_size),
		// Outputs
		.proc2Dmem_command(proc2Dmem_command),
		.proc2Dmem_addr(proc2Dmem_addr),
		.proc2Dmem_data(proc2Dmem_data),
		.dcache_data_out(dcache2lsq_data),
		.dcache_valid_out(dcache2lsq_valid),
		.mshr_head(mshr_head), .mshr_send(mshr_send), .mshr_tail(mshr_tail),
		.retire_pkt_valid(retire_pkt_valid),
		.retire_pkt(mshr_retire_pkt),
		.mshr_arr_out(mshr_arr_out),
		.mshr_empty(mshr_empty),
		.mshr_full(mshr_full)
	);

	// TODO: need to tell if stage which branch to take if both of them take (This is not correct!)
	assign taken_branch	= (cdb1_is_branch & cdb1_branch_rst) | (cdb2_is_branch & cdb2_branch_rst);

	// calculate the correct address if branch mispredict
	always_comb begin
		if (cdb1_is_branch && cdb2_is_branch) begin
			if (mispred_out1 && mispred_out2) begin
				// if both branch mispredict, we take the one with lower brat vector
				if (cdb1_brat_vec < cdb2_brat_vec) begin
					true_branch_target = cdb1_branch_rst ? cdb1_data : retire_packet[cdb_head_out].NPC;
				end else begin
					true_branch_target = cdb2_branch_rst ? cdb2_data : retire_packet[cdb_head_plus1_out].NPC;
				end
			end else if (mispred_out1) begin
				true_branch_target = cdb1_branch_rst ? cdb1_data : retire_packet[cdb_head_out].NPC;
			end else if (mispred_out2) begin
				true_branch_target = cdb2_branch_rst ? cdb2_data : retire_packet[cdb_head_plus1_out].NPC;
			end else begin
				true_branch_target = 0;
			end
		end else if (cdb1_is_branch) begin
			if (mispred_out1) begin
				true_branch_target = cdb1_branch_rst ? cdb1_data : retire_packet[cdb_head_out].NPC;
			end 
		end else if (cdb2_is_branch) begin
			if (mispred_out2) begin
				true_branch_target = cdb2_branch_rst ? cdb2_data : retire_packet[cdb_head_plus1_out].NPC;
			end
		end else begin
			true_branch_target = 0;
		end
	end



endmodule  // module verisimple
`endif // __PIPELINE_V__


