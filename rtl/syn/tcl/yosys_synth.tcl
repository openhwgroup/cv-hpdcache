#
# Copyright 2025 Inria
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Authors        Cesar Fuguet
# Creation Date  May, 2025
# Description    Yosys synthesis script
#
source tcl/yosys_common.tcl

yosys log "======== Yosys Parse RTL Sources ========"
yosys read_slang -F ${param_filelist}
yosys setattr -set top 1 ${param_top}
yosys setattr -unset init
yosys log "======== Yosys End Parse RTL Sources ========\n"

yosys log "======== Yosys Parse Liberty Files ========"
foreach file ${param_synth_macros_lib_path} {
    yosys read_liberty -lib "$file"
}
yosys log "======== Yosys End Parse Liberty Files ========\n"

yosys log "======== Yosys Synthetize ========"
if { [info exists param_blackboxes] } {
    foreach sel ${param_blackboxes} {
        yosys log "Blackboxing the module ${sel}"
        yosys select -list {*}$sel
#        yosys blackbox {*}$sel
        yosys setattr -set keep_hierarchy 1 {*}$sel
    }
}
if { [info exists param_keep_modules] } {
    foreach sel ${param_keep_modules} {
        yosys log "Keep module ${sel}"
        yosys select -list {*}$sel
        yosys setattr -set keep_hierarchy 1 {*}$sel
    }
}
yosys hierarchy -check -top ${param_top}
yosys proc
yosys write_verilog -noattr ${param_netlist_dir}/${param_top}.premap.v
yosys opt_expr
yosys opt_clean
yosys check
yosys opt -noff
yosys fsm
yosys opt
yosys wreduce
yosys peepopt
yosys opt_clean
yosys opt -full
yosys booth
yosys alumacc
yosys share
yosys opt
yosys memory
yosys opt -fast
yosys opt_dff -sat -nodffe -nosdff
yosys share
yosys opt -full
yosys clean -purge
yosys check
yosys log "======== Yosys End Synthetize ========\n"

yosys log "======== Yosys Generic Mapping ========"
yosys techmap
yosys opt -fast
yosys clean -purge

if { ${param_synth_flatten} } {
    yosys flatten
}

yosys opt
yosys opt_dff -sat -nodffe -nosdff
yosys clean
yosys check
yosys log "======== Yosys End Generic Mapping ========\n"

yosys log "======== Yosys Target Technology Mapping ========"
set abc_args ""
if { ${param_synth_timing_run} } {
  set abc_args "${abc_args} -liberty ${param_synth_cell_lib_path}"
  set abc_args "${abc_args} -constr ${param_synth_abc_sdc_file_in}"
  set abc_args "${abc_args} -D ${yosys_abc_clk_period}"
}
yosys dfflibmap -liberty ${param_synth_cell_lib_path}
yosys "abc ${abc_args}"
yosys clean
yosys check
yosys log "======== Yosys End Target Technology Mapping ========\n"

yosys log "======== Yosys Write Final Netlist ========"
yosys write_verilog ${param_netlist_dir}/${param_top}.postmap.v
yosys log "======== Yosys End Write Final Netlist ========\n"

yosys log "======== Yosys Stat Report ========"
yosys tee -o ${param_report_dir}/area.rpt stat \
    -liberty ${param_synth_cell_lib_path} \
    -liberty ${param_synth_macros_lib_path}
yosys log "======== Yosys End Stat Report ========\n"
