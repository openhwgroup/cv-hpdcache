##
#  Copyright 2023,2024 CEA*
#  *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
#
#  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
#  Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
#  may not use this file except in compliance with the License, or, at your
#  option, the Apache License version 2.0. You may obtain a copy of the
#  License at
#
#  https://solderpad.org/licenses/SHL-2.1/
#
#  Unless required by applicable law or agreed to in writing, any work
#  distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#  License for the specific language governing permissions and limitations
#  under the License.
##
##
#  Author     : Cesar Fuguet
#  Date       : October, 2024
#  Description: HPDCACHE Test Makefile
##
CONF_HPDCACHE_PA_WIDTH=40
CONF_HPDCACHE_WORD_WIDTH=32
CONF_HPDCACHE_SETS=32
CONF_HPDCACHE_WAYS=4
CONF_HPDCACHE_CL_WORDS=4
CONF_HPDCACHE_REQ_WORDS=1
CONF_HPDCACHE_REQ_TRANS_ID_WIDTH=3
CONF_HPDCACHE_REQ_SRC_ID_WIDTH=3
CONF_HPDCACHE_VICTIM_SEL=HPDCACHE_VICTIM_RANDOM
CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD=4
CONF_HPDCACHE_DATA_SETS_PER_RAM=$(CONF_HPDCACHE_SETS)
CONF_HPDCACHE_DATA_RAM_WBYTEENABLE=1
CONF_HPDCACHE_ACCESS_WORDS=4
CONF_HPDCACHE_MSHR_SETS=1
CONF_HPDCACHE_MSHR_WAYS=4
CONF_HPDCACHE_MSHR_WAYS_PER_RAM_WORD=$(CONF_HPDCACHE_MSHR_WAYS)
CONF_HPDCACHE_MSHR_SETS_PER_RAM=$(CONF_HPDCACHE_MSHR_SETS)
CONF_HPDCACHE_MSHR_RAM_WBYTEENABLE=0
CONF_HPDCACHE_MSHR_USE_REGBANK=1
CONF_HPDCACHE_REFILL_CORE_RSP_FEEDTHROUGH=1
CONF_HPDCACHE_REFILL_FIFO_DEPTH=2
CONF_HPDCACHE_WBUF_DIR_ENTRIES=4
CONF_HPDCACHE_WBUF_DATA_ENTRIES=2
CONF_HPDCACHE_WBUF_WORDS=1
CONF_HPDCACHE_WBUF_TIMECNT_WIDTH=3
CONF_HPDCACHE_WBUF_SEND_FEEDTHROUGH=0
CONF_HPDCACHE_RTAB_ENTRIES=2
CONF_HPDCACHE_FLUSH_ENTRIES=4
CONF_HPDCACHE_FLUSH_FIFO_DEPTH=2
CONF_HPDCACHE_MEM_ADDR_WIDTH=64
CONF_HPDCACHE_MEM_ID_WIDTH=4
CONF_HPDCACHE_MEM_DATA_WIDTH=64
CONF_HPDCACHE_WT_ENABLE=1
CONF_HPDCACHE_WB_ENABLE=0
CONF_HPDCACHE_FAST_LOAD=1