# OpenHW Core-V High-Performance L1 Dcache (CV-HPDcache)

![HPDcache CI](https://github.com/openhwgroup/cv-hpdcache/actions/workflows/test.yml/badge.svg)

The HPDcache is an open-source High-Performance, Multi-requester, Out-of-Order L1 Dcache for RISC-V cores and accelerators.

## List of Features

- Support for multiple outstanding requests per requester.
- Support for multiple outstanding read and writes to memory.
- Any given requester can access 1 to 64 bytes of a cacheline per cycle.
- Non-allocate, write-through policy or allocate, write-back policy. Either one or both are supported simultaneously at cacheline granularity.
- Hardware write-buffer to mask the latency of write acknowledgements from the memory system.
- For address-overlapping transactions, the cache guarantees that these are committed in the order in which they are consumed from the requesters.
- For non-address-overlapping transactions, the cache may execute them in an out-of-order fashion to improve performance.
- Supports Cache Management Operations (CMOs): cache invalidation and prefetch operations, and memory fences for multi-core synchronisation.
  Cache invalidation operations support the ones defined in the RISC-V CMO Standard.
- Support for Atomic Memory Operations (AMOs) as defined in RISC-V's A extension.
- Comply to the RISC-V Weak Memory Ordering (RVWMO) consistency model.

## Documentation

The HPDcache User Guide document can be found in the *docs* folder.
It is written in reStructuredText format.
You can find the most up-to-date version of the documentation in [the OpenHW ReadTheDocs server](https://openhw-group-cv-hpdcache.readthedocs-hosted.com/).

If you need to compile the User Guide document, a dedicated *Makefile* is in the *docs* folder.
You can find pre-compiled User Guide documents (in both HTML or PDF) in [Releases](https://github.com/openhwgroup/cv-hpdcache/releases)

## Contributing

Contributions are always welcomed. Please read the guidelines for contributions in [CONTRIBUTING](CONTRIBUTING.md).

## Directory Structure

<table>
  <tr>
    <th style="text-align:left;width:20%">Directory</th>
    <th style="text-align:left">Description</th>
  </tr>
  <tr>
    <td>rtl</td>
    <td>Contains the file lists to be used for the compiling of the HPDcache</td>
  </tr>
  <tr>
    <td>rtl/src</td>
    <td>Contains the SystemVerilog RTL sources of the HPDcache</td>
  </tr>
  <tr>
    <td>rtl/syn</td>
    <td>Contains a synthesis flow based on Yosys</td>
  </tr>
  <tr>
    <td>rtl/lint</td>
    <td>Contains a linter wrapper and a Makefile to run a lint tool on the RTL</td>
  </tr>
  <tr>
    <td>rtl/tb</td>
    <td>Contains a HPDcache standalone testbench for validation of the RTL</td>
  </tr>
  <tr>
    <td>rtl/fv/lnt</td>
    <td>Contains a formal HPDcache specification written in LNT</td>
  </tr>
  <tr>
    <td>docs</td>
    <td>Contains documentation of the HPDcache</td>
  </tr>
  <tr>
    <td>vendor</td>
    <td>Third-party IPs maintained outside the repository</td>
  </tr>
</table>

## Licensing

The HPDcache is released under the Solderpad Hardware License (version 2.1).
Please refer to the [LICENSE](LICENSE) file for further information.

This repository may include third-party open-source IPs. These may be covered by different but compatible permissive licenses.

## Integration Examples of the HPDcache

### CVA6

The HPDcache is integrated with the CVA6 core.
The HPDcache repository (this repository) is included as a submodule of the CVA6 Git.
After you clone the [CVA6](https://github.com/openhwgroup/cva6) repository, be sure to pass the ``config_pkg::HPDCACHE`` value to the ``DCacheType`` parameter.
This selects the HPDcache as the L1 Data Cache of the core.
For example, the CVA6 configuration package [cv64a6_imafdc_sv39_hpdcache_config_pkg.sv](https://github.com/openhwgroup/cva6/blob/master/core/include/cv64a6_imafdc_sv39_hpdcache_config_pkg.sv) does this.

The HPDcache is instantiated in the [cva6_hpdcache_subsystem.sv](https://github.com/openhwgroup/cva6/blob/master/core/cache_subsystem/cva6_hpdcache_subsystem.sv) file.
You may take a look if you want to integrate the HPDcache with another core.

### Integration Template

You may look into the docs/lint subdirectory of this repository to see an integration example of the HPDcache ([hpdcache_lint.sv](docs/lint/hpdcache_lint.sv)).

This example uses the macros defined in the [hpdcache_typedef.svh](rtl/include/hpdcache_typedef.svh) file.
These macros ease the definition of types required by the interface of the HPDcache module.

## HPDcache Validation and Verification

For a complete UVM testbench of the HPDcache, please see the [HPDcache Verif](https://github.com/openhwgroup/cv-hpdcache-verif) repository.

There is another testbench (not as complete as the one above) written in SystemC into the `rtl/tb` subdirectory of this repository.
This testbench is compatible with the [Verilator](https://www.veripool.org/verilator/) simulation tool. Thus, it accepts a fully open-source simulation flow.
For more information about the SystemC testbench, read its dedicated [README](rtl/tb/README.md).

## Vendorized repositories

The directory vendor/opentitan contains [vendorized](https://opentitan.org/book/doc/contributing/hw/vendor.html) subdirectories from the [OpenTitan platform](https://github.com/lowRISC/opentitan/) related to the generation of error correction and detection artifacts (ECC encoding and decoding SystemVerilog primitives).

## HPDcache Publications & Tutorials

If you use the HPDcache in your academic work, you can cite us:

<details>
  <summary>HPDcache original publication</summary>
  <ul>
    <li>César Fuguet. 2023. HPDcache: Open-Source High-Performance L1 Data Cache for RISC-V Cores. In Proceedings of the 20th ACM International Conference on Computing Frontiers (CF '23). Association for Computing Machinery, New York, NY, USA, 377–378. <https://doi.org/10.1145/3587135.3591413></li>
  </ul>
</details>

<details>
  <summary>Other HPDcache related publication</summary>
  <ul>
    <li>Technical Paper: D. Million, N. Oliete-Escuín and C. Fuguet, "Breaking the Memory Wall with a Flexible Open-Source L1 Data-Cache," 2024 Design, Automation & Test in Europe Conference & Exhibition (DATE), Valencia, Spain, 2024, pp. 1-2, <https://doi.org/10.23919/DATE58400.2024.10546547</li>
    <li>Video: César Fuguet. 2023. <a href="https://www.youtube.com/watch?v=3r5STMiUq9s">High Performance L1 Dcache for RISC-V Cores. TRISTAN Workshop. RISC-V Summit Europe 2023</a></li>
    <li>Video: Christian Fabre, César Fuguet. 2023. <a href="https://www.youtube.com/watch?v=ODHA-wPOmW0">One Year of Improvements on OpenHW Group's HPDCache. RISC-V Summit US 2023</a></li>
  </ul>
</details>
