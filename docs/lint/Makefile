HPDCACHE_DIR = ../..

export HPDCACHE_DIR

verilator-lint:
	verilator --cc \
		-Wno-fatal \
		-error-limit 100 \
		--top hpdcache_lint \
		-f $(HPDCACHE_DIR)/rtl/hpdcache.Flist \
		$(HPDCACHE_DIR)/rtl/src/common/macros/behav/*.sv \
		hpdcache_lint.sv
