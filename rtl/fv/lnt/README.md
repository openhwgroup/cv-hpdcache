# Motivation
This directory contains a formal model of the HPDcache, describing its high-level architecture.
The model uses the LNT language [1], which is supported by the CADP toolbox [2].

# Overall architecture of the model
The model follows the architecture of the HPDCache [HPDcache User Guide from Oct 11 2024, fig 3.1], i.e. the parallel composition of one process per component.
These processes transmit the requests to each other using gates of channel type 'Wire'.
In addition, all component synchronize on a dedicated 'STATUS' gate enabling the controller to atomically access the local states of all components.

# Files
- `main.lnt` : parallel composition of the HPDcache, along with a requester and a lower-level memory
- `hpdcache.lnt` : parallel compositions of the components & specification of the controller component
- `cachedata.lnt` : cache memory component with local data types and functions
- `misshandler.lnt` : miss handler component with local data types and functions
- `replaytable.lnt` : replay table buffer component with local data types and functions
- `writebuffer.lnt` : write buffer component with local data types and functions
- `types.lnt` : common data types
- `channels.lnt` : common channels (gate types)

# Features
## Implemented features
- Write-through Policy with write-buffer supporting write-coalescing and multiple outstanding write requests
- Non-blocking pipeline with read under multiple misses
- Out-of-order execution of requests (replay) to prevent head-of-line blocking
- Ready-valid memory interface
- Multiple ports for requests

## Yet to be implemented features
- Set-associative cache & miss handler allowing several sets
- Support for Atomic Memory Operations (AMOs)
- Support for Cache Management Operations (CMOs)
- Stride-based memory prefetcher

# Configurability
The model parameters are configurable, by altering type or function definitions as indicated below.

- number of data values (in module types.lnt): `type Data is NoData, D1, D2,` ... `DN`
- number of array locations (in module types.lnt): X ∈ {Memory, Cache, MSHR, RTAB, WBUF}
  - type X is array [1..N] ...
  - function X_NENTRIES is return N ...
  - for X = Memory in addition: `type Addr is NoAddr, A1, A2,` ... `AN`
  - for X = Cache in addition: `type LRU_t is array [1..N] of Bool`
- number of requesters :
  - *types.lnt* : `type SId is range 1..N of nat`...
  - *main.lnt* : add new `|| CRI_REQ, CRI_RSP_R, CRI_RSP_W -> CORE [...] (K of SId)`s in the MAIN process parallel composition, with distinct SIds (denoted "K" above) from 1 to N.
- enable/disable the documentation fix from v5.0.1 (module replaytable.lnt): modify (constant) function fixed

# Simulation and Verification
This formal LNT model can be simulated and verified using the [CADP toolbox](https://cadp.inria.fr/).

# References
- [1] H. Garavel, F. Lang and W. Serwe.
       From LOTOS to LNT.
       In: ModelEd, TestEd, TrustEd-Essays Dedicated to Ed Brinksma on the Occasion of His 60th Birthday.
       Lecture Notes in Computer Science, volume 10500, pp. 3-26, Springer Verlag, 2017.

- [2] H. Garavel, F. Lang, R. Mateescu and W. Serwe.
       CADP 2011: A Toolbox for the Construction and Analysis of Distributed Processes.
       Springer International Journal on Software Tools for Technology Transfer 15(2):89-107, 2013.
       https://cadp.inria.fr

