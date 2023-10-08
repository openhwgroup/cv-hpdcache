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
 *  Creation Date : April, 2021
 *  Description   : Interface adapter for the CMO interface of the CVA6 core
 *  History       :
 */
module cva6_hpdcache_cmo_if_adapter
import hpdcache_pkg::*;

//  Parameters
//  {{{
#(
    parameter type cmo_req_t = logic,
    parameter type cmo_rsp_t = logic
)
//  }}}

//  Ports
//  {{{
(
  //  Clock and active-low reset pins
  input  logic                            clk_i,
  input  logic                            rst_ni,

  //  Port ID
  input  hpdcache_pkg::hpdcache_req_sid_t dcache_req_sid_i,

  //  Request/response ports from/to the CVA6 core
  input  cmo_req_t                        cva6_cmo_req_i,
  output cmo_rsp_t                        cva6_cmo_resp_o,

  //  Request port to the L1 Dcache
  output logic                            dcache_req_valid_o,
  input  logic                            dcache_req_ready_i,
  output hpdcache_pkg::hpdcache_req_t     dcache_req_o,

  //  Response port from the L1 Dcache
  input  logic                            dcache_rsp_valid_i,
  input  hpdcache_pkg::hpdcache_rsp_t     dcache_rsp_i
);
//  }}}

  //  Internal nets and registers
  //  {{{
  enum {
    FORWARD_IDLE,
    FORWARD_CMO,
    FORWARD_CMO_ACK
  } forward_state_q, forward_state_d;

  logic forward_cmo;
  hpdcache_pkg::hpdcache_req_t dcache_req_cmo;
  logic [ariane_pkg::TRANS_ID_BITS-1:0] cmo_tid_q, cmo_tid_d;
  logic cmo_ack;
  logic stall;
  //  }}}

  //  Request forwarding
  //  {{{
  always_comb
  begin : req_forward_comb
    forward_state_d = forward_state_q;
    forward_cmo     = 1'b0;
    cmo_tid_d       = cmo_tid_q;
    cmo_ack         = 1'b0;
    stall           = 1'b0;

    case (forward_state_q)
      FORWARD_IDLE: begin
        if (cva6_cmo_req_i.req) begin
          stall       = ~dcache_req_ready_i;
          forward_cmo = 1'b1;
          cmo_tid_d   = cva6_cmo_req_i.trans_id;
          if (!dcache_req_ready_i) begin
            forward_state_d = FORWARD_CMO;
          end else begin
            forward_state_d = FORWARD_CMO_ACK;
          end
        end
      end

      FORWARD_CMO: begin
        stall       = ~dcache_req_ready_i;
        forward_cmo = 1'b1;
        if (dcache_req_ready_i) begin
          forward_state_d = FORWARD_CMO_ACK;
        end
      end

      FORWARD_CMO_ACK: begin
        stall   = 1'b1;
        cmo_ack = 1'b1;
        if (cva6_cmo_req_i.req) begin
          stall       = ~dcache_req_ready_i;
          forward_cmo = 1'b1;
          cmo_tid_d   = cva6_cmo_req_i.trans_id;
          if (!dcache_req_ready_i) begin
            forward_state_d = FORWARD_CMO;
          end else begin
            forward_state_d = FORWARD_CMO_ACK;
          end
        end else begin
          forward_state_d = FORWARD_IDLE;
        end
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : forward_ff
    if (!rst_ni) begin
      forward_state_q <= FORWARD_IDLE;
      cmo_tid_q <= '0;
    end else begin
      forward_state_q <= forward_state_d;
      cmo_tid_q <= cmo_tid_d;
    end
  end

  //  CMO request
  //  {{{
  always_comb
  begin : cmo_req
    dcache_req_cmo.addr        = hpdcache_req_addr_t'(cva6_cmo_req_i.address);
    dcache_req_cmo.need_rsp    = 1'b0;
    dcache_req_cmo.uncacheable = 1'b0;
    dcache_req_cmo.sid         = dcache_req_sid_i;
    dcache_req_cmo.tid         = cva6_cmo_req_i.trans_id;
    dcache_req_cmo.wdata       = '0;
    dcache_req_cmo.be          = '0;
    dcache_req_cmo.op          = HPDCACHE_REQ_CMO;
    dcache_req_cmo.size        = '0;
    case (cva6_cmo_req_i.cmo_op)
      ariane_pkg::CMO_CLEAN,
      ariane_pkg::CMO_FLUSH,
      ariane_pkg::CMO_ZERO: begin
        // FIXME
      end
      ariane_pkg::CMO_INVAL: begin
        dcache_req_cmo.size = HPDCACHE_REQ_CMO_INVAL_NLINE;
      end
      ariane_pkg::CMO_PREFETCH_R,
      ariane_pkg::CMO_PREFETCH_W: begin
        dcache_req_cmo.size = HPDCACHE_REQ_CMO_PREFETCH;
      end
      ariane_pkg::CMO_CLEAN_ALL,
      ariane_pkg::CMO_FLUSH_ALL: begin
      end
      ariane_pkg::CMO_INVAL_ALL: begin
        dcache_req_cmo.size = HPDCACHE_REQ_CMO_INVAL_ALL;
      end
    endcase
  end
  //  }}}

  assign dcache_req_valid_o        = forward_cmo,
         dcache_req_o              = dcache_req_cmo,
         cva6_cmo_resp_o.req_ready = ~stall;
  //  }}}

  //  Response forwarding
  //  {{{
  assign cva6_cmo_resp_o.ack       = cmo_ack,
         cva6_cmo_resp_o.trans_id  = cmo_tid_q;
  //  }}}

endmodule
