/*
   GROUP 17
	TEST PROGRAM: insertion sort

	long a[] = { 3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3 };

  int i,j,temp;
  for(i=1;i<16;++i) {
    temp = a[i];
    j = i;
    while(1) {
      if(a[j-1] > temp)
        a[j] = a[j-1];
      else
        break; 
      --j;
      if(j == 0) 
        break;      
    }
    a[j] = temp;
  }  
  
  modified from sort.s
*/

 j	start
 nop 
  .dword 3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3 
  .align 4
start:	
	li	x6, 1 #90
  
	li	x10, 16 #94

iloop:
	lw	x4,  0(x10) #98
	mv	x7,	x6 #j = i #9c
	mv	x20,	x10 #index j #a0
	addi	x19,	x20,	-8 #index j-1 #a4
jloop:
	lw	x15,  0(x19) #a8
	lw	x16,  0(x20) #ac

	sltu	x12,	x15,	x4 #b0
	bne	x12,	x0,	ifinish #b4
  
	sw	x15,  0(x20) #b8
  
	addi	x19,	x19,	-8 #index to a[j-1]  #bc
	addi	x20,	x20,	-8 #index to a[j]  #c0
  
	addi	x7,	x7,	-1 #j--  #c4
	beq	x7,	x0,	ifinish # c8
  j jloop #cc
  
ifinish:
	sw	x4,  0(x20) #d0
	addi	x10,	x10,	8 #d4
	addi	x6,	x6,	1 #increment and check i loop #d8
  
	sltu	x11,	x6,	16 # dc
	bne	x11,	x0,	iloop # e0

	wfi #e4

  
