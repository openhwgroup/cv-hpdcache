/*
 *  Copyright 2023 CEA*
 *  *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 *  Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 *  may not use this file except in compliance with the License, or, at your
 *  option, the Apache License version 2.0. You may obtain a copy of the
 *  License at
 *
 *  https://solderpad.org/licenses/SHL-2.1/
 *
 *  Unless required by applicable law or agreed to in writing, any work
 *  distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 *  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 *  License for the specific language governing permissions and limitations
 *  under the License.
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : One-hot to binary decoder
 *  History       :
 */
module hpdcache_1hot_to_binary
    //  Parameters
#(
    parameter  int unsigned N = 0,
    localparam int unsigned Log2N = N > 1 ? $clog2(N) : 1
)
    //  Ports
(
    input  logic [N-1:0] val_i,
    output logic [Log2N-1:0] val_o
);

    always_comb
    begin : decode_comb
        val_o = 0;
        for (int i = 0; i < N; i++) begin
            if (val_i[i]) val_o = i;
        end

`ifndef HPDCACHE_ASSERT_OFF
        assert final ($onehot0(val_i)) else $error("val_i shall be onehot or zero");
`endif
    end
endmodule
