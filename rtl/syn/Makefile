# Copyright 2025 Inria
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Authors         Cesar Fuguet
# Creation Date   June, 2025
#
ORFS_GIT_URL=https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git

all: syn

syn: deps
	bash utils/run_yosys_synth.sh

deps: third-party/ORFS

third-party/ORFS:
	mkdir -p third-party
	git clone --depth 1 ${ORFS_GIT_URL} $@

clean:
	rm -rf log
	rm -rf netlist
	rm -rf report

distclean: clean
	rm -rf third-party/ORFS

.PHONY: syn deps distclean clean
