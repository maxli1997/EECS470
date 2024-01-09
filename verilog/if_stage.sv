/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  if_stage.v                                          //
//                                                                     //
//  Description :  instruction fetch (IF) stage of the pipeline;       // 
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module if_stage(
	input         	clock,                  // system clock
	input         	reset,                  // system reset
	input         	stall,      			// tell if to stall
	                                      // makes pipeline behave as single-cycle
	input			mispredict,					// indicate a mispredict happends
	input         	ex_mem_take_branch,      	// taken-branch signal from EX stage
	input  [`XLEN-1:0] ex_mem_target_pc,        // target pc: use if mispredict is TRUE
	input  [63:0] Imem2proc_data,          // Data coming back from instruction-memory
	input  			Icache_valid,
	input ROB_RETIRE_PACKET retire_pkt_1, retire_pkt_2,
	/* Modified here (two-way superscalar) */
	output logic [`XLEN-1:0] proc2Imem_addr,    // Address sent to Instruction memory
	output IF_ID_PACKET if_packet_out1,         	// Output data packet from IF going to ID, see sys_defs for signal information 
	output IF_ID_PACKET if_packet_out2			// Output data packet2 from IF going to ID

);


	logic    [`XLEN-1:0] PC_reg;             // PC we are currently fetching
	
	logic    [`XLEN-1:0] PC_plus_4;
	logic	 [`XLEN-1:0] PC_plus_8;
	logic    [`XLEN-1:0] next_PC;
	logic           	 PC_enable;
	logic			     pred_taken1, pred_taken2;
	logic	 [`XLEN-1:0] target_loc1, target_loc2;
	logic [`BTB_SIZE-1:0][1:0]	predictor_states;


	predictor bimodal(
		.clock(clock), .reset(reset),
		.pc1(PC_reg), .pc2(PC_plus_4),
		.retire_pkt_1(retire_pkt_1), .retire_pkt_2(retire_pkt_2),
		.taken1(pred_taken1), .taken2(pred_taken2),
		.location1(target_loc1), .location2(target_loc2),
		.predictor_states(predictor_states)
	);
	
	assign proc2Imem_addr = {PC_reg[`XLEN-1:3], 3'b0};
	
	// this mux is because the Imem gives us 64 bits not 32 bits
	assign if_packet_out1.inst = PC_reg[2] ? Imem2proc_data[63:32] : Imem2proc_data[31:0];
	assign if_packet_out2.inst = PC_reg[2] ? `NOP				   : Imem2proc_data[63:32];

	// default next PC value
	assign PC_plus_4 = PC_reg + 4;
	assign PC_plus_8 = PC_reg + 8;
	
	// next PC is target_pc if there is a taken branch or
	// the next sequential PC (PC+4) if no branch
	// (halting is handled with the enable PC_enable;
	// TODO: Update branch predictor info here, 
	assign next_PC = (mispredict) 	  		  ? ex_mem_target_pc :
						pred_taken1			  ? target_loc1 :
				(pred_taken2 & !PC_reg[2])	  ? target_loc2 :
		 				PC_reg[2] 			  ? PC_plus_4 : PC_plus_8;
	
	// The take-branch signal must override stalling (otherwise it may be lost)
	assign PC_enable = (!stall & Icache_valid) | mispredict;
	
	/* TODO: aplly branch predictor here? */
	// Pass PC+4 down pipeline w/instruction 
	assign if_packet_out1.NPC = PC_plus_4;
	assign if_packet_out1.PC  = PC_reg;
	assign if_packet_out2.NPC = PC_plus_8;
	assign if_packet_out2.PC  = PC_plus_4;
	assign if_packet_out1.valid = !stall & Icache_valid;
	assign if_packet_out2.valid = !stall & !PC_reg[2] & Icache_valid & !pred_taken1;

	// pass the predict info down to the pipeline
	assign if_packet_out1.pred_taken = pred_taken1;
	assign if_packet_out2.pred_taken = pred_taken2;

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		// if (pred_taken2) begin
		// 	$display("predict for pc: %d is taken, target addr %d!", PC_plus_4, target_loc2);
		// end
		// if (mispredict) begin
		// 	$display("mispredict at time %d， %d", $time, ex_mem_target_pc);
		// end
		// $display("current pc is: %d, next pc: %d at time %d", PC_reg, next_PC, $time);
		if(reset)
			PC_reg <= `SD 0;       // initial PC value is 0	
		else if(PC_enable)
			PC_reg <= `SD next_PC; // transition to next PC
		else
			PC_reg <= `SD PC_reg;
	end  // always
	
endmodule  // module if_stage
