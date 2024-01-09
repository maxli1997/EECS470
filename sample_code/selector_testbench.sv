`timescale 1ns/100ps

module testbench;

    logic [7:0] req;
    wor [7:0] gnt;
    logic [1:0][2:0] encode;
    wand [8*2-1:0] gnt_bus;
    wire empty;
    logic en, req_up;

    psel_gen p(req, gnt, gnt_bus, empty);
    // ps p(req, en, gnt, req_up);
    pe enc [1:0] (gnt_bus, encode);
    logic clock;

    always begin
        #5 clock=~clock;    
    end

    initial begin
        clock = 0;
        en = 1;
        req = 8'b11111111;
        @(negedge clock);
        req = 8'b00000001;
        #1
        $display("gnt: %b rant_bus: %b", gnt, gnt_bus);
        $display("encode1: %d", encode[0]);
        $display("encode2: %d", encode[1]);
        @(negedge clock);
        req = 8'b11111110;
        #1
        $display("gnt: %b grant_bus: %b", gnt, gnt_bus);
        @(negedge clock);
        req = 8'b01111110;
        $display("gnt: %b", gnt);
        @(negedge clock);
        req = 8'b00000111;
        $display("gnt: %b", gnt);
        @(negedge clock);
        req = 8'b00111110;
        $display("gnt: %b", gnt);
        @(negedge clock);
        req = 8'b11111111;
        $display("gnt: %b", gnt);
        @(negedge clock);
        req = 8'b11111110;
        $display("gnt: %b", gnt);
        @(negedge clock)
        $finish;


    end    


endmodule