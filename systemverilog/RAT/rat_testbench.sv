`timescale 1ns/100ps

module testbench;
    logic                   clock, reset;
    /* inputs from dispatch stage */
    logic                   valid1_in, valid2_in;
    logic   [`AR_LEN-1:0]   reg11_in, reg12_in;
    logic   [`AR_LEN-1:0]   reg21_in, reg22_in;
    logic   [`AR_LEN-1:0]   dest_reg1_in, dest_reg2_in;

    /* inputs from freelist */
    logic   [`PR_LEN-1:0]	regNum1,regNum2;
	logic					success1,success2;
    
    /* inputs from brat */
    // if mispred recover from brat
    logic                                   brat_en;
    logic   [`AR_SIZE-1:0][`PR_LEN-1:0]     brat_arr_in, c_brat;
    logic   [`AR_SIZE-1:0][`PR_LEN-1:0]     c_rat_out1 , c_rat_out2;
    logic   [`AR_SIZE-1:0][`PR_LEN-1:0]     c_rat_arr_out;


    /* outputs */
    // output to prf and this happens after dispatch
    logic		                        rat1_valid, rat2_valid;
	logic   [`PR_LEN-1:0]               rat11_reg, rat12_reg, rat21_reg, rat22_reg;
    // output to brat for backup
    logic   [`AR_SIZE-1:0][`PR_LEN-1:0] rat_out1, rat_out2;
    // rat should be visible by any components
    logic   [`AR_SIZE-1:0][`PR_LEN-1:0] rat_arr_out;
    // previous mapping used for freeing prf
    logic   [`AR_LEN-1:0]               ar1_out, ar2_out;
    logic   [`PR_LEN-1:0]               pr1_out, pr2_out;
    logic                               pr1_valid, pr2_valid;
    logic   [10:0]                      cnt;
    rat r(
        .clock, .reset, 
        .valid1_in, .valid2_in, 
        .reg11_in, .reg12_in,
        .reg21_in, .reg22_in,
        .dest_reg1_in, .dest_reg2_in,
        .regNum1, .regNum2,
        .success1, .success2, 
        .brat_en, .brat_arr_in, 
        .rat1_valid, .rat2_valid,
        .rat11_reg, .rat12_reg,
        .rat21_reg, .rat22_reg,
        .rat_out1, .rat_out2,
        .rat_arr_out,
        .ar1_out, .ar2_out,
        .pr1_out, .pr2_out,
        .pr1_valid, .pr2_valid
    );


    always begin
        #5 clock=~clock;
    end

    task check_rat_output;
        input   rat1_valid, rat2_valid;
	    input   [`PR_LEN-1:0]   rat11_reg, rat12_reg, rat21_reg, rat22_reg;
        input   [`AR_SIZE-1:0][`PR_LEN-1:0] rat_out1, rat_out2;
        input   [`AR_SIZE-1:0][`PR_LEN-1:0] rat_arr_out;
        input   [`AR_LEN-1:0]               ar1_out, ar2_out;
        input   [`PR_LEN-1:0]               pr1_out, pr2_out;
        input   pr1_valid, pr2_valid;
        input   c_rat1_valid, c_rat2_valid;
	    input   [`PR_LEN-1:0]   c_rat11_reg, c_rat12_reg, c_rat21_reg, c_rat22_reg;
        input   [`AR_SIZE-1:0][`PR_LEN-1:0] c_rat_out1, c_rat_out2;
        input   [`AR_SIZE-1:0][`PR_LEN-1:0] c_rat_arr_out;
        input   [`AR_LEN-1:0]               c_ar1_out, c_ar2_out;
        input   [`PR_LEN-1:0]               c_pr1_out, c_pr2_out;
        input   c_pr1_valid, c_pr2_valid;
        // check whether rat correct know the insts are valid or not
        if (rat1_valid != c_rat1_valid) begin
            $display("@@@ Wrong rat1_valid, expected: %d", c_rat1_valid);
            $display("@@@ Failed");
            $finish;
        end
        if (rat2_valid != c_rat2_valid) begin
            $display("@@@ Wrong rat2_valid, expected: %d", c_rat2_valid);
            $display("@@@ Failed");
            $finish;
        end
        // when insts are valid check whether rat correctly find the ar-pr mapping
        if (rat11_reg != c_rat11_reg && c_rat1_valid) begin
            $display("@@@ Wrong rat11_reg, expected: %d, got: %d", c_rat11_reg, rat11_reg);
            $display("@@@ Failed");
            $finish;
        end
        if (rat12_reg != c_rat12_reg && c_rat1_valid) begin
            $display("@@@ Wrong rat12_reg, expected: %d, got: %d", c_rat12_reg, rat12_reg);
            $display("@@@ Failed");
            $finish;
        end
        if (rat21_reg != c_rat21_reg && c_rat2_valid) begin
            $display("@@@ Wrong rat21_reg, expected: %d, got: %d", c_rat21_reg, rat21_reg);
            $display("@@@ Failed");
            $finish;
        end
        if (rat22_reg != c_rat22_reg && c_rat2_valid) begin
            $display("@@@ Wrong rat22_reg, expected: %d, got: %d", c_rat22_reg, rat22_reg);
            $display("@@@ Failed");
            $finish;
        end
        // when insts are valid check whether rat correct backup the updated rat after each inst
        if (rat_out1 != c_rat_out1 && c_rat1_valid) begin
            $display("@@@ Wrong brat backup for first inst");
            $display("@@@ Failed");
            $finish;
        end
        if (rat_out2 != c_rat_out2 && c_rat2_valid) begin
            $display("@@@ Wrong brat backup for second inst");
            $display("@@@ Failed");
            $finish;
        end
        // check the initial rat
        if (rat_arr_out != c_rat_arr_out) begin
            $display("@@@ Wrong rat");
            $display("@@@ Failed");
            $finish;
        end   
        // check for replaced ar-pr mapping  
        if ((ar1_out != c_ar1_out || pr1_out != c_pr1_out) && c_pr1_valid) begin
            $display("@@@ Wrong ar-pr pair, expected: %d -> %d got: %d -> %d", ar1_out,pr1_out, c_ar1_out,c_pr1_out);
            $display("@@@ Failed");
        end
        if ((ar2_out != c_ar2_out || pr2_out != c_pr2_out) && c_pr2_valid) begin
            $display("@@@ Wrong ar-pr pair, expected: %d -> %d got: %d -> %d", ar2_out,pr2_out, c_ar2_out,c_pr2_out);
            $display("@@@ Failed");
            $finish;
        end                               
    endtask
    task show_rat;
        input   rat1_valid, rat2_valid;
	    input   [`PR_LEN-1:0]   rat11_reg, rat12_reg, rat21_reg, rat22_reg;
        input   [`AR_SIZE-1:0][`PR_LEN-1:0] rat_out1, rat_out2;
        input   [`AR_SIZE-1:0][`PR_LEN-1:0] rat_arr_out;
        input   [`AR_LEN-1:0]               ar1_out, ar2_out;
        input   [`PR_LEN-1:0]               pr1_out, pr2_out;
        input   pr1_valid, pr2_valid;
        input   [10:0] cycle_num;
        begin
            $display("@@@\t\tCycle %d", cycle_num);
            $display("@@@updated rat from last cycle:");
            $display("@@@\t\tAR#\t\t\t\t\t\tPR#");
            for (int i = 0; i < `AR_SIZE; i++) begin
                $display("@@@\t%d\t\t\t\t\t\t%d", i, rat_arr_out[i]);
            end
            if (rat1_valid) begin
                $display("@@@inst#1 opa uses pr %d opb uses pr %d", rat11_reg, rat12_reg);
                $display("@@@inst#1 modify ar %d which now is used? %b mapping to pr %d", ar1_out, pr1_valid, pr1_out);
                $display("@@@brat for first inst:");
                $display("@@@\t\tAR#\t\t\t\t\t\tPR#");
                for (int i = 0; i < `AR_SIZE; i++) begin
                    $display("@@@\t%d\t\t\t\t\t\t%d", i, rat_out1[i]);
                end
            end
            else begin
                $display("@@@inst#1 is not valid");
            end
            if (rat2_valid) begin
                $display("@@@inst#2 opa uses pr %d opb uses pr %d", rat21_reg, rat22_reg);
                $display("@@@inst#2 modify ar %d which now is used? %b mapping to pr %d", ar2_out, pr2_valid, pr2_out);
                $display("@@@brat for second inst:");
                $display("@@@\t\tAR#\t\t\t\t\t\tPR#");
                for (int i = 0; i < `AR_SIZE; i++) begin
                    $display("@@@\t%d\t\t\t\t\t\t%d", i, rat_out2[i]);
                end
            end
            else begin
                $display("@@@inst#2 is not valid");
            end
            $display("@@@");
        end
    endtask  // show_rat


    initial begin
        // Initiate to all zero except reset
        cnt = 0;
        clock = 0;
        reset = 1;
        //dispatched insts
        valid1_in = 0;
        valid2_in = 0;
        reg11_in = 1;
        reg12_in = 2;
        reg21_in = 0;
        reg22_in = 0;
        dest_reg1_in = 0;
        dest_reg2_in = 0;
        //freelist assignments
        regNum1 = 10;
        regNum2 = 11;
        success1 = 0;
        success2 = 0;
        // mispred case brat being reversed order
        brat_en = 0;
        for (int i = 0; i<`AR_SIZE;i=i+1) begin
            c_brat[i] = `AR_SIZE-1-i;
        end
        @(negedge clock)
        reset = 0;
        for (int i = 0; i<`AR_SIZE;i=i+1) begin
            c_rat_out1[i] = 0;
            c_rat_out2[i] = 0;
        end

        // cycle 0 just check reset, nothing will be done in cycle 0
        @(posedge clock)
        #2
        show_rat(rat1_valid, rat2_valid, rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out,
            ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid, cnt);
        check_rat_output(rat1_valid, rat2_valid,rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out, ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid,
            0,0,0,0,0,0,c_rat_out1,c_rat_out1,c_rat_out1,0,0,0,0,0,0);
        // at negedge cycle 0 id stage send out insts and correct values are prepared
        @(posedge clock)
        valid1_in = 1;
        cnt += 1;
        c_rat_arr_out = c_rat_out2;
        c_rat_out1[0] = 10;
        c_rat_out2 = c_rat_out1;
        // cycle 1
        // only one inst(load); since no loads have completed the ar will map to 0 as default and means nothing
        // freelist assign pr 10 to ar 0
        // at posedge cycle 1 freelist will send free pr to rat
        regNum1 <= `SD 10;
        success1 <= `SD 1;
        // rat should have finished everything
        #2
        show_rat(rat1_valid, rat2_valid, rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out,
            ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid, cnt);
        check_rat_output(rat1_valid, rat2_valid,rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out, ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid,
            1,0,0,0,0,0,c_rat_out1,c_rat_out2,c_rat_arr_out,0,0,0,0,1,0);        
        // at negedge cycle 1 dispatched inst come
        @(posedge clock)
        cnt += 1;
        valid1_in = 0;
        valid2_in = 1;
        c_rat_arr_out = c_rat_out2;
        c_rat_out1 = c_rat_arr_out;
        c_rat_out2 = c_rat_out1;
        c_rat_out2[0] = 11;
        // cycle 2
        // one inst using the loaded ar 0
        // freelist assign pr 11 to ar 0
        
        success1 <= `SD 0;
        success2 <= `SD 1;
        #2
        show_rat(rat1_valid, rat2_valid, rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out,
            ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid, cnt);
        check_rat_output(rat1_valid, rat2_valid,rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out, ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid,
            0,1,0,0,10,10,c_rat_out1,c_rat_out2,c_rat_arr_out,0,0,0,10,0,1);
        @(posedge clock)
        cnt += 1;
        valid1_in = 1;
        reg11_in = 4;
        reg12_in = 5;
        reg21_in = 6;
        reg22_in = 6;
        dest_reg1_in = 20;
        dest_reg2_in = 21;
        success1 = 0;
        success2 = 0;
        c_rat_arr_out = c_rat_out2;
        c_rat_out1 = c_rat_arr_out;
        c_rat_out1[20] = 1;
        c_rat_out2 = c_rat_out1;
        c_rat_out2[21] = 2;
        // cycle 3
        // two valid insts 
        
        success1 <= `SD 1;
        success2 <= `SD 1;
        regNum1 <= `SD 1;
        regNum2 <= `SD 2;
        #2
        show_rat(rat1_valid, rat2_valid, rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out,
            ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid, cnt);
        check_rat_output(rat1_valid, rat2_valid,rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out, ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid,
            1,1,0,0,0,0,c_rat_out1,c_rat_out2,c_rat_arr_out,20,21,0,0,1,1);
        @(posedge clock)
        cnt += 1;
        valid1_in = 0;
        valid2_in = 0;
        c_rat_arr_out = c_rat_out2;
        c_rat_out1 = c_brat;
        c_rat_out2 = c_brat;
        // cycle 4
        // mispred happens and no new insts
        
        brat_arr_in <= `SD c_brat;
        brat_en <= `SD 1;
        #2
        show_rat(rat1_valid, rat2_valid, rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out,
            ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid, cnt);
        check_rat_output(rat1_valid, rat2_valid,rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out, ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid,
            0,0,0,0,0,0,c_rat_out1,c_rat_out2,c_rat_arr_out,0,0,0,0,0,0);
        @(posedge clock)
        cnt += 1;
        c_rat_arr_out = c_rat_out2;
        valid1_in = 1;
        valid2_in = 1;
        for (int i = 0; i<`AR_SIZE;i=i+1) begin
            c_brat[i] = i;
        end
        c_rat_arr_out = c_rat_out2;
        c_rat_out1 = c_brat;
        c_rat_out2 = c_brat;
        // cycle 5
        // mispred happens and two new insts, these insts should be ignored
        // try another brat which is 0->AR-1
        
        success1 <= `SD 1;
        success2 <= `SD 1;
        regNum1 <= `SD 3;
        regNum2 <= `SD 4;
        brat_arr_in <= `SD c_brat;
        brat_en <= `SD 1;
        #2
        show_rat(rat1_valid, rat2_valid, rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out,
            ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid, cnt);
        check_rat_output(rat1_valid, rat2_valid,rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out, ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid,
            0,0,0,0,0,0,brat_arr_in,brat_arr_in,c_rat_arr_out,20,21,1,2,0,0);
        @(posedge clock)
        valid1_in = 0;
        valid2_in = 0;
        
        brat_en <= `SD 0;
        #2
        show_rat(rat1_valid, rat2_valid, rat11_reg, rat12_reg, rat21_reg, rat22_reg, rat_out1, rat_out2, rat_arr_out,
            ar1_out, ar2_out, pr1_out, pr2_out, pr1_valid, pr2_valid, cnt);
        $display("@@@ PASSED!");
        $finish;
    end


endmodule