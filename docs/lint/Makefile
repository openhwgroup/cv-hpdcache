HPDCACHE_DIR = ../..

export HPDCACHE_DIR

HPDCACHE_FILES=$(shell grep '.*.sv' $(HPDCACHE_DIR)/rtl/hpdcache.Flist)

verilator-lint:
	verilator --cc \
		-Wno-fatal \
		-error-limit 100 \
		--top hpdcache_lint \
		-f $(HPDCACHE_DIR)/rtl/hpdcache.Flist \
		$(HPDCACHE_DIR)/rtl/src/common/macros/behav/*.sv \
		hpdcache_lint.sv

verible-lint:
	verible-verilog-lint \
		--rules_config verible_rules.cfg \
		$(HPDCACHE_FILES) \
		$(HPDCACHE_DIR)/rtl/src/common/macros/behav/*.sv \
		hpdcache_lint.sv
