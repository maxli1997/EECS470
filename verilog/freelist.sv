/////////////////////////////////////////////////////////////////////////
//                                                                     //
//  Modulename :  freelist.sv                                          //
//                                                                     //
//  Description :  This module creates the physical register file and  // 
//                 store value in it.                                  //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __FREELIST_SV__
`define __FREELIST_SV__

`timescale 1ns/100ps


module freelist(
	input								clock, reset,
	input								request1,request2,
	input ROB_RETIRE_PACKET				retire_pkt_1, retire_pkt_2,
	input								mispredictSet,

	input [`PR_SIZE-1:0]				listIn,

	output	logic						success1,success2,
	output	logic [`PR_LEN-1:0]			regNum1_out,regNum2_out,
	output 	logic [`PR_SIZE-1:0]		listOut,
	// these are output to brat for backup
	output 	logic [`PR_SIZE-1:0]		listOut1, listOut2
);

	
	// counter must be larger than PR_LEN to hold the value
	logic [`PR_LEN:0]		freeCounter;
	logic [`PR_SIZE-1:0]	listNxt;

	logic [`PR_SIZE-1:0]	free_request;
	logic [`PR_SIZE-1:0]	free_gnt;
	logic [2*`PR_SIZE-1:0]	free_gnt_bus;
	logic					empty;
	logic [`PR_LEN-1:0]		regNum1, regNum2;

	
	assign free_request = ~listOut;
	
	psel_gen #(.REQS(2), .WIDTH(`PR_SIZE)) sel({free_request[`PR_SIZE-1:1], 1'b0}, free_gnt, free_gnt_bus, empty);
	pe #(.OUT_WIDTH(`PR_LEN)) encoder1(free_gnt_bus[2*`PR_SIZE-1:`PR_SIZE], regNum1);
	pe #(.OUT_WIDTH(`PR_LEN)) encoder2(free_gnt_bus[`PR_SIZE-1:0], regNum2);

	assign regNum1_out = request1 ? regNum1 : 0;
	assign regNum2_out = request2 ? regNum2 : 0;
	
	always_comb begin
		listNxt = listOut;
		listOut1 = listNxt;
		listOut2 = listNxt;
		if(mispredictSet) begin
			listNxt = listIn;
		end
		else begin
			freeCounter = 0;
			if(retire_pkt_1.retire_valid)
				listNxt[retire_pkt_1.prev_phy_reg] = 0;
			if(retire_pkt_2.retire_valid)
				listNxt[retire_pkt_2.prev_phy_reg] = 0;

			/* The request for first inst succeed if freecounter >= 1 and request1*/
			success1 = ((free_gnt >= 1) & request1);
			/* The request for second inst succeed if (freecounter >= 2 and request2) or (freecounter >= 1 and not request1)*/
			success2 = ((free_gnt >= 3) & request2) | ((free_gnt >= 1) & !request1);
			if(request1 & success1) begin 
				listNxt[regNum1] = 1;
			end
			/* whether listNxt get updated, listOut1 should be updated as well */
			listOut1 = listNxt;
			if(request2 & success2) begin 
				listNxt[regNum2] = 1;
			end
			/* whether listNxt get updated, listOut2 should be updated as well */
			listOut2 = listNxt;
		end
	end
	
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			listOut <= `SD 0;
		end
		else begin
			listOut <= listNxt;
		end
	end
	
endmodule
`endif