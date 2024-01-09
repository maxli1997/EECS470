/////////////////////////////////////////////////////////////////////////
//                                                                     //
//  Modulename :  RAT.sv                                               //
//                                                                     //
//  Description :  Register Renaming Table                                    //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __RAT_SV__
`define __RAT_SV__

`timescale 1ns/100ps


module rat(
    input                   clock, reset,
    /* inputs from dispatch stage */
    input                   valid1_in, valid2_in,
    input   [`AR_LEN-1:0]   reg11_in, reg12_in,
    input   [`AR_LEN-1:0]   reg21_in, reg22_in,
    input   [`AR_LEN-1:0]   dest_reg1_in, dest_reg2_in,

    /* inputs from freelist */
    input	[`PR_LEN-1:0]	regNum1,regNum2,
	input					success1,success2,
    
    /* inputs from brat */
    // if mispred recover from brat
    input                               brat_en,
    input   [`AR_SIZE-1:0][`PR_LEN-1:0] brat_arr_in ,

    /* outputs */
    // output to prf and this happens after dispatch
    output		                        rat1_valid, rat2_valid,
	output  [`PR_LEN-1:0]               rat11_reg, rat12_reg, rat21_reg, rat22_reg,
    // output to brat for backup
    output logic [`AR_SIZE-1:0][`PR_LEN-1:0] rat_out1, rat_out2,
    // rat should be visible by any components
    output logic [`AR_SIZE-1:0][`PR_LEN-1:0] rat_arr_out,
    // previous mapping used for freeing prf
    output logic [`AR_LEN-1:0]               ar1_out, ar2_out,
    output logic [`PR_LEN-1:0]               pr1_out, pr2_out,
    output                              pr1_valid, pr2_valid
); 
    logic   [`AR_SIZE-1:0][`PR_LEN-1:0] rat_arr, rat_arr_temp1;
    logic   [`PR_LEN-1:0]               rat11_reg, rat12_reg, rat21_reg, rat22_reg;
    // whenever an inst is valid, the rat should be valid
    // whether corresponding rat entry is empty or not solely depends on the program not rat
    assign rat1_valid = ~brat_en & valid1_in;
    assign rat2_valid = ~brat_en & valid2_in;
    assign ar1_out = dest_reg1_in;
    assign ar2_out = dest_reg2_in;
    assign pr1_valid = (~brat_en & valid1_in & success1);
    assign pr2_valid = (~brat_en & valid2_in & success2);

    always_comb begin
        rat_arr = rat_arr_out;
        rat_arr_temp1 = rat_arr;
        rat11_reg = 0;
        rat12_reg = 0;
        rat21_reg = 0;
        rat22_reg = 0;
        rat_out1 = rat_arr;
        rat_out2 = rat_arr_temp1;
        pr1_out = 0;
        pr2_out = 0;
        // if mispredict recover to given brat and the received insts are then invalid
        if (brat_en) begin
            rat_arr_temp1 = brat_arr_in;
        end
        // if no misprediction, update rat according to freelist
        // only update if inst is valid and freelist is not full
        else begin
            if (valid1_in) begin
                rat11_reg = rat_arr_out[reg11_in];
                rat12_reg = rat_arr_out[reg12_in];
                pr1_out = rat_arr_out[dest_reg1_in];
                if (success1)
                    rat_arr[dest_reg1_in] = regNum1;
                rat_out1 = rat_arr;
            end
            rat_arr_temp1 = rat_arr;
            if (valid2_in) begin
                rat21_reg = rat_arr[reg21_in];
                rat22_reg = rat_arr[reg22_in];
                pr2_out = rat_arr[dest_reg2_in];
                if (success2)
                    rat_arr_temp1[dest_reg2_in] = regNum2;
                rat_out2 = rat_arr_temp1;
            end
        end
    end

    /* Sequential Logic */
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            rat_arr_out <= `SD 0;
        end
        else begin
            rat_arr_out <= `SD rat_arr_temp1;
        end
    end

endmodule

`endif