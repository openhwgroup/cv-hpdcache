/*
 *  Copyright 2023 CEA*
 *  *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 *  Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 *  may not use this file except in compliance with the License, or, at your
 *  option, the Apache License version 2.0. You may obtain a copy of the
 *  License at
 *
 *  https://solderpad.org/licenses/SHL-2.1/
 *
 *  Unless required by applicable law or agreed to in writing, any work
 *  distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 *  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 *  License for the specific language governing permissions and limitations
 *  under the License.
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : February, 2023
 *  Description   : HPDcache Types' Definition
 *  History       :
 */
`ifndef __HPDCACHE_TYPEDEF_SVH__
`define __HPDCACHE_TYPEDEF_SVH__

`define HPDCACHE_DECL_MEM_REQ_T(addr_t, id_t) \
    struct packed { \
        addr_t                                mem_req_addr; \
        hpdcache_pkg::hpdcache_mem_len_t      mem_req_len; \
        hpdcache_pkg::hpdcache_mem_size_t     mem_req_size; \
        id_t                                  mem_req_id; \
        hpdcache_pkg::hpdcache_mem_command_e  mem_req_command; \
        hpdcache_pkg::hpdcache_mem_atomic_e   mem_req_atomic; \
        logic                                 mem_req_cacheable; \
    }

`define HPDCACHE_DECL_MEM_RESP_R_T(id_t, data_t) \
    struct packed { \
        hpdcache_pkg::hpdcache_mem_error_e    mem_resp_r_error; \
        id_t                                  mem_resp_r_id; \
        data_t                                mem_resp_r_data; \
        logic                                 mem_resp_r_last; \
    }

`define HPDCACHE_DECL_MEM_REQ_W_T(data_t, be_t) \
    struct packed { \
        data_t                                mem_req_w_data; \
        be_t                                  mem_req_w_be; \
        logic                                 mem_req_w_last; \
    }

`define HPDCACHE_DECL_MEM_RESP_W_T(id_t) \
    struct packed { \
        logic                                 mem_resp_w_is_atomic; \
        hpdcache_pkg::hpdcache_mem_error_e    mem_resp_w_error; \
        id_t                                  mem_resp_w_id; \
    }

`define HPDCACHE_TYPEDEF_MEM_REQ_T(__name__, addr_t, id_t) \
    typedef `HPDCACHE_DECL_MEM_REQ_T(addr_t, id_t) __name__

`define HPDCACHE_TYPEDEF_MEM_RESP_R_T(__name__, id_t, data_t) \
    typedef `HPDCACHE_DECL_MEM_RESP_R_T(id_t, data_t) __name__

`define HPDCACHE_TYPEDEF_MEM_REQ_W_T(__name__, data_t, be_t) \
    typedef `HPDCACHE_DECL_MEM_REQ_W_T(data_t, be_t) __name__

`define HPDCACHE_TYPEDEF_MEM_RESP_W_T(__name__, id_t) \
    typedef `HPDCACHE_DECL_MEM_RESP_W_T(id_t) __name__

`define HPDCACHE_DECL_REQ_T(offset_t, data_t, be_t, sid_t, tid_t, tag_t) \
    struct packed { \
        offset_t                          addr_offset; \
        data_t                            wdata; \
        hpdcache_pkg::hpdcache_req_op_t   op; \
        be_t                              be; \
        hpdcache_pkg::hpdcache_req_size_t size; \
        sid_t                             sid; \
        tid_t                             tid; \
        logic                             need_rsp; \
        logic                             phys_indexed; \
        tag_t                             addr_tag; \
        hpdcache_pkg::hpdcache_pma_t      pma; \
    }

`define HPDCACHE_TYPEDEF_REQ_T(__name__, offset_t, data_t, be_t, sid_t, tid_t, tag_t) \
    typedef `HPDCACHE_DECL_REQ_T(offset_t, data_t, be_t, sid_t, tid_t, tag_t) __name__

`define HPDCACHE_DECL_RSP_T(data_t, sid_t, tid_t) \
    struct packed { \
        data_t   rdata; \
        sid_t    sid; \
        tid_t    tid; \
        logic    error; \
        logic    aborted; \
    }

`define HPDCACHE_TYPEDEF_RSP_T(__name__, data_t, sid_t, tid_t) \
    typedef `HPDCACHE_DECL_RSP_T(data_t, sid_t, tid_t) __name__

`endif //  __HPDCACHE_TYPEDEF_SVH__
