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
	input		clock, reset,
	input		rat1_valid, rat2_valid,
	input		rat11_reg, rat12_reg, rat21_reg, reg22_reg,
	// valid bit of regNum
	input		success1,success2,
	input		regNum1,regNum2,
	input		cdb1_valid, cdb2_valid,
	input		cdb1_reg, cdb2_reg,
	input		cdb1_value, cdb2_value,
	input ROB_RETIRE_PACKET			retire_pkt_1, retire_pkt_2,
	// misprediction handling
	input		mispredict,
	// brat passes a listin
	input		listIn,
	
	output		rat11_valid, rat12_valid, rat21_valid, rat22_valid,
	output		rat11_value, rat12_value, rat21_value, rat22_value
);

	logic					mispredict,
	logic					cdb1_valid, cdb2_valid;
	logic 					success1, success2;
	logic					rat11_valid, rat12_valid, rat21_valid, rat22_valid;
	logic [`PR_LEN-1:0]		regNum1, regNum2;
	logic [`PR_LEN-1:0]		cdb1_reg, cdb2_reg;
	logic [`PR_LEN-1:0]		rat11_reg, rat12_reg, rat21_reg, reg22_reg;
	logic [`VALUE_SIZE-1:0]	rat11_value, rat12_value, rat21_value, rat22_value;
	logic [`VALUE_SIZE-1:0]	cdb1_value, cdb2_value;
	logic [`PR_SIZE-1:0][`VALUE_SIZE-1:0] registerFile, registerFileNxt;
	logic [`PR_SIZE-1:0]	validList, validListNxt;

	
	always_comb begin
		validListNxt = validList;
		registerFileNxt = registerFile;
		if(mispredict) begin
			validListNxt = listIn;
			if(validListNxt[cdb1_reg] & cdb1_valid & cdb1_reg != 0) begin
			registerFileNxt[cdb1_reg] = cdb1_value;
			validListNxt[cdb1_reg] = 1;
			end
			if(validListNxt[cdb2_reg] & cdb2_valid & cdb2_reg != 0) begin
			registerFileNxt[cdb2_reg] = cdb2_value;
			validListNxt[cdb2_reg] = 1;
			end
		end
		else begin
			if(cdb1_valid & cdb1_reg != 0) begin
				registerFileNxt[cdb1_reg] = cdb1_value;
				validListNxt[cdb1_reg] = 1;
			end
			if(cdb2_valid & cdb2_reg != 0) begin
				registerFileNxt[cdb2_reg] = cdb2_value;
				validListNxt[cdb2_reg] = 1;
			end
			if(rat1_valid) begin
				if(validListNxt[rat11_reg])
					rat11_value = registerFileNxt[rat11_reg];
				else if (rat11_reg == 0)
					rat11_value = 0;
				else
					rat11_value = rat11_reg;
			end
			if(rat1_valid) begin
				if(validListNxt[rat12_reg])
					rat12_value = registerFileNxt[rat12_reg];
				else if (rat12_reg == 0)
					rat12_value = 0;
				else
					rat12_value = rat12_reg;
			end
			if(rat2_valid) begin
				if(validListNxt[rat21_reg])
					rat21_value = registerFileNxt[rat21_reg];
				else if (rat21_reg == 0)
					rat21_value = 0;
				else
					rat21_value = rat21_reg;
			end
			if(rat2_valid) begin
				if(validListNxt[rat22_reg])
					rat22_value = registerFileNxt[rat22_reg];
				else if (rat22_reg == 0)
					rat22_value = 0;
				else
					rat22_value = rat22_reg;
			end
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
			valisdList <= `SD 0;
		end
		else begin
			registerFile <= `SD registerFileNxt;
			validList <= `SD validListNxt;
		end
	end
	
endmodule