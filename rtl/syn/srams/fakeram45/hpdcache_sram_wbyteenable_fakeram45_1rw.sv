/*
 *  Copyright 2025 Inria
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Authors         Cesar Fuguet
 *  Creation Date   June, 2025
 *  Description     Fakeram45 1RW SRAM with write byte enable
 */
module hpdcache_sram_wbyteenable_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1
)
(
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              cs,
    input  logic                              we,
    input  logic [ADDR_SIZE-1:0]              addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   wdata,
    input  logic [NDATA-1:0][DATA_SIZE/8-1:0] wbyteenable,
    output logic [NDATA-1:0][DATA_SIZE-1:0]   rdata
);

logic [NDATA-1:0][DATA_SIZE-1:0] sram_wmask;

hpdcache_sram_wmask_1rw #(
    .ADDR_SIZE(ADDR_SIZE),
    .DATA_SIZE(DATA_SIZE),
    .NDATA(NDATA)
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

for (genvar j = 0; j < NDATA; j++) begin : gen_wmask_j
    for (genvar i = 0; i < DATA_SIZE/8; i++) begin : gen_wmask_i
        assign sram_wmask[j][i*8 +: 8] = wbyteenable[j][i] == 1'b1 ? 8'hff : 8'h00;
    end
end

endmodule
