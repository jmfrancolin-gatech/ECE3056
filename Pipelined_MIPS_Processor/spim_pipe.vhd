--
--  Top level SPIM module.
--

Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_signed.all;


entity spim_pipe is 
port(Out_ID_Instr : out std_logic_vector(31 downto 0);
     Out_EX_Rs, Out_EX_Rt : out std_logic_vector(31 downto 0); 
     Out_WB_MemOut, Out_MEM_ALURes,Out_MEM_MemInData, Out_WB_ALU_Result : out std_logic_vector(31 downto 0); 
     Out_ID_PC : out std_logic_vector(31 downto 0);
     Out_EX_ALUOp : out std_logic_vector(1 downto 0);
     Out_WB_WReg : out std_logic_vector(4 downto 0);
     Out_WB_RegWrite, Out_EX_ALUSrc, Out_EX_RegDst,Out_WB_MemToReg, Out_MEM_MRead, Out_MEM_MWrite : out std_logic);
end spim_pipe;


architecture structural of spim_pipe is
    
    -- clock and reset generation
    
    
component my_clock is
port ( signal sys_clock, reset : out std_logic);
end component my_clock;
--
-- Instruction fetch unit 
--

component fetch 
port(instruction    : out std_logic_vector(31 downto 0);
	  PC_out         : out std_logic_vector (31 downto 0);
	  Branch_PC      : in std_logic_vector(31 downto 0);
	  -- added pc_Stall
	  clock, reset, PCSource, pc_Stall:  in std_logic); 
end component;

--
-- Instruction decode 
--

component decode 
port(
     instruction : in std_logic_vector(31 downto 0);
     memory_data, alu_result :in std_logic_vector(31 downto 0);
     RegWrite, MemToReg, reset  : in std_logic;
     wreg_address : in std_logic_vector(4 downto 0);
     -- added wreg_rs
     -- wreg_rt & wreg_rs are used when accerting load_to_use signal
     wreg_rd, wreg_rt, wreg_rs: out std_logic_vector(4 downto 0);
     register_rs, register_rt :out std_logic_vector(31 downto 0);
     Sign_extend :out std_logic_vector(31 downto 0));
end component;

--
-- Execution unit 
--

component execute
port(
     PC4 : in std_logic_vector(31 downto 0);
     -- added mem_alu_result, wb_memory_data, wb_alu_result
     register_rs, register_rt, mem_alu_result, wb_memory_data, wb_alu_result :in std_logic_vector(31 downto 0);
     Sign_extend:in std_logic_vector(31 downto 0);
     ALUOp: in std_logic_vector(1 downto 0);
     -- added  wb_RegWrite, mem_RegWrite, wb_MemToReg
     -- signals used when accerting load_to_use signal
     ALUSrc, RegDst, wb_RegWrite, mem_RegWrite, wb_MemToReg : in std_logic; 
     wreg_rd, wreg_rt, wreg_rs, mem_wreg_addr, wb_wreg_addr : in std_logic_vector(4 downto 0);
     alu_result, branch_PC :out std_logic_vector(31 downto 0);
     wreg_address : out std_logic_vector(4 downto 0);
     zero : out std_logic);    
end component;

--
-- Data Memory
--

component memory 
port(
     address, write_data : in std_logic_vector(31 downto 0);
     MemWrite, MemRead : in std_logic;
     read_data :out std_logic_vector(31 downto 0));
end component;
    
-- 
-- Control
--
component control
-- added ex_opcode
port(opcode, ex_opcode: in std_logic_vector(5 downto 0);
     -- added ex_wreg_addr
     ex_wreg_addr : in std_logic_vector(4 downto 0);
     -- added instruction
     instruction: in std_logic_vector(31 downto 0);
     -- propagate ps_Stall
     RegDst, MemRead, MemToReg, MemWrite, Branch, pc_Stall :out  std_logic;
     ALUSrc, RegWrite: out std_logic;
     ALUOp: out std_logic_vector(1 downto 0));
end component;

--
-- pipeline register IF/ID
--
component pipe_reg1
port (if_PC4 : in std_logic_vector(31 downto 0);
	if_instruction: in std_logic_vector( 31 downto 0);
	-- added pc_Stall
        clk, reset, pc_Stall : in std_logic; 
	id_PC4 : out std_logic_vector(31 downto 0);
	id_instruction: out std_logic_vector( 31 downto 0));

end component;

