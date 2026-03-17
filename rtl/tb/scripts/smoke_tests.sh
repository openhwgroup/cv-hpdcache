#!/bin/bash
##
#  Copyright 2026 Univ. Grenoble Alpes, Inria, TIMA Laboratory
#
#  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
##
#  Author     : Cesar Fuguet
#  Date       : March, 2026
#  Description: short nonregression script
##
SCRIPT_DIR=$(dirname $(readlink -f $0))
TEST_DIR=$(readlink -f ${SCRIPT_DIR}/..)
LINT_DIR=$(readlink -f ${SCRIPT_DIR}/../../lint)
NTRANS=$((16*1024))
NTESTS=8
SEQUENCES=(random)
USER_ARGS=$*
CONFIGS=(configs/directmap_config.mk
         configs/embedded_config.mk
         configs/hpc_config.mk
         configs/default_config.mk)

(
    cd ${TEST_DIR}
    printf "Checking formatting of testbench C++ sources in ${TEST_DIR}\n"
    ./scripts/check_format_tb.sh
)
ret=$?
if [[ ${ret} != 0 ]] ; then
    printf "FAILURE: there are formatting issues in C++ testbench files\n"
    exit 1 ;
fi

for c in ${CONFIGS[@]} ; do
    make -s -C ${LINT_DIR} verible-lint
    ret=$?
    if [[ ${ret} != 0 ]] ; then
        printf "FAILURE: there are linting errors\n"
        exit 1 ;
    fi

    for s in ${SEQUENCES[@]} ; do
        make -s -C ${TEST_DIR} nonregression \
                CONFIG=${c} \
                SEQUENCE=${s} \
                NTESTS=${NTESTS} \
                NTRANSACTIONS=${NTRANS} \
                ${USER_ARGS}

        ret=$?
        if [[ ${ret} != 0 ]] ; then
            printf "FAILURE: there are failing tests\n"
            printf "Run \"make nonregression CONFIG=$s SEQUENCE=$s\" in the <git>/rtl/tb directory for details\n"
            exit 1 ;
        fi
    done
done

printf "SUCCESS: all tests succeed\n"
exit 0 ;
