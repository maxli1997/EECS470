/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.vh                                         //
//                                                                     //
//  Description :  This file has the macro-defines for macros used in  //
//                 the pipeline design.                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`ifndef __SYS_DEFS_VH__
`define __SYS_DEFS_VH__

/* debug macro */
`define DEBUG_RS


/* Synthesis testing definition, used in DUT module instantiation */

`ifdef  SYNTH_TEST
`define DUT(mod) mod``_svsim
`else
`define DUT(mod) mod
`endif

//////////////////////////////////////////////
//
// Memory/testbench attribute definitions
//
//////////////////////////////////////////////
`define CACHE_MODE //removes the byte-level interface from the memory mode, DO NOT MODIFY!
`define NUM_MEM_TAGS           15

`define MEM_SIZE_IN_BYTES      (64*1024)
`define MEM_64BIT_LINES        (`MEM_SIZE_IN_BYTES/8)

//you can change the clock period to whatever, 10 is just fine
`define VERILOG_CLOCK_PERIOD   10.0
`define SYNTH_CLOCK_PERIOD     15.0 // Clock period for synth and memory latency

`define MEM_LATENCY_IN_CYCLES  0 //(0.0/`SYNTH_CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period).  The default behavior for
// float to integer conversion is rounding to nearest

typedef union packed {
    logic [7:0][7:0] byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
} EXAMPLE_CACHE_BLOCK;

//////////////////////////////////////////////
// Exception codes
// This mostly follows the RISC-V Privileged spec
// except a few add-ons for our infrastructure
// The majority of them won't be used, but it's
// good to know what they are
//////////////////////////////////////////////