--
-- pipeline register ID/EX
--
component pipe_reg2
port (id_MemToReg, id_RegWrite, id_MemWrite, id_MemRead: in std_logic;       
      -- added pc_Stall
      id_ALUSrc, id_RegDst, clk, reset, id_branch, pc_Stall : in std_logic;
      id_ALUOp : in std_logic_vector(1 downto 0);
      id_PC4: in std_logic_vector(31 downto 0);
      -- added id_instruction
      id_register_rs, id_register_rt, id_sign_extend, id_instruction: in std_logic_vector(31 downto 0); 
      -- added id_wreg_rs
      id_wreg_rd, id_wreg_rt, id_wreg_rs : in std_logic_vector(4 downto 0);

      ex_MemToReg, ex_RegWrite, ex_MemWrite, ex_MemRead, ex_branch: out std_logic;
      ex_ALUSrc, ex_RegDst : out std_logic;  
      ex_ALUOp : out std_logic_vector(1 downto 0);
      ex_PC4: out  std_logic_vector(31 downto 0);
      -- propagate ex_instruction
      ex_register_rs, ex_register_rt, ex_sign_extend, ex_instruction: out std_logic_vector(31 downto 0);  
      -- propagate ex_wreg_rs
      ex_wreg_rd, ex_wreg_rt, ex_wreg_rs : out std_logic_vector(4 downto 0));
end component;

--
-- pipeline register EX/MEM
--

component pipe_reg3
port (ex_MemToReg, ex_RegWrite, ex_MemWrite, ex_MemRead, ex_branch, ex_zero: in std_logic;  
      -- added ex_instruction,  
      ex_alu_result, ex_register_rt, ex_branch_PC, ex_instruction : in std_logic_vector(31 downto 0);
      ex_wreg_addr :std_logic_vector(4 downto 0); --signal need to propogate
      clk, reset : in std_logic; 

      mem_MemToReg, mem_RegWrite, mem_MemWrite, mem_MemRead, mem_branch, mem_zero: out std_logic;
      -- propagate mem_instruction
      mem_alu_result, mem_register_rt, mem_branch_PC, mem_instruction : out std_logic_vector(31 downto 0);
      mem_wreg_addr : out std_logic_vector(4 downto 0));
end component;

--
-- pipeline register MEM/WB
--
component pipe_reg4
port (mem_MemToReg, mem_RegWrite : in std_logic;
      -- added mem_instruction
      mem_memory_data, mem_alu_result, mem_instruction: in std_logic_vector(31 downto 0);
      mem_wreg_addr: in std_logic_vector(4 downto 0);
      clk,reset : in std_logic;

      wb_MemToReg, wb_RegWrite : out std_logic;
      wb_memory_data, wb_alu_result: out std_logic_vector(31 downto 0);  
      wb_wreg_addr: out std_logic_vector(4 downto 0));
end component;

-- Local signals "wires"

--
-- IF
--
signal if_PC4 : std_logic_vector (31 downto 0);
signal if_instruction: std_logic_vector(31 downto 0);


--
-- ID
--

signal id_PC4  : std_logic_vector (31 downto 0);
signal id_instruction : std_logic_vector(31 downto 0);
signal id_RegDst,id_MemRead, id_MemWrite,id_ALUSrc, id_Branch : std_logic;
signal id_MemToReg, id_RegWrite : std_logic ;
signal id_ALUOp : std_logic_vector(1 downto 0);
signal id_register_rs, id_register_rt :std_logic_vector(31 downto 0);
signal id_Sign_extend :std_logic_vector(31 downto 0);
-- added id_wreg_rs
signal id_wreg_rd, id_wreg_rt, id_wreg_rs : std_logic_vector(4 downto 0);

--
-- EX
--

-- added clk
signal ex_MemToReg, ex_RegWrite, ex_MemWrite, ex_MemRead, ex_ALUSrc, ex_zero, clk:std_logic;
signal ex_ALUOp :std_logic_vector(1 downto 0);
signal ex_RegDst, ex_branch: std_logic;
-- added ex_instruction
signal ex_PC4, ex_branch_PC, ex_instruction : std_logic_vector(31 downto 0);
signal ex_register_rs, ex_register_rt, ex_sign_extend:std_logic_vector(31 downto 0);   
-- added ex_wreg_rs
signal ex_wreg_rd, ex_wreg_rt,ex_wreg_rs, ex_wreg_addr: std_logic_vector(4 downto 0); 
signal ex_alu_result :std_logic_vector(31 downto 0);

-- 
-- MEM
--

signal mem_MemToReg, mem_RegWrite, mem_MemWrite, mem_MemRead, mem_zero : std_logic;
signal mem_alu_result, mem_write_data, mem_memory_data, mem_Branch_PC, mem_instruction : std_logic_vector(31 downto 0);
signal mem_wreg_addr : std_logic_vector(4 downto 0);
signal mem_PCSource, mem_branch : std_logic;
 
