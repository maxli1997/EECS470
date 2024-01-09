`timescale 1ns/100ps

module testbench;
    logic	clock, reset;
    // Inputs from DISPATCH
    ID_EX_PACKET	id_dispatch_packet1, id_dispatch_packet2;
    logic [`PR_LEN-1:0] dest_phy_reg1, dest_phy_reg2;
    logic [`ROB_LEN-1:0] rob_tail, rob_tail_plus1;
    logic [`ROB_LEN-1:0] rob_head, rob_head_plus1;
    
    // Inputs from DCACHE
    logic dcache2lsq_valid;
    logic [3:0] dcache2lsq_tag;
    logic [`XLEN-1:0] dcache2lsq_data;

    logic mem2lsq_valid;
    logic [3:0] mem2lsq_tag;
    logic [`XLEN-1:0] mem2lsq_data;

    // Inputs from BRAT to squash and shift
    logic brat_en, c_valid1, c_valid2;
    logic [`BRAT_SIZE-1:0] brat_mis;
    logic [`BRAT_LEN-1:0] correct_index1, correct_index2;

    // Inputs from CDB to update address and stored value
    logic cdb1_valid, cdb2_valid;
    logic [`ROB_LEN-1:0] cdb1_tag, cdb2_tag;
    logic [`XLEN-1:0] cdb1_data, cdb2_data; // contain the address of the L/S
    CDB_RETIRE_PACKET cdb1_pkt, cdb2_pkt; // might contain the store values 

    // Outputs to CDB to broadcast loaded data
    EX_PACKET	ld_commit_pkt1, ld_commit_pkt2;
    
    // Outputs to DCACHE/MEMORY
    logic [1:0]	lsq2mem_command;
    logic [`XLEN-1:0] lsq2mem_addr;
    logic [`XLEN-1:0] lsq2mem_data;		// this is store data
    logic retire1_valid;

    logic [1:0]        full;
    `ifdef DEBUG_LSQ
    logic [`LSQ_SIZE-1:0]						lq_valid;
	logic [`LSQ_SIZE-1:0][`XLEN-1:0]			lq_dest_addr;
	logic [`LSQ_SIZE-1:0][`PR_LEN-1:0]			lq_dest_regs;
	logic [`LSQ_SIZE-1:0]						lq_addr_valid;
	logic [`LSQ_SIZE-1:0]						lq_need_mem;
	logic [`LSQ_SIZE-1:0]						lq_need_store;
	logic [`LSQ_SIZE-1:0]						lq_done;
	logic [`LSQ_SIZE-1:0][`BRAT_SIZE-1:0]		lq_brat_vec;
	logic [`LSQ_SIZE-1:0][`ROB_LEN-1:0]			lq_rob_nums;
	logic [`LSQ_SIZE-1:0][`LSQ_LEN-1:0]			lq_age;
	logic [`LSQ_SIZE-1:0][`XLEN-1:0]			lq_value;
    logic [`LSQ_SIZE-1:0]                       lq_issued;
	logic [1:0]									lq_full;
    logic [`LSQ_LEN-1:0]						sq_head;
	logic [`LSQ_LEN-1:0]						sq_tail;
	logic [`LSQ_SIZE-1:0]						sq_valid;
	logic [`LSQ_SIZE-1:0][`XLEN-1:0]			sq_dest_addr;
	logic [`LSQ_SIZE-1:0][`XLEN-1:0]			sq_value;
	logic [`LSQ_SIZE-1:0]						sq_addr_done;
	logic [`LSQ_SIZE-1:0]						sq_done;
	logic [`LSQ_SIZE-1:0][`BRAT_SIZE-1:0]		sq_brat_vec;
	logic [1:0]									sq_full;
	logic [`LSQ_SIZE-1:0][`ROB_LEN-1:0]			sq_rob_nums;
    logic [`LSQ_SIZE-1:0][3:0]                  lq_tags;
    logic [15:0][`LSQ_LEN-1:0]					map_lsq_num;
	logic [15:0]								map_valid;
    `endif
    logic   [10:0]                      cnt;
    lsq load_store_queue(
		.clock, .reset,
		.id_dispatch_packet1, .id_dispatch_packet2,
		.dest_phy_reg1, .dest_phy_reg2,
        .rob_tail, .rob_tail_plus1,
		.rob_head, .rob_head_plus1,
        .dcache2lsq_valid, .dcache2lsq_tag, .dcache2lsq_data, 
        .mem2lsq_valid, .mem2lsq_tag, .mem2lsq_data,
		.brat_en, .c_valid1, .c_valid2,
		.brat_mis, .correct_index1, .correct_index2,
        .retire1_valid,
        .cdb1_valid, .cdb2_valid,
        .cdb1_tag, .cdb2_tag,
        .cdb1_data, .cdb2_data,
        .cdb1_pkt, .cdb2_pkt,
		.ld_commit_pkt1, .ld_commit_pkt2,
        .lsq2mem_command, .lsq2mem_addr, .lsq2mem_data,
        .lq_tags, .lq_issued,
        .map_lsq_num,
        .map_valid,
		.full,
		.lq_valid,.lq_dest_addr,.lq_dest_regs,.lq_addr_valid,.lq_need_mem,
		.lq_need_store,.lq_done,.lq_brat_vec,.lq_rob_nums,.lq_age,.lq_value,.lq_full,
		.sq_head,.sq_tail,.sq_valid,.sq_dest_addr,.sq_value,.sq_addr_done,.sq_done,.sq_brat_vec,.sq_full,.sq_rob_nums
    );


    always begin
        #5 clock=~clock;
    end

    task check_lsq_output;
        input   data2cdb_valid, c_data2cdb_valid;
	    input   [`XLEN-1:0]   data2cdb, c_data2cdb;
        input   [`PR_LEN-1:0] dest_phy_reg_out, c_dest_phy_reg_out;
        input   [`ROB_LEN-1:0] rob_num_out, c_rob_num_out;
        input   [1:0]           lsq2mem_command, c_lsq2mem_command;
        input   [`XLEN-1:0] lsq2mem_addr, c_lsq2mem_addr;
        input   [`XLEN-1:0] lsq2mem_data, c_lsq2mem_data;
        input   [1:0]   full, c_full;
        // check whether load is issued to broadcast correctly
        if (data2cdb_valid != c_data2cdb_valid) begin
            $display("@@@ Wrong load queue broadcast status, expected: %d", c_data2cdb_valid);
            $display("@@@ Failed");
            $finish;
        end
        if (c_data2cdb_valid && (data2cdb != c_data2cdb)) begin
            $display("@@@ Wrong loaded data, expected: %d but get: %%d", c_data2cdb, data2cdb);
            $display("@@@ Failed");
            $finish;
        end
        if (c_data2cdb_valid && (dest_phy_reg_out != c_dest_phy_reg_out)) begin
            $display("@@@ Wrong destination register, expected: %d, got: %d", c_dest_phy_reg_out, dest_phy_reg_out);
            $display("@@@ Failed");
            $finish;
        end
        if (c_data2cdb_valid && (rob_num_out != c_rob_num_out)) begin
            $display("@@@ Wrong load instruction rob number, expected: %d, got: %d", c_rob_num_out, rob_num_out);
            $display("@@@ Failed");
            $finish;
        end
        // check whether the memory access is correct
        if (c_lsq2mem_command != lsq2mem_command) begin
            $display("@@@ Wrong memory access command, expected: %d, got: %d", c_lsq2mem_command, lsq2mem_command);
            $display("@@@ Failed");
            $finish;
        end
        if (c_lsq2mem_command != 0 && (lsq2mem_addr != c_lsq2mem_addr)) begin
            $display("@@@ Wrong memory address, expected: %b, got: %b", c_lsq2mem_addr, lsq2mem_addr);
            $display("@@@ Failed");
            $finish;
        end
        if (c_lsq2mem_command == 2 && (lsq2mem_data != c_lsq2mem_data)) begin
            $display("@@@ Wrong store data, expected: %d, got: %d", c_lsq2mem_data, lsq2mem_data);
            $display("@@@ Failed");
            $finish;
        end
        // check full
        if (full != c_full) begin
            $display("@@@ Wrong full signal, expected: %b, got: %b", c_full, full);
            $display("@@@ Failed");
            $finish;
        end                                  
    endtask

    task show_lsq;
        input [`LSQ_SIZE-1:0]						lq_valid;
	    input [`LSQ_SIZE-1:0][`XLEN-1:0]			lq_dest_addr;
	    input [`LSQ_SIZE-1:0][`PR_LEN-1:0]			lq_dest_regs;
        input [`LSQ_SIZE-1:0]						lq_addr_valid;
        input [`LSQ_SIZE-1:0]						lq_need_mem;
        input [`LSQ_SIZE-1:0]						lq_need_store;
        input [`LSQ_SIZE-1:0]						lq_done;
        input [`LSQ_SIZE-1:0][`BRAT_SIZE-1:0]		lq_brat_vec;
        input [`LSQ_SIZE-1:0][`ROB_LEN-1:0]			lq_rob_nums;
        input [`LSQ_SIZE-1:0][`LSQ_LEN-1:0]			lq_age;
        input [`LSQ_SIZE-1:0][`XLEN-1:0]			lq_value;
        input [`LSQ_SIZE-1:0][3:0]                  lq_tags;
        input [`LSQ_SIZE-1:0]                       lq_issued;
        input [1:0]									lq_full;
        input [`LSQ_LEN-1:0]						sq_head;
        input [`LSQ_LEN-1:0]						sq_tail;
        input [`LSQ_SIZE-1:0]						sq_valid;
        input [`LSQ_SIZE-1:0][`XLEN-1:0]			sq_dest_addr;
        input [`LSQ_SIZE-1:0][`XLEN-1:0]			sq_value;
        input [`LSQ_SIZE-1:0]						sq_addr_done;
        input [`LSQ_SIZE-1:0]						sq_done;
        input [`LSQ_SIZE-1:0][`BRAT_SIZE-1:0]		sq_brat_vec;
        input [1:0]									sq_full;
        input [`LSQ_SIZE-1:0][`ROB_LEN-1:0]			sq_rob_nums;
        input [15:0][`LSQ_LEN-1:0]					map_lsq_num;
	    input [15:0]								map_valid;
        input [10:0]                      cnt;
        begin
            $display("@@@\t\tCycle %d", cnt);
            $display("@@@updated lsq from last cycle:");
            
            // print lq
            $display("@@@\tlq#\tvalid\tdest_addr  dest_reg  addr_valid  need_mem  need_store  done\tbrat_vec\trob#\tage\tvalue\ttags\tissued");
            for (int i = 0; i < `LSQ_SIZE; i++) begin
                //if (lq_tags[i] != 0) $display("lq has wrong tag %d", lq_tags[i]);
                $display("@@@%9d%9d    %8h%9d%9d%9d   %9d%9d        %4b   %9d%9d    %8h%4d  %b",
                    i, lq_valid[i], lq_dest_addr[i], lq_dest_regs[i], lq_addr_valid[i], lq_need_mem[i],lq_need_store[i],lq_done[i],lq_brat_vec[i],lq_rob_nums[i],lq_age[i],lq_value[i],lq_tags[i],lq_issued[i]);
            end
            $display("@@@lq_full: %b", lq_full);
            $display("@@@");
            
            // print lq map
            $display("@@@ lq map:   mem_tag     lq_idx    valid");
            for (int i=0; i<16; i++) begin
                $display("          %9d%9d%9d", i, map_lsq_num[i], map_valid[i]);
            end
            $display("@@@");

            // print sq
            $display("@@@\tsq#\tvalid\tdest_addr      value\t addr_done\tdone\tbrat_vec\trob#");
            for (int i = 0; i < `LSQ_SIZE; i++) begin
                if (sq_valid[i]) begin
                    if (sq_head == i && sq_head == sq_tail) begin
                        $display("@@@%6d%9d      %8h     %8h   %9d%9d        %4b   %9d  HEAD,TAIL", 
                        i, sq_valid[i],sq_dest_addr[i],sq_value[i],sq_addr_done[i],sq_done[i],sq_brat_vec[i],sq_rob_nums[i]);
                    end
                    else if (sq_head == i) begin
                        $display("@@@%6d%9d      %8h     %8h   %9d%9d        %4b   %9d  HEAD", 
                        i, sq_valid[i],sq_dest_addr[i],sq_value[i],sq_addr_done[i],sq_done[i],sq_brat_vec[i],sq_rob_nums[i]);
                    end else if (sq_tail == i) begin
                        $display("@@@%6d%9d      %8h     %8h   %9d%9d        %4b   %9d  TAIL", 
                        i, sq_valid[i],sq_dest_addr[i],sq_value[i],sq_addr_done[i],sq_done[i],sq_brat_vec[i],sq_rob_nums[i]);
                    end else begin
                        $display("@@@%6d%9d      %8h     %8h   %9d%9d        %4b   %9d", 
                        i, sq_valid[i],sq_dest_addr[i],sq_value[i],sq_addr_done[i],sq_done[i],sq_brat_vec[i],sq_rob_nums[i]);
                    end
                end 
                else begin
                    if (sq_head == sq_tail && i == sq_head) begin
                        $display("@@@%6d HEAD,TAIL", i);
                    end else if (i == sq_tail) begin
                        $display("@@@%6d TAIL", i);
                    end else begin
                        $display("@@@%6d", i);
                    end
                end
            end

            
            $display("@@@sq_full: %b", sq_full);
            $display("@@@");
        end
    endtask  // show_lsq


    initial begin
        clock = 0;
        reset = 1;
        id_dispatch_packet1 = '{
				{`XLEN{1'b0}},
				{`XLEN{1'b0}}, 
				{`XLEN{1'b0}}, 
				{`XLEN{1'b0}}, 
				{`AR_LEN{1'b0}},
				{`AR_LEN{1'b0}},
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				{`PR_LEN{1'b0}},
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0, //valid
				1'b0, //pred_taken,
				{`BRAT_SIZE{1'b0}}, //brat_vec
				{`ROB_LEN{1'b0}}
			}; 
        id_dispatch_packet2 = '{
				{`XLEN{1'b0}},
				{`XLEN{1'b0}}, 
				{`XLEN{1'b0}}, 
				{`XLEN{1'b0}}, 
				{`AR_LEN{1'b0}},
				{`AR_LEN{1'b0}},
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				{`PR_LEN{1'b0}},
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0, //valid
				1'b0, //pred_taken,
				{`BRAT_SIZE{1'b0}}, //brat_vec
				{`ROB_LEN{1'b0}}
			}; 
        dest_phy_reg1 = 0;
        dest_phy_reg2 = 0;
        rob_tail = 0;
        rob_tail_plus1 = 1;
        rob_head = 0;
        rob_head_plus1 = 1;
        dcache2lsq_valid = 0;
        dcache2lsq_tag = 0;
        dcache2lsq_data = 0;
        brat_en = 0;
        c_valid1 = 0;
        c_valid2 = 0;
        brat_mis = 0;
        correct_index1 = 0;
        correct_index2 = 0;
        cdb1_valid = 0;
        cdb2_valid = 0;
        cdb1_tag = 0;
        cdb2_tag = 0;
        cdb1_data = 0;
        cdb2_data = 0;
        cdb1_pkt = '{
            {`XLEN{1'b0}},
            {`XLEN{1'b0}},
            1'b0, 1'b0, 1'b0,
            {`BRAT_SIZE{1'b0}},
            {`XLEN{1'b0}},
            1'b0, 1'b0,
            {`PR_LEN{1'b0}},
            {`ROB_LEN{1'b0}},
            1'b0, 1'b0, 1'b0, 1'b0,
            3'b0
        };
        cdb2_pkt = '{
            {`XLEN{1'b0}},
            {`XLEN{1'b0}},
            1'b0, 1'b0, 1'b0,
            {`BRAT_SIZE{1'b0}},
            {`XLEN{1'b0}},
            1'b0, 1'b0,
            {`PR_LEN{1'b0}},
            {`ROB_LEN{1'b0}},
            1'b0, 1'b0, 1'b0, 1'b0,
            3'b0
        };
        retire1_valid = 0;

        // cycle 0 just check reset, nothing will be done in cycle 0
        @(negedge clock)
        // dispatch 2 stores
        reset = 0;
        id_dispatch_packet1.valid = 1;
        id_dispatch_packet1.wr_mem = 1;
        id_dispatch_packet2.valid = 1;
        id_dispatch_packet2.wr_mem = 1;
        // at negedge cycle 0 id stage send out insts and correct values are prepared
        @(negedge clock)
        // issue a store, then load, load's age should be 3
        rob_tail = 2;
        rob_tail_plus1 = 3;
        id_dispatch_packet2.rd_mem = 1;
        id_dispatch_packet2.wr_mem = 0;
        show_lsq(lq_valid, lq_dest_addr,lq_dest_regs,lq_addr_valid,lq_need_mem, lq_need_store,lq_done,lq_brat_vec,lq_rob_nums,lq_age,lq_value,lq_tags,lq_issued,lq_full,
		sq_head,sq_tail,sq_valid,sq_dest_addr,sq_value,sq_addr_done,sq_done,sq_brat_vec,sq_full,sq_rob_nums,map_lsq_num,map_valid, $time);
        @(negedge clock)
        // store 0 broadcast with addr 1 and val 2
        id_dispatch_packet1.valid = 0;
        id_dispatch_packet2.valid = 0;
        cdb1_valid = 1;
        cdb1_tag = 0;
        cdb1_data = 1;
        cdb1_pkt.rs2_value = 2;
        cdb1_pkt.rob_num = 0;
        show_lsq(lq_valid, lq_dest_addr,lq_dest_regs,lq_addr_valid,lq_need_mem, lq_need_store,lq_done,lq_brat_vec,lq_rob_nums,lq_age,lq_value,lq_tags,lq_issued,lq_full,
		sq_head,sq_tail,sq_valid,sq_dest_addr,sq_value,sq_addr_done,sq_done,sq_brat_vec,sq_full,sq_rob_nums,map_lsq_num,map_valid, $time);
        @(negedge clock)
        // store 1 broadcast with addr 0 val 2
        // store 2 broadcast with addr 0 val 1
        cdb1_data = 0;
        cdb1_tag = 1;
        cdb2_valid = 1;
        cdb2_tag = 2;
        cdb2_data = 0;
        cdb2_pkt.rs2_value = 1;
        cdb2_pkt.rob_num = 2;
        show_lsq(lq_valid, lq_dest_addr,lq_dest_regs,lq_addr_valid,lq_need_mem, lq_need_store,lq_done,lq_brat_vec,lq_rob_nums,lq_age,lq_value,lq_tags,lq_issued,lq_full,
		sq_head,sq_tail,sq_valid,sq_dest_addr,sq_value,sq_addr_done,sq_done,sq_brat_vec,sq_full,sq_rob_nums,map_lsq_num,map_valid, $time);
        @(negedge clock)
        // the load (addr 0) should be ready with val 1
        cdb1_data = 0;
        cdb1_tag = 3;
        cdb1_valid = 1;
        cdb2_valid = 0;
        rob_tail = 4;
        rob_tail_plus1 = 5;
        id_dispatch_packet1.valid = 1;
        id_dispatch_packet1.rd_mem = 1;
        id_dispatch_packet1.wr_mem = 0;
        id_dispatch_packet2.valid = 1;
        id_dispatch_packet2.rd_mem = 0;
        id_dispatch_packet2.wr_mem = 1;
        show_lsq(lq_valid, lq_dest_addr,lq_dest_regs,lq_addr_valid,lq_need_mem, lq_need_store,lq_done,lq_brat_vec,lq_rob_nums,lq_age,lq_value,lq_tags,lq_issued,lq_full,
		sq_head,sq_tail,sq_valid,sq_dest_addr,sq_value,sq_addr_done,sq_done,sq_brat_vec,sq_full,sq_rob_nums,map_lsq_num,map_valid, $time);
        @(negedge clock)
        // cycle 5, rob# 3 load addr valid
        cdb1_valid = 0;
        rob_tail = 6;
        rob_tail_plus1 = 7;
        show_lsq(lq_valid, lq_dest_addr,lq_dest_regs,lq_addr_valid,lq_need_mem, lq_need_store,lq_done,lq_brat_vec,lq_rob_nums,lq_age,lq_value,lq_tags,lq_issued,lq_full,
		sq_head,sq_tail,sq_valid,sq_dest_addr,sq_value,sq_addr_done,sq_done,sq_brat_vec,sq_full,sq_rob_nums,map_lsq_num,map_valid, $time);
        @(negedge clock)
        // rob#3 load resolved
        rob_tail = 0;
        rob_tail_plus1 = 1;
        cdb1_valid = 1;
        cdb1_data = 7;
        cdb1_tag = 4;
        id_dispatch_packet1.valid = 1;
        id_dispatch_packet1.rd_mem = 1;
        id_dispatch_packet1.wr_mem = 0;
        id_dispatch_packet2.valid = 1;
        id_dispatch_packet2.rd_mem = 1;
        id_dispatch_packet2.wr_mem = 0;
        show_lsq(lq_valid, lq_dest_addr,lq_dest_regs,lq_addr_valid,lq_need_mem, lq_need_store,lq_done,lq_brat_vec,lq_rob_nums,lq_age,lq_value,lq_tags,lq_issued,lq_full,
		sq_head,sq_tail,sq_valid,sq_dest_addr,sq_value,sq_addr_done,sq_done,sq_brat_vec,sq_full,sq_rob_nums,map_lsq_num,map_valid, $time);
        @(negedge clock)
        // rob#3 load commmitted
        // issue rob# 4 load, cache miss
        id_dispatch_packet1.valid = 0;
        id_dispatch_packet2.valid = 0;
        cdb1_valid = 1;
        cdb1_tag = 5;
        cdb1_data = 13;
        cdb2_valid = 1;
        cdb2_tag = 6;
        cdb2_data = 15;
        dcache2lsq_tag = 1;
        
        show_lsq(lq_valid, lq_dest_addr,lq_dest_regs,lq_addr_valid,lq_need_mem, lq_need_store,lq_done,lq_brat_vec,lq_rob_nums,lq_age,lq_value,lq_tags,lq_issued,lq_full,
		sq_head,sq_tail,sq_valid,sq_dest_addr,sq_value,sq_addr_done,sq_done,sq_brat_vec,sq_full,sq_rob_nums,map_lsq_num,map_valid, $time);
        $display("ld issue valid: %b, addr: %d", lsq2mem_command, lsq2mem_addr);
        @(negedge clock)
        // memory respond to issued load rob #4
        // issue rob #6 cache hit
        cdb1_valid = 0;
        cdb2_valid = 0;
        mem2lsq_valid = 1;
        mem2lsq_tag = 1;
        mem2lsq_data = 8;
        dcache2lsq_valid = 1;
        dcache2lsq_tag = 2;
        dcache2lsq_data = 16;
        show_lsq(lq_valid, lq_dest_addr,lq_dest_regs,lq_addr_valid,lq_need_mem, lq_need_store,lq_done,lq_brat_vec,lq_rob_nums,lq_age,lq_value,lq_tags,lq_issued,lq_full,
		sq_head,sq_tail,sq_valid,sq_dest_addr,sq_value,sq_addr_done,sq_done,sq_brat_vec,sq_full,sq_rob_nums,map_lsq_num,map_valid, $time);
        @(negedge clock)
        // rob# 4, 6 done
        mem2lsq_valid = 0;
        dcache2lsq_valid = 0;
        rob_head = 1;
        rob_head_plus1 = 2;
        show_lsq(lq_valid, lq_dest_addr,lq_dest_regs,lq_addr_valid,lq_need_mem, lq_need_store,lq_done,lq_brat_vec,lq_rob_nums,lq_age,lq_value,lq_tags,lq_issued,lq_full,
		sq_head,sq_tail,sq_valid,sq_dest_addr,sq_value,sq_addr_done,sq_done,sq_brat_vec,sq_full,sq_rob_nums,map_lsq_num,map_valid, $time);
        @(negedge clock)
        rob_head = 2;
        rob_head_plus1 = 3;

        show_lsq(lq_valid, lq_dest_addr,lq_dest_regs,lq_addr_valid,lq_need_mem, lq_need_store,lq_done,lq_brat_vec,lq_rob_nums,lq_age,lq_value,lq_tags,lq_issued,lq_full,
		sq_head,sq_tail,sq_valid,sq_dest_addr,sq_value,sq_addr_done,sq_done,sq_brat_vec,sq_full,sq_rob_nums,map_lsq_num,map_valid, $time);
        @(negedge clock)
        rob_head = 4;
        rob_head_plus1 = 5;
        retire1_valid = 0;
        show_lsq(lq_valid, lq_dest_addr,lq_dest_regs,lq_addr_valid,lq_need_mem, lq_need_store,lq_done,lq_brat_vec,lq_rob_nums,lq_age,lq_value,lq_tags,lq_issued,lq_full,
		sq_head,sq_tail,sq_valid,sq_dest_addr,sq_value,sq_addr_done,sq_done,sq_brat_vec,sq_full,sq_rob_nums,map_lsq_num,map_valid, $time);
        @(negedge clock)
        show_lsq(lq_valid, lq_dest_addr,lq_dest_regs,lq_addr_valid,lq_need_mem, lq_need_store,lq_done,lq_brat_vec,lq_rob_nums,lq_age,lq_value,lq_tags,lq_issued,lq_full,
		sq_head,sq_tail,sq_valid,sq_dest_addr,sq_value,sq_addr_done,sq_done,sq_brat_vec,sq_full,sq_rob_nums,map_lsq_num,map_valid, $time);
        
        $display("@@@ PASSED!");
        $finish;
    end


endmodule