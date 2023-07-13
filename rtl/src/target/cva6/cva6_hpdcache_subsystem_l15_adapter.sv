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
 *  Authors      : Noelia Oliete, Cesar Fuguet
 *  Creation Date: June, 2023
 *  Description  : Adapter module to connect the HPDC and L1I$ to the native interface of the OpenPiton L1.5 cache.
 *                 L1 Dcache (CV-HPDcache).
 *  History      :
 */
module cva6_hpdcache_subsystem_l15_adapter import ariane_pkg::*;import wt_cache_pkg::*;import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
  parameter ariane_pkg::ariane_cfg_t ArianeCfg = ariane_pkg::ArianeDefaultConfig,  // contains cacheable regions

  parameter int  HPDcacheMemDataWidth = 128, //L1D cacheline

  parameter type hpdcache_mem_req_t = logic,
  parameter type hpdcache_mem_req_w_t = logic,
  parameter type hpdcache_mem_resp_r_t = logic,
  parameter type hpdcache_mem_resp_w_t = logic,
  parameter type hpdcache_mem_id_t = logic,
  parameter type hpdcache_mem_addr_t = logic,
  parameter type req_portid_t = logic
)
//  }}}

//  Ports
//  {{{
(
  input   logic                               clk_i,
  input   logic                               rst_ni,

  //  Interfaces from/to I$
  //  {{{
  input   logic                               icache_miss_valid_i,
  output  logic                               icache_miss_ready_o,
  input   wt_cache_pkg::icache_req_t          icache_miss_i,
  input   req_portid_t                        icache_miss_pid_i,

  output  logic                               icache_miss_resp_valid_o,
  output  wt_cache_pkg::icache_rtrn_t         icache_miss_resp_o,
  //  }}}

  //  Interfaces from/to D$
  //  {{{
  output  logic                               dcache_miss_ready_o,
  input   logic                               dcache_miss_valid_i,
  input   hpdcache_mem_req_t                  dcache_miss_i,
  input   req_portid_t                        dcache_miss_pid_i,

  input   logic                               dcache_miss_resp_ready_i,
  output  logic                               dcache_miss_resp_valid_o,
  output  hpdcache_mem_resp_r_t               dcache_miss_resp_o,

  //      Write-buffer write interface
  output  logic                               dcache_wbuf_ready_o,
  input   logic                               dcache_wbuf_valid_i,
  input   hpdcache_mem_req_t                  dcache_wbuf_i,
  input   req_portid_t                        dcache_wbuf_pid_i,

  output  logic                               dcache_wbuf_data_ready_o,
  input   logic                               dcache_wbuf_data_valid_i,
  input   hpdcache_mem_req_w_t                dcache_wbuf_data_i,

  input   logic                               dcache_wbuf_resp_ready_i,
  output  logic                               dcache_wbuf_resp_valid_o,
  output  hpdcache_mem_resp_w_t               dcache_wbuf_resp_o,

  //      Uncached read interface
  output  logic                               dcache_uc_read_ready_o,
  input   logic                               dcache_uc_read_valid_i,
  input   hpdcache_mem_req_t                  dcache_uc_read_i,
  input   req_portid_t                        dcache_uc_read_pid_i,

  input   logic                               dcache_uc_read_resp_ready_i,
  output  logic                               dcache_uc_read_resp_valid_o,
  output  hpdcache_mem_resp_r_t               dcache_uc_read_resp_o,

  //      Uncached write interface
  output  logic                               dcache_uc_write_ready_o,
  input   logic                               dcache_uc_write_valid_i,
  input   hpdcache_mem_req_t                  dcache_uc_write_i,
  input   req_portid_t                        dcache_uc_write_pid_i,

  output  logic                               dcache_uc_write_data_ready_o,
  input   logic                               dcache_uc_write_data_valid_i,
  input   hpdcache_mem_req_w_t                dcache_uc_write_data_i,

  input   logic                               dcache_uc_write_resp_ready_i,
  output  logic                               dcache_uc_write_resp_valid_o,
  output  hpdcache_mem_resp_w_t               dcache_uc_write_resp_o,
  //  }}}
  
  //    Ports to/from L1.5 
  //  {{{
  output l15_req_t                                l15_req_o,
  input  l15_rtrn_t                               l15_rtrn_i
  //  }}}
);
//  }}}

  // Internal types of the adapter
  // {{{
  typedef logic [ariane_pkg::ICACHE_LINE_WIDTH-1:0]  icache_resp_data_t;
  typedef struct packed {
       logic                                            all;         // invalidate all ways
       logic [ariane_pkg::ICACHE_INDEX_WIDTH-1:0]       idx;         // physical address to invalidate
  } hpdcache_mem_inval_t;

  //Unified structure for r and w responses
  typedef struct packed {

       hpdcache_mem_error_e                    mem_resp_error; //mem_resp_r_error/mem_resp_w_error
       hpdcache_mem_id_t                       mem_resp_id;    //mem_resp_r_id/mem_resp_w_id
       logic [ariane_pkg::ICACHE_LINE_WIDTH-1:0] mem_resp_r_data; //Fixed to 32B (OP ICACHE line size)
       logic                                   mem_resp_r_last;
       logic                                   mem_resp_w_is_atomic;
       hpdcache_mem_inval_t                    mem_inv;
  } hpdcache_mem_resp_t;
  //  }}}

  //  Adapt the I$ interface to the HPDcache memory interface
  //  {{{
  localparam int ICACHE_CL_WORDS        = ariane_pkg::ICACHE_LINE_WIDTH/64;
  localparam int ICACHE_CL_WORD_INDEX   = $clog2(ICACHE_CL_WORDS);
  localparam int ICACHE_CL_SIZE         = $clog2(ariane_pkg::ICACHE_LINE_WIDTH/8);
  localparam int ICACHE_WORD_SIZE       = ArianeCfg.Axi64BitCompliant ? 3 : 2;
  localparam int ICACHE_MEM_REQ_CL_LEN  =
    (ariane_pkg::ICACHE_LINE_WIDTH + HPDcacheMemDataWidth - 1)/HPDcacheMemDataWidth;
  localparam int ICACHE_MEM_REQ_CL_SIZE =
    (HPDcacheMemDataWidth <= ariane_pkg::ICACHE_LINE_WIDTH) ?
      $clog2(HPDcacheMemDataWidth/8) :
      ICACHE_CL_SIZE;

  //    I$ request
  //    {{{
  hpdcache_mem_req_t  icache_miss_req_wdata;
  logic  icache_miss_req_w, icache_miss_req_wok;

  hpdcache_mem_req_t  icache_miss_req_rdata;
  logic  icache_miss_req_r, icache_miss_req_rok;

  //  This FIFO has two functionnalities:
  //  -  Stabilize the ready-valid protocol. The ICACHE can abort a valid
  //     transaction without receiving the corresponding ready signal. This
  //     behavior is not supported by AXI.
  //  -  Cut a possible long timing path.
  hpdcache_fifo_reg #(
      .FIFO_DEPTH  (1),
      .fifo_data_t (hpdcache_mem_req_t)
  ) i_icache_miss_req_fifo (
      .clk_i,
      .rst_ni,

      .w_i    (icache_miss_req_w),
      .wok_o  (icache_miss_req_wok),
      .wdata_i(icache_miss_req_wdata),

      .r_i    (icache_miss_req_r), 
      .rok_o  (icache_miss_req_rok),
      .rdata_o(icache_miss_req_rdata)
  );

  assign icache_miss_req_w   = icache_miss_valid_i,
         icache_miss_ready_o = icache_miss_req_wok;

  assign icache_miss_req_wdata.mem_req_addr      = icache_miss_i.paddr,
         icache_miss_req_wdata.mem_req_len       = icache_miss_i.nc ? 0 : ICACHE_MEM_REQ_CL_LEN - 1,
         icache_miss_req_wdata.mem_req_size      = icache_miss_i.nc ? ICACHE_WORD_SIZE : ICACHE_MEM_REQ_CL_SIZE,
         icache_miss_req_wdata.mem_req_id        = icache_miss_i.tid,
         icache_miss_req_wdata.mem_req_command   = hpdcache_pkg::HPDCACHE_MEM_READ,
         icache_miss_req_wdata.mem_req_atomic    = hpdcache_pkg::hpdcache_mem_atomic_e'(0),
         icache_miss_req_wdata.mem_req_cacheable = ~icache_miss_i.nc;
  //    }}}


  //    I$ response
  //    {{{
  logic                                icache_miss_resp_w, icache_miss_resp_wok;
  hpdcache_mem_resp_t                  icache_miss_resp_wdata;

  logic                                icache_miss_resp_data_w, icache_miss_resp_data_wok;
  logic                                icache_miss_resp_data_r;
  icache_resp_data_t                   icache_miss_resp_data_rdata;

  logic                                icache_miss_resp_meta_w, icache_miss_resp_meta_wok;
  logic                                icache_miss_resp_meta_r, icache_miss_resp_meta_rok;
  hpdcache_mem_id_t                    icache_miss_resp_meta_id;

  //Translate the request from HPDC format to ariane's format
  assign icache_miss_resp_valid_o = icache_miss_resp_meta_rok,
         icache_miss_resp_o.rtype = (icache_miss_resp_wdata.mem_inv.all) ?  wt_cache_pkg::ICACHE_INV_REQ : wt_cache_pkg::ICACHE_IFILL_ACK,
         icache_miss_resp_o.data = icache_miss_resp_data_rdata,
         icache_miss_resp_o.user = '0,
         icache_miss_resp_o.inv.idx = icache_miss_resp_wdata.mem_inv.idx,
         icache_miss_resp_o.inv.all = icache_miss_resp_wdata.mem_inv.all,
         icache_miss_resp_o.inv.way = '0,
         icache_miss_resp_o.inv.vld = '0,
         icache_miss_resp_o.tid = icache_miss_resp_meta_id;

  assign icache_miss_resp_meta_rok = icache_miss_resp_w,
         icache_miss_resp_wok = 1'b1,
         icache_miss_resp_meta_id = icache_miss_resp_wdata.mem_resp_id,
         icache_miss_resp_data_rdata = icache_miss_resp_wdata.mem_resp_r_data;
  //    }}}
  //  }}}

  //  L1.5 Request arbiter
  //  {{{

    // Requests
  logic                            mem_req_ready      [4:0];
  logic                            mem_req_valid      [4:0];
  hpdcache_mem_req_t mem_req            [4:0];
  

  logic                            mem_req_ready_arb;
  logic                            mem_req_valid_arb;
  hpdcache_mem_req_t mem_req_arb;

    // Data
  logic                              mem_req_data_ready  [4:0];
  logic                              mem_req_data_valid  [4:0];
  hpdcache_mem_req_w_t mem_req_data        [4:0];
  hpdcache_mem_req_w_t mem_req_data_arb;

    // Port of the Request, 5 available ports
  req_portid_t         mem_req_pid [4:0];
  req_portid_t         mem_req_pid_arb;
    
   // Request type selected
  logic                              mem_req_index_arb   [4:0];


  //Request types
  //IFILL
  assign icache_miss_req_r      = mem_req_ready[0],
         mem_req_valid[0]       = icache_miss_req_rok,
         mem_req_pid[0]         = icache_miss_pid_i,
         mem_req[0]             = icache_miss_req_rdata,
         mem_req_data_valid[0]  = 1'b1, //There is no data for this request -> always valid
         mem_req_data[0]        = '0;
         
  //Read
  assign dcache_miss_ready_o    = mem_req_ready[1],
         mem_req_valid[1]       = dcache_miss_valid_i,
         mem_req_pid[1]         = dcache_miss_pid_i,
         mem_req[1]             = dcache_miss_i,
         mem_req_data_valid[1]  = 1'b1, //There is no data for this request -> always valid
         mem_req_data[1]        = '0;
         
  //Write
  assign dcache_wbuf_ready_o    = mem_req_ready[2],
         mem_req_valid[2]       = dcache_wbuf_valid_i,
         mem_req_pid[2]         = dcache_wbuf_pid_i,
         mem_req[2]             = dcache_wbuf_i;
         

  assign dcache_wbuf_data_ready_o = mem_req_ready[2], //Ready at the same time as the request
         mem_req_data_valid[2]    = dcache_wbuf_data_valid_i,
         mem_req_data[2]          = dcache_wbuf_data_i;

  //Uncachable Read
  assign dcache_uc_read_ready_o   = mem_req_ready[3],
         mem_req_valid[3]         = dcache_uc_read_valid_i,
         mem_req_pid[3]           = dcache_uc_read_pid_i,
         mem_req[3]               = dcache_uc_read_i,
         mem_req_data_valid[3]    = 1'b1, //There is no data for this request -> always valid
         mem_req_data[3]          = '0;
         
 //Uncachable Write
  assign dcache_uc_write_ready_o  = mem_req_ready[4],
         mem_req_valid[4]         = dcache_uc_write_valid_i,
         mem_req_pid[4]           = dcache_uc_write_pid_i,
         mem_req[4]               = dcache_uc_write_i;
         

  assign dcache_uc_write_data_ready_o = mem_req_ready[4], //Ready at the same time as the request
         mem_req_data_valid[4]  = dcache_uc_write_data_valid_i,
         mem_req_data[4]        = dcache_uc_write_data_i;

  hpdcache_l15_req_arbiter #(
    .N(5),
    .hpdcache_mem_req_t                              (hpdcache_mem_req_t),
    .hpdcache_mem_req_w_t                            (hpdcache_mem_req_w_t),
    .req_portid_t                                    (req_portid_t) //NTODO: Optimize for more threads
  ) i_l15_req_arbiter (
    .clk_i,
    .rst_ni,
    //Request
    .mem_req_ready_o (mem_req_ready),
    .mem_req_valid_i (mem_req_valid),
    .mem_req_pid_i   (mem_req_pid),
    .mem_req_i       (mem_req),

    //Data
    .mem_req_data_valid_i (mem_req_data_valid),
    .mem_req_data_i       (mem_req_data),
    //Arbiter 
    .mem_req_ready_i (mem_req_ready_arb),
    .mem_req_valid_o (mem_req_valid_arb), //Valid when both request and data are valid. 

    //Req & Data selected 
    .mem_req_pid_o        (mem_req_pid_arb),
    .mem_req_o            (mem_req_arb),
    //Data output
    //Arbiter ready is the same for the request and the valid==1 if
    //the request and the optional date are also valid
    .mem_req_data_o       (mem_req_data_arb),
    .mem_req_index_o      (mem_req_index_arb)
    
  );
  //  }}}

  //  L1.5 Response demultiplexor
  //  {{{
  logic                                mem_resp_ready;
  logic                                mem_resp_valid;
  hpdcache_mem_resp_t                  mem_resp;

  logic                                mem_resp_ready_arb [4:0];
  logic                                mem_resp_valid_arb [4:0];
  hpdcache_mem_resp_t                  mem_resp_arb       [4:0];

  //Port 0 -> ICACHE, Port 1 -> Read, Port 2 -> Write, Port 3 -> UC Read, Port 4 -> UC Write
  req_portid_t           mem_resp_pid;

  hpdcache_l15_resp_demux #(
    .N                  (5),
    .resp_t             (hpdcache_mem_resp_t),
    .resp_id_t          (hpdcache_mem_id_t),
    .req_portid_t       (req_portid_t)
  ) i_l15_resp_demux (
    .clk_i,
    .rst_ni,
    //From arbiter
    .mem_resp_ready_o   (mem_resp_ready),
    .mem_resp_valid_i   (mem_resp_valid),
    .mem_resp_id_i      (mem_resp.mem_resp_id),
    .mem_resp_i         (mem_resp),
    //To HPDC
    .mem_resp_ready_i   (mem_resp_ready_arb),
    .mem_resp_valid_o   (mem_resp_valid_arb),
    .mem_resp_o         (mem_resp_arb),
    //Port selecter
    .mem_sel_i          (mem_resp_pid)
  );

  //Responses 
  //IFILL
  assign icache_miss_resp_w          = mem_resp_valid_arb[0],
         icache_miss_resp_wdata      = mem_resp_arb[0],
         mem_resp_ready_arb[0]       = icache_miss_resp_wok;
  //Read
  assign dcache_miss_resp_valid_o    = mem_resp_valid_arb[1],
         dcache_miss_resp_o.mem_resp_r_data  = mem_resp_arb[1].mem_resp_r_data[HPDcacheMemDataWidth-1:0],
         dcache_miss_resp_o.mem_resp_r_error = mem_resp_arb[1].mem_resp_error,
         dcache_miss_resp_o.mem_resp_r_id    = mem_resp_arb[1].mem_resp_id,
         dcache_miss_resp_o.mem_resp_r_last  = mem_resp_arb[1].mem_resp_r_last,
         mem_resp_ready_arb[1]       = dcache_miss_resp_ready_i;
  //Write
  assign dcache_wbuf_resp_valid_o     = mem_resp_valid_arb[2],
         dcache_wbuf_resp_o.mem_resp_w_is_atomic = mem_resp_arb[2].mem_resp_w_is_atomic,
         dcache_wbuf_resp_o.mem_resp_w_error     = mem_resp_arb[2].mem_resp_error,
         dcache_wbuf_resp_o.mem_resp_w_id        = mem_resp_arb[2].mem_resp_id,
         mem_resp_ready_arb[2]        = dcache_wbuf_resp_ready_i;

  //Uncachable Read
  assign dcache_uc_read_resp_valid_o = mem_resp_valid_arb[3],
         dcache_uc_read_resp_o.mem_resp_r_error = mem_resp_arb[3].mem_resp_error,
         dcache_uc_read_resp_o.mem_resp_r_id    = mem_resp_arb[3].mem_resp_id,
         dcache_uc_read_resp_o.mem_resp_r_data  = mem_resp_arb[3].mem_resp_r_data[HPDcacheMemDataWidth-1:0],
         dcache_uc_read_resp_o.mem_resp_r_last  = mem_resp_arb[3].mem_resp_r_last,
         mem_resp_ready_arb[3]       = dcache_uc_read_resp_ready_i;
  //Uncachable Write
  assign dcache_uc_write_resp_valid_o = mem_resp_valid_arb[4],
         dcache_uc_write_resp_o.mem_resp_w_is_atomic = mem_resp_arb[4].mem_resp_w_is_atomic,
         dcache_uc_write_resp_o.mem_resp_w_error     = mem_resp_arb[4].mem_resp_error,
         dcache_uc_write_resp_o.mem_resp_w_id        = mem_resp_arb[4].mem_resp_id,
         mem_resp_ready_arb[4]        = dcache_uc_write_resp_ready_i;

  //  }}}

  //  L15 Adapter
  //  {{{

  wt_cache_pkg::l15_req_t   l15_req;
  wt_cache_pkg::l15_rtrn_t  l15_rtrn;

  hpdcache_to_l15 #(
       .N                    (5),
       .SwapEndianess        (ArianeCfg.SwapEndianess),
       .hpdcache_mem_req_t                              (hpdcache_mem_req_t),
       .hpdcache_mem_req_w_t                            (hpdcache_mem_req_w_t),
       .hpdcache_mem_id_t                               (hpdcache_mem_id_t),
       .hpdcache_mem_addr_t                             (hpdcache_mem_addr_t),
       .hpdcache_mem_resp_t                             (hpdcache_mem_resp_t),
       .req_portid_t                                    (req_portid_t)
  ) i_hpdcache_to_l15 ( 

    .clk_i,
    .rst_ni,
    
    //HPDC to Adapter
    .req_ready_o          (mem_req_ready_arb), // L1.5 is ready to receive
    .req_valid_i          (mem_req_valid_arb), // Request and optional data are valid
    .req_pid_i            (mem_req_pid_arb),
    .req_i                (mem_req_arb),
    .req_data_i           (mem_req_data_arb),
    .req_index_i          (mem_req_index_arb), // Identify the type of request
    //Adapter to HPDC
    .resp_ready_i         (mem_resp_ready),
    .resp_valid_o         (mem_resp_valid),
    .resp_pid_o           (mem_resp_pid),
    .resp_o               (mem_resp),
    //Adapter to L1.5, sending request
    .l15_req_o            (l15_req),           // Request
    //L1.5 to Adapter
    .l15_rtrn_i           (l15_rtrn)           // Response
  );

  assign l15_req_o = l15_req;
  assign l15_rtrn = l15_rtrn_i;

  //  }}}
endmodule : cva6_hpdcache_subsystem_l15_adapter
