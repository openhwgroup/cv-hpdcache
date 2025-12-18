/*
 *  Copyright 2023 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *  Copyright 2023 Univ. Grenoble Alpes, Inria, TIMA Laboratory
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : December, 2025
 *  Description   : Blackbox model of a 1RW SRAM with write byte enable and ECC
 *  History       :
 */
(* black_box *) module hpdcache_sram_wbyteenable_ecc_1rw
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
    input  logic [NDATA-1][DATA_SIZE-1:0]   wdata,
    input  logic [NDATA-1][DATA_SIZE/8-1:0] wbyteenable,
    output logic [NDATA-1][DATA_SIZE-1:0]   rdata

    input  logic                            err_inj_i,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] err_inj_msk_i,
    output logic [NDATA-1:0]                err_cor_o,
    output logic [NDATA-1:0]                err_unc_o
);

endmodule
// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en
