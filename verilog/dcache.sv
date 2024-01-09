
module dcache(
    input   clock,
    input   reset,
    input   [3:0] Dmem2proc_response,
    input  [63:0] Dmem2proc_data,
    input   [3:0] Dmem2proc_tag,

    // Input from lsq
    input  [`XLEN-1:0] proc2dcache_addr,  
    input  [`XLEN-1:0] proc2dcache_data,
    input   [1:0] proc2Dcache_command,  // BUS_LOAD, BUS_STORE or BUS_NONE (stick to write through for now)
	input  [1:0] wr_size,

    output logic  [1:0] proc2Dmem_command,
    output logic [31:0] proc2Dmem_addr,
    output logic [63:0] proc2Dmem_data,

	// Outputs to lsq
    output logic [`XLEN-1:0] dcache_data_out, // value is memory[proc2dcache_addr]
    output logic  dcache_valid_out,      // when this is high


    // MSHR output to DCache
    output [`MSHRLEN-1:0] mshr_head, mshr_send, mshr_tail,
	output mshr_full,
    output retire_pkt_valid,
    output MSHR_ENTRY_PACKET retire_pkt,
	output MSHR_ENTRY_PACKET [`MSHRSIZE-1:0]   mshr_arr_out,
	output mshr_empty

  );

	logic 								dcache_miss;
	MSHR_ENTRY_PACKET 					mshr_pkt_in;
	MSHR_ENTRY_PACKET [`MSHRSIZE-1:0]   mshr_arr_out;
	logic [`MSHRLEN-1:0]				HEAD, TAIL, SEND;
	MSHR_ENTRY_PACKET            retire_pkt;
  logic                               retire_pkt_valid;

	// Inputs to data cache content
	logic rd1_en, wr1_en;
	logic [4:0] wr1_idx, rd1_idx;
	logic [7:0] wr1_tag, rd1_tag;
	logic [63:0] wr1_data;
	logic [63:0] rd1_data;
	logic rd1_valid, load_addr_conflict;


	logic [3:0] dcache2mshr_response;
	logic [1:0] mshr2dcache_command;
	logic [`XLEN-1:0] mshr2dcache_addr;
	logic [63:0] mshr2dcache_data;

	assign dcache_miss = (!rd1_valid | load_addr_conflict) && (proc2Dcache_command != BUS_NONE);
	assign dcache2mshr_response = Dmem2proc_response;
	assign proc2Dmem_command = mshr2dcache_command;
	assign proc2Dmem_addr = mshr2dcache_addr;
	assign proc2Dmem_data = mshr2dcache_data;


	// assign wr1_en = (rd1_valid && (proc2Dcache_command == BUS_STORE)) 
	// 				| (retire_pkt_valid && retire_pkt.typ);
	// assign wr1_tag = (rd1_valid && (proc2Dcache_command == BUS_STORE)) ? 
	// 					proc2dcache_addr[15:8] : retire_pkt.addr[15:8];
	// assign wr1_idx = (rd1_valid && (proc2Dcache_command == BUS_STORE)) ?
	// 					proc2dcache_addr[7:3] : retire_pkt.addr[7:3];
	assign rd1_en = (proc2Dcache_command != BUS_NONE);
	assign {rd1_tag, rd1_idx} = proc2dcache_addr[15:3];
	assign dcache_data_out = proc2dcache_addr[2] ? rd1_data[63:32] : rd1_data[31:0];
	assign dcache_valid_out = rd1_valid && (proc2Dcache_command != BUS_NONE) && !load_addr_conflict;
	
	// when cache miss (or store), issue a packet to mshr
	assign mshr_pkt_in.valid = dcache_miss | (proc2Dcache_command == BUS_STORE);
	assign mshr_pkt_in.addr = proc2dcache_addr;
	assign mshr_pkt_in.typ = (proc2Dcache_command == BUS_LOAD) ? 0 : 1;

	// these fields are the initial value
	assign mshr_pkt_in.done = 0;
	assign mshr_pkt_in.mem_tag = 0;
	assign mshr_pkt_in.wr_size = wr_size;
	assign mshr_pkt_in.send_wait = 0;

	assign mshr_head = HEAD;
	assign mshr_tail = TAIL;
	assign mshr_send = SEND;

	always_comb begin
		// assemble the mshr_pkt_data
		mshr_pkt_in.data = 0;
		if (proc2Dcache_command == BUS_STORE) begin
			/*if (wr_size == 2'b00) begin
				if (proc2dcache_addr[2:0] == 3'b000)
					mshr_pkt_in.data[7:0] = proc2dcache_data[7:0];
				else if (proc2dcache_addr[2:0] == 3'b001)
					mshr_pkt_in.data[15:8] = proc2dcache_data[7:0];
				else if (proc2dcache_addr[2:0] == 3'b010)
					mshr_pkt_in.data[23:16] = proc2dcache_data[7:0];
				else if (proc2dcache_addr[2:0] == 3'b011)
					mshr_pkt_in.data[31:24] = proc2dcache_data[7:0];
				else if (proc2dcache_addr[2:0] == 3'b100)
					mshr_pkt_in.data[39:32] = proc2dcache_data[7:0];
				else if (proc2dcache_addr[2:0] == 3'b101)
					mshr_pkt_in.data[47:40] = proc2dcache_data[7:0];
				else if (proc2dcache_addr[2:0] == 3'b110)
					mshr_pkt_in.data[55:48] = proc2dcache_data[7:0];
				else
					mshr_pkt_in.data[63:56] = proc2dcache_data[7:0];
			end 
			else if (wr_size == 2'b01) begin
				if (proc2dcache_addr[2:1] == 2'b00)
						mshr_pkt_in.data[15:0] = proc2dcache_data[15:0];
				else if (proc2dcache_addr[2:1] == 2'b01)
					mshr_pkt_in.data[31:16] = proc2dcache_data[15:0];
				else if (proc2dcache_addr[2:1] == 2'b10)
					mshr_pkt_in.data[47:32] = proc2dcache_data[15:0];
				else
					mshr_pkt_in.data[63:48] = proc2dcache_data[15:0];
			end
			else begin */
			if (proc2dcache_addr[2] == 0)
				mshr_pkt_in.data[31:0] = proc2dcache_data;
			else
				mshr_pkt_in.data[63:32] = proc2dcache_data;		
		end

		wr1_en = retire_pkt_valid;
		{wr1_tag, wr1_idx} = retire_pkt.addr[15:3];
		wr1_data = retire_pkt.data;
		// $display("rd1 vliad at! req addr %d cmd %d %d", proc2dcache_addr, proc2Dcache_command, $time);
		// if (rd1_valid && (proc2Dcache_command == BUS_STORE)) begin
		// 	// $display("a hit store happened! %d", $time);
		// 	// $display("rd1_idx %d rd1_tag %d", rd1_idx, rd1_tag);
		// 	wr1_en = 1;
		// 	{wr1_tag, wr1_idx} = proc2dcache_addr[15:3];
		// 	wr1_data = rd1_data;
		// 	if (wr_size == 2'b00) begin
		// 		if (proc2dcache_addr[2:0] == 3'b000)
		// 			wr1_data[7:0] = proc2dcache_data[7:0];
		// 		else if (proc2dcache_addr[2:0] == 3'b001)
		// 			wr1_data[15:8] = proc2dcache_data[7:0];
		// 		else if (proc2dcache_addr[2:0] == 3'b010)
		// 			wr1_data[23:16] = proc2dcache_data[7:0];
		// 		else if (proc2dcache_addr[2:0] == 3'b011)
		// 			wr1_data[31:24] = proc2dcache_data[7:0];
		// 		else if (proc2dcache_addr[2:0] == 3'b100)
		// 			wr1_data[39:32] = proc2dcache_data[7:0];
		// 		else if (proc2dcache_addr[2:0] == 3'b101)
		// 			wr1_data[47:40] = proc2dcache_data[7:0];
		// 		else if (proc2dcache_addr[2:0] == 3'b110)
		// 			wr1_data[55:48] = proc2dcache_data[7:0];
		// 		else
		// 			wr1_data[63:56] = proc2dcache_data[7:0];
		// 	end
		// 	else if (wr_size == 2'b01) begin
		// 		if (proc2dcache_addr[2:1] == 2'b00)
		// 			wr1_data[15:0] = proc2dcache_data[15:0];
		// 		else if (proc2dcache_addr[2:1] == 2'b01)
		// 			wr1_data[31:16] = proc2dcache_data[15:0];
		// 		else if (proc2dcache_addr[2:1] == 2'b10)
		// 			wr1_data[47:32] = proc2dcache_data[15:0];
		// 		else
		// 			wr1_data[63:48] = proc2dcache_data[15:0];
		// 	end
		// 	else begin
		// 		if (proc2dcache_addr[2] == 0)
		// 			wr1_data[31:0] = proc2dcache_data;
		// 		else
		// 			wr1_data[63:32] = proc2dcache_data;
		// 	end
		// end else begin
		// 	// once the retire packet is valid, we need to have the results written into the cache
		// 	wr1_en = retire_pkt_valid;
		// 	{wr1_tag, wr1_idx} = retire_pkt.addr[15:3];
		// 	wr1_data = retire_pkt.data;
		// end
		

		$display("proc2dcache_addr :%h data %d, mshr2dcache_addr: %h request valid:%d dcache_valid_out %d data %h, rd1_tag %h, rd1_idx %h", 
				proc2dcache_addr, proc2dcache_data, mshr2dcache_addr, mshr_pkt_in.valid, dcache_valid_out, rd1_data, rd1_tag, rd1_idx);
		$display("mshr 2 dcache cmd2:%d addr: %h at time %d", mshr2dcache_command, proc2Dmem_addr, $time);
	end
	

	MSHR mshr(
		// Inputs
		.clock(clock), .reset(reset),
		.pkt_in(mshr_pkt_in),
		.mem2proc_response(dcache2mshr_response),
		.mem2proc_data(Dmem2proc_data),
		.mem2proc_tag(Dmem2proc_tag),
		.load_addr(proc2dcache_addr),
		
		.load_addr_conflict(load_addr_conflict),
		// Outputs
		.HEAD(HEAD), .TAIL(TAIL), .SEND(SEND),
		.mshr_arr_out(mshr_arr_out),
		.full(mshr_full),
		.empty(mshr_empty),
		.retire_pkt(retire_pkt),
		.retire_pkt_valid(retire_pkt_valid),	
		.proc2mem_command(mshr2dcache_command),
		.proc2mem_addr(mshr2dcache_addr),
		.proc2mem_data(mshr2dcache_data)
	);

	

	// the data cache
	datacache datacache(
		.clock, .reset,
		.rd1_en,
		.wr1_en,
		.wr1_idx, .rd1_idx,
        .wr1_tag, .rd1_tag,
        .wr1_data, 

        .rd1_data,
        .rd1_valid
	);



endmodule

