`ifndef __RS_SV__
`define __RS_SV__

`timescale 1ns/100ps

module pe(gnt,enc);
        //synopsys template
        parameter OUT_WIDTH=3;
        parameter IN_WIDTH=1<<OUT_WIDTH;

	input   [IN_WIDTH-1:0] gnt;

	output [OUT_WIDTH-1:0] enc;
        wor    [OUT_WIDTH-1:0] enc;
        
        genvar i,j;
        generate
          for(i=0;i<OUT_WIDTH;i=i+1)
          begin : foo
            for(j=1;j<IN_WIDTH;j=j+1)
            begin : bar
              if (j[i])
                assign enc[i] = gnt[j];
            end
          end
        endgenerate
endmodule

/*
  Joshua Smith (smjoshua@umich.edu)

  psel_gen.v - Parametrizable priority selector module

  Module is parametrizable in the width of the request bus (WIDTH), and the
  number of simultaneous requests granted (REQS).
 */

`timescale 1ns/100ps

module psel_gen ( // Inputs
                  req,
                 
                  // Outputs
                  gnt,
                  gnt_bus,
                  empty
                );

  // synopsys template
  parameter REQS  = 2;
  parameter WIDTH = 8;

  // Inputs
  input wire  [WIDTH-1:0]       req;

  // Outputs
  output wor  [WIDTH-1:0]       gnt;
  output wand [WIDTH*REQS-1:0]  gnt_bus;
  output wire                   empty;

  // Internal stuff
  wire  [WIDTH*REQS-1:0]  tmp_reqs;
  wire  [WIDTH*REQS-1:0]  tmp_reqs_rev;
  wire  [WIDTH*REQS-1:0]  tmp_gnts;
  wire  [WIDTH*REQS-1:0]  tmp_gnts_rev;

  // Calculate trivial empty case
  assign empty = ~(|req);
  
  genvar j, k;
  for (j=0; j<REQS; j=j+1)
  begin:foo
    // Zero'th request/grant trivial, just normal priority selector
    if (j == 0) begin
      assign tmp_reqs[WIDTH-1:0]  = req[WIDTH-1:0];
      assign gnt_bus[WIDTH-1:0]   = tmp_gnts[WIDTH-1:0];

    // First request/grant, uses input request vector but reversed, mask out
    //  granted bit from first request.
    end else if (j == 1) begin
      for (k=0; k<WIDTH; k=k+1)
      begin:Jone
        assign tmp_reqs[2*WIDTH-1-k] = req[k];
      end

      assign gnt_bus[2*WIDTH-1 -: WIDTH] = tmp_gnts_rev[2*WIDTH-1 -: WIDTH] & ~tmp_gnts[WIDTH-1:0];

    // Request/grants 2-N.  Request vector for j'th request will be same as
    //  j-2 with grant from j-2 masked out.  Will alternate between normal and
    //  reversed priority order.  For the odd lines, need to use reversed grant
    //  output so that it's consistent with order of input.
    end else begin    // mask out gnt from req[j-2]
      assign tmp_reqs[(j+1)*WIDTH-1 -: WIDTH] = tmp_reqs[(j-1)*WIDTH-1 -: WIDTH] &
                                                ~tmp_gnts[(j-1)*WIDTH-1 -: WIDTH];
      
      if (j%2==0)
        assign gnt_bus[(j+1)*WIDTH-1 -: WIDTH] = tmp_gnts[(j+1)*WIDTH-1 -: WIDTH];
      else
        assign gnt_bus[(j+1)*WIDTH-1 -: WIDTH] = tmp_gnts_rev[(j+1)*WIDTH-1 -: WIDTH];

    end

    // instantiate priority selectors
    wand_sel #(WIDTH) psel (.req(tmp_reqs[(j+1)*WIDTH-1 -: WIDTH]), .gnt(tmp_gnts[(j+1)*WIDTH-1 -: WIDTH]));

    // reverse gnts (really only for odd request lines)
    for (k=0; k<WIDTH; k=k+1)
    begin:rev
      assign tmp_gnts_rev[(j+1)*WIDTH-1-k] = tmp_gnts[(j)*WIDTH+k];
    end

    // Mask out earlier granted bits from later grant lines.
    // gnt[j] = tmp_gnt[j] & ~tmp_gnt[j-1] & ~tmp_gnt[j-3]...
    for (k=j+1; k<REQS; k=k+2)
    begin:gnt_mask
      assign gnt_bus[(k+1)*WIDTH-1 -: WIDTH] = ~gnt_bus[(j+1)*WIDTH-1 -: WIDTH];
    end
  end

  // assign final gnt outputs
  // gnt_bus is the full-width vector for each request line, so OR everything
  for(k=0; k<REQS; k=k+1)
  begin:final_gnt
    assign gnt = gnt_bus[(k+1)*WIDTH-1 -: WIDTH];
  end

