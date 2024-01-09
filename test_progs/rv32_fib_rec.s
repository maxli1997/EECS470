/*
	TEST PROGRAM #4: compute nth fibonacci number recursively

	int output;
	
	void
	main(void)
	{
	   output = fib(14); 
	}

	int
	fib(int arg)
	{
	    if (arg == 0 || arg == 1)
		return 1;

	    return fib(arg-1) + fib(arg-2);
	}
*/
	
	data = 0x400															
	stack = 0x1000															
    li  x8, 1																#0
	li	x31, stack															#4

	li	x17, 14																#8
	jal	x27,	fib 		#c								

	li	x2, data			#10
	sw	x1, 0(x2)			#14
	wfi						#18
	
fib:	beq	x17,	x0,	fib_ret_1 # arg is 0: return 1 1c

	#cmpeq	x2,	x17,	1 # arg is 1: return 1
	beq	x17,	x8,	fib_ret_1 # 20

	addi	x31,	x31,	-32 # allocate stack frame 24
	sw	x27, 24(x31)	#28

	sw	x17, 0(x31)		#2c

	addi	x17,	x17,	-1 # arg = arg-1 30
	jal	x27,	fib # call fib 34
	sw	x1, 8(x31)	#38

	lw	x17, 0(x31)	#3c
	addi	x17,	x17,	-2 # arg = arg-2 40
	jal	x27,	fib # call fib 44

	lw	x2, 8(x31)	# 48
	add	x1,	x2,	x1 # fib(arg-1)+fib(arg-2) 4c

	lw	x27, 24(x31)	#50
	addi	x31,	x31,	32 # deallocate stack frame# 54
	jalr x0, x27, 0 # 58 --> 88 decimal
	
fib_ret_1:
	li	x1,	1 # set return value to 1
	jalr x0, x27, 0
	
