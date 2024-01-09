#!/bin/bash

# This script performs a unit test of some specific tests of previous passed .s tests

RED='\033[0;31m'
GREEN='\033[0;32m'
reset=`tput sgr0`

usage() {
  echo "Usage: $0 (syn | sim)"
}

if [ $# -ne 1 ]; then
  usage
  exit 1
fi

check_diff_return_value() {
    if [[ $1 -eq 1 ]]; then
        echo -e "${RED}test failed for testcase: ${filename}.s"
        echo -e "${RED}FAILED"
        exit 1
    fi
}

# if [[ $# -ne 1 ]]; then
#     echo -e "Usage: ./unit_test.sh"
#     exit 1
# fi

# output_dir="$1"
answer_dir=./example_output

# make a directory if not exist to save the output
# mkdir -p ${output_dir}

passed_filename=(
    "rv32_mult"
    "rv32_parallel"
    "rv32_copy_long"
    "rv32_copy"
    "rv32_fib_long"
    "rv32_fib"
    "rv32_saxpy"
    "rv32_evens_long"
    "rv32_evens"
    "rv32_btest1"
    "rv32_btest2"
    "rv32_insertion"
    "rv32_halt"
    "haha"
    "mult_no_lsq"
    "sampler"
)

passed_c_filename=(
  "bfs"
  "basic_malloc"
  "insertionsort"
  "dft"
  "fc_forward"
  "alexnet"
  "backtrack"
  "matrix_mult_rec"
  "omegalul"
  "priority_queue"
  "quicksort"
  "sort_search"
  "outer_product"
)

# not passed: graph.c mergesort.c 


case $1 in
  "syn")
    echo "Testing Synthesis"
    for filename in "${passed_filename[@]}"; do 
        echo "${reset}Assembling $filename"
        sed -i "s/SOURCE = test_progs\/*.*/SOURCE = test_progs\/${filename}.s/" Makefile # replace SOURCE in Makefile
        make assembly > /dev/null    # Compile the assembly code
        echo "Running $file"
        make syn > /dev/null
        diff writeback.out "${answer_dir}/${filename}_writeback.out"
        return_value=$?
        check_diff_return_value ${return_value}
        diff <(grep "^@@@" program.out) <(grep "^@@@" "${answer_dir}/${filename}_program.out")
        return_value=$?
        check_diff_return_value ${return_value}
        echo -e "${GREEN} test ${filename} passed"
    done

    for filename in "${passed_c_filename[@]}"; do
		echo "${reset}Compiling $filename"
		sed -i "s/SOURCE = test_progs\/*.*/SOURCE = test_progs\/${filename}.c/" Makefile
		make program > /dev/null
		echo "Running $file"
		make syn > /dev/null
		diff writeback.out "${answer_dir}/${filename}_writeback.out"
        return_value=$?
		check_diff_return_value ${return_value}	
		diff <(grep "^@@@" program.out) <(grep "^@@@" "${answer_dir}/${filename}_program.out")
        return_value=$?
        check_diff_return_value ${return_value}
        echo -e "${GREEN} test ${filename} passed"	  
    done

    make clean > /dev/null
    echo -e "${GREEN}PASSED"
    ;;

  "sim")
    echo "Testing Simulation"
    rm -rf cpi_result.out              
    echo "Using the following parameters:" >> cpi_result.out
    cat <(grep "^// AR_SIZE" sys_defs.svh) >>cpi_result.out
    for filename in "${passed_filename[@]}"; do 
        echo "${reset}Assembling $filename"
        sed -i "s/SOURCE = test_progs\/*.*/SOURCE = test_progs\/${filename}.s/" Makefile # replace SOURCE in Makefile
        make assembly > /dev/null    # Compile the assembly code
        echo "Running $file"
        make > /dev/null
        diff writeback.out "${answer_dir}/${filename}_writeback.out"
        return_value=$?
        check_diff_return_value ${return_value}
        diff <(grep "^@@@" program.out) <(grep "^@@@" "${answer_dir}/${filename}_program.out")
        echo "Executing $filename" >>cpi_result.out
        cat <(grep "^@@!" program.out) >>cpi_result.out
        return_value=$?
        check_diff_return_value ${return_value}
        echo -e "${GREEN} test ${filename} passed"
    done

	  for filename in "${passed_c_filename[@]}"; do
        echo "${reset}Compiling $filename"
        sed -i "s/SOURCE = test_progs\/*.*/SOURCE = test_progs\/${filename}.c/" Makefile
        make program > /dev/null
        echo "Running $file"
        make > /dev/null
        diff writeback.out "${answer_dir}/${filename}_writeback.out"
        return_value=$?
        check_diff_return_value ${return_value}	
        diff <(grep "^@@@" program.out) <(grep "^@@@" "${answer_dir}/${filename}_program.out")
        echo "Executing $filename" >>cpi_result.out
        cat <(grep "^@@!" program.out) >>cpi_result.out
        return_value=$?
        check_diff_return_value ${return_value}
        echo -e "${GREEN} test ${filename} passed"	  
    done
        echo "All programs executed!" >>cpi_result.out
    make clean > /dev/null
    echo -e "${GREEN}PASSED"
    ;;

	
  *)
    usage
    exit 1
    ;;
esac
