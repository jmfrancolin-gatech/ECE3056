TIME=500ns
GHDL = ghdl
GHDL_SIM_OPT = --stop-time=$(TIME)
GHDL_FLAGS = --ieee=synopsys -fexplicit
WORKDIR = Simulate
TOP_ENTITY = spim_pipe
echoPath = .bash_profile

.PHONY : all compile run
all : ./Simulate compile run

./Simulate :
	mkdir -p $(WORKDIR)
	$(GHDL) -i --workdir=$(WORKDIR) *.vhd

compile :
	$(GHDL) -m $(GHDL_FLAGS) --workdir=$(WORKDIR)/ $(TOP_ENTITY)

run :
	$(GHDL) -r --workdir=$(WORKDIR) $(TOP_ENTITY) --stop-time=$(TIME) --wave=$(TOP_ENTITY).ghw --vcd=$(TOP_ENTITY).vcd

clean :
	rm -rf Simulate
	rm -f $(TOP_ENTITY).ghw
	rm -f $(TOP_ENTITY).vcd
	rm -f e~$(TOP_ENTITY).o

install-OSX :
	./install.sh

test :
	printf "export PATH=\"~/sources/GHDL/bin/:\$${PATH}\"\n" >> ~/$(echoPath)
