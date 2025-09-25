/*
 *  Copyright 2025 Inria
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Authors         Cesar Fuguet
 *  Creation Date   June, 2025
 *  Description     Fakeram45 1RW SRAM
 */
(* blackbox *) module fakeram45_64x64
(
    input  logic             clk,
    input  logic             ce_in,
    input  logic             we_in,
    input  logic [5:0]       addr_in,
    input  logic [63:0]      wd_in,
    input  logic [63:0]      w_mask_in,
    output logic [63:0]      rd_out
);

endmodule
