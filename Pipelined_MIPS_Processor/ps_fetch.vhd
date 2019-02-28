--
-- Instruction fetch behavioral model.
-- 

Library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.Std_logic_arith.all;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;


entity fetch is 
--

port(instruction  : out std_logic_vector(31 downto 0);
	  PC_out       : out std_logic_vector (31 downto 0);
	  Branch_PC    : in std_logic_vector(31 downto 0);
	  -- added pc_Stall
	  clock, reset, PCSource, pc_Stall:  in std_logic);
end fetch;

architecture behavioral of fetch is 
TYPE INST_MEM IS ARRAY (0 to 11) of STD_LOGIC_VECTOR (31 DOWNTO 0);
   SIGNAL iram : INST_MEM := (
   	

	X"01084020", -- add $t0 $t0 $t0
	X"01284820", -- add $t1 $t1 $t0
	X"01285020", -- add $t2 $t1 $t0
	
   	X"8C10000C", -- lw $s0 12($zero)
	X"8C110004", -- lw $s1 4($zero)
	X"02308820", -- add $s1 $s1 $s0

	X"00008020", -- add $s0 $zero $zero
	X"02008820", -- add $s1 $s0 $zero
	X"1000FFFD", -- beq $zero $zero -3
	X"01090020", -- add $zero $t0 $t1
	X"012A8020", -- add $s0 $t1 $t2
	X"8C10000C" -- lw $s0 12($zero)
	);
   
   SIGNAL PC, Next_PC : STD_LOGIC_VECTOR( 31 DOWNTO 0 );

BEGIN 						
-- access instruction pointed to by current PC
-- and increment PC by 4. This is combinational
		             
Instruction <=  iram(CONV_INTEGER(PC(4 downto 2)));  -- since the instruction
                                                     -- memory is indexed by integer
-- added condition to update PC
PC_out<= (PC + 4) when pc_Stall = '0' else
              PC;			
   
-- compute value of next PC and Prevent the PC from updating, if needed

Next_PC <=  (PC + 4)     when pc_Stall = '0'  and  PCSource = '0' else
            Branch_PC    when pc_Stall = '0' and PCSource = '1'  else 
            PC           when pc_Stall ='1' else
            X"CCCCCCCC";
			   
-- update the PC on the next clock			   
	PROCESS
		BEGIN
			WAIT UNTIL (rising_edge(clock));
			IF (reset = '1') THEN
				PC<= X"00000000" ;
			ELSE 
				PC <= Next_PC;    -- cannot read/write a port hence need to duplicate info
			 end if; 
			 
	END PROCESS; 
   
   end behavioral;


	
