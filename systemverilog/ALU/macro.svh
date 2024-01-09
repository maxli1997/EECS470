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
`define XLEN		32
`define RS_SIZE     8
`define RS_LEN	    3

typedef struct packed {
	logic [`AR_LEN-1:0]     arch_reg;
    logic [`PR_LEN-1:0]     phy_reg;
	logic [`PR_LEN-1:0]     prev_phy_reg;
    logic [`PC_LEN-1:0]     pc;
    logic [`FU_LEN-1:0]     fu;
    logic                   pred_taken, branch_rst, done, valid;

} ROB_ENTRY_PACKET;

/*typedef struct packed {
    logic [`PR_LEN-1:0]     phy_reg;
    logic                   done;
    logic                   valid;

} RAT_ENTRY_PACKET;*/

typedef struct packed {
    logic [`AR_LEN-1:0]     arch_reg;
    logic [`PR_LEN-1:0]     phy_reg;
	logic [`PR_LEN-1:0]     prev_phy_reg;
    logic [`PC_LEN-1:0]     pc;
    logic [`FU_LEN-1:0]     fu;
    logic                   branch_rst, retire_valid;
} ROB_RETIRE_PACKET;

typedef struct packed {
	logic [`PR_LEN-1:0]		phy_reg_free;
	logic					retire_valid;
} BRAT_PACKET;

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
	logic [`BRAT_SIZE-1:0]	brat_vec; // the dependent brat vector of this cdb results
	//pass throughs from decode stage
	logic [`XLEN-1:0]       rs2_value;
	logic                   rd_mem, wr_mem;
	logic [`PR_LEN-1:0]     dest_phy_reg;
    logic [`ROB_LEN-1:0]    rob_num;
	logic                   halt, illegal, csr_op, valid;
	logic [2:0]             mem_size; // byte, half-word or word
} CDB_RETIRE_PACKET;

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

typedef enum logic [1:0] {
	OPA_IS_RS1  = 2'h0,
	OPA_IS_NPC  = 2'h1,
	OPA_IS_PC   = 2'h2,
	OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

typedef enum logic [3:0] {
	OPB_IS_RS2    = 4'h0,
	OPB_IS_I_IMM  = 4'h1,
	OPB_IS_S_IMM  = 4'h2,
	OPB_IS_B_IMM  = 4'h3,
	OPB_IS_U_IMM  = 4'h4,
	OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

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

} INST;

typedef struct packed {
	logic [`XLEN-1:0] NPC;   // PC + 4
	logic [`XLEN-1:0] PC;    // PC

	logic [`XLEN-1:0] rs1_value;    // reg A value                                  
	logic [`XLEN-1:0] rs2_value;    // reg B value                                  
	                                                                                
	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	
	logic [4:0] dest_phy_reg;  // destination (writeback) register index      
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
} ID_EX_PACKET;

typedef struct packed {
	logic [`PR_LEN-1:0]     tag;
    logic [`VALUE_SIZE-1:0] tag1, tag2;
    logic [`PC_LEN-1:0]     pc;
    logic [`FU_LEN-1:0]     fu;
    logic                   tag1_rdy, tag2_rdy;
    logic                   valid;
    ID_EX_PACKET      id_ex_packet;
    logic [`BRAT_SIZE-1:0]             brat_vec;
} RS_ENTRY_PACKET;