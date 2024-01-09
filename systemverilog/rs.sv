`ifndef __RS_SV__
`define __RS_SV__

`timescale 1ns/100ps

//TODO: Finish ??? part


//INPUT DISPATCH FREELIST CDB
//OUTPUT FU \
/*
module shift(
    input   [`BRAT_SIZE-1:0]    shift_in,
    input                       shift_bit,
    output  [`BRAT_SIZE-1:0]    shift_out
);
    logic [`BRAT_SIZE-1:0]      shift_temp;
    assign shift_temp = 1<<shift_bit;
    assign shift_out = shift_in - shift_temp + (shift_in & (shift_temp - 1'b1)) << 1
endmodule
*/

module empty_entry_selector(
    input  RS_ENTRY_PACKET [`RS_SIZE-1:0]   rs_arr,
    output logic [`RS_LEN-1:0]    rs_empty_idx1, rs_empty_idx2,
    output logic               rs_valid1, rs_valid2
);
    
    always_comb begin
        logic count = 0;
    rs_valid1 = 0;
    rs_valid2 = 0;
    for (int i = 0; i < `RS_SIZE; i++) begin
        if (!rs_arr[i].valid && count != 2) begin
            if (count == 0) begin
                rs_empty_idx1 = i;
                rs_valid1 = 1;
                count = 1;
            end
            else begin
                rs_empty_idx2 = i;
                rs_valid2 = 1;
                count = 2;
                break;
            end
        end
    end
    end

endmodule

module done_entry_selector(
    input  RS_ENTRY_PACKET [`RS_SIZE-1:0]   rs_arr,
    input   mul_in_use1, mul_in_use2,
    output logic [`RS_LEN-1:0]    rs_done_idx1, rs_done_idx2,
    output logic                rs_done1, rs_done2
);
    logic count = 0;
   
    always_comb begin
    rs_done1 = 0;
    rs_done2 = 0;
    for (int i = 0; i < `RS_SIZE; i++) begin
        if ((mul_in_use1 && !mul_in_use2) || (!mul_in_use1 && mul_in_use2)) begin
            if ((rs_arr[i].tag1_rdy && rs_arr[i].tag2_rdy) && count != 2) begin
                if (count == 0) begin
                    rs_done_idx1 = i;
                    count = 1;
                    rs_done1 = 1;
                end
                else begin
                    if (rs_arr[i].fu != ALU_MUL || rs_arr[i].fu != ALU_MULH || rs_arr[i].fu != ALU_MULHSU || rs_arr[i].fu != ALU_MULHU) begin
                        rs_done_idx2 = i;
                        count = 2;
                        rs_done2 = 1;
                        break;
                    end
                end
            end
        end
        else if (mul_in_use1 && mul_in_use2) begin
            if ((rs_arr[i].tag1_rdy && rs_arr[i].tag2_rdy) && count != 2 && 
            (rs_arr[i].fu != ALU_MUL || rs_arr[i].fu != ALU_MULH || rs_arr[i].fu != ALU_MULHSU|| rs_arr[i].fu != ALU_MULHU)) begin
                if (count == 0) begin
                    rs_done_idx1 = i;
                    count = 1;
                    rs_done1 = 1;
                end
                else begin
                    rs_done_idx2 = i;
                    count = 2;
                    rs_done2 = 1;
                    break;
                end
            end
        end
        else begin
            if ((rs_arr[i].tag1_rdy && rs_arr[i].tag2_rdy) && count != 2) begin
                if (count == 0) begin
                    rs_done_idx1 = i;
                    count = 1;
                    rs_done1 = 1;
                end
                else begin
                    rs_done_idx2 = i;
                    count = 2;
                    rs_done2 = 1;
                    break;
                end
            end
        end
    end
    end

endmodule


module rs_entry(    
    input                       clock, reset,
    input                       clear,
    input   RS_ENTRY_PACKET     packet_in,

    output  RS_ENTRY_PACKET     packet_out

);
    logic                   valid;
    logic [`PR_LEN-1:0]     tag;
    //logic [`AR_LEN-1;0]     tag1_reg, tag2_reg;
    logic [`VALUE_SIZE-1:0] tag1, tag2;
    logic [`PC_LEN-1:0]     pc;
    logic [`FU_LEN-1:0]     fu;
    logic                   tag1_rdy, tag2_rdy;
    ID_EX_PACKET      id_ex_packet;
    //logic [`BRAT_SIZE-1:0]  brat_vec;

    assign packet_out.valid = valid;
    assign packet_out.tag = tag;
    //assign packet_out.tag1_reg = tag1_reg;
    //assign packet_out.tag2_reg = tag2_reg;
    assign packet_out.tag1 = tag1;
    assign packet_out.tag2 = tag2;
    assign packet_out.pc = pc;
    assign packet_out.fu = fu;
    assign packet_out.tag1_rdy = tag1_rdy;
    assign packet_out.tag2_rdy = tag2_rdy;
    assign packet_out.id_ex_packet = id_ex_packet;

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset || clear) begin
            valid           <= `SD 0;
            tag             <= `SD 0;
            tag1            <= `SD 0;
            tag2            <= `SD 0;
            pc              <= `SD 0;
            fu              <= `SD 0;
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
                {`BRAT_SIZE{1'b0}}
			}; 
        end 
        else if (packet_in.valid) begin
            valid           <= `SD 1;
            tag             <= `SD packet_in.tag;
            tag1            <= `SD packet_in.tag1;
            tag2            <= `SD packet_in.tag2;
            pc              <= `SD packet_in.pc;
            fu              <= `SD packet_in.fu;
            id_ex_packet    <= `SD packet_in.id_ex_packet;
            //brat_vec        <= `SD packet_in.brat_vec;
        end

    end
    
endmodule

module rs(
    input                   clock, reset,
    // dispatch's instructions is valid or not
    //TODO: input: id_ex_packet
    //      output: id_ex_packet
    //      function: change relevant values in id_ex_packet
    input   ID_EX_PACKET    id_ex_packet_in1, id_ex_packet_in2,
    input                   valid1_in, valid2_in,
    //input   [`AR_LEN-1:0]   arch_reg1_in, arch_reg2_in,
    //input   [`PR_LEN-1:0]   phy_reg1_in, phy_reg2_in,
    input   [`PC_LEN-1:0]   pc1_in, pc2_in,                         
    input   [`FU_LEN-1:0]   fu1_in, fu2_in,
    input                   mul_in_use1, mul_in_use2,
    /* inputs from cdb */
    input                   cdb1_valid_in, cdb2_valid_in,
    // rob  number
    input   [`ROB_LEN-1:0]  cdb1_tag_in, cdb2_tag_in,
    input   [`VALUE_SIZE-1:0]               cdb1_value, cdb2_value,
    input                            rat11_valid, rat12_valid, rat21_valid, rat22_valid,
    input   [`VALUE_SIZE-1:0]       rat11_value, rat12_value, rat21_value, rat22_value,
    input   [`PR_LEN-1:0]           regNum1, regNum2,
    input   [`BRAT_LEN-1:0]         correct_index1, correct_index2,
    input   [`BRAT_SIZE-1:0]        brat_mis,
    input   [`BRAT_SIZE-1:0]        brat_in_use1, brat_in_use2,

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
    RS_ENTRY_PACKET [`RS_SIZE-1:0] rs_arr ;
    RS_ENTRY_PACKET [`RS_SIZE-1:0] rs_arr_out ;


    // this is the main part of the rs
    rs_entry rs_body [`RS_SIZE-1:0] (
        .clock(clock), .reset(reset),
        .clear(clear_arr),
        .packet_in(rs_arr), 
        .packet_out(rs_arr_out)
    );
    logic [`RS_LEN-1:0]    rs_empty_idx1, rs_empty_idx2;
    logic [`RS_LEN-1:0]    rs_done_idx1, rs_done_idx2;
    logic                   rs_valid1, rs_valid2, rs_done1, rs_done2;
    
    
    empty_entry_selector empty_entry(
        .rs_arr(rs_arr_out),
        .rs_empty_idx1(rs_empty_idx1),
        .rs_empty_idx2(rs_empty_idx2),
        .rs_valid1(rs_valid1),
        .rs_valid2(rs_valid2)
    );

    done_entry_selector done_entry(
        .rs_arr(rs_arr_out),
        .mul_in_use1(mul_in_use1),
        .mul_in_use2(mul_in_use2),
        .rs_done_idx1(rs_done_idx1),
        .rs_done_idx2(rs_done_idx2),
        .rs_done1(rs_done1),
        .rs_done2(rs_done2)
    );

    
    assign issue_packet1.NPC            = rs_arr_out[rs_done_idx1].id_ex_packet.NPC;
    assign issue_packet1.PC             = rs_arr_out[rs_done_idx1].id_ex_packet.PC;
    assign issue_packet1.rs1_value      = rs_arr_out[rs_done_idx1].tag1;
    assign issue_packet1.rs2_value      = rs_arr_out[rs_done_idx1].tag2;
    assign issue_packet1.rs1_reg        = rs_arr_out[rs_done_idx1].id_ex_packet.rs1_reg;
    assign issue_packet1.rs2_reg        = rs_arr_out[rs_done_idx1].id_ex_packet.rs2_reg;
    assign issue_packet1.opa_select     = rs_arr_out[rs_done_idx1].id_ex_packet.opa_select;
    assign issue_packet1.opb_select     = rs_arr_out[rs_done_idx1].id_ex_packet.opb_select;
    assign issue_packet1.inst           = rs_arr_out[rs_done_idx1].id_ex_packet.inst;
    assign issue_packet1.dest_reg_idx   = rs_arr_out[rs_done_idx1].id_ex_packet.dest_reg_idx;
    assign issue_packet1.dest_phy_reg   = rs_arr_out[rs_done_idx1].tag;
    assign issue_packet1.alu_func       = rs_arr_out[rs_done_idx1].id_ex_packet.alu_func;
    assign issue_packet1.rd_mem         = rs_arr_out[rs_done_idx1].id_ex_packet.rd_mem;        
	assign issue_packet1.wr_mem         = rs_arr_out[rs_done_idx1].id_ex_packet.wr_mem;        
	assign issue_packet1.cond_branch    = rs_arr_out[rs_done_idx1].id_ex_packet.cond_branch;   
	assign issue_packet1.uncond_branch  = rs_arr_out[rs_done_idx1].id_ex_packet.uncond_branch; 
	assign issue_packet1.halt           = rs_arr_out[rs_done_idx1].id_ex_packet.halt;          
	assign issue_packet1.illegal        = rs_arr_out[rs_done_idx1].id_ex_packet.illegal;       
	assign issue_packet1.csr_op         = rs_arr_out[rs_done_idx1].id_ex_packet.csr_op;       
	assign issue_packet1.valid          = rs_arr_out[rs_done_idx1].id_ex_packet.valid;    
    assign issue_packet1.pred_taken     = rs_arr_out[rs_done_idx1].id_ex_packet.pred_taken;
    assign issue_packet1.brat_vec       = rs_arr_out[rs_done_idx1].id_ex_packet.brat_vec;     

    assign issue_packet2.NPC            = rs_arr_out[rs_done_idx2].id_ex_packet.NPC;
    assign issue_packet2.PC             = rs_arr_out[rs_done_idx2].id_ex_packet.PC;
    assign issue_packet2.rs1_value      = rs_arr_out[rs_done_idx2].tag1;
    assign issue_packet2.rs2_value      = rs_arr_out[rs_done_idx2].tag2;
    assign issue_packet2.rs1_reg        = rs_arr_out[rs_done_idx2].id_ex_packet.rs1_reg;
    assign issue_packet2.rs2_reg        = rs_arr_out[rs_done_idx2].id_ex_packet.rs2_reg;
    assign issue_packet2.opa_select     = rs_arr_out[rs_done_idx2].id_ex_packet.opa_select;
    assign issue_packet2.opb_select     = rs_arr_out[rs_done_idx2].id_ex_packet.opb_select;
    assign issue_packet2.inst           = rs_arr_out[rs_done_idx2].id_ex_packet.inst;
    assign issue_packet2.dest_reg_idx   = rs_arr_out[rs_done_idx2].id_ex_packet.dest_reg_idx;
    assign issue_packet2.dest_phy_reg   = rs_arr_out[rs_done_idx2].tag;
    assign issue_packet2.alu_func       = rs_arr_out[rs_done_idx2].id_ex_packet.alu_func;
    assign issue_packet2.rd_mem         = rs_arr_out[rs_done_idx2].id_ex_packet.rd_mem;        
	assign issue_packet2.wr_mem         = rs_arr_out[rs_done_idx2].id_ex_packet.wr_mem;        
	assign issue_packet2.cond_branch    = rs_arr_out[rs_done_idx2].id_ex_packet.cond_branch;   
	assign issue_packet2.uncond_branch  = rs_arr_out[rs_done_idx2].id_ex_packet.uncond_branch; 
	assign issue_packet2.halt           = rs_arr_out[rs_done_idx2].id_ex_packet.halt;          
	assign issue_packet2.illegal        = rs_arr_out[rs_done_idx2].id_ex_packet.illegal;       
	assign issue_packet2.csr_op         = rs_arr_out[rs_done_idx2].id_ex_packet.csr_op;       
	assign issue_packet2.valid          = rs_arr_out[rs_done_idx2].id_ex_packet.valid;   
    assign issue_packet2.pred_taken     = rs_arr_out[rs_done_idx2].id_ex_packet.pred_taken;
    assign issue_packet2.brat_vec       = rs_arr_out[rs_done_idx2].id_ex_packet.brat_vec; 

    assign full =   rs_valid2 ? 2'b11 :
                    rs_valid1 ? 2'b10 : 2'b00;
    always_comb begin
        //initialize
        rs_arr = '{
            (`RS_SIZE) {'{
            {`PR_LEN{1'b0}},
            {`VALUE_SIZE{1'b0}},
            {`VALUE_SIZE{1'b0}},
            {`PC_LEN{1'b0}},
            {`FU_LEN{1'b0}},
            1'b0,
            1'b0,
            1'b0,
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
                {`BRAT_SIZE{1'b0}}
			},
            {`BRAT_SIZE{1'b0}}
        }}};
        //dispatch
        if (valid1_in && rs_valid1) begin
            rs_arr[rs_empty_idx1] = '{
                regNum1,
                rat11_value,
                rat12_value,
                pc1_in,
                fu1_in,            
                rat11_valid,
                rat12_valid,            
                1'b1,
                id_ex_packet_in1,
                brat_in_use1                  
            };
        end
        if (valid2_in &&rs_valid2) begin
            rs_arr[rs_empty_idx2] = '{
                regNum2,
                rat21_value,
                rat22_value,
                pc2_in,
                fu2_in,        
                rat21_valid,
                rat22_valid,               
                1'b1,
                id_ex_packet_in2,
                brat_in_use2                 
            };
        end     
        //issue
        if (rs_done1) begin
            rs_arr[rs_done_idx1] = '{
            {`PR_LEN{1'b0}},
            {`VALUE_SIZE{1'b0}},
            {`VALUE_SIZE{1'b0}},
            {`PC_LEN{1'b0}},
            {`FU_LEN{1'b0}},
            1'b0,
            1'b0,
            1'b0,
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
                {`BRAT_SIZE{1'b0}}
			},
            {`BRAT_SIZE{1'b0}}
        };
        end
        if (rs_done2) begin
            rs_arr[rs_done_idx2] = '{
            {`PR_LEN{1'b0}},
            {`VALUE_SIZE{1'b0}},
            {`VALUE_SIZE{1'b0}},
            {`PC_LEN{1'b0}},
            {`FU_LEN{1'b0}},
            1'b0,
            1'b0,
            1'b0,
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
                {`BRAT_SIZE{1'b0}}
			},
            {`BRAT_SIZE{1'b0}}
        };
        end


        //shift when issue
        for (int i=0; i< `RS_SIZE; i++) begin
            if (rs_arr[i].valid) begin
                rs_arr[i].brat_vec = rs_arr[i].brat_vec - (1<<correct_index1) + (rs_arr[i].brat_vec & ((1<<correct_index1)-1'b1));
                rs_arr[i].brat_vec = rs_arr[i].brat_vec - (1<<correct_index2) + (rs_arr[i].brat_vec & ((1<<correct_index2)-1'b1));
            end
        end

        // get value from CDB
        if (cdb1_valid_in) begin
            for (int i = 0; i < `RS_SIZE; i++) begin
                if (rs_arr[i].tag1 == cdb1_tag_in) begin
                    rs_arr[i].tag1_rdy = 1;
                    rs_arr[i].tag1 = cdb1_value;
                end
                if (rs_arr[i].tag2 == cdb1_tag_in) begin
                    rs_arr[i].tag2_rdy = 1;
                    rs_arr[i].tag2 = cdb1_value;
                end
            end
        end
        if (cdb2_valid_in) begin
            for (int i = 0; i < `RS_SIZE; i++) begin
                if (rs_arr[i].tag1 == cdb2_tag_in) begin
                    rs_arr[i].tag1_rdy = 1;
                    rs_arr[i].tag1 = cdb2_value;
                end
                if (rs_arr[i].tag2 == cdb2_tag_in) begin
                    rs_arr[i].tag2_rdy = 1;
                    rs_arr[i].tag2 = cdb2_value;
                end
            end
        end

        //Squash
        
        for (int i=0; i< `RS_SIZE; i++) begin
            if (rs_arr[i].id_ex_packet.brat_vec > brat_mis) begin
                rs_arr[i] = '{
                {`PR_LEN{1'b0}},
                {`VALUE_SIZE{1'b0}},
                {`VALUE_SIZE{1'b0}},
                {`PC_LEN{1'b0}},
                {`FU_LEN{1'b0}},
                1'b0,
                1'b0,
                1'b0,
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
                    {`BRAT_SIZE{1'b0}}
                },
                {`BRAT_SIZE{1'b0}}
                };
            end
        end

        //retire

    end
endmodule

`endif
