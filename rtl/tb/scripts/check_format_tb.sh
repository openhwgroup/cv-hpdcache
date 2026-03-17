#!/bin/bash
##
#  Copyright 2026 Univ. Grenoble Alpes, Inria, TIMA Laboratory
#
#  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
##
#  Author     : Cesar Fuguet
#  Date       : March, 2026
#  Description: C++ code formatting wrapper script
##
FLIST=/tmp/hpdcache_tb.flist
SRC_DIRS=(include/
          sc_verif_lib/
          qemu_plugin/
          sequence_lib/)

find ${SRC_DIRS} -type f \( \
        -name '*.h' -or \
        -name '*.c' -or \
        -name '*.cpp' \) \
        > ${FLIST}

clang-format-15 -Werror --dry-run --files ${FLIST} hpdcache_tb.cpp
