#  Yosys-based Synthesis Flow for the HPDcache

This directory contains a simple synthesis flow using Yosys for the HPDcache in a standalone configuration (no processor core associated).
The objective is to provide coarse grain area and timing estimation on a given ASIC technology for the HPDcache alone.
The flow here-proposed is not optimized. Hence, it is not meant for actual tape-outs.

The flow only utilizes open-source PDKs. Currently, only the Nangate45 cells library is supported.

## Prerequisites

The synthesis scripts provided required the following tools to be installed in your system:

1. The Yosys Open Synthesis Suite:
    Sources are available here: [https://github.com/YosysHQ/yosys](https://github.com/YosysHQ/yosys)

2. The Yosys-Slang plugin for loading SystemVerilog designs
    Sources are available here: [https://github.com/povik/yosys-slang](https://github.com/povik/yosys-slang)

Follow the corresponding instructions to install these tools.
You may find binary (prebuilt) distributions of these tools in [https://github.com/YosysHQ/oss-cad-suite-build](https://github.com/YosysHQ/oss-cad-suite-build).

## Run the synthesis

A makefile is provided to facilitate the flow execution:

```bash
make syn
```

To clean all the generated artifacts:

```bash
make clean
```
