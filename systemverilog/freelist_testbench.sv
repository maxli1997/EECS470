`timescale 1ns/100ps

module testbench;

	logic						clock, reset;
	logic						request1,request2;
	ROB_RETIRE_PACKET		retire_pkt_1, retire_pkt_2;
	logic						mispredictSet;
	logic [`PR_SIZE-1:0]			listIn;
	logic						success1,success2;
	logic [`PR_LEN-1:0]			regNum1,regNum2;
	logic [`PR_SIZE-1:0]		listOut,listOut1,listOut2;
	logic [`PR_SIZE-1:0]			expected;
	
	freelist f( 
					clock, reset,
					request1,request2,
					retire_pkt_1, retire_pkt_2,
					mispredictSet,
					listIn,
					success1,success2,
					regNum1,regNum2,
					listOut,
					listOut1,listOut2
	);
	
	always begin
		#5 clock=~clock;
	end
	
	task check_freelist_out;
		input						request1,request2;
		input ROB_RETIRE_PACKET		retire_pkt_1, retire_pkt_2;
		input						mispredictSet;
		input [`PR_SIZE-1:0]		listIn;
		input						success1,success2;
		input [`PR_LEN-1:0]			regNum1,regNum2;
		input [`PR_SIZE-1:0]			listOut;
		input [`PR_SIZE-1:0]			expected;
		begin
			if (listOut != expected) begin
				$display("Test Failed at this step");
				$display("listOut: %h, expected: %h", listOut, expected);
				$display("request1: %h, request2: %h, retire_pkt_1: %h, retire_pkt_2: %h, mispredictSet: %h"
						,request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet);
				$display("listIn: %h, success1: %h, success2: %h, regNum1: %h, regNum2: %h", listIn, success1, success2, regNum1, regNum2);
				$finish;
			end
		end
	endtask
	
	initial
	begin
		clock = 0;
		reset = 1;
		request1 = 0;
		request2 = 0;
		retire_pkt_1 = 0;
		retire_pkt_2 = 0;
		mispredictSet = 1;
		listIn = 0;
/*
		success1 = 0;
		success2 = 0;
		regNum1 = 0;
		regNum2 = 0;
		listOut = 0;
*/
		expected = 0;
		// check list in
		@(negedge clock)
		reset = 0;
		listIn = 12;
		expected = 0;
		check_freelist_out(request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet,listIn,success1,success2,regNum1,regNum2,listOut,expected);
		@(negedge clock)
		reset = 0;
		listIn = 64'hffffffffffffffff;
		expected = 12;
		check_freelist_out(request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet,listIn,success1,success2,regNum1,regNum2,listOut,expected);
		// check reset
		@(negedge clock)
		mispredictSet = 0;
		reset = 1;
		expected = 64'hffffffffffffffff;	check_freelist_out(request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet,listIn,success1,success2,regNum1,regNum2,listOut,expected);
@(negedge clock)
		reset = 0;
		request1 = 1;
		request2 = 1;
		expected = 0;	check_freelist_out(request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet,listIn,success1,success2,regNum1,regNum2,listOut,expected);
		@(negedge clock)
		request1 = 1;
		request2 = 0;
		expected = 6;	check_freelist_out(request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet,listIn,success1,success2,regNum1,regNum2,listOut,expected);
		@(negedge clock)
		expected = 14;	check_freelist_out(request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet,listIn,success1,success2,regNum1,regNum2,listOut,expected);
		$display("Test Passed");
		$finish;
	end
	
endmodule