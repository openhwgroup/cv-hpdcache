#!/bin/bash

python3 vendor.py lowrisc_opentitan.vendor.hjson -v
patch -p1 -d opentitan/util/design < patches/opentitan/util/design/001_secded_gen_no_c.patch
