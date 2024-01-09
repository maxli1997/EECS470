/////////////////////////////////////////////////////////////////////////
//                                                                     //
//  Modulename :  freelist.sv                                          //
//                                                                     //
//  Description :  This module creates the physical register file and  // 
//                 store value in it.                                  //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __FREELIST_SV__
`define __FREELIST_SV__

`timescale 1ns/100ps

module pe(gnt,enc);
        //synopsys template
        parameter OUT_WIDTH=6;
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
  parameter WIDTH = 64;

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

// regNum1,regNum2, success1, success2 become wire
module freelist(
	input								clock, reset,
	input								request1,request2,
	input ROB_RETIRE_PACKET				retire_pkt_1, retire_pkt_2,
	input								mispredictSet,

	input [`PR_SIZE-1:0]				listIn,

	output	logic						success1,success2,
	output	logic [`PR_LEN-1:0]			regNum1_out,regNum2_out,
	output 	logic [`PR_SIZE-1:0]		listOut,
	// these are output to brat for backup
	output 	logic [`PR_SIZE-1:0]		listOut1, listOut2
);

	
	// counter must be larger than PR_LEN to hold the value
	logic [`PR_LEN:0]		freeCounter;
	logic [`PR_SIZE-1:0]	listNxt;

	logic [`PR_SIZE-1:0]	free_request;
	logic [`PR_SIZE-1:0]	free_gnt;
	logic [2*`PR_SIZE-1:0]	free_gnt_bus;
	logic					empty;
	logic [`PR_LEN-1:0]		regNum1, regNum2;

	
	assign free_request = ~listOut;
	
	psel_gen #(.REQS(2), .WIDTH(`PR_SIZE)) sel(free_request, free_gnt, free_gnt_bus, empty);
	pe #(.OUT_WIDTH(`PR_LEN)) encoder1(free_gnt_bus[2*`PR_SIZE-1:`PR_SIZE], regNum1);
	pe #(.OUT_WIDTH(`PR_LEN)) encoder2(free_gnt_bus[`PR_SIZE-1:0], regNum2);

	assign regNum1_out = request1 ? regNum1 : 0;
	assign regNum2_out = request2 ? regNum2 : 0;
	
	always_comb begin
		listNxt = listOut;
		listOut1 = listNxt;
		listOut2 = listNxt;
		if(mispredictSet) begin
			listNxt = listIn;
		end
		else begin
			freeCounter = 0;
			if(retire_pkt_1.retire_valid)
				listNxt[retire_pkt_1.prev_phy_reg] = 0;
			if(retire_pkt_2.retire_valid)
				listNxt[retire_pkt_2.prev_phy_reg] = 0;

			/* The request for first inst succeed if freecounter >= 1 and request1*/
			success1 = ((free_gnt >= 1) & request1);
			/* The request for second inst succeed if (freecounter >= 2 and request2) or (freecounter >= 1 and not request1)*/
			success2 = ((free_gnt >= 3) & request2) | ((free_gnt >= 1) & !request1);
			if(request1 & success1) begin 
				listNxt[regNum1] = 1;
			end
			/* whether listNxt get updated, listOut1 should be updated as well */
			listOut1 = listNxt;
			if(request2 & success2) begin 
				listNxt[regNum2] = 1;
			end
			/* whether listNxt get updated, listOut2 should be updated as well */
			listOut2 = listNxt;
		end
	end
	
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			listOut <= `SD 0;
		end
		else begin
			listOut <= listNxt;
		end
	end
	
endmodule
`endif