`timescale 1ns/100ps
// `include "./mult.sv"

    // task print_helper;
    //     input EX_PACKET pkt;
    //     begin
    //         if (pkt.valid) begin
    //             $write("%8h", pkt.result);
    //         end else begin
    //             $write("%8h", pkt.result);
    //         end
    //     end
    // endtask

    // task print_ex_packet;
    //     input EX_PACKET pkt1;
    //     input EX_PACKET pkt1_mul;
    //     input EX_PACKET pkt2;
    //     input EX_PACKET pkt2_mul;
    //     begin
    //         $write("@@@ ");
    //         print_helper(pkt1);
    //         print_helper(pkt1_mul);
    //         print_helper(pkt2);
    //         print_helper(pkt2_mul);
    //         $write("\n");
    //     end
    // endtask

module adder_substractor(                                                   // completely non-sequential
	input           [`XLEN-1:0] opa,
	input           [`XLEN-1:0] opb,
	input           ALU_FUNC    func,

	output logic    [`XLEN-1:0] result,
    output                      valid                                       // if the input instruction is an
                                                                            // operation that can be handled here
                                                                            // i.e. ADD, SUB, ADD, SLT, SLTU, OR,
                                                                            // XOR, SRL, SLL or SRA.
);
                                                                            // use valid bit in packet to identify
                                                                            // if a packet contains valid data. it
                                                                            // was originally used for statistics,
                                                                            // might add an extra bit in packet if
                                                                            // we want to preserve the original
                                                                            // functionality.
	wire signed [`XLEN-1:0]     signed_opa, signed_opb;
	wire signed [2*`XLEN-1:0]   signed_mul, mixed_mul;
	wire        [2*`XLEN-1:0]   unsigned_mul;
    logic                       valid_reg;
	assign signed_opa = opa;                                                // untouched
	assign signed_opb = opb;
    assign valid = valid_reg;

	always_comb begin
        valid_reg = 1;
		case (func)
			ALU_ADD:        result = opa + opb;
			ALU_SUB:        result = opa - opb;
			ALU_AND:        result = opa & opb;
			ALU_SLT:        result = signed_opa < signed_opb;
			ALU_SLTU:       result = opa < opb;
			ALU_OR:         result = opa | opb;
			ALU_XOR:        result = opa ^ opb;
			ALU_SRL:        result = opa >> opb[4:0];
			ALU_SLL:        result = opa << opb[4:0];
			ALU_SRA:        result = signed_opa >>> opb[4:0];               // arithmetic from logical shift

			default: begin
                            result = `XLEN'hfacebeec;                       // here to prevent latches
                            valid_reg  = 0;
            end
		endcase
	end
endmodule

module brcond(                                                              // completely non-sequential
	input [`XLEN-1:0] rs1,                                                  // values to check against condition
	input [`XLEN-1:0] rs2,
	input  [2:0] func,                                                      // specifies which condition to check

	output logic cond                                                       // 0/1 condition result (False/True)
);

	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	always_comb begin
		cond = 0;
		case (func)
			3'b000: cond = signed_rs1 == signed_rs2;                        // BEQ
			3'b001: cond = signed_rs1 != signed_rs2;                        // BNE
			3'b100: cond = signed_rs1 < signed_rs2;                         // BLT
			3'b101: cond = signed_rs1 >= signed_rs2;                        // BGE
			3'b110: cond = rs1 < rs2;                                       // BLTU
			3'b111: cond = rs1 >= rs2;                                      // BGEU
		endcase
	end
	
endmodule


module ex(
	input                       clock,                                      // system clock
	input                       reset,                                      // system reset
	input   [`BRAT_SIZE-1:0]    brat_idx,                                   // from BRAT 
    input   ID_EX_PACKET        issue_pkt_in,
    input                       issue_valid,
    input   [`BRAT_SIZE-1:0]    brat_mis,
    input                       brat_mis_valid,
    input                       c_valid1, c_valid2,
    input [`BRAT_LEN-1:0]       c_index1, c_index2,

	output  EX_PACKET           ex_packet_out_mul,
    output  EX_PACKET           ex_packet_out_non_mul,
    output                      mul_will_done,
    output                      mul_free
);

    logic [`XLEN-1:0]       opa_mux_out, opb_mux_out;
	logic                   brcond_result;
    logic [`XLEN-1:0]       add_sub_rst, mul_rst;
    logic                   is_add_sub, is_mul;
    ID_EX_PACKET            mul_cache;
    logic [`BRAT_SIZE-1:0]  mul_brat;
    logic                   mul_done, in_use;

	// ALU opA mux
	always_comb begin
		opa_mux_out = `XLEN'hdeadfbac;
		case (issue_pkt_in.opa_select)
			OPA_IS_RS1:  opa_mux_out = issue_pkt_in.rs1_value;
			OPA_IS_NPC:  opa_mux_out = issue_pkt_in.NPC;
			OPA_IS_PC:   opa_mux_out = issue_pkt_in.PC;
			OPA_IS_ZERO: opa_mux_out = 0;
		endcase
	end

	 // ALU opB mux
	always_comb begin
		opb_mux_out = `XLEN'hfacefeed;
		case (issue_pkt_in.opb_select)
			OPB_IS_RS2:   opb_mux_out = issue_pkt_in.rs2_value;
			OPB_IS_I_IMM: opb_mux_out = `RV32_signext_Iimm(issue_pkt_in.inst);
			OPB_IS_S_IMM: opb_mux_out = `RV32_signext_Simm(issue_pkt_in.inst);
			OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(issue_pkt_in.inst);
			OPB_IS_U_IMM: opb_mux_out = `RV32_signext_Uimm(issue_pkt_in.inst);
			OPB_IS_J_IMM: opb_mux_out = `RV32_signext_Jimm(issue_pkt_in.inst);
		endcase 
	end

	adder_substractor alu_0 (
		.opa(opa_mux_out),
		.opb(opb_mux_out),
		.func(issue_pkt_in.alu_func),

		.result(add_sub_rst),
        .valid(is_add_sub)
	);

    mult mul_0 (
        .clock(clock), 
        .reset(reset),
		.func(issue_pkt_in.alu_func),
		.mcand(opa_mux_out), 
        .mplier(opb_mux_out),
        .mult_valid(issue_valid),
        .brat_idx(brat_idx),
        .brat_mis(brat_mis),
        .brat_mis_valid(brat_mis_valid),
        .cache_in(issue_pkt_in),
        .c_valid1(c_valid1), .c_valid2(c_valid2),
		.c_index1(c_index1), .c_index2(c_index2),
				
		.product_out(mul_rst),
		.will_done(mul_will_done),                                          // indicate that the multiplier will
                                                                            // be done in the next cycle. when RS
                                                                            // see this, it should not issue any
                                                                            // operation.
        .done(mul_done),                                                    // when the multiplier is buzy but its
                                                                            // result is not going to be valid in
                                                                            // the next cycle, non-multiplication
                                                                            // operations are allowed to be issued.
        .in_use(in_use),
        .brat_idx_out(mul_brat),
        .cache_out(mul_cache)
    );

	brcond brcond (
		.rs1(issue_pkt_in.rs1_value), 
		.rs2(issue_pkt_in.rs2_value),
		.func(issue_pkt_in.inst.b.funct3),                                  // inst bits to determine check

		.cond(brcond_result)
	);

    assign mul_free = (mul_done | ~in_use) & !(issue_valid & issue_pkt_in.alu_func > 5'h09 & issue_pkt_in.alu_func < 5'h0e); 
    always_comb begin
        if (mul_done == 1) begin                                            // if multiplication done, there cannot
                                                                            // be any other operation that finishes
                                                                            // computation.
            ex_packet_out_mul.result        = mul_rst;
            ex_packet_out_mul.valid         = 1;
            ex_packet_out_mul.NPC           = mul_cache.NPC;
            ex_packet_out_mul.rob_num       = mul_cache.rob_num;
            ex_packet_out_mul.rs2_value     = mul_cache.rs2_value;
            ex_packet_out_mul.rd_mem        = mul_cache.rd_mem;
            ex_packet_out_mul.wr_mem        = mul_cache.wr_mem;
            ex_packet_out_mul.dest_phy_reg  = mul_cache.dest_phy_reg;
            ex_packet_out_mul.halt          = mul_cache.halt;
            ex_packet_out_mul.illegal       = mul_cache.illegal;
            ex_packet_out_mul.csr_op        = mul_cache.csr_op;
            ex_packet_out_mul.mem_size      = mul_cache.inst.r.funct3;
            ex_packet_out_mul.cond_branch   = mul_cache.cond_branch;
            ex_packet_out_mul.uncond_branch = mul_cache.uncond_branch;
            // shift in the multiplier
            ex_packet_out_mul.brat_vec      = mul_brat;
            if (brat_mis_valid && (mul_brat > brat_mis)) begin                                      
                ex_packet_out_mul.valid = 0;
            end
        end else begin                                                      // otherwise, the instruction that has
                                                                            // finished must be from alu_0 if any
            ex_packet_out_mul.valid             = 0;
        end
        ex_packet_out_non_mul.NPC           = issue_pkt_in.NPC;
        ex_packet_out_non_mul.rs2_value     = issue_pkt_in.rs2_value;
        ex_packet_out_non_mul.rob_num       = issue_pkt_in.rob_num;
        ex_packet_out_non_mul.rd_mem        = issue_pkt_in.rd_mem;
        ex_packet_out_non_mul.wr_mem        = issue_pkt_in.wr_mem;
        ex_packet_out_non_mul.dest_phy_reg  = issue_pkt_in.dest_phy_reg;
        ex_packet_out_non_mul.halt          = issue_pkt_in.halt;
        ex_packet_out_non_mul.illegal       = issue_pkt_in.illegal;
        ex_packet_out_non_mul.csr_op        = issue_pkt_in.csr_op;
        ex_packet_out_non_mul.mem_size      = issue_pkt_in.inst.r.funct3;
        ex_packet_out_non_mul.result        = add_sub_rst;
        ex_packet_out_non_mul.valid         = issue_valid & ~reset & is_add_sub;
        ex_packet_out_non_mul.cond_branch   = issue_pkt_in.cond_branch;
        ex_packet_out_non_mul.uncond_branch = issue_pkt_in.uncond_branch;
        ex_packet_out_non_mul.brat_vec      = issue_pkt_in.brat_vec;
        // shift when branch correctly resolved
        if (c_valid1 && issue_pkt_in.brat_vec[c_index1]) begin
            ex_packet_out_non_mul.brat_vec = issue_pkt_in.brat_vec - (1<<c_index1) + (issue_pkt_in.brat_vec & ((1<<c_index1)-1'b1));
            if (c_valid2 && ex_packet_out_non_mul.brat_vec[c_index2])
                ex_packet_out_non_mul.brat_vec = ex_packet_out_non_mul.brat_vec - (1<<c_index2) + (ex_packet_out_non_mul.brat_vec & ((1<<c_index2)-1'b1));
        end
        else if (c_valid2 && issue_pkt_in.brat_vec[c_index2]) begin
            ex_packet_out_non_mul.brat_vec = issue_pkt_in.brat_vec - (1<<c_index2) + (issue_pkt_in.brat_vec & ((1<<c_index2)-1'b1));
        end
        //$display("issue_valid brat_idx:%b %d",issue_pkt_in.brat_vec, $time);
        if (brat_mis_valid && (brat_idx > brat_mis)) begin                                      
            ex_packet_out_non_mul.valid = 0;
        end
    end
	assign ex_packet_out_non_mul.take_branch = issue_pkt_in.uncond_branch
		                          | (issue_pkt_in.cond_branch & brcond_result);
    assign ex_packet_out_mul.take_branch = 0; // for mult, always not taken
endmodule

module ex_stage (
    input                       clock,                                      // system clock
	input                       reset,                                      // system reset
	input   [`BRAT_SIZE-1:0]    brat_idx_1, brat_idx_2,                     // from BRAT 
    input   ID_EX_PACKET        issue_pkt_in_1, issue_pkt_in_2,
    input                       issue_valid_1, issue_valid_2,
    input   [`BRAT_SIZE-1:0]    brat_mis,
    input                       brat_mis_valid,
    input                       c_index1_valid, c_index2_valid,
    input  [`BRAT_LEN-1:0]      c_index1, c_index2,
	output  EX_PACKET           ex_packet_out_1_non_mul, ex_packet_out_1_mul, ex_packet_out_2_non_mul, ex_packet_out_2_mul,
    output                      mul_will_done_1, mul_will_done_2,
    output                      mul_done_1, mul_done_2
);
    ex ex_1 (                                                               // simply instantiate 2 sets of ex
                                                                            // module as it makes no difference.
                                                                            // when mul in ex_1 is occupied, RS
                                                                            // can issue to ex_2 if it is free.
        .clock(clock),
        .reset(reset),
        .brat_idx(brat_idx_1),
        .issue_pkt_in(issue_pkt_in_1),
        .issue_valid(issue_valid_1),
        .brat_mis(brat_mis),
        .brat_mis_valid(brat_mis_valid),
        .c_valid1(c_index1_valid), .c_valid2(c_index2_valid),
        .c_index1(c_index1), .c_index2(c_index2),

        .ex_packet_out_mul(ex_packet_out_1_mul),
        .ex_packet_out_non_mul(ex_packet_out_1_non_mul),
        .mul_will_done(mul_will_done_1),
        .mul_free(mul_done_1)
    );

    ex ex_2 (
        .clock(clock),
        .reset(reset),
        .brat_idx(brat_idx_2),
        .issue_pkt_in(issue_pkt_in_2),
        .issue_valid(issue_valid_2),
        .brat_mis(brat_mis),
        .brat_mis_valid(brat_mis_valid),
        .c_valid1(c_index1_valid), .c_valid2(c_index2_valid),
        .c_index1(c_index1), .c_index2(c_index2),
        
        .ex_packet_out_mul(ex_packet_out_2_mul),
        .ex_packet_out_non_mul(ex_packet_out_2_non_mul),
        .mul_will_done(mul_will_done_2),
        .mul_free(mul_done_2)
    );

    // always_comb begin

    // end

endmodule
