/////////////////////////////////////////////////////////////////////////
//                                                                     //
//  Modulename :  prf.sv                                               //
//                                                                     //
//  Description :  This module creates the physical register file and  // 
//                 store value in it.                                  //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

// current problem, how to determine whether the prf is valid or not
// 


`ifndef __PRF_SV__
`define __PRF_SV__

`timescale 1ns/100ps

// have a freelist and mispredict, freelist valid 0 free 0
// freelist 
// cdb valid 1 change valid

module prf(
	input						clock, reset,
	input						rat1_valid, rat2_valid,
	input [`PR_LEN-1:0]			rat11_reg, rat12_reg, rat21_reg, rat22_reg,
	// valid bit of regNum
	input						success1,success2,
	input [`PR_LEN-1:0]			regNum1,regNum2,
	input						cdb1_valid, cdb2_valid,
	input [`PR_LEN-1:0]			cdb1_reg, cdb2_reg,
	input [`VALUE_SIZE-1:0]		cdb1_value, cdb2_value,
	input ROB_RETIRE_PACKET		retire_pkt_1, retire_pkt_2,
	// input [`PR_SIZE-1:0]		free_list,			// the current free_list
	// misprediction handling
	input						mispredict,
	// brat passes a listin
	input [`PR_SIZE-1:0]		listIn,
	
	output logic					rat11_valid, rat12_valid, rat21_valid, rat22_valid,
	output logic [`VALUE_SIZE-1:0]	rat11_value, rat12_value, rat21_value, rat22_value,
	output logic [`PR_SIZE-1:0][`VALUE_SIZE-1:0] registerFile,
	output [`PR_SIZE-1:0]			validOut
);




	logic [`PR_SIZE-1:0][`VALUE_SIZE-1:0] registerFileNxt;
	logic [`PR_SIZE-1:0]	validList, validListNxt;

	assign validOut = validList;
	always_comb begin
		validListNxt = validList;
		registerFileNxt = registerFile;
		if(mispredict) begin
			//$display("mispredict at %d, %b", $time, listIn[63]);
			// when a mispredict happens, the brat will pass the correct free list listIn
			// and at this point, the valid phy regs should be those are already valid
			// and are still in use from listIn, and should not write to the prfs if cdb
			// broadcast a not in use phy regs
			validListNxt = listIn & validList;
			if(listIn[cdb1_reg] & cdb1_valid & cdb1_reg != 0) begin
				registerFileNxt[cdb1_reg] = cdb1_value;
				validListNxt[cdb1_reg] = 1;
			end
			if(listIn[cdb2_reg] & cdb2_valid & cdb2_reg != 0) begin
				//$display("Still write cdb2_reg at %d, %d", $time, cdb2_reg);
				registerFileNxt[cdb2_reg] = cdb2_value;
				validListNxt[cdb2_reg] = 1;
			end
		end
		else begin
			if (success1) begin
				validListNxt[regNum1] = 0;
			end
			if (success2) begin
				validListNxt[regNum2] = 0;
			end
			if(cdb1_valid & cdb1_reg != 0) begin
				registerFileNxt[cdb1_reg] = cdb1_value;
				validListNxt[cdb1_reg] = 1;
			end
			if(cdb2_valid & cdb2_reg != 0) begin
				// $display("write at %d, %d", $time, cdb2_reg);
				registerFileNxt[cdb2_reg] = cdb2_value;
				validListNxt[cdb2_reg] = 1;
			end
			if(rat1_valid) begin
				if(validListNxt[rat11_reg]) begin
					rat11_value = registerFileNxt[rat11_reg];
					rat11_valid = 1'b1;
				end
				else if (rat11_reg == 0) begin
					rat11_value = 0;
					rat11_valid = 1'b1;
				end
				else begin
					rat11_value = rat11_reg;
					rat11_valid = 1'b0;
				end
			end else rat11_valid = 0;
			if(rat1_valid) begin
				if(validListNxt[rat12_reg]) begin
					rat12_value = registerFileNxt[rat12_reg];
					rat12_valid = 1'b1;
				end
				else if (rat12_reg == 0) begin
					rat12_value = 0;
					rat12_valid = 1'b1;
				end
				else begin
					rat12_value = rat12_reg;
					rat12_valid = 1'b0;
				end
			end else rat12_valid = 0;
			if(rat2_valid) begin
				if(validListNxt[rat21_reg]) begin
					rat21_value = registerFileNxt[rat21_reg];
					rat21_valid = 1'b1;
				end
				else if (rat21_reg == 0) begin
					rat21_value = 0;
					rat21_valid = 1'b1;
				end
				else begin
					rat21_value = rat21_reg;
					rat21_valid = 1'b0;
				end
			end else rat21_valid = 0;
			if(rat2_valid) begin
				if(validListNxt[rat22_reg]) begin
					rat22_value = registerFileNxt[rat22_reg];
					rat22_valid = 1'b1;
				end
				else if (rat22_reg == 0) begin
					rat22_value = 0;
					rat22_valid = 1'b1;
				end
				else begin
					rat22_value = rat22_reg;
					rat22_valid = 1'b0;
				end
			end else rat22_valid = 0;
		end
		if(retire_pkt_1.retire_valid) begin
			validListNxt[retire_pkt_1.prev_phy_reg] = 0;
		end
		if(retire_pkt_2.retire_valid) begin
			validListNxt[retire_pkt_2.prev_phy_reg] = 0;
		end

	end
	
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			registerFile <= `SD 0;
			validList <= `SD 0;
		end
		else begin
			registerFile <= `SD registerFileNxt;
			validList <= `SD validListNxt;
		end
	end
	
endmodule

`endif