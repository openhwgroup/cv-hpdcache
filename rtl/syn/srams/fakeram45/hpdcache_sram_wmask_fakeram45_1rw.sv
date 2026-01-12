/*
 *  Copyright 2025 Inria
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Authors         Cesar Fuguet
 *  Creation Date   June, 2025
 *  Description     Fakeram45 1RW SRAM with write mask
 */
module hpdcache_sram_wmask_1rw
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
    output logic [NDATA-1:0][DATA_SIZE-1:0] rdata
);

if ((DEPTH > 64) || ((NDATA*DATA_SIZE) > 64)) begin : gen_sram_unsupported
    $fatal(1, "error: unsupported SRAM geometry");

end else if ((NDATA*DATA_SIZE) <= 64) begin : gen_sram_64bw
    logic [63:0] sram_wdata;
    logic [63:0] sram_rdata;
    logic [63:0] sram_wmask;
    logic [5:0]  sram_addr;

    fakeram45_64x64 i_sram(
        .clk       (clk),
        .ce_in     (cs),
        .we_in     (we),
        .addr_in   (sram_addr),
        .w_mask_in (sram_wmask),
        .wd_in     (sram_wdata),
        .rd_out    (sram_rdata)
    );

    if (ADDR_SIZE < 6) begin : gen_narrow_addr
        assign sram_addr = {{6-ADDR_SIZE{1'b0}}, addr};
    end else begin : gen_wide_addr
        assign sram_addr = addr[5:0];
    end
    assign sram_wmask = {{64-NDATA*DATA_SIZE{1'b0}}, wmask};
    assign sram_wdata = {{64-NDATA*DATA_SIZE{1'b0}}, wdata};
    assign rdata = sram_rdata[NDATA*DATA_SIZE-1:0];
end

endmodule
