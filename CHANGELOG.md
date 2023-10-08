# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Removed

### Changed

### Fixed

## [3.0.0] 2023-10-08

### Added

- Add support for virtually-indexed addressing

### Fixed

- Fix forwarding logic of uncacheable Icache response in the cva6 cache subsystem.
- Fix wrong mask signal when implementing the MSHR in registers

## [2.1.0] - 2023-09-25

### Added

- Add additional configuration to implement MSHR in registers (when the number
  of entries is low)

### Fixed

- Fix cache data SRAM chip-select generation when word width is different than
  64 bits (e.g. 32 bits)

## [2.0.0] - 2023-09-18

### Added

- Add parameters in the HPDcache module to define the types of interfaces to
  the memory
- Add helper verilog header file with macros to ease the type definition of
  interfaces to the memory
- Add new event signals in the HPDCache top module
- Add generic single-port RAM macros with byte-enable signals
- Add parameters in the package to choose between RAM macros implementing
  byte-enable or bitmask for the different RAMs instances
- Add additional assertions to verify parameters
- Add additional configuration signal to inhibit write coalescing in the write
  buffer

### Removed

- Remove base_id ports in the HPDCache top module
- Remove nettype (wire,var) in ports as it looks like is badly supported in
  some cases by some simulation tools

### Changed

- Split the hpdcache_pkg into: (1) the hpdcache_pkg contains internally defined
  parameters; (2) a new hpdcache_params_pkg that defines user parameters
- New selection policy of ready requests in the replay table. It gives priority
  to requests in the same linked list.
- The write buffer now accepts writes from requesters in a pending slot when it
  is waiting for the internal arbiter to forward the data to the NoC.

### Fixed

- Correctly support HPDCACHE_ACCESS_WORDS=1
- Correctly support HPDCACHE_ACCESS_WORDS=HPDCACHE_CL_WORDS
- Fix width of the nlines count register in the HW memory prefetcher.

## [1.0.0] - 2023-02-22

### Added
- Initial release to the OpenHW Group
