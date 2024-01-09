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
	
	freelist f ( 
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

	task show_free_list;
		input [`PR_SIZE-1:0] listOut;
		input [`PR_SIZE-1:0] listOut1, listOut2;
		input [10:0] cycle_num;
		begin
			$display("@@@ Free List       /     ListOut1  /      ListOut2");
			$display("@@@ Cycle %9d", cycle_num);
			for (int i=0; i<`PR_SIZE; i++) begin
				$display("%9d%9d%9d%9d",i, listOut[i], listOut1[i], listOut2[i]);
			end
		end
		$display("@@@");
	endtask
	
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

		expected = 0;
		// check list in
		@(negedge clock)
		reset = 0;
		listIn = 64'h000000000000000c; // 1100
		expected = 0;
		// check_freelist_out(request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet,listIn,success1,success2,regNum1,regNum2,listOut,expected);
		@(negedge clock)
		mispredictSet = 0;
		request1 = 1;
		request2 = 1;
		expected = 12;
		show_free_list(listOut, listOut1, listOut2, $time);
		// check_freelist_out(request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet,listIn,success1,success2,regNum1,regNum2,listOut,expected);
		// check reset
		@(negedge clock)
		mispredictSet = 0;
		show_free_list(listOut, listOut1, listOut2, $time);	
		#1;
		$display("got phy reg: %d, %d", regNum1, regNum2);
		// check_freelist_out(request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet,listIn,success1,success2,regNum1,regNum2,listOut,expected);
		@(negedge clock)
		reset = 0;
		request1 = 0;
		request2 = 0;
		expected = 0;	
		show_free_list(listOut, listOut1, listOut2, $time);	
		// check_freelist_out(request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet,listIn,success1,success2,regNum1,regNum2,listOut,expected);
		@(negedge clock)
		request1 = 1;
		request2 = 0;
		expected = 6;	
		// check_freelist_out(request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet,listIn,success1,success2,regNum1,regNum2,listOut,expected);
		@(negedge clock)
		expected = 14;	
		// check_freelist_out(request1,request2,retire_pkt_1,retire_pkt_2,mispredictSet,listIn,success1,success2,regNum1,regNum2,listOut,expected);
		$display("Test Passed");
		$finish;
	end
	
endmodule