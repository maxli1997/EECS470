nop                     # 0
li a3, 1                # 4
li a1, 2                # 8
li a2, 4                # 12
add a3, a2, a1          # 16
add a1, a3, a2          # 20
li a1, 1                # 24 
loop: add a1, a1, a1    # 28
      bne a1, a2, loop	# 32 a1 != $t1 then target     
add a1, a1, a1    # 36
add a1, a1, a1    # 40 
wfi                     # 44
