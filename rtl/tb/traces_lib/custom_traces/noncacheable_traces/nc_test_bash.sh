#!/bin/bash
set -e

make run TRACE=0 SEQUENCE=from_trace TRACE_SEQ_FILE=/root/hpdcache-pr/rtl/tb/traces_lib/custom_traces/noncacheable_traces/NC_MISS_ONLY.bin LOG_LEVEL=3 SEED=42 CONFIG=configs/default_config_wb.mk
make run TRACE=0 SEQUENCE=from_trace TRACE_SEQ_FILE=/root/hpdcache-pr/rtl/tb/traces_lib/custom_traces/noncacheable_traces/NC_ON_CLEAN_HIT.bin LOG_LEVEL=3 SEED=42 CONFIG=configs/default_config_wb.mk
make run TRACE=0 SEQUENCE=from_trace TRACE_SEQ_FILE=/root/hpdcache-pr/rtl/tb/traces_lib/custom_traces/noncacheable_traces/NC_ON_DIRTY_HIT.bin LOG_LEVEL=3 SEED=42 CONFIG=configs/default_config_wb.mk
make run TRACE=0 SEQUENCE=from_trace TRACE_SEQ_FILE=/root/hpdcache-pr/rtl/tb/traces_lib/custom_traces/noncacheable_traces/NC_ONLY_CONSECUTIVE.bin LOG_LEVEL=3 SEED=42 CONFIG=configs/default_config_wb.mk

make run SEQUENCE=random LOG_LEVEL=3 NTRANSACTIONS=10000 SEED=42 CONFIG=configs/default_config_wb.mk
make run SEQUENCE=read LOG_LEVEL=3 NTRANSACTIONS=10000 SEED=42 CONFIG=configs/default_config_wb.mk
make run SEQUENCE=write LOG_LEVEL=3 NTRANSACTIONS=10000 SEED=42 CONFIG=configs/default_config_wb.mk
make run SEQUENCE=unique_set LOG_LEVEL=3 NTRANSACTIONS=10000 SEED=42 CONFIG=configs/default_config_wb.mk

make nonregression SEQUENCE=random LOG_LEVEL=3 NTRANSACTIONS=10000 NTESTS=32 CONFIG=configs/default_config_wb.mk