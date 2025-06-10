#!/bin/bash
# Copyright 2025 Inria
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Authors         Cesar Fuguet
# Creation Date   June, 2025
#
script_filename=$(basename $0 .sh)

if [[ ! -d third-party/ORFS ]] ; then
    echo "error: OpenROAD Flow Scripts (ORFS) not found"
    exit 1
fi

export HPDCACHE_DIR=`pwd`/../..
export YOSYS_NETLIST_OUTDIR=netlist
export YOSYS_REPORT_OUTDIR=report
export YOSYS_LOG_OUTDIR=log
export YOSYS_TOP_MODULE=hpdcache_wrapper
export YOSYS_RTL_FILELIST=${YOSYS_TOP_MODULE}.Flist
export YOSYS_BLACKBOX_MODULES="n:*fakeram45_64x64*"
export YOSYS_KEEP_MODULES=
export YOSYS_CELLS_LIB_PATH=third-party/ORFS/flow/platforms/nangate45/lib
export YOSYS_CELLS_LIB=${YOSYS_CELLS_LIB_PATH}/NangateOpenCellLibrary_typical.lib
export YOSYS_MACROS_LIB=${YOSYS_CELLS_LIB_PATH}/fakeram45_64x64.lib
export YOSYS_ABC_SDC=sdc/${YOSYS_TOP_MODULE}.abc.sdc
export YOSYS_FLATTEN_HIER=1
export YOSYS_CLOCK_PERIOD=10000
export YOSYS_CLOCK_UPRATE=1.5

mkdir -p ${YOSYS_LOG_OUTDIR}
mkdir -p ${YOSYS_NETLIST_OUTDIR}
mkdir -p ${YOSYS_REPORT_OUTDIR}

yosys -c tcl/yosys_synth.tcl \
    -l ${YOSYS_LOG_OUTDIR}/yosys_synth.log \
    |& tee ${YOSYS_LOG_OUTDIR}/${script_filename}.log

yosys_status=$?
if [[ ${yosys_status} != 0 ]]; then
    echo "ERROR: Yosys exited with an error"
    exit ${yosys_status}
fi
errors=$(grep -i '^ERROR:' ${YOSYS_LOG_OUTDIR}/${script_filename}.log)
if [[ "x${errors}" != "x" ]] ; then
    echo "ERROR: Yosys found errors during synthesis"
    exit 1
fi

exit 0
