# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Removed

- Remove base_id ports in the HPDCache top module
- Remove nettype (wire,var) in ports as it looks like is badly supported in
  some cases by some simulation tools

### Changed

- Split the hpdcache_pkg into: (1) the hpdcache_pkg contains internally defined
  parameters; (2) a new hpdcache_params_pkg that defines user parameters
- New selection policy of ready requests in the replay table. It gives priority
  to requests in the same linked list.

### Fixed

- Correctly support HPDCACHE_ACCESS_WORDS=1
- Correctly support HPDCACHE_ACCESS_WORDS=HPDCACHE_CL_WORDS
- Fix width of the nlines count register in the HW memory prefetcher.

## [1.0.0] - 2023-02-22

### Added
- Initial release to the OpenHW Group