--
-- WB
--

signal wb_MemToReg, wb_RegWrite :std_logic;
signal wb_memory_data, wb_alu_result : std_logic_vector(31 downto 0);
signal wb_wreg_addr: std_logic_vector(4 downto 0); 

--
-- global signals
--

-- added  pc_Stall
signal clock, reset, pc_Stall : std_logic;
begin

--
-- identify all signals that will show up on the trace and 
-- connnect them to internal signals on the datapath
--
-- what signals do we want to see from ID?
--
Out_ID_Instr <= id_instruction;
Out_ID_PC <= id_PC4;
--
-- signals traced from EX?
--
Out_EX_Rs <= ex_register_rs;
Out_EX_Rt <= ex_register_rt;
Out_EX_ALUSrc <= ex_ALUSrc;
Out_EX_RegDst <= ex_RegDst;
Out_EX_ALUOp <= ex_ALUOp;
--
-- signals traced from MEM?
--
Out_MEM_ALURes <= mem_alu_result;
Out_MEM_MemInData <= mem_write_data;
Out_MEM_MRead <= mem_MemRead;
Out_MEM_MWrite <= mem_MemWrite;
--
--signals traced from WB?
--
Out_WB_MemOut <= wb_memory_data;
Out_WB_ALU_Result <= wb_alu_result;
Out_WB_WReg <= wb_wreg_addr;
Out_WB_RegWrite <= wb_RegWrite;
Out_WB_MemToReg <= wb_MemToReg;



-- instantiate clock module

SCLK: my_clock 
port map(sys_clock => clock,
               reset => reset);
               
IFE: fetch    -- instantiate the fetch component

port map(PC_out => if_PC4,
         instruction => if_instruction,
         Branch_PC => mem_Branch_PC,
         PCSource => mem_PCSource,
         reset =>reset,
	 -- wire pc_Stall
	 pc_Stall => pc_Stall,
         clock => clock);

if_id: pipe_reg1  -- instantiate the pipeline registers IF/ID
port map(clk => clock,
	 reset => reset,
	 -- wire pc_Stall
	 pc_Stall => pc_Stall,
	 if_PC4 => if_PC4,
         if_instruction => if_instruction,
	 id_PC4 => id_PC4,
	 id_instruction => id_instruction);


spim_control: control -- instantiate the control component

port map(
        -- wire instruction
	instruction => id_instruction,
        -- wire ex_opcode
	opcode => id_instruction(31 downto 26),
	ex_wreg_addr => ex_wreg_addr,
	ex_opcode => ex_instruction(31 downto 26),

        RegDst => id_RegDst,

        MemRead => id_MemRead,
        MemToReg => id_MemToReg,
        MemWrite => id_MemWrite,

	-- wire pc_Stall
	pc_Stall => pc_Stall,
         
        ALUSrc => id_ALUSrc,
        Branch => id_Branch,
        RegWrite => id_RegWrite,
        ALUOp => id_ALUOp);

ID: decode  -- instantiate the decode component

port map(
	 -- wire instruction
         instruction => id_instruction,
         memory_data =>wb_memory_data,
         alu_result => wb_alu_result,
         RegWrite => wb_RegWrite,
         MemToReg => wb_MemToReg,
	 reset => reset,
         register_rs => id_register_rs,
         register_rt => id_register_rt,

         Sign_extend => id_Sign_extend,

	     wreg_address => wb_wreg_addr,
	     wreg_rd => id_wreg_rd,
	     -- wire wreg_rs
	     wreg_rs => id_wreg_rs,
	     wreg_rt => id_wreg_rt);

id_ex: pipe_reg2 -- instantiate the pipeline register ID/EX
port map(clk => clock,
         reset => reset, 
         -- wire pc_Stall
	 pc_Stall => pc_Stall,
	 id_branch => id_branch,
	 id_MemToReg => id_MemToReg,
	 id_RegWrite => id_RegWrite,
	 id_MemWrite => id_MemWrite,
	 id_MemRead => id_MemRead,
	 id_ALUSrc => id_ALUSrc,
	 id_RegDst => id_RegDst,
	 -- wire id_instruction
	 id_instruction => id_instruction,
         id_ALUOp  => id_ALUOp,
	 id_PC4 => id_PC4,
	
	 id_register_rs  => id_register_rs,
	 id_register_rt  => id_register_rt,
	 id_sign_extend  => id_sign_extend,
	 id_wreg_rd  => id_wreg_rd,
	 id_wreg_rt  => id_wreg_rt,
	 -- wire id_wreg_rs
	 id_wreg_rs => id_wreg_rs,

	 -- wire ex_instruction
         ex_instruction => ex_instruction,
         -- wire ex_wreg_rs
	 ex_wreg_rs => ex_wreg_rs,
	 ex_branch => ex_branch,
	 ex_MemToReg => ex_MemToReg,
	 ex_RegWrite => ex_RegWrite,
	 ex_MemWrite => ex_MemWrite,
	 ex_MemRead => ex_MemRead,
	 ex_ALUSrc => ex_ALUSrc,
	 ex_RegDst => ex_RegDst,

         ex_ALUOp => ex_ALUOp,
	 ex_PC4  => ex_PC4,
	 ex_register_rs  => ex_register_rs,
	 ex_register_rt  => ex_register_rt,
	 ex_sign_extend  => ex_sign_extend,
	 ex_wreg_rd  => ex_wreg_rd,

	 ex_wreg_rt  => ex_wreg_rt);

