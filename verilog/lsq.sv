/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  lsq.sv                                              //
//                                                                     //
//  Description :  Load Store Queue                                    //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __LSQ_SV__
`define __LSQ_SV__

`timescale 1ns/100ps

module lsq(
		input	clock, reset,
        // Inputs from DISPATCH
		input ID_EX_PACKET	id_dispatch_packet1, id_dispatch_packet2,
		input [`BRAT_SIZE-1:0] brat_vec1, brat_vec2,
		input [`PR_LEN-1:0] dest_phy_reg1, dest_phy_reg2,
        input [`ROB_LEN-1:0] rob_tail, rob_tail_plus1,
		input [`ROB_LEN-1:0] rob_head, rob_head_plus1,
		input retire1_valid, 
		input halt_when_st,
        
        // Inputs from DCACHE
        input dcache2lsq_valid,						// determine if cache hit
        input [`MSHRLEN-1:0] mshr_tail,				// mshr_tail, the position in MSHR
        input [`XLEN-1:0] dcache2lsq_data, 

		// Inputs from Dcache, containing the value for previous loads
		input retire_pkt_valid,					// mshr retire packet valid
        input [`MSHRLEN-1:0] mshr_head,					// mshr_head, 
		input MSHR_ENTRY_PACKET retire_pkt, 	// data is in the MSHR_ENTRY_PACKET
		input mshr_full,						// indicate mshr is full

        // Inputs from BRAT to squash and shift
		input brat_en, c_valid1, c_valid2,
		input [`BRAT_SIZE-1:0] brat_mis,
		input [`BRAT_LEN-1:0] correct_index1, correct_index2,
		

        // Inputs from CDB to update address and stored value
        input cdb1_valid, cdb2_valid,
		input cdb1_ld_addr_valid, cdb2_ld_addr_valid,
        input [`ROB_LEN-1:0] cdb1_tag, cdb2_tag,
        input [`XLEN-1:0] cdb1_data, cdb2_data, // contain the address of the L/S
        input CDB_RETIRE_PACKET cdb1_pkt, cdb2_pkt, // might contain the store values 

        // Outputs to CDB to broadcast loaded data
		output EX_PACKET	ld_commit_pkt1, ld_commit_pkt2,	
        
		// Outputs to DCACHE/MEMORY
		output [1:0]	lsq2mem_command,
		output [`XLEN-1:0] lsq2mem_addr,
		output [`XLEN-1:0] lsq2mem_data, 		// this is store data
		output [1:0]	   lsq2mem_wr_size,
		

		// Ouput of full follows the same rule from ROB
		output 				sq_empty,
        output [1:0]        full

		`ifdef DEBUG_LSQ
		,output lq_valid,
		output lq_dest_addr,
		output lq_dest_regs,
		output lq_addr_valid,
		output lq_need_mem,
		output lq_need_store,
		output lq_done,
		output lq_brat_vec,
		output lq_rob_nums,
		output lq_age,
		output lq_value,
		output lq_issued,
		output lq_full,
		output lq_tags,
		output sq_head,
		output sq_tail,
		output sq_valid,
		output sq_dest_addr,
		output sq_value,
		output sq_addr_done,
		output sq_done,
		output sq_brat_vec,
		output sq_full,
		output sq_rob_nums,
		output map_lsq_num,
		output map_valid,
		output sq_mem_size
		`endif
);
	
	//LQ ENTRY
	logic [`LSQ_SIZE-1:0]						lq_valid, lq_valid_next;
	logic [`LSQ_SIZE-1:0][`XLEN-1:0]			lq_dest_addr, lq_dest_addr_next;
	logic [`LSQ_SIZE-1:0][`PR_LEN-1:0]			lq_dest_regs, lq_dest_regs_next;
	logic [`LSQ_SIZE-1:0]						lq_addr_valid, lq_addr_valid_next;
	logic [`LSQ_SIZE-1:0]						lq_need_mem, lq_need_mem_next;
	logic [`LSQ_SIZE-1:0]						lq_need_store, lq_need_store_next;
	logic [`LSQ_SIZE-1:0]						lq_done, lq_done_next;
	logic [`LSQ_SIZE-1:0][`BRAT_SIZE-1:0]		lq_brat_vec, lq_brat_vec_next;
	logic [`LSQ_SIZE-1:0][`ROB_LEN-1:0]			lq_rob_nums, lq_rob_nums_next;
	logic [`LSQ_SIZE-1:0][`LSQ_LEN-1:0]			lq_age, lq_age_next;
	logic [`LSQ_SIZE-1:0][`XLEN-1:0]			lq_value, lq_value_next;
	logic [`LSQ_SIZE-1:0][3:0]					lq_tags, lq_tags_next;
	logic [`LSQ_SIZE-1:0]						lq_issued, lq_issued_next;
	logic [`LSQ_SIZE-1:0][2:0]					lq_mem_size, lq_mem_size_next;
	logic [1:0]									lq_full;

	// LQ selection (dispatch/issue) logic
	logic [`LSQ_SIZE-1:0]						lq_empty_slots, lq_issue_slots;
	wire  [`LSQ_SIZE-1:0]						lq_empty_gnt, lq_issue_gnt;
	wire  [2*`LSQ_SIZE-1:0]						lq_empty_gnt_bus;
	wire  [`LSQ_SIZE-1:0]						lq_issue_gnt_bus;
	wire  										lq_empty_none, lq_issue_none;
	logic [`LSQ_LEN-1:0]						lq_empty_idx1, lq_empty_idx2;
	logic [`LSQ_LEN-1:0]						lq_issue_idx;
	logic [`LSQ_LEN:0]							lq_cnt; // count the empty slots
	logic										lq_issue_valid; // indicates a valid issue of load

	// LQ commit (broadcast) logic
	wire [`LSQ_SIZE-1:0]						lq_commit_gnt;
	wire [2*`LSQ_SIZE-1:0]						lq_commit_gnt_bus;
	wire 										lq_done_empty;
	logic [`LSQ_LEN-1:0]						lq_commit_idx1, lq_commit_idx2;
	
	
	//SQ ENTRY
	logic [`LSQ_LEN-1:0]						sq_head, sq_head_nxt;
	logic [`LSQ_LEN-1:0]						sq_tail, sq_tail_nxt, sq_tail_nxt_plus1, halt_tail;
	logic [`LSQ_SIZE-1:0]						sq_valid, sq_valid_nxt;
	logic [`LSQ_SIZE-1:0][`XLEN-1:0]			sq_dest_addr, sq_dest_addr_nxt;
	logic [`LSQ_SIZE-1:0][`XLEN-1:0]			sq_value, sq_value_nxt;
	logic [`LSQ_SIZE-1:0]						sq_addr_done, sq_addr_done_nxt;
	logic [`LSQ_SIZE-1:0]						sq_done, sq_done_nxt;
	logic [`LSQ_SIZE-1:0][`BRAT_SIZE-1:0]		sq_brat_vec, sq_brat_vec_nxt;
	logic [1:0]									sq_full;
	logic [`LSQ_SIZE-1:0][`ROB_LEN-1:0]			sq_rob_nums, sq_rob_nums_nxt;
	logic [`LSQ_SIZE-1:0][2:0]					sq_mem_size, sq_mem_size_next;	
	logic [`LSQ_LEN-1:0]						sq_tail_plus1, sq_tail_plus2, sq_mispred_tail;
	logic [`LSQ_LEN-1:0]						sq_head_plus1, sq_head_plus2;
	logic [`LSQ_LEN-1:0] 						sq_total_test_num, sq_completed_num;
	
	// SQ selection logic
	// Might need to make it 2-way
	logic										sq_issue_valid;  // indicate a store can issue

	// Map table to link mem_tags with load instructions
	logic [15:0][`LSQ_LEN-1:0]					map_lsq_num, map_lsq_num_next;
	logic [15:0]								map_valid, map_valid_next;


	always_comb begin
	    lq_cnt = 0;
    	for (int i=0; i<`LSQ_SIZE; i++) begin
            lq_empty_slots[i] = !(lq_valid[i]);
	        lq_cnt += !(lq_valid[i]);
    	end
		if (id_dispatch_packet1.valid & id_dispatch_packet1.rd_mem) begin
			lq_cnt--;
		end
		if (id_dispatch_packet2.valid & id_dispatch_packet2.rd_mem) begin
			lq_cnt--;
		end
	end
	
	// lq_need_mem iff comparisons finished and no match
	// loads can be issued if need_mem & not done & not issued
	assign lq_issue_slots = lq_valid & lq_need_mem & lq_addr_valid & (~lq_need_store) & (~lq_done) & (~lq_issued);
	
	
	assign lq_full = (lq_cnt >= 2) ? 2'b00 : 
					 (lq_cnt > 0)  ? 2'b01 : 2'b10;
	// TODO: Could make it the same as rob full, for now keep it simple
	assign sq_full = sq_valid[sq_tail_nxt]			? 2'b10 :
					 sq_valid[sq_tail_nxt_plus1] 	? 2'b01 : 2'b00;

	// select the next two empty lq entry
	psel_gen #(.REQS(2), .WIDTH(`LSQ_SIZE)) lq_empty_sel(
		lq_empty_slots,
		lq_empty_gnt,
		lq_empty_gnt_bus,
		lq_empty_none
	);

	pe #(.OUT_WIDTH(`LSQ_LEN)) lq_empty_enc1(
		lq_empty_gnt_bus[`LSQ_SIZE-1:0],
		lq_empty_idx1
	);

	pe #(.OUT_WIDTH(`LSQ_LEN)) lq_empty_enc2(
		lq_empty_gnt_bus[2*`LSQ_SIZE-1:`LSQ_SIZE],
		lq_empty_idx2
	);

	psel_gen #(.REQS(1), .WIDTH(`LSQ_SIZE)) lq_issue_sel(
		lq_issue_slots,
		lq_issue_gnt,
		lq_issue_gnt_bus,
		lq_issue_none
	);

	pe #(.OUT_WIDTH(`LSQ_LEN)) lq_issue_enc(
		lq_issue_gnt_bus,
		lq_issue_idx
	);

	// need selection logic to determine loads to cdb broadcast
	psel_gen #(.REQS(2), .WIDTH(`LSQ_SIZE)) lq_commit_sel(
		lq_done,
		lq_commit_gnt,
		lq_commit_gnt_bus,
		lq_done_empty
	);

	pe #(.OUT_WIDTH(`LSQ_LEN)) lq_commit_enc1(
		lq_commit_gnt_bus[`LSQ_SIZE-1:0],
		lq_commit_idx1
	);

	pe #(.OUT_WIDTH(`LSQ_LEN)) lq_commit_enc2(
		lq_commit_gnt_bus[2*`LSQ_SIZE-1:`LSQ_SIZE],
		lq_commit_idx2
	);



	// When mispredict in the same cycle, need to check brat_vec of commit pkt
	// format the output ex packet (containing the load results)
	assign ld_commit_pkt1.valid			= (lq_commit_gnt_bus[`LSQ_SIZE-1:0] > 0) 
										& ((!brat_en) | (brat_en & (lq_brat_vec[lq_commit_idx1] <= brat_mis)));
	assign ld_commit_pkt2.valid			= (lq_commit_gnt_bus[2*`LSQ_SIZE-1:`LSQ_SIZE] > 0)
										& ((!brat_en) | (brat_en & (lq_brat_vec[lq_commit_idx2] <= brat_mis)));
	assign ld_commit_pkt1.brat_vec 		= lq_brat_vec[lq_commit_idx1];
	assign ld_commit_pkt2.brat_vec 		= lq_brat_vec[lq_commit_idx2];
	assign ld_commit_pkt1.dest_phy_reg 	= lq_dest_regs[lq_commit_idx1];
	assign ld_commit_pkt2.dest_phy_reg 	= lq_dest_regs[lq_commit_idx2];
	assign ld_commit_pkt1.rob_num		= lq_rob_nums[lq_commit_idx1];
	assign ld_commit_pkt2.rob_num		= lq_rob_nums[lq_commit_idx2];

	// assign ld results
	always_comb begin
		if (~lq_mem_size[lq_commit_idx1][2]) begin //is this an signed/unsigned load?
			if (lq_mem_size[lq_commit_idx1][1:0] == 2'b0) begin
				if (lq_dest_addr[lq_commit_idx1][1:0] == 2'b0) begin
					ld_commit_pkt1.result = {{(`XLEN-8){lq_value[lq_commit_idx1][7]}}, lq_value[lq_commit_idx1][7:0]};
				end else if (lq_dest_addr[lq_commit_idx1][1:0] == 2'b01) begin
					ld_commit_pkt1.result = {{(`XLEN-8){lq_value[lq_commit_idx1][15]}}, lq_value[lq_commit_idx1][15:8]};
				end else if (lq_dest_addr[lq_commit_idx1][1:0] == 2'b10) begin
					ld_commit_pkt1.result = {{(`XLEN-8){lq_value[lq_commit_idx1][23]}}, lq_value[lq_commit_idx1][23:16]};
				end else begin
					ld_commit_pkt1.result = {{(`XLEN-8){lq_value[lq_commit_idx1][31]}}, lq_value[lq_commit_idx1][31:24]};
				end
			end
			else if  (lq_mem_size[lq_commit_idx1][1:0] == 2'b01) begin
				if (!lq_dest_addr[lq_commit_idx1][1]) begin
					ld_commit_pkt1.result = {{(`XLEN-16){lq_value[lq_commit_idx1][15]}}, lq_value[lq_commit_idx1][15:0]};
				end else begin
					ld_commit_pkt1.result = {{(`XLEN-16){lq_value[lq_commit_idx1][31]}}, lq_value[lq_commit_idx1][31:16]};
				end
			end else
				ld_commit_pkt1.result = lq_value[lq_commit_idx1];
		end else begin
			if (lq_mem_size[lq_commit_idx1][1:0] == 2'b0) begin
				if (lq_dest_addr[lq_commit_idx1][1:0] == 2'b0) begin
					ld_commit_pkt1.result = {{(`XLEN-8){1'b0}}, lq_value[lq_commit_idx1][7:0]};
				end else if (lq_dest_addr[lq_commit_idx1][1:0] == 2'b01) begin
					ld_commit_pkt1.result = {{(`XLEN-8){1'b0}}, lq_value[lq_commit_idx1][15:8]};
				end else if (lq_dest_addr[lq_commit_idx1][1:0] == 2'b10) begin
					ld_commit_pkt1.result = {{(`XLEN-8){1'b0}}, lq_value[lq_commit_idx1][23:16]};
				end else begin
					ld_commit_pkt1.result = {{(`XLEN-8){1'b0}}, lq_value[lq_commit_idx1][31:24]};
				end				
			end
			else if  (lq_mem_size[lq_commit_idx1][1:0] == 2'b01) begin
				if (!lq_dest_addr[lq_commit_idx1][1]) begin
					ld_commit_pkt1.result = {{(`XLEN-16){1'b0}}, lq_value[lq_commit_idx1][15:0]};
				end else begin
					ld_commit_pkt1.result = {{(`XLEN-16){1'b0}}, lq_value[lq_commit_idx1][31:16]};
				end
			end
			else ld_commit_pkt1.result = lq_value[lq_commit_idx1];
		end
		if (~lq_mem_size[lq_commit_idx2][2]) begin //is this an signed/unsigned load?
			if (lq_mem_size[lq_commit_idx2][1:0] == 2'b0) begin
				if (lq_dest_addr[lq_commit_idx2][1:0] == 2'b0) begin
					ld_commit_pkt2.result = {{(`XLEN-8){lq_value[lq_commit_idx2][7]}}, lq_value[lq_commit_idx2][7:0]};
				end else if (lq_dest_addr[lq_commit_idx2][1:0] == 2'b01) begin
					ld_commit_pkt2.result = {{(`XLEN-8){lq_value[lq_commit_idx2][15]}}, lq_value[lq_commit_idx2][15:8]};
				end else if (lq_dest_addr[lq_commit_idx2][1:0] == 2'b10) begin
					ld_commit_pkt2.result = {{(`XLEN-8){lq_value[lq_commit_idx2][23]}}, lq_value[lq_commit_idx2][23:16]};
				end else begin
					ld_commit_pkt2.result = {{(`XLEN-8){lq_value[lq_commit_idx2][31]}}, lq_value[lq_commit_idx2][31:24]};
				end
			end
			else if  (lq_mem_size[lq_commit_idx2][1:0] == 2'b01) begin
				if (!lq_dest_addr[lq_commit_idx2][1]) begin
					ld_commit_pkt2.result = {{(`XLEN-16){lq_value[lq_commit_idx2][15]}}, lq_value[lq_commit_idx2][15:0]};
				end else begin
					ld_commit_pkt2.result = {{(`XLEN-16){lq_value[lq_commit_idx2][31]}}, lq_value[lq_commit_idx2][31:16]};
				end
			end else
				ld_commit_pkt2.result = lq_value[lq_commit_idx2];
		end else begin
			if (lq_mem_size[lq_commit_idx2][1:0] == 2'b0) begin
				if (lq_dest_addr[lq_commit_idx2][1:0] == 2'b0) begin
					ld_commit_pkt2.result = {{(`XLEN-8){1'b0}}, lq_value[lq_commit_idx2][7:0]};
				end else if (lq_dest_addr[lq_commit_idx2][1:0] == 2'b01) begin
					ld_commit_pkt2.result = {{(`XLEN-8){1'b0}}, lq_value[lq_commit_idx2][15:8]};
				end else if (lq_dest_addr[lq_commit_idx2][1:0] == 2'b10) begin
					ld_commit_pkt2.result = {{(`XLEN-8){1'b0}}, lq_value[lq_commit_idx2][23:16]};
				end else begin
					ld_commit_pkt2.result = {{(`XLEN-8){1'b0}}, lq_value[lq_commit_idx2][31:24]};
				end				
			end
			else if  (lq_mem_size[lq_commit_idx2][1:0] == 2'b01) begin
				if (!lq_dest_addr[lq_commit_idx2][1]) begin
					ld_commit_pkt2.result = {{(`XLEN-16){1'b0}}, lq_value[lq_commit_idx2][15:0]};
				end else begin
					ld_commit_pkt2.result = {{(`XLEN-16){1'b0}}, lq_value[lq_commit_idx2][31:16]};
				end
			end
			else ld_commit_pkt2.result = lq_value[lq_commit_idx2];
		end		
	end

	/* we don't care about these fileds since it's a ld inst */
	assign ld_commit_pkt1.rd_mem		= 1;
	assign ld_commit_pkt2.rd_mem		= 1;
	assign ld_commit_pkt1.wr_mem		= 0;
	assign ld_commit_pkt2.wr_mem		= 0;
	assign ld_commit_pkt1.take_branch	= 0;
	assign ld_commit_pkt1.cond_branch	= 0;
	assign ld_commit_pkt1.uncond_branch = 0;
	assign ld_commit_pkt1.halt			= 0;
	assign ld_commit_pkt1.illegal		= 0;
	assign ld_commit_pkt1.csr_op		= 0;
	assign ld_commit_pkt1.NPC			= 0; // this is because the rob already has the correct NPC, here it is not used
	assign ld_commit_pkt2.take_branch	= 0;
	assign ld_commit_pkt2.cond_branch	= 0;
	assign ld_commit_pkt2.uncond_branch = 0;
	assign ld_commit_pkt2.halt			= 0;
	assign ld_commit_pkt2.illegal		= 0;
	assign ld_commit_pkt2.csr_op		= 0;
	assign ld_commit_pkt2.NPC			= 0; // this is because the rob already has the correct NPC, here it is not used
	


	assign lq_issue_valid = (lq_issue_gnt_bus > 0) & !mshr_full
							& ((!brat_en) | (brat_en & (lq_brat_vec[lq_issue_idx] <= brat_mis)));
	// we can only issue a store if it's gonna retire 
	assign sq_issue_valid = (sq_addr_done[sq_head] & ((rob_head == sq_rob_nums[sq_head]) | 
							((rob_head_plus1 == sq_rob_nums[sq_head]) & retire1_valid))) & !mshr_full;
	
	assign lsq2mem_command = sq_issue_valid ? BUS_STORE	: 
							 lq_issue_valid ? BUS_LOAD	: BUS_NONE;
	assign lsq2mem_addr = sq_issue_valid ? sq_dest_addr[sq_head]		:
						  lq_issue_valid ? lq_dest_addr[lq_issue_idx]	: 0;
	assign lsq2mem_data = sq_issue_valid ? sq_value[sq_head] : 0;
	assign lsq2mem_wr_size = sq_issue_valid ? sq_mem_size[sq_head][1:0] : 0;

	
	assign sq_head_plus1 = (sq_head == (`LSQ_SIZE-1)) ? 0 : (sq_head+1);

	assign sq_tail_plus1 = (sq_tail == (`LSQ_SIZE-1)) ? 0 : (sq_tail+1);
	assign sq_tail_plus2 = (sq_tail_plus1 == (`LSQ_SIZE-1)) ? 0 : (sq_tail_plus1+1);
	// if two stores, tail+2, one store, tail+1
	assign sq_tail_nxt = halt_when_st ? halt_tail :
						brat_en ? sq_mispred_tail : (id_dispatch_packet1.wr_mem & id_dispatch_packet1.valid 
						& id_dispatch_packet2.wr_mem & id_dispatch_packet2.valid) ? sq_tail_plus2 :
						((id_dispatch_packet1.wr_mem & id_dispatch_packet1.valid)
						| (id_dispatch_packet2.wr_mem & id_dispatch_packet2.valid)) ? sq_tail_plus1 : sq_tail;
	assign sq_tail_nxt_plus1 = (sq_tail_nxt == (`LSQ_SIZE-1)) ? 0 : (sq_tail_nxt+1);
																					
	assign sq_head_nxt = sq_issue_valid ? sq_head_plus1 : sq_head;
	assign sq_empty = (sq_head==sq_tail) & !sq_valid[sq_head];
	assign full = (lq_full > sq_full) ? lq_full : sq_full;
	
	always_comb begin
		lq_valid_next = lq_valid;
		lq_dest_addr_next = lq_dest_addr;
		lq_dest_regs_next = lq_dest_regs;
		lq_addr_valid_next = lq_addr_valid;
		lq_need_mem_next = lq_need_mem;
		lq_need_store_next = lq_need_store;
		lq_done_next = lq_done;
		lq_brat_vec_next = lq_brat_vec;
		lq_rob_nums_next = lq_rob_nums;
		lq_value_next = lq_value;
		lq_age_next = lq_age;
		sq_valid_nxt = sq_valid;
		sq_dest_addr_nxt =  sq_dest_addr;
		sq_addr_done_nxt = sq_addr_done;
		sq_brat_vec_nxt = sq_brat_vec;
		sq_done_nxt = sq_done;
		sq_value_nxt = sq_value;
		sq_rob_nums_nxt = sq_rob_nums;
		map_lsq_num_next = map_lsq_num;
		map_valid_next = map_valid;
		lq_tags_next = lq_tags;
		lq_issued_next = lq_issued;
		lq_mem_size_next = lq_mem_size;
		sq_mem_size_next = sq_mem_size;
		// CDB broadcast address for LOAD STORE and value for STORE
		if (cdb1_valid) begin
			for (int i=0; i<`LSQ_SIZE; i++) begin
				if (sq_valid[i] && sq_rob_nums[i] == cdb1_tag) begin
					sq_dest_addr_nxt[i] = cdb1_data;
					sq_addr_done_nxt[i] = 1;
					sq_done_nxt[i] = 1;
					if (sq_mem_size[i][1:0] == 2'b00) begin
						// store byte
						case (sq_dest_addr_nxt[i][1:0])
							2'b00: sq_value_nxt[i][7:0] = cdb1_pkt.rs2_value[7:0];
							2'b01: sq_value_nxt[i][15:8] = cdb1_pkt.rs2_value[7:0];
							2'b10: sq_value_nxt[i][23:16] = cdb1_pkt.rs2_value[7:0];
							2'b11: sq_value_nxt[i][31:24] = cdb1_pkt.rs2_value[7:0];
							default: sq_value_nxt[i][7:0] = cdb1_pkt.rs2_value[7:0];
						endcase
					end else if (sq_mem_size[i][1:0] == 2'b01) begin
						// store half
						case (sq_dest_addr_nxt[i][1])
							1'b0: sq_value_nxt[i][15:0] = cdb1_pkt.rs2_value[15:0];
							1'b1: sq_value_nxt[i][31:16] = cdb1_pkt.rs2_value[15:0];
							default: sq_value_nxt[i][15:0] = cdb1_pkt.rs2_value[15:0];
						endcase
					end else begin
						// store word
						sq_value_nxt[i] = cdb1_pkt.rs2_value;
					end
					break;
				end
			end
		end
		if (cdb1_ld_addr_valid) begin
			for (int i=0; i<`LSQ_SIZE; i++) begin
				if (lq_valid[i] && lq_rob_nums[i] == cdb1_tag) begin
					lq_dest_addr_next[i] = cdb1_data;
					lq_addr_valid_next[i] = 1;
					// whether we need this break can be tested
					break;
				end
			end	
		end
		if (cdb2_valid) begin
			for (int i=0; i<`LSQ_SIZE; i++) begin
				if (sq_valid[i] && sq_rob_nums[i] == cdb2_tag) begin
					sq_dest_addr_nxt[i] = cdb2_data;
					sq_addr_done_nxt[i] = 1;
					sq_done_nxt[i] = 1;
					if (sq_mem_size[i][1:0] == 2'b00) begin
						// store byte
						case (sq_dest_addr_nxt[i][1:0])
							2'b00: sq_value_nxt[i][7:0] = cdb2_pkt.rs2_value[7:0];
							2'b01: sq_value_nxt[i][15:8] = cdb2_pkt.rs2_value[7:0];
							2'b10: sq_value_nxt[i][23:16] = cdb2_pkt.rs2_value[7:0];
							2'b11: sq_value_nxt[i][31:24] = cdb2_pkt.rs2_value[7:0];
							default: sq_value_nxt[i][7:0] = cdb2_pkt.rs2_value[7:0];
						endcase
					end else if (sq_mem_size[i][1:0] == 2'b01) begin
						// store half
						case (sq_dest_addr_nxt[i][1])
							1'b0: sq_value_nxt[i][15:0] = cdb2_pkt.rs2_value[15:0];
							1'b1: sq_value_nxt[i][31:16] = cdb2_pkt.rs2_value[15:0];
							default: sq_value_nxt[i][15:0] = cdb2_pkt.rs2_value[15:0];
						endcase
					end else begin
						// store word
						sq_value_nxt[i] = cdb2_pkt.rs2_value;
					end
					break;
				end
			end
		end
		if (cdb2_ld_addr_valid) begin
			for (int i=0; i<`LSQ_SIZE; i++) begin
				if (lq_valid[i] && lq_rob_nums[i] == cdb2_tag) begin
					lq_dest_addr_next[i] = cdb2_data;
					lq_addr_valid_next[i] = 1;
					break;
				end
			end
		end
		// if issuing a load this cycle, make issue valid for next cycle
		if (lq_issue_valid && !sq_issue_valid)
			lq_issued_next[lq_issue_idx] = 1;
		// Response from DCACHE dcache2lsq_valid indicates cache hit
		if (dcache2lsq_valid && (lq_issue_valid && !sq_issue_valid)) begin
			// DCACHE hit
			lq_value_next[lq_issue_idx] = dcache2lsq_data;
			lq_done_next[lq_issue_idx] = 1;
		end
		else if ((!dcache2lsq_valid) && (lq_issue_valid && !sq_issue_valid)) begin
			// DCACHE miss
			map_valid_next[mshr_tail] = 1;
			map_lsq_num_next[mshr_tail] = lq_issue_idx;
			lq_tags_next[lq_issue_idx] = mshr_tail;
		end
		if (retire_pkt_valid && !retire_pkt.typ && map_valid[mshr_head]) begin
			// MEM response for missed DCACHE request
			// data in retire packet has 64 bits, need to check which part to take
			if (lq_addr_valid_next[map_lsq_num[mshr_head]] && lq_dest_addr_next[map_lsq_num[mshr_head]][2])
				lq_value_next[map_lsq_num[mshr_head]] = retire_pkt.data[63:32];
			else if (lq_addr_valid_next[map_lsq_num[mshr_head]] && !lq_dest_addr_next[map_lsq_num[mshr_head]][2])
				lq_value_next[map_lsq_num[mshr_head]] = retire_pkt.data[31:0];
			// lq_value_next[map_lsq_num[mshr_head]] = retire_pkt.data;
			lq_done_next[map_lsq_num[mshr_head]] = 1;
			map_valid_next[mshr_head] = 0;
		end
		// Squash mispredicted inst(s)
		if (brat_en) begin
			sq_mispred_tail = sq_head;
			for (int i=0; i<`LSQ_SIZE; i++) begin
				if (lq_valid[i] && lq_brat_vec[i] > brat_mis) begin
					lq_valid_next[i] = 0;
					if (lq_issued[i]) // only clear the map valid of issued but squashed loads
						map_valid_next[lq_tags_next[i]] = 0;
				end
				if (sq_head + i >= `LSQ_SIZE) begin
					if (sq_valid[sq_head+i-`LSQ_SIZE] && (sq_brat_vec[sq_head+i-`LSQ_SIZE] <= brat_mis)) begin
						sq_mispred_tail = sq_head + i + 1 - `LSQ_SIZE;
					end
				end else begin
					if (sq_valid[sq_head+i] && (sq_brat_vec[sq_head+i] <= brat_mis)) begin
						sq_mispred_tail = sq_head + i + 1;
					end
				end
				if (sq_valid[i] && sq_brat_vec[i] > brat_mis) begin
					sq_valid_nxt[i] = 0;
					sq_addr_done_nxt[i] = 0;
					sq_done_nxt[i] = 0;
				end
			end
			// $display("@lsq: mispredict lsq at %d, brat_mis: %d, sq_next_tail: %d", $time, brat_mis, sq_mispred_tail);
		end
		// Update brat_vec for correctly predicted branches
		if (c_valid1) begin
			// if (brat_en) begin
			// 	$display("correct prediction while mispredict! idx: %d", correct_index1);
			// end
            for (int i=0; i< `LSQ_SIZE; i++) begin
                if (lq_valid[i] && lq_brat_vec[i][correct_index1]) begin
                    lq_brat_vec_next[i] = lq_brat_vec[i] - (1<<correct_index1) + (lq_brat_vec[i] & ((1<<correct_index1)-1'b1));
                    if (c_valid2 && lq_brat_vec_next[i][correct_index2])
                        lq_brat_vec_next[i] = lq_brat_vec_next[i] - (1<<correct_index2) + (lq_brat_vec_next[i] & ((1<<correct_index2)-1'b1));
                end
				if (sq_valid[i] && sq_brat_vec[i][correct_index1]) begin
                    sq_brat_vec_nxt[i] = sq_brat_vec[i] - (1<<correct_index1) + (sq_brat_vec[i] & ((1<<correct_index1)-1'b1));
                    if (c_valid2 && sq_brat_vec_nxt[i][correct_index2])
                        sq_brat_vec_nxt[i] = sq_brat_vec_nxt[i] - (1<<correct_index2) + (sq_brat_vec_nxt[i] & ((1<<correct_index2)-1'b1));
                end
            end
        end
        else if (c_valid2) begin
            for (int i=0; i< `LSQ_SIZE; i++) begin
                if (lq_valid[i] && lq_brat_vec[i][correct_index2]) begin
                    lq_brat_vec_next[i] = lq_brat_vec[i]- (1<<correct_index2) + (lq_brat_vec[i] & ((1<<correct_index2)-1'b1));
                end
				if (sq_valid[i] && sq_brat_vec[i][correct_index2]) begin
                    sq_brat_vec_nxt[i] = sq_brat_vec[i]- (1<<correct_index2) + (sq_brat_vec[i] & ((1<<correct_index2)-1'b1));
                end
            end
        end

		// Dispatch
		// Add new inst(s) only when no misprediction
		if (!brat_en) begin
			if (id_dispatch_packet1.valid) begin
				if (id_dispatch_packet1.rd_mem) begin
					lq_valid_next[lq_empty_idx1] = 1;
					lq_dest_addr_next[lq_empty_idx1] = 0;
					lq_dest_regs_next[lq_empty_idx1] = dest_phy_reg1;
					lq_addr_valid_next[lq_empty_idx1] = 0;
					lq_need_mem_next[lq_empty_idx1] = 0;
					lq_need_store_next[lq_empty_idx1] = 0;
					lq_done_next[lq_empty_idx1] = 0;
					lq_brat_vec_next[lq_empty_idx1] = brat_vec1;
					lq_rob_nums_next[lq_empty_idx1] = rob_tail;
					lq_age_next[lq_empty_idx1] = sq_tail;
					lq_value_next[lq_empty_idx1] = 0;
					lq_tags_next[lq_empty_idx1] = 0;
					lq_issued_next[lq_empty_idx1] = 0;
					lq_mem_size_next[lq_empty_idx1] = id_dispatch_packet1.inst.r.funct3;
				end
				else if (id_dispatch_packet1.wr_mem) begin
					sq_dest_addr_nxt[sq_tail] = 0;
					sq_valid_nxt[sq_tail] = 1;
					sq_addr_done_nxt[sq_tail] = 0;
					sq_done_nxt[sq_tail] = 0;
					sq_brat_vec_nxt[sq_tail] = brat_vec1;
					sq_value_nxt[sq_tail] = 0;
					sq_rob_nums_nxt[sq_tail] = rob_tail;
					sq_mem_size_next[sq_tail] = id_dispatch_packet1.inst.r.funct3;
				end
			end
			if (id_dispatch_packet2.valid) begin
				if (id_dispatch_packet2.rd_mem) begin
					// $display("inst2 with rob_tail_plus1:%d, %d", rob_tail_plus1,  $time);
					lq_valid_next[lq_empty_idx2] = 1;
					lq_dest_addr_next[lq_empty_idx2] = 0;
					lq_dest_regs_next[lq_empty_idx2] = dest_phy_reg2;
					lq_addr_valid_next[lq_empty_idx2] = 0;
					lq_need_mem_next[lq_empty_idx2] = 0;
					lq_need_store_next[lq_empty_idx2] = 0;
					lq_done_next[lq_empty_idx2] = 0;
					lq_brat_vec_next[lq_empty_idx2] = brat_vec2;
					lq_rob_nums_next[lq_empty_idx2] = rob_tail_plus1;
					lq_value_next[lq_empty_idx2] = 0;
					lq_tags_next[lq_empty_idx2] = 0;
					lq_issued_next[lq_empty_idx2] = 0;
					lq_mem_size_next[lq_empty_idx2] = id_dispatch_packet2.inst.r.funct3;
					if (id_dispatch_packet1.valid && id_dispatch_packet1.wr_mem)
						lq_age_next[lq_empty_idx2] = sq_tail_plus1;
					else
						lq_age_next[lq_empty_idx2] = sq_tail;
				end
				else if (id_dispatch_packet2.wr_mem) begin
					// FIXED: if the first inst is also a store, put this one in tail+1, otherwise put on tail
					if (id_dispatch_packet1.wr_mem) begin
						sq_dest_addr_nxt[sq_tail_plus1] = 0;
						sq_valid_nxt[sq_tail_plus1] = 1;
						sq_addr_done_nxt[sq_tail_plus1] = 0;
						sq_done_nxt[sq_tail_plus1] = 0;
						sq_brat_vec_nxt[sq_tail_plus1] = brat_vec2;
						sq_value_nxt[sq_tail_plus1] = 0;
						sq_rob_nums_nxt[sq_tail_plus1] = rob_tail_plus1;
						sq_mem_size_next[sq_tail_plus1] = id_dispatch_packet2.inst.r.funct3;
					end 
					else begin
						sq_dest_addr_nxt[sq_tail] = 0;
						sq_valid_nxt[sq_tail] = 1;
						sq_addr_done_nxt[sq_tail] = 0;
						sq_done_nxt[sq_tail] = 0;
						sq_brat_vec_nxt[sq_tail] = brat_vec2;
						sq_value_nxt[sq_tail] = 0;
						sq_rob_nums_nxt[sq_tail] = rob_tail_plus1;
						sq_mem_size_next[sq_tail] = id_dispatch_packet2.inst.r.funct3;
					end
				end
			end
		end
		
		
		// Check dependencies for each LOAD inst
		// Find out the number of calculated store addresses until hitting the first unresolved address
		sq_completed_num = 0;
		for (int i=0; i<`LSQ_SIZE; i++) begin
			if (((sq_head+i) < `LSQ_SIZE) & sq_valid_nxt[sq_head+i] & sq_addr_done_nxt[sq_head+i])
				sq_completed_num += 1;
			else if (((sq_head+i) >= `LSQ_SIZE) & sq_valid_nxt[sq_head+i-`LSQ_SIZE] & sq_addr_done_nxt[sq_head+i-`LSQ_SIZE]) begin
				sq_completed_num += 1;
			end
			else
				break;
		end
		// $display("sq head: %d, sq_tail:%d", sq_head, sq_tail);
		// $display("sq valid next: %b", sq_valid_nxt);
		// $display("sq completed num: %d, %d", sq_completed_num, $time);
		// For each load, first calculate the total number of comparing needed
		// If the number is larger than the sq_completed_num, it means there is not resolved but potentially matching address
		// Therefore the comparison will be useless, so, stop it.
		// If comparison is necessary, start from sq head and stop at sq_head + test_num.
		// Notice, addr and addr_done refer to next cycle since internal forwarding of same-cycle completed store is needed.
		// Valid refer to this cycle because retiring sq will be invalid but still need to compare.
		// lq_value is newly added to store value from sq. An alternative is to use lq_addr if data_size = addr_size
		for (int i=0; i<`LSQ_SIZE; i++) begin
			sq_total_test_num = 0;
			sq_total_test_num = (lq_age[i] > sq_head) ? (lq_age[i] - sq_head) : (`LSQ_SIZE - (sq_head - lq_age[i]));
			// FIXED: should only consider loads that their addr has resolved 
			if (lq_valid_next[i] && lq_addr_valid_next[i] && (sq_total_test_num <= sq_completed_num)) begin	
				// $display("total test num for lq idx: %d, %d, %d", i, sq_total_test_num, $time);
				for (int j=0; j<`LSQ_SIZE; j++) begin
					if (j<sq_total_test_num) begin
						// forwarding condition: sq valid, addr done, addr equal, size less or equal
						if ((sq_head+j < `LSQ_SIZE) && sq_valid_nxt[sq_head+j] && sq_addr_done_nxt[sq_head+j] && (lq_mem_size_next[i][1:0] <= sq_mem_size_next[sq_head+j][1:0])
							&& (sq_dest_addr_nxt[sq_head+j]==lq_dest_addr_next[i])) begin
							// $display("store to load forwarding happens at %d with addr %h and data %d", $time, lq_dest_addr_next[i], sq_value_nxt[sq_head+j]);
							lq_need_store_next[i] = 1;
							lq_value_next[i] = sq_value_nxt[sq_head+j];
							lq_done_next[i] = 1;
							lq_need_mem_next[i] = 0;
						end else if ((sq_head+j >= `LSQ_SIZE) && sq_valid_nxt[sq_head+j-`LSQ_SIZE] && sq_addr_done_nxt[sq_head+j-`LSQ_SIZE] 
							&& (lq_mem_size_next[i][1:0] <= sq_mem_size_next[sq_head+j-`LSQ_SIZE][1:0]) && (sq_dest_addr_nxt[sq_head+j-`LSQ_SIZE]==lq_dest_addr_next[i])) begin
							// $display("store to load forwarding happens at %d with addr %h and data %d", $time, lq_dest_addr_next[i], sq_value_nxt[sq_head+j]);
							lq_need_store_next[i] = 1;
							lq_value_next[i] = sq_value_nxt[sq_head+j-`LSQ_SIZE];
							lq_done_next[i] = 1;
							lq_need_mem_next[i] = 0;
						end
					end 
				end
				if (!lq_done_next[i]) begin
					lq_need_mem_next[i] = 1;
				end
			end
		end


		// Moved clear logic to the end, since there are load comparison logic that need to perform before invalidation
		// Clear issued inst(s)
		if (ld_commit_pkt1.valid) begin
			// we can not just clear the issued load because we have to wait for dcache & memory responses
			// we can clear the committed loads for sure, FIXED: need to invalidate all the control bits
			lq_valid_next[lq_commit_idx1] = 0;
			lq_addr_valid_next[lq_commit_idx1] = 0;
			lq_need_mem_next[lq_commit_idx1] = 0;
			lq_done_next[lq_commit_idx1] = 0;
		end
		if (ld_commit_pkt2.valid) begin
			lq_valid_next[lq_commit_idx2] = 0;
			lq_addr_valid_next[lq_commit_idx2] = 0;
			lq_need_mem_next[lq_commit_idx2] = 0;
			lq_done_next[lq_commit_idx2] = 0;
		end
		if (sq_issue_valid) begin
			sq_valid_nxt[sq_head] = 0;
			sq_done_nxt[sq_head] = 0;
			sq_addr_done_nxt[sq_head] = 0;
		end
		if (halt_when_st) begin
			sq_valid_nxt = 0;
			halt_tail = sq_head;
		end
	end

	// lq sequential logic
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			lq_valid		<= `SD 0;
			lq_dest_addr	<= `SD 0;
			lq_dest_regs    <= `SD 0;
			lq_addr_valid   <= `SD 0;
			lq_need_mem		<= `SD 0;
			lq_need_store	<= `SD 0;
			lq_done			<= `SD 0;
			lq_brat_vec		<= `SD 0;
			lq_rob_nums     <= `SD 0;
			lq_age          <= `SD 0;
			lq_value		<= `SD 0;
			lq_tags			<= `SD 0;
			lq_issued		<= `SD 0;
			map_lsq_num		<= `SD 0;
			map_valid		<= `SD 0;
			lq_mem_size		<= `SD 0;
		end
		else begin
			lq_valid 		<= `SD lq_valid_next;
			lq_dest_addr	<= `SD lq_dest_addr_next;
			lq_dest_regs	<= `SD lq_dest_regs_next;
			lq_addr_valid	<= `SD lq_addr_valid_next;
			lq_need_mem		<= `SD lq_need_mem_next;
			lq_need_store	<= `SD lq_need_store_next;
			lq_done			<= `SD lq_done_next;
			lq_brat_vec 	<= `SD lq_brat_vec_next;
			lq_rob_nums     <= `SD lq_rob_nums_next;
			lq_age			<= `SD lq_age_next;
			lq_value		<= `SD lq_value_next;
			lq_tags			<= `SD lq_tags_next;
			lq_issued		<= `SD lq_issued_next;
			map_lsq_num		<= `SD map_lsq_num_next;
			map_valid		<= `SD map_valid_next;
			lq_mem_size		<= `SD lq_mem_size_next;
		end
	end


	// SQ sequential logic
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		//$display("sq issue valid %b at rob head? %b at head+1? %b sqhead %d rob %d value %d valid %b", sq_issue_valid,(rob_head == sq_rob_nums[sq_head]),((rob_head_plus1 == sq_rob_nums[sq_head]) & retire1_valid),sq_head,sq_rob_nums[sq_head],sq_value[sq_head],sq_valid[sq_head]);
		//$monitor("head %d next head %d",sq_head,sq_head_nxt);
		if(reset) begin 
			sq_head			<= `SD 0;
			sq_tail			<= `SD 0;
			sq_dest_addr	<= `SD 0;
			sq_valid		<= `SD 0;
			sq_addr_done	<= `SD 0;
			sq_done			<= `SD 0;
			sq_brat_vec		<= `SD 0;
			sq_value		<= `SD 0;
			sq_rob_nums		<= `SD 0;
			sq_mem_size		<= `SD 0;
		end
		else begin
			sq_head			<= `SD sq_head_nxt;
			sq_tail			<= `SD sq_tail_nxt;
			sq_dest_addr	<= `SD sq_dest_addr_nxt;
			sq_valid		<= `SD sq_valid_nxt;
			sq_addr_done	<= `SD sq_addr_done_nxt;
			sq_done			<= `SD sq_done_nxt;
			sq_brat_vec		<= `SD sq_brat_vec_nxt;
			sq_value		<= `SD sq_value_nxt;
			sq_rob_nums		<= `SD sq_rob_nums_nxt;
			sq_mem_size		<= `SD sq_mem_size_next;
			// assert (sq_valid_nxt[sq_head_nxt] | (!sq_valid_nxt[sq_head_nxt] & (sq_head_nxt == sq_tail_nxt))) 
			// else   $finish;
		end
	end

endmodule
`endif