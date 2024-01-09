/////////////////////////////////////////////////////////////////////////
//                                                                     //
//  Modulename :  bratfreelist.sv                                      //
//                                                                     //
//  Description :  This module creates the physical register file and  // 
//                 store value in it.                                  //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __BRATFREELIST_SV__
`define __BRATFREELIST_SV__

`timescale 1ns/100ps

module bratfreelist(
	input						updateClock, reset,
	input						numberBeforeCurrent,
	input [PR_SIZE-1:0]			listIn,
	
	output [PR_SIZE-1:0]			bratList,
);

	logic [PR_SIZE-1:0]			listIn, bratList;
	logic [BRAT_SIZE-1:0][PR_SIZE-1:0]		listCurrent, listNxt;
	
	always_comb begin
		listNxt <= listCurrent;
		if(numberBeforeCurrent < BRAT_SIZE-1 && numberBeforeCurrent > 0) begin
			listNxt <= {listCurrent[BRAT_SIZE-2:0], listIn};
			bratList = listCurrent[numberBeforeCurrent];
		end
	end
	
	always_ff @(posedge updateClock) begin
		if(reset) begin
			listCurrent <= `SD 0;
		end
		else begin
			listCurrent <= listNxt;
		end
	end
	
endmodule