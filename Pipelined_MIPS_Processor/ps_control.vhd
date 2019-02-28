--
-- Control unit.
-- Simply implements the truth table for a small set of
-- instructions 
--

Library IEEE;
use IEEE.std_logic_1164.all;

entity control is
port(opcode, ex_opcode: in std_logic_vector(5 downto 0);
     -- added ex_wreg_addr
     ex_wreg_addr : in std_logic_vector(4 downto 0);
     -- added instruction
     instruction : in std_logic_vector(31 downto 0);
     -- added pc_Stall
     RegDst, MemRead, MemToReg, MemWrite, pc_Stall :out  std_logic;
     ALUSrc, RegWrite, Branch: out std_logic;
     ALUOp: out std_logic_vector(1 downto 0));
end control;

architecture behavioral of control is

signal rformat, lw, sw, beq  :std_logic; -- define local signals
				    -- corresponding to instruction
				    -- type 
-- added load_to_use signal
signal load_to_use :std_logic;
 begin 
--
-- recognize opcode for each instruction type
-- these variable should be inferred as wires	 

	rformat     <=  '1'  WHEN  Opcode = "000000"  ELSE '0';
	Lw          <=  '1'  WHEN  Opcode = "100011"  ELSE '0';
 	Sw          <=  '1'  WHEN  Opcode = "101011"  ELSE '0';
   	Beq         <=  '1'  WHEN  Opcode = "000100"  ELSE '0';

-- Logic to detect hazards / stalls

-- load_to_use gets true when ex_wreg_addr == (rs or rt)
load_to_use <= '1' when (instruction(25 downto 21) = ex_wreg_addr or instruction(20 downto 16) = ex_wreg_addr) else
	'0';

-- pc_Stall gets true when the pipeline has a load instruction and load_to_use is asserted
pc_Stall <= '1' when (opcode ="000000" and ex_opcode = "100011" and load_to_use ='1') else
 	  '0';

--
-- implement each output signal as the column of the truth
-- table  which defines the control
--

RegDst <= rformat;
ALUSrc <= (lw or sw) ;

MemToReg <= lw ;
RegWrite <= (rformat or lw);
MemRead <= lw ;
MemWrite <= sw;	   
Branch <= beq;

-- FLAG
ALUOp(1 downto 0) <=  rformat & beq; -- note the use of the concatenation operator
				     -- to form  2 bit signal
                                     
end behavioral;
