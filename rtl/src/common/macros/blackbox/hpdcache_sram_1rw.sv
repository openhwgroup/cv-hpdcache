/*
 *  Copyright 2023 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *  Copyright 2025 Univ. Grenoble Alpes, Inria, TIMA Laboratory
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : March, 2020
 *  Description   : SRAM blackbox model
 *  History       :
 */
(* black_box *) module hpdcache_sram_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1
)
(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          cs,
    input  logic                          we,
    input  logic [ADDR_SIZE-1:0]          addr,
    input  logic [NDATA-1][DATA_SIZE-1:0] wdata,
    output logic [NDATA-1][DATA_SIZE-1:0] rdata
);

endmodule
// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en