endmodule

module wand_sel (req,gnt);
  //synopsys template
  parameter WIDTH=64;
  input wire  [WIDTH-1:0] req;
  output wand [WIDTH-1:0] gnt;

  wire  [WIDTH-1:0] req_r;
  wand  [WIDTH-1:0] gnt_r;

  //priority selector
  genvar i;
  // reverse inputs and outputs
  for (i = 0; i < WIDTH; i = i + 1)
  begin : reverse
    assign req_r[WIDTH-1-i] = req[i];
    assign gnt[WIDTH-1-i]   = gnt_r[i];
  end

  for (i = 0; i < WIDTH-1 ; i = i + 1)
  begin : foo
    assign gnt_r [WIDTH-1:i] = {{(WIDTH-1-i){~req_r[i]}},req_r[i]};
  end
  assign gnt_r[WIDTH-1] = req_r[WIDTH-1];

endmodule

module rs_entry(    
    input                       clock, reset,
    input                       clear,
    input                       update,
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
    //
    //  TODO: Finish output assignment
    //
    RS_ENTRY_PACKET [`RS_SIZE-1:0] rs_arr;
    RS_ENTRY_PACKET [`RS_SIZE-1:0] rs_arr_out;
    /* This is used to clear rs entry on issue */
    logic [`RS_SIZE-1:0] clear_arr;
    /* This is used to indicate a rs entry need update on cdb match */
    logic [`RS_SIZE-1:0] update_arr;


    // this is the main part of the rs
    rs_entry rs_body [`RS_SIZE-1:0] (
        .clock(clock), .reset(reset),
        .clear(clear_arr),
        .update(update_arr),
        .packet_in(rs_arr), 
        .packet_out(rs_arr_out)
    );
    logic [`RS_LEN-1:0]    rs_empty_idx1, rs_empty_idx2;
    logic [`RS_LEN-1:0]    rs_ready_idx1, rs_ready_idx2;
    logic                  rs_valid1, rs_valid2, rs_done1, rs_done2;

    logic [`RS_SIZE-1:0] rs_empty_list;
    logic [`RS_SIZE-1:0] rs_ready_list;
    logic [`RS_SIZE-1:0] rs_empty_gnt, rs_ready_gnt;
    logic [`RS_SIZE*2-1:0] rs_empty_gnt_bus, rs_ready_gnt_bus;
    logic rs_empty_empty, rs_ready_empty;
    // logic [1:0] free_mult;
    
    //assign in_use_mult = mul_in_use1 + mul_in_use2;
    
    genvar i;
    for (i=0; i<`RS_SIZE; i++) begin
        assign rs_empty_list[i] = !(rs_arr_out[i].valid);
    end

    always_comb begin
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

    assign rs_valid2 = (rs_empty_gnt > 2);
    assign rs_valid1 = (rs_empty_gnt > 0);

    assign rs_done1 = (rs_ready_gnt_bus[`RS_SIZE-1:0] > 0);
    assign rs_done2 = (rs_ready_gnt_bus[`RS_SIZE*2-1:`RS_SIZE] > 0);



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
	assign issue_packet1.valid          = rs_arr_out[rs_ready_idx1].id_ex_packet.valid & rs_done1;    
    assign issue_packet1.pred_taken     = rs_arr_out[rs_ready_idx1].id_ex_packet.pred_taken;
    assign issue_packet1.brat_vec       = rs_arr_out[rs_ready_idx1].brat_vec;
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
	assign issue_packet2.valid          = rs_arr_out[rs_ready_idx2].id_ex_packet.valid & rs_done2;   
    assign issue_packet2.pred_taken     = rs_arr_out[rs_ready_idx2].id_ex_packet.pred_taken;
    assign issue_packet2.brat_vec       = rs_arr_out[rs_ready_idx2].brat_vec; 
    assign issue_packet2.rob_num        = rs_arr_out[rs_ready_idx2].rob_num;
    assign issue_packet2.dest_reg_idx   = rs_arr_out[rs_ready_idx2].id_ex_packet.dest_reg_idx;  

    assign full =   rs_valid2 ? 2'b11 :
                    rs_valid1 ? 2'b10 : 2'b00;

    always_comb begin
        // $monitor("issue packet brat vec from rs:%b %b at time : %d",issue_packet1.brat_vec,issue_packet2.brat_vec,$time);
        update_arr = {`RS_SIZE{1'b0}};
        clear_arr = {`RS_SIZE{1'b0}};
        //initialize
        rs_arr = '{
            (`RS_SIZE) {'{
            {`PR_LEN{1'b0}},
            {`VALUE_SIZE{1'b0}},
            {`VALUE_SIZE{1'b0}},
            {`PC_LEN{1'b0}},
            1'b0,
            1'b0,
            1'b0,                       // valid
            '{
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
			},
            {`BRAT_SIZE{1'b0}},
            {`ROB_LEN{1'b0}}       // rob_num in RS_ENTRY_PACKET
        }}};
        //dispatch
        if (valid1_in && rs_valid1) begin
            //$display("brat in use 1: %b at time: %d",brat_in_use1,$time);
            if ((id_ex_packet_in1.opa_select == OPA_IS_RS1) || id_ex_packet_in1.cond_branch) begin
                if ((id_ex_packet_in1.opb_select == OPB_IS_RS2) || id_ex_packet_in1.cond_branch) begin
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
                if ((id_ex_packet_in1.opb_select == OPB_IS_RS2) || id_ex_packet_in1.cond_branch) begin
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
        if (valid2_in && rs_valid2) begin
            //$display("brat in use 2: %b at time: %d",brat_in_use2,$time);
            if ((id_ex_packet_in2.opa_select == OPA_IS_RS1) || id_ex_packet_in2.cond_branch) begin
                if ((id_ex_packet_in2.opb_select == OPB_IS_RS2) || id_ex_packet_in2.cond_branch)  begin
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
                if ((id_ex_packet_in2.opb_select == OPB_IS_RS2) || id_ex_packet_in2.cond_branch) begin
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

        // issued inst, clear in next cycle
        if (rs_done1) begin
            clear_arr[rs_ready_idx1] = 1;
        end
        if (rs_done2) begin
            clear_arr[rs_ready_idx2] = 1;
        end

        // shift when issue
        if (c_valid1) begin
            for (int i=0; i< `RS_SIZE; i++) begin
                if (rs_arr[i].valid) begin
                    rs_arr[i].brat_vec = rs_arr[i].brat_vec - (1<<correct_index1) + (rs_arr[i].brat_vec & ((1<<correct_index1)-1'b1));
                    if (c_valid2)
                        rs_arr[i].brat_vec = rs_arr[i].brat_vec - (1<<correct_index2) + (rs_arr[i].brat_vec & ((1<<correct_index2)-1'b1));
                end
            end
        end
        else if (c_valid2) begin
            for (int i=0; i< `RS_SIZE; i++) begin
                if (rs_arr[i].valid) begin
                    rs_arr[i].brat_vec = rs_arr[i].brat_vec - (1<<correct_index2) + (rs_arr[i].brat_vec & ((1<<correct_index2)-1'b1));
                end
            end
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
                if (rs_arr[i].id_ex_packet.brat_vec > brat_mis) begin
                    clear_arr[i] = 1;
                end
            end
        end
    end
endmodule



`endif
