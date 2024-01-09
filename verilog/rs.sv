`ifndef __RS_SV__
`define __RS_SV__

`timescale 1ns/100ps

module rs_entry(    
    input                       clock, reset,
    input                       clear,
    input                       update,
    input                       update_brat_vec,
    input   RS_ENTRY_PACKET     packet_in,

    output  RS_ENTRY_PACKET     packet_out

);
    logic                   valid;
    logic [`PR_LEN-1:0]     tag;
    logic [`VALUE_SIZE-1:0] tag1, tag2;
    logic [`PC_LEN-1:0]     pc;
    logic                   tag1_rdy, tag2_rdy;
    ID_EX_PACKET            id_ex_packet;
    logic [`BRAT_SIZE-1:0]  brat_vec;
    logic [`ROB_LEN-1:0]   rob_num;

    assign packet_out.valid = valid;
    assign packet_out.tag = tag;
    assign packet_out.tag1 = tag1;
    assign packet_out.tag2 = tag2;
    assign packet_out.pc = pc;
    assign packet_out.tag1_rdy = tag1_rdy;
    assign packet_out.tag2_rdy = tag2_rdy;
    assign packet_out.id_ex_packet = id_ex_packet;
	assign packet_out.brat_vec = brat_vec;
    assign packet_out.rob_num  = rob_num;

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        // $display("rob num %d brat_vec %b pktin brat_vec %b update %b clear %b",rob_num,brat_vec,packet_in.brat_vec,update_brat_vec,clear);
        if (reset | clear) begin
            valid           <= `SD 0;
            tag             <= `SD 0;
            tag1            <= `SD 0;
            tag2            <= `SD 0;
            pc              <= `SD 0;
            tag1_rdy        <= `SD 0;
            tag2_rdy        <= `SD 0;
            id_ex_packet    <= `SD '{
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
                1'b0,
                {`BRAT_SIZE{1'b0}},
                {`ROB_LEN{1'b0}}
			}; 
		    brat_vec	<= `SD 0;
            rob_num     <= `SD 0;
        end 
        else if (packet_in.valid) begin
            valid           <= `SD 1;
            tag             <= `SD packet_in.tag;
            tag1            <= `SD packet_in.tag1;
            tag2            <= `SD packet_in.tag2;
            pc              <= `SD packet_in.pc;
            id_ex_packet    <= `SD packet_in.id_ex_packet;
            brat_vec        <= `SD packet_in.brat_vec;
            tag1_rdy        <= `SD packet_in.tag1_rdy;
            tag2_rdy        <= `SD packet_in.tag2_rdy;
            rob_num         <= `SD packet_in.rob_num;
        end else if (update) begin
            // CDB match, update the two source value
            if (packet_in.tag1_rdy) begin
                tag1_rdy    <= `SD 1;
                tag1        <= `SD packet_in.tag1;
            end else begin
                tag1_rdy    <= `SD tag1_rdy;
                tag1        <= `SD tag1;
            end
            if (packet_in.tag2_rdy) begin
                tag2_rdy    <= `SD 1;
                tag2        <= `SD packet_in.tag2;
            end else begin
                tag2_rdy    <= `SD tag2_rdy;
                tag2        <= `SD tag2;
            end
        end
        if (update_brat_vec) begin
            brat_vec    <= `SD packet_in.brat_vec;
        end
    end
    
endmodule

module rs(
    input                   clock, reset,
    // dispatch's instructions is valid or not
    input   ID_EX_PACKET    id_ex_packet_in1, id_ex_packet_in2,
    input                   valid1_in, valid2_in,
    input   [`PC_LEN-1:0]   pc1_in, pc2_in,                         

    input                           mul_free1, mul_free2,
    /* inputs from cdb */
    input                           cdb1_valid_in, cdb2_valid_in,
    // phy reg num
    input   [`PR_LEN-1:0]           cdb1_tag_in, cdb2_tag_in,
    input   [`VALUE_SIZE-1:0]       cdb1_value, cdb2_value,
    input                           rat11_valid, rat12_valid, rat21_valid, rat22_valid,
    input   [`VALUE_SIZE-1:0]       rat11_value, rat12_value, rat21_value, rat22_value,
    input   [`PR_LEN-1:0]           regNum1, regNum2,
    input                           c_valid1,c_valid2,
    input   [`BRAT_LEN-1:0]         correct_index1, correct_index2,
    input                           brat_en,
    input   [`BRAT_SIZE-1:0]        brat_mis,
    input   [`BRAT_SIZE-1:0]        brat_in_use1, brat_in_use2,

    // need to keep track of the disptach instrution's rob number
    input   [`ROB_LEN-1:0]         rob_tail, rob_tail_plus1,

    output  ID_EX_PACKET   issue_packet1, issue_packet2,
    output  [1:0]           full
    `ifdef DEBUG_RS
    , output RS_ENTRY_PACKET [`RS_SIZE-1:0] rs_arr_out,
    output  [`RS_LEN-1:0]   rs_empty_idx1, rs_empty_idx2
    `endif

);

    RS_ENTRY_PACKET [`RS_SIZE-1:0] rs_arr;
    RS_ENTRY_PACKET [`RS_SIZE-1:0] rs_arr_out;
    /* This is used to clear rs entry on issue */
    logic [`RS_SIZE-1:0] clear_arr;
    /* This is used to indicate a rs entry need update on cdb match */
    logic [`RS_SIZE-1:0] update_arr;
    logic [`RS_SIZE-1:0] update_brat_arr;


    // this is the main part of the rs
    rs_entry rs_body [`RS_SIZE-1:0] (
        .clock(clock), .reset(reset),
        .clear(clear_arr),
        .update(update_arr),
        .update_brat_vec(update_brat_arr),
        .packet_in(rs_arr), 
        .packet_out(rs_arr_out)
    );
    logic [`RS_LEN-1:0]    rs_empty_idx1, rs_empty_idx2;
    logic [`RS_LEN-1:0]    rs_ready_idx1, rs_ready_idx2;
    logic                  rs_valid1, rs_valid2, rs_done1, rs_done2;
    logic [`RS_LEN-1:0]    rs_only_empty_idx; // used when there is only 1 slot

    logic [`RS_SIZE-1:0] rs_empty_list;
    logic [`RS_SIZE-1:0] rs_ready_list;
    logic [`RS_SIZE-1:0] rs_empty_gnt, rs_ready_gnt;
    logic [`RS_SIZE*2-1:0] rs_empty_gnt_bus, rs_ready_gnt_bus;
    logic rs_empty_empty, rs_ready_empty;
    logic [`RS_LEN:0] rs_cnt;
    // logic [1:0] free_mult;
    
    //assign in_use_mult = mul_in_use1 + mul_in_use2;
    

    always_comb begin
        // free_mult = mul_free1 + mul_free2;
	    rs_cnt = 0;
    	for (int i=0; i<`RS_SIZE; i++) begin
            rs_empty_list[i] = !(rs_arr_out[i].valid);
	        rs_cnt += !(rs_arr_out[i].valid);
    	end
        if (valid1_in)
            rs_cnt -= 1;
        if (valid2_in)
            rs_cnt -= 1;
        for (int j=0; j<`RS_SIZE; j++) begin
            if (rs_arr_out[j].id_ex_packet.alu_func > 5'h09 & rs_arr_out[j].id_ex_packet.alu_func < 5'h0e) begin
                rs_ready_list[j] = rs_arr_out[j].tag1_rdy & rs_arr_out[j].tag2_rdy & (mul_free1 & mul_free2);
                // free_mult = free_mult > 1 ? (free_mult - 1) : 0;
            end else begin
                rs_ready_list[j] = rs_arr_out[j].tag1_rdy & rs_arr_out[j].tag2_rdy;
            end
        end
    end

    psel_gen #(.REQS(2), .WIDTH(`RS_SIZE)) empty_sel(
        rs_empty_list,
        rs_empty_gnt,
        rs_empty_gnt_bus,
        rs_empty_empty
    );

    pe #(.OUT_WIDTH(`RS_LEN)) empty_enc1(
        rs_empty_gnt_bus[`RS_SIZE-1:0],
        rs_empty_idx1
    );

    pe #(.OUT_WIDTH(`RS_LEN)) empty_enc2(
        rs_empty_gnt_bus[`RS_SIZE*2-1:`RS_SIZE],
        rs_empty_idx2
    );

    psel_gen #(.REQS(2), .WIDTH(`RS_SIZE)) ready_sel(
        rs_ready_list,
        rs_ready_gnt,
        rs_ready_gnt_bus,
        rs_ready_empty
    );

    pe #(.OUT_WIDTH(`RS_LEN)) read_enc1(
        rs_ready_gnt_bus[`RS_SIZE-1:0],
        rs_ready_idx1
    );

    pe #(.OUT_WIDTH(`RS_LEN)) read_enc2(
        rs_ready_gnt_bus[`RS_SIZE*2-1:`RS_SIZE],
        rs_ready_idx2
    );

    // two empty slots
    assign rs_valid2 = !(^rs_empty_gnt) & (rs_empty_gnt > 0);

    assign rs_valid1 = (^rs_empty_gnt) & (rs_empty_gnt > 0);

    assign rs_done1 = (rs_ready_gnt_bus[`RS_SIZE-1:0] > 0);
    assign rs_done2 = (rs_ready_gnt_bus[`RS_SIZE*2-1:`RS_SIZE] > 0);
    assign rs_only_empty_idx =          rs_valid1 ? 
            ((rs_empty_gnt_bus[`RS_SIZE-1:0] > 0) ? rs_empty_idx1 : rs_empty_idx2) : 0;


    assign issue_packet1.NPC            = rs_arr_out[rs_ready_idx1].id_ex_packet.NPC;
    assign issue_packet1.PC             = rs_arr_out[rs_ready_idx1].id_ex_packet.PC;
    assign issue_packet1.rs1_value      = rs_arr_out[rs_ready_idx1].tag1;
    assign issue_packet1.rs2_value      = rs_arr_out[rs_ready_idx1].tag2;
    assign issue_packet1.rs1_reg        = rs_arr_out[rs_ready_idx1].id_ex_packet.rs1_reg;
    assign issue_packet1.rs2_reg        = rs_arr_out[rs_ready_idx1].id_ex_packet.rs2_reg;
    assign issue_packet1.opa_select     = rs_arr_out[rs_ready_idx1].id_ex_packet.opa_select;
    assign issue_packet1.opb_select     = rs_arr_out[rs_ready_idx1].id_ex_packet.opb_select;
    assign issue_packet1.inst           = rs_arr_out[rs_ready_idx1].id_ex_packet.inst;
    assign issue_packet1.dest_phy_reg   = rs_arr_out[rs_ready_idx1].tag;
    assign issue_packet1.alu_func       = rs_arr_out[rs_ready_idx1].id_ex_packet.alu_func;
    assign issue_packet1.rd_mem         = rs_arr_out[rs_ready_idx1].id_ex_packet.rd_mem;        
	assign issue_packet1.wr_mem         = rs_arr_out[rs_ready_idx1].id_ex_packet.wr_mem;        
	assign issue_packet1.cond_branch    = rs_arr_out[rs_ready_idx1].id_ex_packet.cond_branch;   
	assign issue_packet1.uncond_branch  = rs_arr_out[rs_ready_idx1].id_ex_packet.uncond_branch; 
	assign issue_packet1.halt           = rs_arr_out[rs_ready_idx1].id_ex_packet.halt;          
	assign issue_packet1.illegal        = rs_arr_out[rs_ready_idx1].id_ex_packet.illegal;       
	assign issue_packet1.csr_op         = rs_arr_out[rs_ready_idx1].id_ex_packet.csr_op; 

    // issue_packet1.valid: indicate this packet is issued successfully       
	assign issue_packet1.valid          = rs_arr_out[rs_ready_idx1].id_ex_packet.valid & rs_done1 
                                            & ((brat_en & (rs_arr_out[rs_ready_idx1].brat_vec <= brat_mis))
                                            | !brat_en);    
    assign issue_packet1.pred_taken     = rs_arr_out[rs_ready_idx1].id_ex_packet.pred_taken;
    // if this cycle has a correct prediction, use the shifted value instead
    assign issue_packet1.brat_vec       = (!c_valid1 & !c_valid2) ? rs_arr_out[rs_ready_idx1].brat_vec : rs_arr[rs_ready_idx1].brat_vec;
    assign issue_packet1.rob_num        = rs_arr_out[rs_ready_idx1].rob_num; 
    assign issue_packet1.dest_reg_idx   = rs_arr_out[rs_ready_idx1].id_ex_packet.dest_reg_idx;   

    assign issue_packet2.NPC            = rs_arr_out[rs_ready_idx2].id_ex_packet.NPC;
    assign issue_packet2.PC             = rs_arr_out[rs_ready_idx2].id_ex_packet.PC;
    assign issue_packet2.rs1_value      = rs_arr_out[rs_ready_idx2].tag1;
    assign issue_packet2.rs2_value      = rs_arr_out[rs_ready_idx2].tag2;
    assign issue_packet2.rs1_reg        = rs_arr_out[rs_ready_idx2].id_ex_packet.rs1_reg;
    assign issue_packet2.rs2_reg        = rs_arr_out[rs_ready_idx2].id_ex_packet.rs2_reg;
    assign issue_packet2.opa_select     = rs_arr_out[rs_ready_idx2].id_ex_packet.opa_select;
    assign issue_packet2.opb_select     = rs_arr_out[rs_ready_idx2].id_ex_packet.opb_select;
    assign issue_packet2.inst           = rs_arr_out[rs_ready_idx2].id_ex_packet.inst;
    assign issue_packet2.dest_phy_reg   = rs_arr_out[rs_ready_idx2].tag;
    assign issue_packet2.alu_func       = rs_arr_out[rs_ready_idx2].id_ex_packet.alu_func;
    assign issue_packet2.rd_mem         = rs_arr_out[rs_ready_idx2].id_ex_packet.rd_mem;        
	assign issue_packet2.wr_mem         = rs_arr_out[rs_ready_idx2].id_ex_packet.wr_mem;        
	assign issue_packet2.cond_branch    = rs_arr_out[rs_ready_idx2].id_ex_packet.cond_branch;   
	assign issue_packet2.uncond_branch  = rs_arr_out[rs_ready_idx2].id_ex_packet.uncond_branch; 
	assign issue_packet2.halt           = rs_arr_out[rs_ready_idx2].id_ex_packet.halt;          
	assign issue_packet2.illegal        = rs_arr_out[rs_ready_idx2].id_ex_packet.illegal;       
	assign issue_packet2.csr_op         = rs_arr_out[rs_ready_idx2].id_ex_packet.csr_op;     
    // issue_packet2.valid: indicate this packet is issued successfully   
	assign issue_packet2.valid          = rs_arr_out[rs_ready_idx2].id_ex_packet.valid & rs_done2
                                        & ((brat_en & (rs_arr_out[rs_ready_idx2].brat_vec <= brat_mis))
                                            | !brat_en);   
    assign issue_packet2.pred_taken     = rs_arr_out[rs_ready_idx2].id_ex_packet.pred_taken;
    assign issue_packet2.brat_vec       = (!c_valid1 & !c_valid2) ? rs_arr_out[rs_ready_idx2].brat_vec : rs_arr[rs_ready_idx2].brat_vec; 
    assign issue_packet2.rob_num        = rs_arr_out[rs_ready_idx2].rob_num;
    assign issue_packet2.dest_reg_idx   = rs_arr_out[rs_ready_idx2].id_ex_packet.dest_reg_idx;  

    assign full =   rs_cnt >= 2   ? 2'b11 :
                    rs_cnt == 1 ? 2'b10 : 2'b00;

    always_comb begin
        // $monitor("issue packet brat vec from rs:%b %b at time : %d",issue_packet1.brat_vec,issue_packet2.brat_vec,$time);
        update_arr = {`RS_SIZE{1'b0}};
        update_brat_arr = {`RS_SIZE{1'b0}};
        clear_arr = {`RS_SIZE{1'b0}};
        //initialize
        rs_arr = rs_arr_out;

        //dispatch, only dispatch inst if no mispredict
        if (rs_valid2 & !brat_en) begin
            if (valid1_in) begin
                if ((id_ex_packet_in1.opa_select == OPA_IS_RS1) || id_ex_packet_in1.cond_branch
                    || id_ex_packet_in1.wr_mem) begin
                    if ((id_ex_packet_in1.opb_select == OPB_IS_RS2) || id_ex_packet_in1.cond_branch
                        || id_ex_packet_in1.wr_mem) begin
                        rs_arr[rs_empty_idx1] = '{
                                                    regNum1,
                                                    rat11_value,
                                                    rat12_value,
                                                    pc1_in,           
                                                    rat11_valid,
                                                    rat12_valid,            
                                                    1'b1,
                                                    id_ex_packet_in1,
                                                    brat_in_use1,
                                                    rob_tail                  
                                                };
                    end 
                    else begin
                        rs_arr[rs_empty_idx1] = '{
                                                    regNum1,
                                                    rat11_value,
                                                    rat12_value,
                                                    pc1_in,          
                                                    rat11_valid,
                                                    1,            
                                                    1'b1,
                                                    id_ex_packet_in1,
                                                    brat_in_use1,
                                                    rob_tail                  
                                                };
                    end
                end 
                else begin  
                    if ((id_ex_packet_in1.opb_select == OPB_IS_RS2) || id_ex_packet_in1.cond_branch
                        || id_ex_packet_in1.wr_mem) begin
                        rs_arr[rs_empty_idx1] = '{
                                                    regNum1,
                                                    rat11_value,
                                                    rat12_value,
                                                    pc1_in,           
                                                    1'b1,
                                                    rat12_valid,            
                                                    1'b1,
                                                    id_ex_packet_in1,
                                                    brat_in_use1,
                                                    rob_tail                  
                                                };
                    end 
                    else begin
                        rs_arr[rs_empty_idx1] = '{
                                                    regNum1,
                                                    rat11_value,
                                                    rat12_value,
                                                    pc1_in,          
                                                    1'b1,               // rdy1
                                                    1'b1,               // rdy2
                                                    1'b1,
                                                    id_ex_packet_in1,
                                                    brat_in_use1,
                                                    rob_tail                  
                                                };
                    end
                end                
            end
            if (valid2_in) begin
                if ((id_ex_packet_in2.opa_select == OPA_IS_RS1) || id_ex_packet_in2.cond_branch
                    || id_ex_packet_in2.wr_mem) begin
                    if ((id_ex_packet_in2.opb_select == OPB_IS_RS2) || id_ex_packet_in2.cond_branch
                        || id_ex_packet_in2.wr_mem)  begin
                        //$display("at rs rat21 rat22 %d %d at time %d", rat21_valid, rat22_valid, $time);
                        rs_arr[rs_empty_idx2] = '{
                                                    regNum2,
                                                    rat21_value,
                                                    rat22_value,
                                                    pc2_in,        
                                                    rat21_valid,
                                                    rat22_valid,               
                                                    1'b1,
                                                    id_ex_packet_in2,
                                                    brat_in_use2,
                                                    rob_tail_plus1                 
                                                };
                    end 
                    else begin
                        rs_arr[rs_empty_idx2] = '{
                                                    regNum2,
                                                    rat21_value,
                                                    rat22_value,
                                                    pc2_in,      
                                                    rat21_valid,
                                                    1,               
                                                    1'b1,
                                                    id_ex_packet_in2,
                                                    brat_in_use2,
                                                    rob_tail_plus1                 
                                                };
                    end
                end 
                else begin
                    if ((id_ex_packet_in2.opb_select == OPB_IS_RS2) || id_ex_packet_in2.cond_branch
                        || id_ex_packet_in2.wr_mem) begin
                        rs_arr[rs_empty_idx2] = '{
                                                    regNum2,
                                                    rat21_value,
                                                    rat22_value,
                                                    pc2_in,        
                                                    1'b1,
                                                    rat22_valid,               
                                                    1'b1,
                                                    id_ex_packet_in2,
                                                    brat_in_use2,
                                                    rob_tail_plus1                 
                                                };
                    end 
                    else begin
                        rs_arr[rs_empty_idx2] = '{
                                                    regNum2,
                                                    rat21_value,
                                                    rat22_value,
                                                    pc2_in,      
                                                    1'b1,
                                                    1'b1,               
                                                    1'b1,
                                                    id_ex_packet_in2,
                                                    brat_in_use2,
                                                    rob_tail_plus1                 
                                                };
                    end
                end                
            end
        end
        else if (rs_valid1 & valid1_in & !brat_en) begin
            if ((id_ex_packet_in1.opa_select == OPA_IS_RS1) || id_ex_packet_in1.cond_branch
                || id_ex_packet_in1.wr_mem) begin
                if ((id_ex_packet_in1.opb_select == OPB_IS_RS2) || id_ex_packet_in1.cond_branch
                    || id_ex_packet_in1.wr_mem) begin
                    rs_arr[rs_only_empty_idx] = '{
                                                regNum1,
                                                rat11_value,
                                                rat12_value,
                                                pc1_in,           
                                                rat11_valid,
                                                rat12_valid,            
                                                1'b1,
                                                id_ex_packet_in1,
                                                brat_in_use1,
                                                rob_tail                  
                                            };
                end 
                else begin
                    rs_arr[rs_only_empty_idx] = '{
                                                regNum1,
                                                rat11_value,
                                                rat12_value,
                                                pc1_in,          
                                                rat11_valid,
                                                1,            
                                                1'b1,
                                                id_ex_packet_in1,
                                                brat_in_use1,
                                                rob_tail                  
                                            };
                end
            end 
            else begin  
                if ((id_ex_packet_in1.opb_select == OPB_IS_RS2) || id_ex_packet_in1.cond_branch
                    || id_ex_packet_in1.wr_mem) begin
                    rs_arr[rs_only_empty_idx] = '{
                                                regNum1,
                                                rat11_value,
                                                rat12_value,
                                                pc1_in,           
                                                1'b1,
                                                rat12_valid,            
                                                1'b1,
                                                id_ex_packet_in1,
                                                brat_in_use1,
                                                rob_tail                  
                                            };
                end 
                else begin
                    rs_arr[rs_only_empty_idx] = '{
                                                regNum1,
                                                rat11_value,
                                                rat12_value,
                                                pc1_in,          
                                                1'b1,               // rdy1
                                                1'b1,               // rdy2
                                                1'b1,
                                                id_ex_packet_in1,
                                                brat_in_use1,
                                                rob_tail                  
                                            };
                end
            end        
        end

        // issued inst, clear in next cycle
        if (issue_packet1.valid) begin
            clear_arr[rs_ready_idx1] = 1;
        end
        if (issue_packet2.valid) begin
            clear_arr[rs_ready_idx2] = 1;
        end

        // shift when issue

        if (c_valid1) begin
            // $display("index1 valid, %d, time %d, rs ", correct_index1, $time);
            // $display("rs issue idx1: %d, idx2: %d brat_vec before shift: %b %b", rs_ready_idx1, rs_ready_idx2, rs_arr_out[rs_ready_idx1].brat_vec, rs_arr_out[rs_ready_idx2].brat_vec); 
            for (int i=0; i< `RS_SIZE; i++) begin
                if (rs_arr_out[i].valid && rs_arr_out[i].brat_vec[correct_index1]) begin
                    //$display("rs idx %d brat_vec before shift: %b", i, rs_arr_out[i].brat_vec); 
                    update_brat_arr[i] = 1;
                    rs_arr[i].brat_vec = rs_arr_out[i].brat_vec - (1<<correct_index1) + (rs_arr_out[i].brat_vec & ((1<<correct_index1)-1'b1));
                    if (c_valid2 && rs_arr[i].brat_vec[correct_index2])
                        rs_arr[i].brat_vec = rs_arr[i].brat_vec - (1<<correct_index2) + (rs_arr[i].brat_vec & ((1<<correct_index2)-1'b1));
                end
            end
            // $display("rs issue brat_vec: %b %b", rs_arr[rs_ready_idx1].brat_vec, rs_arr[rs_ready_idx2].brat_vec);
        end
        else if (c_valid2) begin
            // $display("index2 valid, %d, time %d, rs ", correct_index2, $time);
            // $display("rs issue idx1: %d, idx2: %d brat_vec before shift: %b %b", rs_ready_idx1, rs_ready_idx2, rs_arr_out[rs_ready_idx1].brat_vec, rs_arr_out[rs_ready_idx2].brat_vec);
            for (int i=0; i< `RS_SIZE; i++) begin
                if (rs_arr_out[i].valid && rs_arr_out[i].brat_vec[correct_index2]) begin
                    //$display("rs idx %d brat_vec before shift: %b", i, rs_arr_out[i].brat_vec); 
                    update_brat_arr[i] = 1;
                    rs_arr[i].brat_vec = rs_arr_out[i].brat_vec - (1<<correct_index2) + (rs_arr_out[i].brat_vec & ((1<<correct_index2)-1'b1));
                end
            end
            // $display("calculated value is %b", (rs_arr_out[rs_ready_idx1].brat_vec - (1<<correct_index2) + (rs_arr_out[rs_ready_idx1].brat_vec & ((1<<correct_index2)-1'b1))));
            // $display("rs issue brat_vec: %b %b", rs_arr[rs_ready_idx1].brat_vec, rs_arr[rs_ready_idx2].brat_vec);
        end

        // get value from CDB
        if (cdb1_valid_in) begin
            for (int i = 0; i < `RS_SIZE; i++) begin
                // need to check rs_arr_out to see cdb broadcast
                if ((rs_arr_out[i].tag1 == cdb1_tag_in) && (rs_arr_out[i].tag1 != 0) && !rs_arr_out[i].tag1_rdy) begin
                    // need to set update bit to 1 in order to update rs_entry
                    update_arr[i] = 1;
                    rs_arr[i].tag1_rdy = 1;
                    rs_arr[i].tag1 = cdb1_value;
                end
                if ((rs_arr_out[i].tag2 == cdb1_tag_in) && (rs_arr_out[i].tag2 != 0) && !rs_arr_out[i].tag2_rdy) begin
                    // need to set update bit to 1 in order to update rs_entry
                    update_arr[i] = 1;
                    rs_arr[i].tag2_rdy = 1;
                    rs_arr[i].tag2 = cdb1_value;
                end
            end
        end
        if (cdb2_valid_in) begin
            for (int i = 0; i < `RS_SIZE; i++) begin
                // need to check rs_arr_out to see cdb broadcast
                if ((rs_arr_out[i].tag1 == cdb2_tag_in) && (rs_arr_out[i].tag1 != 0) && !rs_arr_out[i].tag1_rdy) begin
                    // need to set update bit to 1 in order to update rs_entry
                    update_arr[i] = 1;
                    rs_arr[i].tag1_rdy = 1;
                    rs_arr[i].tag1 = cdb2_value;
                end
                if ((rs_arr_out[i].tag2 == cdb2_tag_in) && (rs_arr_out[i].tag2 != 0) && !rs_arr_out[i].tag2_rdy) begin
                    // need to set update bit to 1 in order to update rs_entry
                    update_arr[i] = 1;
                    rs_arr[i].tag2_rdy = 1;
                    rs_arr[i].tag2 = cdb2_value;
                end
            end
        end

        // squash
        if (brat_en) begin
            for (int i=0; i< `RS_SIZE; i++) begin
                if (rs_arr_out[i].brat_vec > brat_mis) begin
                    clear_arr[i] = 1;
                end
            end
        end
    end
endmodule



`endif
