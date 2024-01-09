/////////////////////////////////////////////////////////////////////////
//                                                                     //
//  Modulename :  btb.sv                                               //
//                                                                     //
//  Description :  This module check the previous branch and make      // 
//                 prediction                                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////



module stateSelector(
		input clock, reset,
		input taken, enable,
		
		output state
);

	// 00,01,10,11
	// in, A, B,NA
    logic [1:0] state;
    logic [1:0] next_state;

    always_comb begin
		if(enable) begin 
		  case(state)
			2'b00: 
				if(taken)
					next_state = 2'b01;
				else 
					next_state = 2'b00;
			2'b01: 
				if(taken)
					next_state = 2'b10;
				else
					next_state = 2'b00;
			2'b10: 
				if(taken)
					next_state = 2'b11;
				else
					next_state = 2'b01;
			2'b11: 
				if(!taken)
					next_state = 2'b10;
				else 
					next_state = 2'b11;
			default:
				next_state = 2'b00;
		  endcase
		end else begin
			next_state = state;
		end
    end

	// synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
		if(reset)
			state <= `SD 0;
		else
			state <= `SD next_state;
    end
endmodule


// branch target buffer, for now it is a direct mapped cache
module btb(
	input					clock, reset,
	input [`XLEN-1:0]		rd_pc1,rd_pc2,
	input [`XLEN-1:0]		wr_pc1, wr_pc2,
	input					wr_valid1, wr_valid2,
	// next instructions' pc
	input [`XLEN-1:0]		wr_target1, wr_target2,

	output					rd_found1, rd_found2,
	output [`XLEN-1:0]		rd_target1, rd_target2 
);

	logic [`BTB_SIZE-1:0][`PC_LEN-1:0]				buffer;
	// tag size = 32 - `BTB_LEN - 2 (the last two bits are always 0)
	logic [`BTB_SIZE-1:0][(`XLEN-`BTB_LEN-3):0]		tags;
	logic [`BTB_SIZE-1:0]							valid;
	logic [`BTB_LEN-1:0] rd_idx1, rd_idx2;
	logic [(`XLEN-`BTB_LEN-3):0] rd_tag1, rd_tag2;
	logic [`BTB_LEN-1:0] wr_idx1, wr_idx2;
	logic [(`XLEN-`BTB_LEN-3):0] wr_tag1, wr_tag2;

	
	assign rd_idx1 = rd_pc1[(1+`BTB_LEN):2];
	assign rd_idx2 = rd_pc2[(1+`BTB_LEN):2];
	assign wr_idx1 = wr_pc1[(1+`BTB_LEN):2];
	assign wr_idx2 = wr_pc2[(1+`BTB_LEN):2];

	assign rd_tag1 = rd_pc1[`XLEN-1:(2+`BTB_LEN)];
	assign rd_tag2 = rd_pc2[`XLEN-1:(2+`BTB_LEN)];
	assign wr_tag1 = wr_pc1[`XLEN-1:(2+`BTB_LEN)];
	assign wr_tag2 = wr_pc2[`XLEN-1:(2+`BTB_LEN)];

	
	assign rd_found1 = valid[rd_idx1] & (tags[rd_idx1] == rd_tag1);
	assign rd_found2 = valid[rd_idx2] & (tags[rd_idx2] == rd_tag2);
	assign rd_target1 = buffer[rd_idx1];
	assign rd_target2 = buffer[rd_idx2];

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			buffer <= `SD 0;;
			valid  <= `SD 0;
		end
		else begin
			if(wr_valid1) begin
				buffer[wr_idx1] <= wr_target1;
				valid[wr_idx1] <= 1;
				tags[wr_idx1]	<= wr_tag1;
			end
			if(wr_valid2) begin
				buffer[wr_idx2] <= wr_target2;
				valid[wr_idx2] <= 1;
				tags[wr_idx2]  <= wr_tag2;
			end
		end
	end
endmodule

module predictor(
	input						clock, reset,
	input [`PC_LEN-1:0]			pc1, pc2,
	// updating the predicted address
	input ROB_RETIRE_PACKET		retire_pkt_1, retire_pkt_2,
	
	output						taken1,taken2,
	output [`XLEN-1:0]		location1,location2,
	output						predictor_states
);

	logic						found1, found2;	
	logic 						wr_btb1, wr_btb2;	
	logic [`BTB_SIZE-1:0]		state_t_in;
	logic [`BTB_SIZE-1:0]		state_wr_in;
	logic [`BTB_SIZE-1:0][1:0]	predictor_states;

	logic [`BTB_LEN-1:0] rd_idx1, rd_idx2;
	logic [`BTB_LEN-1:0] wr_idx1, wr_idx2;
	assign rd_idx1 = pc1[(1+`BTB_LEN):2];
	assign rd_idx2 = pc2[(1+`BTB_LEN):2];

	// taken is high if found in BTB and predictor predict taken
	assign taken1 = found1 & (predictor_states[rd_idx1] > 2'b01);
	assign taken2 = found2 & (predictor_states[rd_idx2] > 2'b01);

	assign wr_idx1 = retire_pkt_1.pc[(1+`BTB_LEN):2];
	assign wr_idx2 = retire_pkt_2.pc[(1+`BTB_LEN):2];

	
	// update the btb if teh retire packet is conditional branch and taken, or unconditional branch 
	// the next write to btb only proceeds if the first inst is not a taken branch
	assign wr_btb1 = (retire_pkt_1.decoded_packet.cond_branch & retire_pkt_1.branch_rst & retire_pkt_1.retire_valid);
					// | (retire_pkt_1.retire_valid & retire_pkt_1.decoded_packet.uncond_branch);
	assign wr_btb2 = (retire_pkt_2.decoded_packet.cond_branch & retire_pkt_2.branch_rst & retire_pkt_2.retire_valid);
					// | (retire_pkt_2.retire_valid & retire_pkt_2.decoded_packet.uncond_branch);

	// taken1, taken2 should be output of the btb
	btb b(
		.clock(clock), .reset(reset),
		.rd_pc1(pc1), .rd_pc2(pc2),
		.wr_pc1(retire_pkt_1.pc), .wr_pc2(retire_pkt_2.pc),
		.wr_valid1(wr_btb1), .wr_valid2(wr_btb2),
		.wr_target1(retire_pkt_1.decoded_packet.NPC), .wr_target2(retire_pkt_2.decoded_packet.NPC),
		.rd_found1(found1), .rd_found2(found2),
		.rd_target1(location1), .rd_target2(location2)
	);

	always_comb begin
		state_t_in = 0;
		state_t_in[wr_idx1] = wr_btb1;
		state_t_in[wr_idx2] = wr_btb2;
		state_wr_in = 0;
		// as long as the retired inst is a branch, update the predictor
		state_wr_in[wr_idx1] = (retire_pkt_1.decoded_packet.cond_branch & retire_pkt_1.retire_valid);
							// | (retire_pkt_1.retire_valid & retire_pkt_1.decoded_packet.uncond_branch);
		state_wr_in[wr_idx2] = (retire_pkt_2.decoded_packet.cond_branch & retire_pkt_2.retire_valid);
							// | (retire_pkt_2.retire_valid & retire_pkt_2.decoded_packet.uncond_branch);
	end
	


	stateSelector predictor [`BTB_SIZE-1:0] (
		.clock(clock), .reset(reset),
		.taken(state_t_in), .enable(state_wr_in),
		.state(predictor_states)
	);

endmodule