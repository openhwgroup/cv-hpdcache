/*
 *  Copyright 2023 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *  Copyright 2025 Univ. Grenoble Alpes, Inria, TIMA Laboratory
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : December, 2025
 *  Description   : Behavioral model of a 1RW SRAM with write byte enable and ECC
 *  History       :
 */
module hpdcache_sram_wbyteenable_ecc_1rw
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
    output logic [NDATA-1:0][DATA_SIZE-1:0]   rdata,

    input  logic                              err_inj_i,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   err_inj_msk_i,
    output logic [NDATA-1:0]                  err_cor_o,
    output logic [NDATA-1:0]                  err_unc_o
);

    localparam int unsigned SYND_WIDTH = prim_secded_pkg::get_synd_width(
        prim_secded_pkg::SecdedHsiao, DATA_SIZE);
    localparam int unsigned WORD_WIDTH = prim_secded_pkg::get_full_width(
        prim_secded_pkg::SecdedHsiao, DATA_SIZE);
    localparam int unsigned WORD_BYTES = (WORD_WIDTH + 7)/8;

    //  Width of the encoder's input data is not necessarily a multiple of 8
    logic [NDATA-1:0][WORD_WIDTH-1:0] wdata_enc_ecc;

    //  Width of the SRAM's data is a multiple of 8 bits
    logic [NDATA-1:0][WORD_BYTES*8-1:0] wdata_sram;
    logic [NDATA-1:0][WORD_BYTES*8-1:0] rdata_sram;
    logic [NDATA-1:0][WORD_BYTES-1:0] wbyte_sram;

    logic [NDATA-1:0][SYND_WIDTH-1:0] syndr_ecc;
    logic [NDATA-1:0][1:0] err;

    hpdcache_sram_wbyteenable_1rw #(
        .ADDR_SIZE (ADDR_SIZE),
        .DATA_SIZE (WORD_BYTES*8),
        .DEPTH     (DEPTH),
        .NDATA     (NDATA)
    ) i_sram(
        .clk,
        .rst_n,
        .cs,
        .we,
        .addr,
        .wdata       (wdata_sram),
        .wbyteenable (wbyte_sram),
        .rdata       (rdata_sram)
    );

    for (genvar i = 0; i < NDATA; i++) begin : gen_ecc_enc_dec
        for (genvar j = 0; j < WORD_BYTES; j++) begin : gen_ecc_wbyteenable
            if (j < DATA_SIZE/8) begin : gen_ecc_data_wbyteenable
                //  Data bits are written according to the byte-enable signal
                assign wbyte_sram[i][j] = wbyteenable[i][j];
            end else begin : gen_ecc_check_wbyteenable
                //  Check bits byte are written if the last byte of the word is modified
                //  When using ECC, all the bytes of word need to be written to correctly compute
                //  the check bits. Hence, we can arbitrarily take a byte-enable for the check bits
                assign wbyte_sram[i][j] = wbyteenable[i][(DATA_SIZE/8) - 1];
            end
        end

        `SECDED_INST_ENC(prim_secded_pkg::SecdedHsiao,
            DATA_SIZE,
            ecc_enc,
            wdata[i],
            wdata_enc_ecc[i])

        //  Complete MSbs with zeros if the data + checks bits is not a multiple of byte
        assign wdata_sram[i] = wdata_enc_ecc[i];

        `SECDED_INST_DEC(prim_secded_pkg::SecdedHsiao,
            DATA_SIZE,
            ecc_dec,
            rdata_sram[i][WORD_WIDTH-1:0],
            rdata[i],
            syndr_ecc[i],
            err[i])

        assign err_cor_o[i] = err[i][0];
        assign err_unc_o[i] = err[i][1];

        byteenable_all_set_assert: assert property (@(posedge clk) disable iff (rst_n !== 1'b1)
            ((cs & we) == 1'b1) && ((&wbyteenable[i] == 1'b1) || (|wbyteenable[i] == 0))) else
            $warning("partial write (sparse byteenable) not supported when implementing ECC");
    end

    if (!prim_secded_pkg::is_width_valid(prim_secded_pkg::SecdedHsiao, DATA_SIZE))
    begin : gen_ecc_valid_width_assertion
        $fatal(1, $sformatf("Unsupported DATA_SIZE = %0d", DATA_SIZE));
    end

    if ((DATA_SIZE % 8) != 0) begin : gen_data_width_assertion
        $fatal(1, $sformatf("DATA_SIZE = %0d must be a multiple of 8", DATA_SIZE));
    end

endmodule
// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en
