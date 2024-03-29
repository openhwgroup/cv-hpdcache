# OpenHW Core-V High-Performance L1 Dcache (CV-HPDcache)

The HPDcache is an open-source High-Performance, Multi-requester, Out-of-Order L1 Dcache for RISC-V cores and accelerators.


## Directory Structure

<table>
  <tr>
    <th style="text-align:left;width:20%">Directory</th>
    <th style="text-align:left">Description</th>
  </tr>
  <tr>
    <td><i>rtl</i></td>
    <td>Contains the file lists to be used for the compiling of the HPDcache</td>
  </tr>
  <tr>
    <td><i>rtl/src<i></td>
    <td>Contains the SystemVerilog RTL sources of the HPDcache</td>
  </tr>
  <tr>
    <td><i>rtl/src/target</i></td>
    <td>Contains processor-dependent sources (e.g. adapter modules for the CVA6 core)</td>
  </tr>
  <tr>
    <td><i>docs</i></td>
    <td>Contains documentation of the HPDcache</td>
  </tr>
</table>


## Documentation

The HPDcache specification document can be found in the *docs/hpdcache_spec_document* folder.
It is written in LaTeX.
You cand find pre-compiled PDF documents in *docs/hpdcache_spec_document/release*.

If you need to recompile the specification document, a dedicated *Makefile* is in the specification folder.
This *Makefile* needs the *latexmk* command-line tool (included in most common LaTeX distributions) and the *inkscape* tool to convert SVG images into PDF.


## Licensing

The HPDcache is released under the Solderpad Hardware License (version 2.1).
Please refer to the [LICENSE](LICENSE) file for further information.


## HPDcache Publications & Tutorials

- Technical Paper: César Fuguet. 2023. HPDcache: Open-Source High-Performance L1 Data Cache for RISC-V Cores. In Proceedings of the 20th ACM International Conference on Computing Frontiers (CF '23). Association for Computing Machinery, New York, NY, USA, 377–378. <https://doi.org/10.1145/3587135.3591413>

- Video: César Fuguet. 2023. High Performance L1 Dcache for RISC-V Cores. TRISTAN Workshop. RISC-V Summit Europe 2023. <https://www.youtube.com/watch?v=3r5STMiUq9s>

- Video: Christian Fabre, César Fuguet. 2023. One Year of Improvements on OpenHW Group's HPDCache. RISC-V Summit US 2023. <https://www.youtube.com/watch?v=ODHA-wPOmW0>
