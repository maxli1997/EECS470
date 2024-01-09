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

// add a freelist for brt

// regNum1,regNum2, success1, success2 become wire
module freelist(
	input						clock, reset,
	input						request1,request2,
	input ROB_RETIRE_PACKET		retire_pkt_1, retire_pkt_2,
	input						mispredictSet,

	input [`PR_SIZE-1:0]		listIn,

	output						success1,success2,
	output [`PR_LEN-1:0]		regNum1,regNum2,
	output [`PR_SIZE-1:0]		listOut,
	// these are output to brat for backup
	output [`PR_SIZE-1:0]		listOut1, listOut2
);

	
	// counter must be larger than PR_LEN to hold the value
	logic [`PR_LEN:0]		freeCounter;
	logic [`PR_SIZE-1:0]	listOut, listNxt, listOut1, listOut2;
	// can't be wire
	logic [`PR_LEN-1:0] 		regNum1, regNum2;
	logic 					success1, success2;
	
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
			regNum1 = 0;
			regNum2 = 0;
			for(int i = 1;i < `PR_SIZE;i++) begin
				if (listOut[i] == 1'b0) begin 
					freeCounter = freeCounter + 1;
					if(freeCounter == 1) begin 
						regNum1 = i;
						regNum2 = i;
					end
					else if(freeCounter == 2) begin
						regNum2 = i;
					end
				end
			end
			success1 = (freeCounter >= 1);
			success2 = (freeCounter >= 2);
			if(request1 & success1) begin 
				listNxt[regNum1] = 1;
				listOut1 = listNxt;
			end
			if(request2 & success2) begin 
				listNxt[regNum2] = 1;
				listOut2 = listNxt;
			end
		end
	end
	
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