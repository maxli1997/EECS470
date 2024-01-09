.section .text
.align 4
nop                 #0
li a0, 0            #4
li a1, 12314        #8
li a2, 342          #12
li sp, 2048         #16
sw a1, 0(sp)        #20
addi sp, sp, 4      #24
add a0, a2, a0      #28
add a0, a2, a1      #32
sw a0, 0(sp)        #36
addi sp, sp, -16    #40
lw a0, 0(sp)        #44
sub a0, a2, a0      #48
nop                 #52
nop                 #56
wfi                 #60



