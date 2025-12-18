/*
 *  Copyright 2023 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *  Copyright 2025 Univ. Grenoble Alpes, Inria, TIMA Laboratory
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : December, 2025
 *  Description   : Behavioral model of a 1RW SRAM with write bit mask and ECC
 *  History       :
 */
`include "prim_secded_inc.svh"

module hpdcache_sram_wmask_ecc_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1
)
(
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            cs,
    input  logic                            we,
    input  logic [ADDR_SIZE-1:0]            addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] wdata,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] wmask,
    output logic [NDATA-1:0][DATA_SIZE-1:0] rdata,

    input  logic                            err_inj_i,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] err_inj_msk_i,
    output logic [NDATA-1:0]                err_cor_o,
    output logic [NDATA-1:0]                err_unc_o
);

    localparam int unsigned SYND_WIDTH = prim_secded_pkg::get_synd_width(
        prim_secded_pkg::SecdedHsiao, DATA_SIZE);
    localparam int unsigned WORD_WIDTH = prim_secded_pkg::get_full_width(
        prim_secded_pkg::SecdedHsiao, DATA_SIZE);

    logic [NDATA-1:0][WORD_WIDTH-1:0] wdata_ecc, rdata_ecc, wmask_ecc;
    logic [NDATA-1:0][SYND_WIDTH-1:0] syndr_ecc;
    logic [NDATA-1:0][1:0] err;

    hpdcache_sram_wmask_1rw #(
        .ADDR_SIZE (ADDR_SIZE),
        .DATA_SIZE (WORD_WIDTH),
        .DEPTH     (DEPTH),
        .NDATA     (NDATA)
    ) i_sram(
        .clk,
        .rst_n,
        .cs,
        .we,
        .addr,
        .wdata (wdata_ecc),
        .wmask (wmask_ecc),
        .rdata (rdata_ecc)
    );

    for (genvar i = 0; i < NDATA; i++) begin : gen_ecc_enc_dec
        for (genvar j = 0; j < WORD_WIDTH; j++) begin : gen_ecc_wmask
            if (j < DATA_SIZE) begin : gen_ecc_data_wmask
                //  Data bits are written according to the write mask
                assign wmask_ecc[i][j] = wmask[i][j];
            end else begin : gen_ecc_check_wmask
                //  Check bits byte are written if the last bit of the word is modified.
                //  When using ECC, all the bits of word need to be written to correctly compute the
                //  check bits. Hence, we can arbitrarily take a mask bit for the check bits
                assign wmask_ecc[i][j] = wmask[i][DATA_SIZE-1];
            end
        end

        `SECDED_INST_ENC(prim_secded_pkg::SecdedHsiao,
            DATA_SIZE,
            ecc_enc,
            wdata[i],
            wdata_ecc[i])

        `SECDED_INST_DEC(prim_secded_pkg::SecdedHsiao,
            DATA_SIZE,
            ecc_dec,
            rdata_ecc[i],
            rdata[i],
            syndr_ecc[i],
            err[i])

        assign err_cor_o[i] = err[i][0];
        assign err_unc_o[i] = err[i][1];
    end

    //  Assertions
    //  {{{
`ifndef HPDCACHE_ASSERT_OFF
    if (!prim_secded_pkg::is_width_valid(prim_secded_pkg::SecdedHsiao, DATA_SIZE))
    begin : gen_ecc_valid_width_assertion
        $fatal(1, $sformatf("Unsupported DATA_SIZE = %0d", DATA_SIZE));
    end
`endif
    //  }}}

endmodule
// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en