typedef enum logic [3:0] {
	INST_ADDR_MISALIGN  = 4'h0,
	INST_ACCESS_FAULT   = 4'h1,
	ILLEGAL_INST        = 4'h2,
	BREAKPOINT          = 4'h3,
	LOAD_ADDR_MISALIGN  = 4'h4,
	LOAD_ACCESS_FAULT   = 4'h5,
	STORE_ADDR_MISALIGN = 4'h6,
	STORE_ACCESS_FAULT  = 4'h7,
	ECALL_U_MODE        = 4'h8,
	ECALL_S_MODE        = 4'h9,
	NO_ERROR            = 4'ha, //a reserved code that we modified for our purpose
	ECALL_M_MODE        = 4'hb,
	INST_PAGE_FAULT     = 4'hc,
	LOAD_PAGE_FAULT     = 4'hd,
	HALTED_ON_WFI       = 4'he, //another reserved code that we used
	STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;


//////////////////////////////////////////////
//
// Datapath control signals
//
//////////////////////////////////////////////

//
// ALU opA input mux selects
//
typedef enum logic [1:0] {
	OPA_IS_RS1  = 2'h0,
	OPA_IS_NPC  = 2'h1,
	OPA_IS_PC   = 2'h2,
	OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

//
// ALU opB input mux selects
//
typedef enum logic [3:0] {
	OPB_IS_RS2    = 4'h0,
	OPB_IS_I_IMM  = 4'h1,
	OPB_IS_S_IMM  = 4'h2,
	OPB_IS_B_IMM  = 4'h3,
	OPB_IS_U_IMM  = 4'h4,
	OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

//
// Destination register select
//
typedef enum logic [1:0] {
	DEST_RD = 2'h0,
	DEST_NONE  = 2'h1
} DEST_REG_SEL;

//
// ALU function code input
// probably want to leave these alone
//
typedef enum logic [4:0] {
	ALU_ADD     = 5'h00,
	ALU_SUB     = 5'h01,
	ALU_SLT     = 5'h02,
	ALU_SLTU    = 5'h03,
	ALU_AND     = 5'h04,
	ALU_OR      = 5'h05,
	ALU_XOR     = 5'h06,
	ALU_SLL     = 5'h07,
	ALU_SRL     = 5'h08,
	ALU_SRA     = 5'h09,
	ALU_MUL     = 5'h0a,
	ALU_MULH    = 5'h0b,
	ALU_MULHSU  = 5'h0c,
	ALU_MULHU   = 5'h0d,
	ALU_DIV     = 5'h0e,
	ALU_DIVU    = 5'h0f,
	ALU_REM     = 5'h10,
	ALU_REMU    = 5'h11
} ALU_FUNC;

//////////////////////////////////////////////
//
// Assorted things it is not wise to change
//
//////////////////////////////////////////////

//
// actually, you might have to change this if you change VERILOG_CLOCK_PERIOD
// JK you don't ^^^
//
`define SD #1

`define AR_LEN      5
`define AR_SIZE     32
`define ROB_LEN     5
`define PR_LEN      6
`define PR_SIZE     64
`define ROB_SIZE    8
`define FU_LEN      3
`define PC_LEN      32
`define DEBUG_ROB   1
`define BRAT_LEN    2
`define BRAT_SIZE   4
`define VALUE_SIZE  32
`define RS_SIZE     32
`define RS_LEN	    5


// the RISCV register file zero register, any read of this register always
// returns a zero value, and any write to this register is thrown away
//
`define ZERO_REG 5'd0

//
// Memory bus commands control signals
//
typedef enum logic [1:0] {
	BUS_NONE     = 2'h0,
	BUS_LOAD     = 2'h1,
	BUS_STORE    = 2'h2
} BUS_COMMAND;

`ifndef CACHE_MODE
typedef enum logic [1:0] {
	BYTE = 2'h0,
	HALF = 2'h1,
	WORD = 2'h2,
	DOUBLE = 2'h3
} MEM_SIZE;
`endif
//
// useful boolean single-bit definitions
//
`define FALSE  1'h0
`define TRUE  1'h1

// RISCV ISA SPEC
`define XLEN 32
typedef union packed {
	logic [31:0] inst;
	struct packed {
		logic [6:0] funct7;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} r; //register to register instructions
	struct packed {
		logic [11:0] imm;
		logic [4:0]  rs1; //base
		logic [2:0]  funct3;
		logic [4:0]  rd;  //dest
		logic [6:0]  opcode;
	} i; //immediate or load instructions
	struct packed {
		logic [6:0] off; //offset[11:5] for calculating address
		logic [4:0] rs2; //source
		logic [4:0] rs1; //base
		logic [2:0] funct3;
		logic [4:0] set; //offset[4:0] for calculating address
		logic [6:0] opcode;
	} s; //store instructions
	struct packed {
		logic       of; //offset[12]
		logic [5:0] s;   //offset[10:5]
		logic [4:0] rs2;//source 2
		logic [4:0] rs1;//source 1
		logic [2:0] funct3;
		logic [3:0] et; //offset[4:1]
		logic       f;  //offset[11]
		logic [6:0] opcode;
	} b; //branch instructions
	struct packed {
		logic [19:0] imm;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} u; //upper immediate instructions
	struct packed {
		logic       of; //offset[20]
		logic [9:0] et; //offset[10:1]
		logic       s;  //offset[11]
		logic [7:0] f;	//offset[19:12]
		logic [4:0] rd; //dest
		logic [6:0] opcode;
	} j;  //jump instructions
`ifdef ATOMIC_EXT
	struct packed {
		logic [4:0] funct5;
		logic       aq;
		logic       rl;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} a; //atomic instructions
`endif
`ifdef SYSTEM_EXT
	struct packed {
		logic [11:0] csr;
		logic [4:0]  rs1;
		logic [2:0]  funct3;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} sys; //system call instructions
`endif

} INST; //instruction typedef, this should cover all types of instructions

//
// Basic NOP instruction.  Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
//
`define NOP 32'h00000013

//////////////////////////////////////////////
//
// IF Packets:
// Data that is exchanged between the IF and the ID stages  
//
//////////////////////////////////////////////

typedef struct packed {
	logic valid; // If low, the data in this struct is garbage
    INST  inst;  // fetched instruction out
	logic [`XLEN-1:0] NPC; // PC + 4
	logic [`XLEN-1:0] PC;  // PC 
	logic pred_taken;	// predicted signal if a branch
} IF_ID_PACKET;

//////////////////////////////////////////////
//
// ID Packets:
// Data that is exchanged from ID to EX stage
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] NPC;   // PC + 4
	logic [`XLEN-1:0] PC;    // PC

	logic [`XLEN-1:0] rs1_value;    // reg A value                                  
	logic [`XLEN-1:0] rs2_value;    // reg B value  
	logic [`AR_LEN-1:0] rs1_reg;
	logic [`AR_LEN-1:0] rs2_reg;                                 
	                                                                                
	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	
	logic [4:0] dest_reg_idx;  // destination (writeback) register index   
	logic [`PR_LEN-1:0]     dest_phy_reg;   
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?
	logic		pred_taken;	   // predicted signal if a branch
	logic [`BRAT_SIZE-1:0]	brat_vec; // the dependent brat vector of the inst 
	logic [`ROB_LEN-1:0]	rob_num;  // the dependent rob number of this inst	
} ID_EX_PACKET;

typedef struct packed {
	logic [`AR_LEN-1:0]     arch_reg;
    logic [`PR_LEN-1:0]     phy_reg;
	logic [`PR_LEN-1:0]     prev_phy_reg;
    logic [`PC_LEN-1:0]     pc;
	ID_EX_PACKET			decoded_packet;
    logic                   pred_taken, branch_rst, done, valid;
} ROB_ENTRY_PACKET;

typedef struct packed {
    logic [`AR_LEN-1:0]     arch_reg;
    logic [`PR_LEN-1:0]     phy_reg;
	logic [`PR_LEN-1:0]     prev_phy_reg;
    logic [`PC_LEN-1:0]     pc;
    logic [`FU_LEN-1:0]     fu;
    logic                   branch_rst, retire_valid;
	ID_EX_PACKET			decoded_packet;
} ROB_RETIRE_PACKET;

typedef enum logic [2:0] {
    ADD = 3'b00,
    SUB = 3'b01,
    MUL = 3'b10,
    BRANCH = 3'b11
} FUNCTION_UNIT;

typedef struct packed {
	logic [`XLEN-1:0]       result; // alu/mult_result
	logic [`XLEN-1:0]       NPC; //pc + 4
	logic                   take_branch; // is this a taken branch?
	logic					cond_branch;
	logic					uncond_branch;
	logic [`BRAT_SIZE-1:0]	brat_vec; // the dependent brat vector of this cdb results
	//pass throughs from decode stage
	logic [`XLEN-1:0]       rs2_value;
	logic                   rd_mem, wr_mem;
	logic [`PR_LEN-1:0]     dest_phy_reg;
    logic [`ROB_LEN-1:0]    rob_num;
	logic                   halt, illegal, csr_op, valid;
	logic [2:0]             mem_size; // byte, half-word or word
} EX_PACKET;

typedef struct packed {
	logic [`XLEN-1:0]       result; // result
	logic [`XLEN-1:0]       NPC; //pc + 4
	logic                   take_branch; // is this a taken branch?
	logic					cond_branch;
	logic					uncond_branch;
	logic [`BRAT_SIZE-1:0]	brat_vec; // the dependent brat vector of this cdb results
	//pass throughs from decode stage
	logic [`XLEN-1:0]       rs2_value;
	logic                   rd_mem, wr_mem;
	logic [`PR_LEN-1:0]     dest_phy_reg;
    logic [`ROB_LEN-1:0]    rob_num;
	logic                   halt, illegal, csr_op, valid;
	logic [2:0]             mem_size; // byte, half-word or word
} CDB_RETIRE_PACKET;

typedef struct packed {
	logic [`PR_LEN-1:0]     tag;  // dest phy reg
    logic [`VALUE_SIZE-1:0] tag1, tag2;	// value1 value2
    logic [`PC_LEN-1:0]     pc;	
    logic                   tag1_rdy, tag2_rdy;
    logic                   valid;
    ID_EX_PACKET      		id_ex_packet;
	logic [`BRAT_SIZE-1:0] 	brat_vec;
	logic [`ROB_LEN-1:0]  	rob_num;
} RS_ENTRY_PACKET;


`endif // __SYS_DEFS_VH__
