# EECS 470 Final Project Group 6

## ATTENTION!

* The Makefile we mentioned below is in the SystemVerilog folder, not the one in the original folder

* Please use the one we wrote in the SystemVerilog folder !!!

## Module Submitted

* We are submitting four files for milestone one.

* They are 'systemverilog/rob.sv', 'systemverilog/rob_testsbench.sv', 'systemverilog/Makefile' and 'systemverilog/macro.svh'.

* The Makefile is in the SystemVerilog, and it supports 'make' and 'make dve/syn/clean/nuke'

## Tips (Just write here some subtle things that might be forgotten during inmplementation)

* Stores need to be performed at ROB commit time

* Update the branch predictor at commit time

## Questions

* Is load_store_queue compulsory? A: It should be helpful having such a structure

* Maintain Freelist seperately? (For now, yes) A: Might be easier to think about if having a free list seperately

* When dispatch, update the RAT, ROB and RS in one cycle

* Do we still need a BRAT acting as a RRAT?

* How to squash part of the RS without using the ROB number?

* vector of brats in use (branch masks)

* speculatively update predictor ?

* how to update RAT using BRAT when mispredict ?

copy freelist (BRAT) to FREELIST  ---  merge RAT with BRAT

* Schedule the cdb when dispatch ?

* ROB: if mispredict, retire packet should be false...

* Problem: when rs only left with 1 slot.... (148 does not get in ..)