EX: execute  -- instantiate the component EX?

port map(PC4 => ex_PC4,
	 -- wire wb_MemToReg
	 wb_MemToReg => wb_MemToReg,
         register_rs => ex_register_rs,
         register_rt => ex_register_rt,
         sign_extend => ex_sign_extend,
	 -- wire wb_alu_result
	 wb_alu_result => wb_alu_result,
	 RegDst => ex_RegDst,
         ALUOp => ex_ALUOp,
         ALUSrc => ex_ALUSrc,
         alu_result => ex_alu_result,
	 wreg_rd => ex_wreg_rd,
	 wreg_rt => ex_wreg_rt,
	 -- wire wreg_rs
	 wreg_rs => ex_wreg_rs,
	 -- wire mem_alu_result
	 mem_alu_result => mem_alu_result,
         mem_RegWrite => mem_RegWrite,

	 -- wire mem_RegWrite, wb_memory_data,
	 -- wb_RegWrite, wb_wreg_addr, mem_wreg_addr
         wb_memory_data => wb_memory_data,
	 wb_RegWrite => wb_RegWrite,
	 wb_wreg_addr => wb_wreg_addr,
	 mem_wreg_addr => mem_wreg_addr,
	 
	 wreg_address => ex_wreg_addr,
         branch_pc => ex_branch_PC,
	 zero => ex_zero);

ex_mem: pipe_reg3 -- instantiate the pipeline registers EX/MEM
port map(clk => clock,
         reset => reset,	  
         ex_branch_pc => ex_branch_pc,
	 ex_branch => ex_branch,
	 ex_MemToReg => ex_MemToReg,
	 ex_RegWrite => ex_RegWrite,
	 ex_MemWrite => ex_MemWrite,
	 ex_MemRead => ex_MemRead,
	 ex_alu_result => ex_alu_result,
	 ex_register_rt  => ex_register_rt,
	 ex_wreg_addr => ex_wreg_addr,
	 ex_zero => ex_zero,
	 -- wire ex_instruction
	 ex_instruction =>ex_instruction,
	 
	 mem_branch_pc => mem_branch_pc,
	 mem_branch => mem_branch,
	 mem_MemToReg => mem_MemToReg,
	 mem_RegWrite => mem_RegWrite,
	 mem_MemWrite => mem_MemWrite,
	 mem_MemRead => mem_MemRead,
	 mem_alu_result  => mem_alu_result,
	 mem_register_rt => mem_write_data,
	 mem_wreg_addr => mem_wreg_addr,
	 -- wire mem_instruction
	 mem_instruction => mem_instruction,
	 mem_zero => mem_zero);		 
	 
	 -- generate the branch condition for fetch
		 
	 mem_PCSource <= mem_branch and mem_zero;

MEM: memory -- instantiate the memory component

port map(address => mem_alu_result,
         write_data => mem_write_data,
         MemWrite =>mem_MemWrite,
         MemRead => mem_MemRead,
         read_data => mem_memory_data);


mem_wb: pipe_reg4   -- instantiate the pipeline register MEM/WB
port map(clk => clock,
	 reset => reset,
	 mem_MemToReg => mem_MemToReg,
	 mem_RegWrite => mem_RegWrite,
	 mem_memory_data => mem_memory_data,
	 -- wire mem_instruction
	 mem_instruction => mem_instruction,
	 mem_alu_result => mem_alu_result,
 	 mem_wreg_addr => mem_wreg_addr,

	 wb_MemToReg  => wb_MemToReg,
	 wb_RegWrite => wb_RegWrite,
	
	 wb_memory_data  => wb_memory_data,
	 wb_alu_result => wb_alu_result,
 	 wb_wreg_addr => wb_wreg_addr);
 
end structural;


