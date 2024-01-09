/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  cachemen.sv                                         //
//                                                                     //
//  Description :  Set associative data cache module                   //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __D_CACHEMEM__
`define __D_CACHEMEM__
`define DCACHE_SET_IDX_BITS 4
`define DCACHE_SET         (1<<`DCACHE_SET_IDX_BITS)
`define DCACHE_TAG_BITS (13-`DCACHE_SET_IDX_BITS)
`define SD 1

`timescale 1ns/100ps

module dcachemem(
        input clock, reset, wr1_en,
        input   rd1_en,
        input  [3:0] wr1_idx, rd1_idx,
        input  [8:0] wr1_tag, rd1_tag,
        input [63:0] wr1_data, 

        output [63:0] rd1_data,
        output rd1_valid,
        output logic [`DCACHE_SET-1:0][1:0][63:0] data
        
      );
  logic [`DCACHE_SET-1:0] set_rd_en;
  logic [`DCACHE_SET-1:0] set_wr_en;
  logic [`DCACHE_SET-1:0] set_rd_valid;
  logic [`DCACHE_SET-1:0][63:0] set_rd_data;
  // logic [`DCACHE_SET-1:0][1:0][63:0] data;

  assign rd1_data = set_rd_data[rd1_idx];
  assign rd1_valid = set_rd_valid[rd1_idx];

  always_comb begin
    set_rd_en = 0;
    set_rd_en[rd1_idx] = rd1_en;
    set_wr_en = 0;
    set_wr_en[wr1_idx] = wr1_en;
  end

  generate;
    genvar i;
    for (i=0; i<`DCACHE_SET; i++) begin
      dcache_set cache_sets (
            clock, reset,
            set_rd_en[i], rd1_tag,
            set_wr_en[i], wr1_tag,
            wr1_data, set_rd_data[i],
            set_rd_valid[i],
            data[i]
      );
    end
  endgenerate

endmodule

// a two-way set
module dcache_set(
  input                         clock, reset,
  input                         rd_en,
  input [`DCACHE_TAG_BITS-1:0]  rd_tag,
  input                         wr_en,
  input [`DCACHE_TAG_BITS-1:0]  wr_tag,
  input [63:0]                  wr_data,
  output [63:0]                 rd_data,
  output                        rd_valid,
  output logic [1:0][63:0] data
);

  logic [1:0][63:0] data;
  logic [1:0][`DCACHE_TAG_BITS-1:0] tags;
  logic [1:0] valids;
  logic recent;
  logic rd_miss, rd_way, wr_way; // way 0 or way 1

  //assign wr_way = wr_en ? (wr_tag == tags[1]) ? 1 : ((wr_tag == tags[0]) ? 0 : (recent ? 0 : 1)) : 0;

  assign rd_data = (wr_tag == rd_tag & rd_en & wr_en) ? wr_data :
                                             (rd_way)  ? data[1] : data[0];
  assign rd_valid = (rd_en & wr_en & wr_tag == rd_tag) ? 1 : 
                                    (rd_en & !rd_miss) ? (rd_way ? valids[1] : valids[0]) : 0;

  always_comb begin
    rd_miss = 0;
    if (rd_en) begin
      if			((rd_tag == tags[1]) && valids[1]) 
        rd_way = 1'b1;
      else if	((rd_tag == tags[0]) && valids[0]) 
        rd_way = 1'b0;
      else		
        rd_miss = 1'b1;
    end
    if(wr_en) begin
				if			(wr_tag == tags[1])	wr_way = 1'b1;
				else if	(wr_tag == tags[0])	wr_way = 1'b0;
				else if (recent == 0)		wr_way = 1'b1;
				else if (recent == 1)		wr_way = 1'b0;
				else		wr_way = 1'b0;
    end
    // if (wr_en) begin
    //   $display("write enable and write to way %d at time %d", wr_way, $time);
    // end
  end

  //synopsys sync_set_reset "reset"
  always_ff @(posedge clock) begin
    if (reset) begin
      valids <= 0;
      data   <= 0;
      recent <= 0;
    end    
    else begin
      if (wr_en) begin
        // $display("write enable and write to way %d", wr_way);
        if (wr_way) begin
          data[1]   <=  wr_data;
          tags[1]   <=  wr_tag;
          recent    <=  1;
          valids[1] <=  1;
        end
        else begin
          data[0]   <=  wr_data;
          tags[0]   <=  wr_tag;
          recent    <=  0;
          valids[0] <=  1;
        end
      end
      if (rd_en && !rd_miss) begin
          recent <=  (rd_way) ? 1 : 0;
      end
    end
  end

endmodule

`endif