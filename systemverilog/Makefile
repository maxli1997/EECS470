# make          <- runs simv (after compiling simv if needed)
# make simv     <- compiles simv without running
# make dve      <- runs GUI debugger (after compiling it if needed)
# make syn      <- runs syn_simv (after synthesizing if needed then 
#                                 compiling syn_simv if needed)
# make clean    <- remove files created during compilations (but not synthesis)
# make nuke     <- remove all files created during compilation and synthesis
#
# To compile additional files, add them to the TESTBENCH or SIMFILES as needed
# Every .vg file will need its own rule and one or more synthesis scripts
# The information contained here (in the rules for those vg files) will be 
# similar to the information in those scripts but that seems hard to avoid.
#

VCS = SW_VCS=2017.12-SP2-1 vcs -sverilog +vc -Mupdate -line -full64 +define+ -cm line+cond+tgl
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v

all:	simv
	(./simv -cm line+cond+tgl | tee program.out) && (urg -dir simv.vdb -format text) && (cp ./urgReport/modlist.txt ./coverage.txt) 

##### 
# Modify starting here
#####

HEADERS     = $(wildcard *.svh)

TESTBENCH = rob_testsbench.sv
SIMFILES = rob.sv
SYNFILES = rob.vg


#####
# Should be no need to modify after here
#####
simv:	$(HEADERS) $(SIMFILES) $(TESTBENCH)
	$(VCS) $(HEADERS) $(TESTBENCH) $(SIMFILES) -o simv

dve:	$(HEADERS) $(SIMFILES) $(TESTBENCH) 
	$(VCS) +memcbk $(HEADERS) $(TESTBENCH) $(SIMFILES) -o dve -R -gui

.PHONY: dve

syn_simv:	$(HEADERS) $(SYNFILES) $(TESTBENCH)
	$(VCS) $(HEADERS) $(TESTBENCH) $(SYNFILES) $(LIB) -o syn_simv

syn:	syn_simv
	./syn_simv | tee syn_program.out

rob.vg:	rob.sv macro.svh rob.tcl
	dc_shell-t -f rob.tcl | tee synth.out

clean:
	rm -rvf simv *.daidir csrc vcs.key program.out \
	syn_simv syn_simv.daidir syn_program.out \
	dve *.vpd *.vcd *.dump ucli.key 

nuke:	clean
	rm -rvf *.vg *.rep *.db *.chk *.log *.out DVEfiles/

full_adder_1bit.vg:	fa1.v tut_synth.tcl
	dc_shell-t -f tut_synth.tcl | tee synth.out

full_adder_64bit.vg:	fa64.v tut_synth.tcl
	dc_shell-t -f tut_synth.tcl | tee synth.out

