// Copyright (c) 2025 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.1 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.1. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

//
// Authors       : Riccardo Tedeschi
// Creation Date : April, 2025
// Description   : Priority Binary Encoder
// History       :
//

module hpdcache_prio_bin_encoder
    //  Parameters
#(
    parameter  int unsigned N = 0,
    localparam int unsigned N_LOG2 = N > 1 ? $clog2(N) : 1
)
    //  Ports
(
    input  logic [N-1:0]      val_i,
    output logic [N_LOG2-1:0] val_o
);

    always_comb begin
        val_o = '0;
        for (int i = N-1; i >= 0; i--)
            if (val_i[i]) val_o = N_LOG2'(i);
    end
endmodule
