// Copyright (c) 2025 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.1 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.1. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

//
// Authors       : Riccardo Tedeschi
// Creation Date : July, 2025
// Description   : ACE snoop adapter
// History       :
//

module hpdcache_snoop_to_ace_snoop
import hpdcache_pkg::*;
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type hpdcache_snoop_req_t = logic,
    parameter type hpdcache_snoop_resp_data_t = logic,
    parameter type ac_chan_t = logic,
    parameter type cr_chan_t = logic,
    parameter type cd_chan_t = logic
)
(
    output logic                          snoop_req_valid_o,
    input  logic                          snoop_req_ready_i,
    output hpdcache_snoop_req_t           snoop_req_o,

    input  logic                          snoop_rsp_meta_valid_i,
    output logic                          snoop_rsp_meta_ready_o,
    input  hpdcache_snoop_meta_t          snoop_rsp_meta_i,

    output logic                          snoop_rsp_data_ready_o,
    input  logic                          snoop_rsp_data_valid_i,
    input  hpdcache_snoop_resp_data_t     snoop_rsp_data_i,

    input  logic                          ace_ac_valid_i,
    output logic                          ace_ac_ready_o,
    input  ac_chan_t                      ace_ac_i,

    output logic                          ace_cr_valid_o,
    input  logic                          ace_cr_ready_i,
    output cr_chan_t                      ace_cr_o,

    output logic                          ace_cd_valid_o,
    input  logic                          ace_cd_ready_i,
    output cd_chan_t                      ace_cd_o
);

    hpdcache_req_op_t op;

    always_comb begin : op_comb
        case (ace_ac_i.snoop)
            ace_pkg::CleanInvalid:       op = HPDCACHE_REQ_SNOOP_CLEAN_INVALID;
            ace_pkg::CleanShared:        op = HPDCACHE_REQ_SNOOP_CLEAN_SHARED;
            ace_pkg::MakeInvalid:        op = HPDCACHE_REQ_SNOOP_MAKE_INVALID;
            ace_pkg::ReadClean:          op = HPDCACHE_REQ_SNOOP_READ_CLEAN;
            ace_pkg::ReadNotSharedDirty: op = HPDCACHE_REQ_SNOOP_READ_NOT_SHARED_DIRTY;
            ace_pkg::ReadOnce:           op = HPDCACHE_REQ_SNOOP_READ_ONCE;
            ace_pkg::ReadShared:         op = HPDCACHE_REQ_SNOOP_READ_SHARED;
            ace_pkg::ReadUnique:         op = HPDCACHE_REQ_SNOOP_READ_UNIQUE;
            default:                     op = HPDCACHE_REQ_SNOOP_READ_SHARED;
        endcase
    end

    assign snoop_req_valid_o = ace_ac_valid_i;
    assign ace_ac_ready_o    = snoop_req_ready_i;
    assign snoop_req_o.nline = ace_ac_i.addr >> HPDcacheCfg.clOffsetWidth;
    assign snoop_req_o.op    = op;
    //  ACPROT is unused

    assign ace_cr_valid_o            = snoop_rsp_meta_valid_i;
    assign snoop_rsp_meta_ready_o    = ace_cr_ready_i;
    assign ace_cr_o.resp.WasUnique   = snoop_rsp_meta_i.was_unique;
    assign ace_cr_o.resp.IsShared    = snoop_rsp_meta_i.is_shared;
    assign ace_cr_o.resp.PassDirty   = snoop_rsp_meta_i.pass_dirty;
    assign ace_cr_o.resp.Error       = snoop_rsp_meta_i.error;
    assign ace_cr_o.resp.DataTransfer= snoop_rsp_meta_i.data_transfer;

    assign ace_cd_valid_o         = snoop_rsp_data_valid_i;
    assign snoop_rsp_data_ready_o = ace_cd_ready_i;
    assign ace_cd_o.data          = snoop_rsp_data_i.data;
    assign ace_cd_o.last          = snoop_rsp_data_i.last;

endmodule
