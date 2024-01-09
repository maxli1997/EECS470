`timescale 1ns/100ps


`define DCACHE_SET_IDX_BITS 4
`define DCACHE_SET         (1<<`DCACHE_SET_IDX_BITS)
`define DCACHE_TAG_BITS (16-3-`DCACHE_SET_IDX_BITS)
`define SD 1

module testbench;
    logic	clock, reset;
    logic   wr1_en;
    logic   rd1_en;
    logic  [3:0] wr1_idx, rd1_idx;
    logic  [8:0] wr1_tag, rd1_tag;
    logic [63:0] wr1_data;

    logic [63:0] rd1_data;
    logic rd1_valid;
    logic [`DCACHE_SET-1:0][1:0][63:0] data;

    logic [31:0] rd_addr;
    logic [31:0] wr_addr;

    assign rd1_idx = rd_addr[6:3];
    assign rd1_tag = rd_addr[15:7];
    assign wr1_idx = wr_addr[6:3];
    assign wr1_tag = wr_addr[15:7];

    dcachemem d(
        .clock, .reset,
        .wr1_en,
        .rd1_en,
        .wr1_idx, .rd1_idx,
        .wr1_tag, .rd1_tag,
        .wr1_data, 
        .rd1_data,
        .rd1_valid,
        .data
    );

    always begin
        #5 clock=~clock;
    end


    task show_cache;        
        input [`DCACHE_SET-1:0][1:0][63:0] data;
        input [10:0]                       cnt;
        begin
            $display("@@@\t\tCycle %d", cnt);

            $display("@@@\tSet#\tdata");
            for (int i = 0; i < `DCACHE_SET; i++) begin
                $display("@@@%9d%9d",
                    i, data[i][0]);
                $display("@@@         %9d", data[i][1]);
            end

            $display("@@@");
        end
    endtask  // show_lsq


    initial begin
        clock = 0;
        reset = 1;
        wr1_en = 0;
        rd1_en = 0;
        rd_addr = 0;
        wr_addr = 0;
        @(negedge clock)
        reset = 0;
        rd_addr = 32'h00000000;
        wr_addr = 32'h00000008;
        wr1_data = 15;
        rd1_en = 1;
        wr1_en = 1;
        show_cache(data, $time);
        $display("rw idx: %d, tag: %d at %d", wr1_idx, wr1_tag, $time);
        $display("rd1 valid: %d, data %d", rd1_valid, rd1_data);
        @(negedge clock)
        #1;
        wr1_en = 1;
        wr_addr = 32'h00000208;
        rd_addr = 32'h00000008;
        wr1_data = 5;
        rd1_en = 1;
        #1;
        show_cache(data, $time);
        $display("rd idx: %d, tag: %d at %d", rd1_idx, rd1_tag, $time);
        $display("rd1 valid: %d, data %d", rd1_valid, rd1_data);
        @(negedge clock)
        rd_addr = 32'h00000208;
        wr1_data = 10;
        #1;

        show_cache(data, $time);
        $display("rd idx: %d, tag: %d at %d", rd1_idx, rd1_tag, $time);
        $display("rd1 valid: %d, data %d", rd1_valid, rd1_data);
        @(negedge clock)
        wr_addr = 32'h00001118;
        wr1_data = 13;
        rd1_en = 0;
        show_cache(data, $time);
        @(negedge clock)
        rd_addr = 32'h00001108;
        show_cache(data, $time);
        $display("rd1 valid: %d, data %d", rd1_valid, rd1_data);
        $display("@@@ PASSED");
        $finish;
    end


endmodule