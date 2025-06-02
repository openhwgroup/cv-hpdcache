#
# Copyright 2025 Inria
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Authors        Cesar Fuguet
# Creation Date  May, 2025
# Description    Yosys synthesis script
#
yosys plugin -i slang
yosys echo on
set param_netlist_dir $::env(YOSYS_NETLIST_OUTDIR)
set param_report_dir $::env(YOSYS_REPORT_OUTDIR)
set param_top $::env(YOSYS_TOP_MODULE)
set param_filelist $::env(YOSYS_RTL_FILELIST)
set param_blackboxes $::env(YOSYS_BLACKBOX_MODULES)
set param_synth_flatten $::env(YOSYS_FLATTEN_HIER)
set param_synth_timing_run 1
set param_synth_clk_period $::env(YOSYS_CLOCK_PERIOD)
set param_synth_abc_clk_uprate [expr ${param_synth_clk_period}/$::env(YOSYS_CLOCK_UPRATE)]
set param_synth_abc_sdc_file_in $::env(YOSYS_ABC_SDC)
set param_synth_cell_lib_path $::env(YOSYS_CELLS_LIB)
set param_synth_macros_lib_path $::env(YOSYS_MACROS_LIB)
set yosys_abc_clk_period [expr ${param_synth_clk_period} - ${param_synth_abc_clk_uprate}]
