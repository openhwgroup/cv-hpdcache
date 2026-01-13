#!/bin/bash
##
#  Copyright 2025 Inria, Universite Grenoble-Alpes, TIMA
#  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
##
#  Author     : Cesar Fuguet
#  Date       : July, 2025
#  Description: Check code style of the C++ testbench using clang-format
##
(
    find rtl/tb \
    \( -not -path "rtl/tb/thirdparty/*" -and \
       -not -path "rtl/tb/build/*" -and \
        \( -name '*.cpp' -or -name '*.c' -or -name '*.h' \) \
    \) \
    -exec clang-format-15 --style=file:rtl/tb/.clang-format -Werror -n {} \;
) |& tee clang-format.log
grep -q 'error:' clang-format.log
[[ $? -eq 0 ]] && exit 1
exit 0
