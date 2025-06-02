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
    parameter int unsigned DEPTH = 2**ADDR_SIZE
)
(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   cs,
    input  logic                   we,
    input  logic [ADDR_SIZE-1:0]   addr,
    input  logic [DATA_SIZE-1:0]   wdata,
    input  logic [DATA_SIZE/8-1:0] wbyteenable,
    output logic [DATA_SIZE-1:0]   rdata
);

logic [DATA_SIZE-1:0] sram_wmask;

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

for (i = 0; i < DATA_SIZE/8; i++) begin : gen_wmask
    assign sram_wmask[(i+1)*8:i*8] = wbyteenable[i] == 1'b1 ? 8'hff : 8'h00;
end

endmodule
