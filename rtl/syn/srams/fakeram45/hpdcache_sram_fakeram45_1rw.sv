/*
 *  Copyright 2025 Inria
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Authors         Cesar Fuguet
 *  Creation Date   June, 2025
 *  Description     Fakeram45 1RW SRAM
 */
module hpdcache_sram_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE
)
(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  cs,
    input  logic                  we,
    input  logic [ADDR_SIZE-1:0]  addr,
    input  logic [DATA_SIZE-1:0]  wdata,
    output logic [DATA_SIZE-1:0]  rdata
);

hpdcache_sram_wmask_1rw #(
    .ADDR_SIZE(ADDR_SIZE),
    .DATA_SIZE(DATA_SIZE)
) i_sram(
    .clk,
    .rst_n,
    .cs,
    .we,
    .addr,
    .wdata,
    .wmask('1),
    .rdata
);

endmodule
