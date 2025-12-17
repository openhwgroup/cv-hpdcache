/*
 *  Copyright 2023 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *  Copyright 2025 Univ. Grenoble Alpes, Inria, TIMA Laboratory
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : March, 2020
 *  Description   : Wrapper for 1RW SRAM macros implementing a write byte enable
 *  History       :
 */
module hpdcache_sram_wbyteenable
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1,
    parameter bit          ECC_EN = 1'b0
)
(
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              cs,
    input  logic                              we,
    input  logic [ADDR_SIZE-1:0]              addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   wdata,
    input  logic [NDATA-1:0][DATA_SIZE/8-1:0] wbyteenable,
    output logic [NDATA-1:0][DATA_SIZE-1:0]   rdata,

    input  logic                              err_inj_i,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   err_inj_msk_i,
    output logic [NDATA-1:0]                  err_cor_o,
    output logic [NDATA-1:0]                  err_unc_o
);

    if (ECC_EN) begin : gen_sram_ecc
        hpdcache_sram_wbyteenable_ecc_1rw #(
            .ADDR_SIZE(ADDR_SIZE),
            .DATA_SIZE(DATA_SIZE),
            .DEPTH(DEPTH),
            .NDATA(NDATA)
        ) ram_i(
            .clk,
            .rst_n,
            .cs,
            .we,
            .addr,
            .wdata,
            .wbyteenable,
            .rdata,

            .err_inj_i,
            .err_inj_msk_i,
            .err_cor_o,
            .err_unc_o
        );
    end else begin : gen_sram
        logic _unused_err_inj;

        hpdcache_sram_wbyteenable_1rw #(
            .ADDR_SIZE(ADDR_SIZE),
            .DATA_SIZE(DATA_SIZE),
            .DEPTH(DEPTH),
            .NDATA(NDATA)
        ) ram_i(
            .clk,
            .rst_n,
            .cs,
            .we,
            .addr,
            .wdata,
            .wbyteenable,
            .rdata
        );

        assign _unused_err_inj = 1'b0 && (err_inj_i & |err_inj_msk_i);
        assign err_cor_o = {NDATA{1'b0}};
        assign err_unc_o = {NDATA{1'b0}};
    end
endmodule
// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en
