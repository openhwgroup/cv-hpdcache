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
// Creation Date : May, 2025
// Description   : Population counter
// History       :
//

module hpdcache_popcount #(
    parameter  int unsigned N = 0,
    localparam int unsigned OUT_WIDTH = (N > 1) ? $clog2(N) + 1 : 1
) (
    input  logic [N-1:0] val_i,
    output logic [OUT_WIDTH-1:0] val_o
);

always_comb begin
    val_o = '0;
    for (int unsigned i = 0; i < N; i++) begin
        val_o += OUT_WIDTH'(val_i[i]);
    end
end

endmodule
