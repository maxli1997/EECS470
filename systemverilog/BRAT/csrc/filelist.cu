PIC_LD=ld

ARCHIVE_OBJS=
ARCHIVE_OBJS += _16669_archive_1.so
_16669_archive_1.so : archive.3/_16669_archive_1.a
	@$(AR) -s $<
	@$(PIC_LD) -shared  -o .//../syn_simv.daidir//_16669_archive_1.so --whole-archive $< --no-whole-archive
	@rm -f $@
	@ln -sf .//../syn_simv.daidir//_16669_archive_1.so $@


ARCHIVE_OBJS += _prev_archive_1.so
_prev_archive_1.so : archive.3/_prev_archive_1.a
	@$(AR) -s $<
	@$(PIC_LD) -shared  -o .//../syn_simv.daidir//_prev_archive_1.so --whole-archive $< --no-whole-archive
	@rm -f $@
	@ln -sf .//../syn_simv.daidir//_prev_archive_1.so $@



VCS_ARC0 =_csrc0.so

VCS_OBJS0 =objs/amcQw_d.o 



%.o: %.c
	$(CC_CG) $(CFLAGS_CG) -c -o $@ $<

$(VCS_ARC0) : $(VCS_OBJS0)
	$(PIC_LD) -shared  -o .//../syn_simv.daidir//$(VCS_ARC0) $(VCS_OBJS0)
	rm -f $(VCS_ARC0)
	@ln -sf .//../syn_simv.daidir//$(VCS_ARC0) $(VCS_ARC0)

CU_UDP_OBJS = \
objs/udps/guAtk.o objs/udps/hUcmi.o objs/udps/PjGxs.o objs/udps/aKVa7.o objs/udps/MzHq6.o  \
objs/udps/GLrQJ.o objs/udps/F8ezs.o objs/udps/dKp3B.o 

CU_LVL_OBJS = \
SIM_l.o 

MAIN_OBJS = \


CU_OBJS = $(MAIN_OBJS) $(ARCHIVE_OBJS) $(VCS_ARC0) $(CU_UDP_OBJS) $(CU_LVL_OBJS)

