`ifndef __MULT_SV__
`define __MULT_SV__

module mult #(parameter XLEN = 32, parameter NUM_STAGE = 4) (
				input 					clock, reset,
			//	input 					start,								// assume that a multiply instruction 
																			// will appear only when multiplier is
																			// not buzy, so that when ever there is
																			// a multiplication, accept it.
			// 	input [1:0] 			sign,								// handle sign by parsing func (might
																			// be errorneous due to unfamiliar ops)
				input  ALU_FUNC			func,
				input  [XLEN-1:0]	 	mcand, mplier,
				input  [`BRAT_SIZE-1:0] brat_mis, brat_idx,
				input  ID_EX_PACKET		cache_in,
				input					mult_valid,
				input					brat_mis_valid,
				input  [`BRAT_LEN-1:0]  correct_index1, correct_index2,         // the correct shift index
    			input                   index1_valid, index2_valid,
				
				output [XLEN-1:0] 	product_out,
				output 					done, will_done, in_use,
				output ID_EX_PACKET		cache_out,
				output [`BRAT_SIZE-1:0]	brat_idx_out
			);
	logic [(2*XLEN)-1:0] mcand_out, mplier_out, mcand_in, mplier_in;
	logic [NUM_STAGE:0][2*XLEN-1:0] internal_mcands, internal_mpliers;
	logic [NUM_STAGE:0][2*XLEN-1:0] internal_products;
	logic [NUM_STAGE:0] internal_dones;
	logic [(2*XLEN)-1:0] product;
	logic done_reg;

	logic start;
	logic in_use_reg;
	logic [1:0] sign;
	logic [`BRAT_SIZE-1:0] brat_idx_reg, brat_idx_buffer;
	ID_EX_PACKET cache;

	assign cache_out = cache;
	assign brat_idx_out = brat_idx_reg;

	assign sign 	= 	(mult_valid == 0) ? 2'b01 : (func == ALU_MUL || func == ALU_MULH) ? 2'b11 :
						func == ALU_MULHSU ? 2'b10 :
						func == ALU_MULHU ? 2'b00 : 2'b01;					// 2'b01 means it's not multiplication
																			// or the input operation is not valid

//	assign start 	=	1;
	assign start	=   (sign != 2'b01) & (brat_idx <= brat_mis || brat_mis_valid == 0);
																			// start the multiplication if we see a
																			// multiplication which is not going to
																			// be squashed.

	assign mcand_in  = sign[0] ? {{XLEN{mcand[XLEN-1]}}, mcand}   : {{XLEN{1'b0}}, mcand} ;
	assign mplier_in = sign[1] ? {{XLEN{mplier[XLEN-1]}}, mplier} : {{XLEN{1'b0}}, mplier};

	assign internal_mcands[0]   = mcand_in;
	assign internal_mpliers[0]  = mplier_in;
	assign internal_products[0] = 'h0;
	assign internal_dones[0]    = start;

    assign done    		= internal_dones[NUM_STAGE];
	assign will_done	= internal_dones[NUM_STAGE - 1];
	assign product 		= internal_products[NUM_STAGE];
	assign product_out	= (cache.alu_func == ALU_MUL) ? product[XLEN-1:0] : product[2*XLEN-1:XLEN];
	assign in_use		= in_use_reg;

	genvar i;
	for (i = 0; i < NUM_STAGE; ++i) begin : mstage
		mult_stage #(.XLEN(XLEN), .NUM_STAGE(NUM_STAGE)) ms (
			.clock(clock),
			.reset(reset || (brat_mis_valid && (brat_idx_reg > brat_mis)) || (done & ~start)),						
																			// clear stages if the multiplication
																			// undergoing needs to be squashed.
			.product_in(internal_products[i]),
			.mplier_in(internal_mpliers[i]),
			.mcand_in(internal_mcands[i]),
			.start(internal_dones[i]),
			.product_out(internal_products[i+1]),
			.mplier_out(internal_mpliers[i+1]),
			.mcand_out(internal_mcands[i+1]),
			.done(internal_dones[i+1])
		);
	end

	// handel brat_vec update when a correctly predicted branch is committed
	always_comb begin
		brat_idx_buffer = brat_idx_reg;
		if (index1_valid) begin
			brat_idx_buffer = brat_idx_buffer - (1<<correct_index1) + (brat_idx_buffer & ((1<<correct_index1)-1'b1));
		end
		if (index2_valid) begin
			brat_idx_buffer = brat_idx_buffer - (1<<correct_index1) + (brat_idx_buffer & ((1<<correct_index1)-1'b1));
		end
	end

	always_ff @(posedge clock) begin
		if (reset || (brat_mis_valid && (brat_idx_reg > brat_mis)) || (done & ~start)) begin
			brat_idx_reg <= `SD 0;
			in_use_reg <= `SD 0;
			done_reg <= `SD 0;
		end else if (sign != 2'b01 && start) begin							// if encounters a multilpication, the 
																			// preceeding multiplication must have
																			// ended. we update the brat idx if it is
																			// going to be excecuted afterwards. we
																			// didn't change brat idx when finishing
																			// a multiplication as erasing it doesn't
																			// cause any trouble anyway
			brat_idx_reg <= `SD brat_idx;
			cache		 <= `SD cache_in;									// update cache in the meantime
			in_use_reg		 <=	`SD 1;
		end else if (done) begin											
			in_use_reg		 <= `SD 0;
			done_reg <= `SD 1;
		end else begin
			brat_idx_reg <= brat_idx_buffer;								// assume that when the multiplication is
																			// just starting. It's incomming brat_vec
																			// should have been handled by rs
		end
	end
endmodule

module mult_stage #(parameter XLEN = 32, parameter NUM_STAGE = 4) (
					input clock, reset, start,
					input [(2*XLEN)-1:0] mplier_in, mcand_in,
					input [(2*XLEN)-1:0] product_in,

					output logic done,
					output logic [(2*XLEN)-1:0] mplier_out, mcand_out,
					output logic [(2*XLEN)-1:0] product_out
				);

	parameter NUM_BITS = (2*XLEN)/NUM_STAGE;

	logic [(2*XLEN)-1:0] prod_in_reg, partial_prod, next_partial_product, partial_prod_unsigned;
	logic [(2*XLEN)-1:0] next_mplier, next_mcand;

	assign product_out = prod_in_reg + partial_prod;

	assign next_partial_product = mplier_in[(NUM_BITS-1):0] * mcand_in;

	assign next_mplier = {{(NUM_BITS){1'b0}},mplier_in[2*XLEN-1:(NUM_BITS)]};
	assign next_mcand  = {mcand_in[(2*XLEN-1-NUM_BITS):0],{(NUM_BITS){1'b0}}};

	//synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		prod_in_reg      <= product_in;
		partial_prod     <= next_partial_product;
		mplier_out       <= next_mplier;
		mcand_out        <= next_mcand;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			done     <= 1'b0;
		end else begin
			done     <= start;
		end
	end

endmodule
`endif //__MULT_SV__
