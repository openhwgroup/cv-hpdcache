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
 *  Description   : Interface adapter for the CVA6 core
 *  History       :
 */
module cva6_hpdcache_if_adapter
import hpdcache_pkg::*;

//  Parameters
//  {{{
#(
    parameter ariane_pkg::ariane_cfg_t ArianeCfg = ariane_pkg::ArianeDefaultConfig
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
  input  ariane_pkg::dcache_req_i_t       cva6_req_i,
  output ariane_pkg::dcache_req_o_t       cva6_req_o,
  input  ariane_pkg::amo_req_t            cva6_amo_req_i,
  output ariane_pkg::amo_resp_t           cva6_amo_resp_o,

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
  struct packed {
      logic                                      req_valid;
      logic [ariane_pkg::DCACHE_INDEX_WIDTH-1:0] address_index;
      logic [(riscv::XLEN/8)-1:0]                data_be;
      logic [1:0]                                data_size;
      logic [ariane_pkg::DCACHE_TID_WIDTH-1:0]   data_id;

      logic                                      tag_valid;
      logic [HPDCACHE_TAG_WIDTH-1:0]             address_tag;
  } load_buf_q;

  enum {
    FORWARD_IDLE,
    FORWARD_STORE,
    FORWARD_AMO,
    FORWARD_AMO_WAIT
  } forward_state_q, forward_state_d;

  hpdcache_pkg::hpdcache_req_t dcache_req_load, dcache_req_store, dcache_req_amo;
  logic [HPDCACHE_TAG_WIDTH-1:0] dcache_req_tag;
  logic load_buf_set, load_buf_reset;
  logic load_tag_set, load_tag_reset;
  logic forward_load, forward_store, forward_amo;
  logic dcache_req_is_cacheable;
  logic stall;
  //  }}}

  //  Core request grant control
  //  {{{
  //  }}}

  //  Buffer for load requests
  //  {{{
  assign load_buf_set   = cva6_req_o.data_gnt & cva6_req_i.data_req & ~cva6_req_i.data_we,
         load_buf_reset = (~load_buf_q.tag_valid & cva6_req_i.kill_req) | (forward_load & dcache_req_ready_i);

  assign load_tag_set   = ~load_buf_q.tag_valid
                        & (load_buf_q.req_valid & (cva6_req_i.tag_valid & ~cva6_req_i.kill_req))
                        & ~dcache_req_ready_i,
         load_tag_reset = dcache_req_ready_i;

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : load_buf_ff
    if (!rst_ni) begin
      load_buf_q <= '0;
    end else begin
      load_buf_q.req_valid <= load_buf_set | (load_buf_q.req_valid & ~load_buf_reset);
      if (load_buf_set) begin
        load_buf_q.address_index <= cva6_req_i.address_index;
        load_buf_q.data_be       <= cva6_req_i.data_be;
        load_buf_q.data_size     <= cva6_req_i.data_size;
        load_buf_q.data_id       <= cva6_req_i.data_id;
      end

      load_buf_q.tag_valid <= load_tag_set | (load_buf_q.tag_valid & ~load_tag_reset);
      if (load_tag_set) begin
        load_buf_q.address_tag <= cva6_req_i.address_tag;
      end
    end
  end
  //  }}}

  //  Request forwarding
  //  {{{
  always_comb
  begin : req_forward_comb
    forward_state_d = forward_state_q;
    forward_load    = 1'b0;
    forward_store   = 1'b0;
    forward_amo     = 1'b0;
    stall           = 1'b0;

    case (forward_state_q)
      FORWARD_IDLE: begin
        stall = ~dcache_req_ready_i & load_buf_q.req_valid;
        if ((cva6_req_i.data_req && !cva6_req_i.data_we) || load_buf_q.req_valid) begin
          //  Forward the load when the tag is valid
          forward_load = load_buf_q.req_valid &
                         ((cva6_req_i.tag_valid & ~cva6_req_i.kill_req) | load_buf_q.tag_valid);
        end

        else if (cva6_req_i.data_req && cva6_req_i.data_we) begin
          stall         = ~dcache_req_ready_i;
          forward_store = 1'b1;
          if (!dcache_req_ready_i) begin
            forward_state_d = FORWARD_STORE;
          end
        end

        else if (cva6_amo_req_i.req) begin
          stall           = 1'b1;
          forward_amo     = 1'b1;
          if (!dcache_req_ready_i) begin
            forward_state_d = FORWARD_AMO;
          end else begin
            forward_state_d = FORWARD_AMO_WAIT;
          end
        end
      end

      FORWARD_STORE: begin
        stall         = ~dcache_req_ready_i;
        forward_store = 1'b1;
        if (dcache_req_ready_i) begin
          forward_state_d = FORWARD_IDLE;
        end
      end

      FORWARD_AMO: begin
        stall       = 1'b1;
        forward_amo = 1'b1;
        if (dcache_req_ready_i) begin
          forward_state_d = FORWARD_AMO_WAIT;
        end
      end

      FORWARD_AMO_WAIT: begin
        stall = 1'b1;
        if (cva6_amo_resp_o.ack) begin
          forward_state_d = FORWARD_IDLE;
        end
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni)
  begin : forward_ff
    if (!rst_ni) begin
      forward_state_q <= FORWARD_IDLE;
    end else begin
      forward_state_q <= forward_state_d;
    end
  end

  //  Check if the forwarded address is cacheable
  assign dcache_req_is_cacheable =
    ariane_pkg::is_inside_cacheable_regions(ArianeCfg, { {{64-riscv::PLEN}{1'b0}}, dcache_req_o.addr });

  //  LOAD request
  //  {{{
  assign dcache_req_tag              = load_buf_q.tag_valid ? load_buf_q.address_tag : cva6_req_i.address_tag,
         dcache_req_load.addr        = hpdcache_req_addr_t'({dcache_req_tag, load_buf_q.address_index}),
         dcache_req_load.wdata       = '0,
         dcache_req_load.op          = hpdcache_pkg::HPDCACHE_REQ_LOAD,
         dcache_req_load.be          = load_buf_q.data_be,
         dcache_req_load.size        = load_buf_q.data_size,
         dcache_req_load.uncacheable = ~dcache_req_is_cacheable,
         dcache_req_load.sid         = dcache_req_sid_i,
         dcache_req_load.tid         = load_buf_q.data_id,
         dcache_req_load.need_rsp    = 1'b1;
  //  }}}

  //  STORE request
  //  {{{
  assign dcache_req_store.addr        = hpdcache_req_addr_t'({cva6_req_i.address_tag, cva6_req_i.address_index}),
         dcache_req_store.wdata       = cva6_req_i.data_wdata,
         dcache_req_store.op          = hpdcache_pkg::HPDCACHE_REQ_STORE,
         dcache_req_store.be          = cva6_req_i.data_be,
         dcache_req_store.size        = cva6_req_i.data_size,
         dcache_req_store.uncacheable = ~dcache_req_is_cacheable,
         dcache_req_store.sid         = dcache_req_sid_i,
         //  CVA6 ignores responses for writes, hence do not ask for them to the dcache and send dummy TID
         dcache_req_store.tid         = 0,
         dcache_req_store.need_rsp    = 1'b0;
  //  }}}

  //  AMO request
  //  {{{
  logic amo_is_word, amo_is_word_hi;

  assign amo_is_word    = (cva6_amo_req_i.size == 2'b10),
         amo_is_word_hi = cva6_amo_req_i.operand_a[2];

  assign dcache_req_amo.addr        = hpdcache_req_addr_t'(cva6_amo_req_i.operand_a),
         dcache_req_amo.size        = cva6_amo_req_i.size,
         dcache_req_amo.uncacheable = ~dcache_req_is_cacheable,
         dcache_req_amo.sid         = dcache_req_sid_i,
         dcache_req_amo.tid         = '1, //  All-one TID allows to distinguish AMO responses
         dcache_req_amo.need_rsp    = 1'b1;

  assign dcache_req_amo.wdata = amo_is_word ? {2{cva6_amo_req_i.operand_b[0 +: 32]}} : cva6_amo_req_i.operand_b;

  assign dcache_req_amo.be = amo_is_word_hi ? 8'hf0 :
                             amo_is_word    ? 8'h0f : 8'hff;

  assign dcache_req_amo.op = (cva6_amo_req_i.amo_op == ariane_pkg::AMO_LR  ) ? HPDCACHE_REQ_AMO_LR   :
                             (cva6_amo_req_i.amo_op == ariane_pkg::AMO_SC  ) ? HPDCACHE_REQ_AMO_SC   :
                             (cva6_amo_req_i.amo_op == ariane_pkg::AMO_SWAP) ? HPDCACHE_REQ_AMO_SWAP :
                             (cva6_amo_req_i.amo_op == ariane_pkg::AMO_ADD ) ? HPDCACHE_REQ_AMO_ADD  :
                             (cva6_amo_req_i.amo_op == ariane_pkg::AMO_AND ) ? HPDCACHE_REQ_AMO_AND  :
                             (cva6_amo_req_i.amo_op == ariane_pkg::AMO_OR  ) ? HPDCACHE_REQ_AMO_OR   :
                             (cva6_amo_req_i.amo_op == ariane_pkg::AMO_XOR ) ? HPDCACHE_REQ_AMO_XOR  :
                             (cva6_amo_req_i.amo_op == ariane_pkg::AMO_MAX ) ? HPDCACHE_REQ_AMO_MAX  :
                             (cva6_amo_req_i.amo_op == ariane_pkg::AMO_MAXU) ? HPDCACHE_REQ_AMO_MAXU :
                             (cva6_amo_req_i.amo_op == ariane_pkg::AMO_MIN ) ? HPDCACHE_REQ_AMO_MIN  :
                                                                               HPDCACHE_REQ_AMO_MINU;
  //  }}}

  assign dcache_req_valid_o = forward_load | forward_store | forward_amo,
         dcache_req_o       = forward_load  ? dcache_req_load  :
                              forward_store ? dcache_req_store : dcache_req_amo;
  //  }}}

  //  Response forwarding
  //  {{{
  //      FIXME: CVA6 does not support forwarding of errors from the memory (error = 0)
  logic [31:0] amo_resp_word;

  assign cva6_req_o.data_rvalid = dcache_rsp_valid_i && (dcache_rsp_i.tid != '1),
         cva6_req_o.data_rdata  = dcache_rsp_i.rdata,
         cva6_req_o.data_rid    = dcache_rsp_i.tid,
         cva6_req_o.data_gnt    = ~stall;

  assign amo_resp_word          = amo_is_word_hi ? dcache_rsp_i.rdata[0][32 +: 32]
                                                 : dcache_rsp_i.rdata[0][0  +: 32];

  assign cva6_amo_resp_o.ack    = dcache_rsp_valid_i && (dcache_rsp_i.tid == '1),
         cva6_amo_resp_o.result = amo_is_word ? {{32{amo_resp_word[31]}}, amo_resp_word}
                                              : dcache_rsp_i.rdata[0][63:0];
  //  }}}

  //  Assertions
  //  {{{
  //    pragma translate_off
  forward_one_request_assert: assert property (@(posedge clk_i)
    ($onehot0({forward_store, forward_load, forward_amo}))) else
    $error("Only one request shall be forwarded");
  //    pragma translate_on
  //  }}}

endmodule
