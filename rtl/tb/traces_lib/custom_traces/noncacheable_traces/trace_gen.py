import struct
import zlib

# =========================================================
# Fill these opcodes from hpdcache_test_transaction.h
# =========================================================
HPDCACHE_REQ_LOAD  = 0   # <-- replace if needed
HPDCACHE_REQ_STORE = 1   # <-- replace if needed

# Add others if you need them, e.g. AMO, CMO, etc.

def pack_size_byte(size_value_store: int, req_size: int) -> bytes:
    """
    size byte:
      upper 4 bits = size_value_store
      lower 4 bits = req_size
    """
    if not (0 <= size_value_store <= 0xF):
        raise ValueError("size_value_store must fit in 4 bits")
    if not (0 <= req_size <= 0xF):
        raise ValueError("req_size must fit in 4 bits")
    return struct.pack("<B", ((size_value_store & 0xF) << 4) | (req_size & 0xF))

def pack_meta_byte(req_op: int, need_rsp: int, uncacheable: int) -> bytes:
    """
    meta byte:
      bits [7:2] = req_op
      bit  [1]   = need_rsp
      bit  [0]   = uncacheable
    """
    if req_op < 0 or req_op > 0x3F:
        raise ValueError("req_op must fit in 6 bits")
    if need_rsp not in (0, 1):
        raise ValueError("need_rsp must be 0 or 1")
    if uncacheable not in (0, 1):
        raise ValueError("uncacheable must be 0 or 1")
    value = (req_op << 2) | (need_rsp << 1) | uncacheable
    return struct.pack("<B", value)

def pack_write_data(data: int, size_value_store: int) -> bytes:
    """
    read_value() in your code interprets:
      0 -> 1 byte
      1 -> 2 bytes
      2 -> 4 bytes
      3 -> 8 bytes
      4 -> 8 bytes  (yes, code reads uint64_t again)
    """
    if size_value_store == 0:
        return struct.pack("<B", data & 0xFF)
    elif size_value_store == 1:
        return struct.pack("<H", data & 0xFFFF)
    elif size_value_store == 2:
        return struct.pack("<I", data & 0xFFFFFFFF)
    elif size_value_store in (3, 4):
        return struct.pack("<Q", data & 0xFFFFFFFFFFFFFFFF)
    else:
        raise ValueError(f"unsupported size_value_store={size_value_store}")

def make_record(
    delay: int,
    address: int,
    req_size: int,
    size_value_store: int,
    req_op: int,
    need_rsp: int = 1,
    uncacheable: int = 0,
    write_data: int | None = None,
) -> bytes:
    """
    One transaction record:
      [delay:1][address:8][size:1][meta:1][optional write_data]
    """
    if not (0 <= delay <= 0xFF):
        raise ValueError("delay must fit in 1 byte")
    if not (0 <= address <= 0xFFFFFFFFFFFFFFFF):
        raise ValueError("address must fit in 8 bytes")

    rec = bytearray()
    rec += struct.pack("<B", delay)
    rec += struct.pack("<Q", address)  # little-endian uint64_t
    rec += pack_size_byte(size_value_store, req_size)
    rec += pack_meta_byte(req_op, need_rsp, uncacheable)

    if req_op == HPDCACHE_REQ_STORE:
        if write_data is None:
            raise ValueError("STORE requires write_data")
        rec += pack_write_data(write_data, size_value_store)

    return bytes(rec)

def write_trace(records: list[bytes], out_path: str) -> None:
    raw = b"".join(records)
    compressed = zlib.compress(raw)
    with open(out_path, "wb") as f:
        f.write(compressed)

def NC_ONLY_CONSECUTIVE() -> None:
    records = []

    # =========================================================
    # CASE: Consecutive non-cacheable accesses to the same line
    #
    # Goal:
    #   Verify repeated NC accesses to the same address.
    #
    # Check:
    #   - NC LOAD/STORE are handled through NC path
    #   - NC STORE result is visible to following NC LOAD
    # =========================================================

    # 1. Cacheable LOAD to unrelated line
    records.append(
        make_record(
            delay=10,
            address=0x0000000080000000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )

    # 2. NC LOAD to target line
    records.append(
        make_record(
            delay=10,
            address=0x000000008000_1000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=1,
        )
    )

    # 3. NC STORE to same target line
    records.append(
        make_record(
            delay=20,
            address=0x000000008000_1000,
            req_size=2,
            size_value_store=2,
            req_op=HPDCACHE_REQ_STORE,
            need_rsp=1,
            uncacheable=1,
            write_data=0x12345678,
        )
    )

    # 4. NC LOAD again to same target line
    records.append(
        make_record(
            delay=10,
            address=0x000000008000_1000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=1,
        )
    )

    write_trace(records, "NC_ONLY_CONSECUTIVE.bin")


def NC_MISS_ONLY() -> None:
    records = []

    # =========================================================
    # CASE: Non-cacheable requests on cache-miss lines only
    #
    # Goal:
    #   Verify NC requests to lines not resident in cache.
    #
    # Check:
    #   - Direct NC path
    #   - No dirty-hit flush behavior
    # =========================================================

    # 1. NC LOAD
    records.append(
        make_record(
            delay=10,
            address=0x000000008000_1000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=1,
        )
    )

    # 2. NC LOAD
    records.append(
        make_record(
            delay=10,
            address=0x000000008008_0000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=1,
        )
    )

    # 3. NC LOAD
    records.append(
        make_record(
            delay=10,
            address=0x000000008010_0000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=1,
        )
    )

    # 4. NC STORE
    records.append(
        make_record(
            delay=20,
            address=0x000000008020_0000,
            req_size=2,
            size_value_store=2,
            req_op=HPDCACHE_REQ_STORE,
            need_rsp=1,
            uncacheable=1,
            write_data=0x12345678,
        )
    )

    # 5. NC STORE
    records.append(
        make_record(
            delay=20,
            address=0x000000008040_0000,
            req_size=2,
            size_value_store=2,
            req_op=HPDCACHE_REQ_STORE,
            need_rsp=1,
            uncacheable=1,
            write_data=0x12345678,
        )
    )

    # 6. NC STORE
    records.append(
        make_record(
            delay=20,
            address=0x000000008080_0000,
            req_size=2,
            size_value_store=2,
            req_op=HPDCACHE_REQ_STORE,
            need_rsp=1,
            uncacheable=1,
            write_data=0x12345678,
        )
    )

    write_trace(records, "NC_MISS_ONLY.bin")


def NC_ON_CLEAN_HIT() -> None:
    records = []

    # =========================================================
    # CASE: NC request on cache-hit clean line
    #
    # Goal:
    #   Verify NC request when matching line is present and clean.
    #   Cache invalidation is valid 
    # Check:
    #   - Hit exists
    #   - Dirty bit is not set
    #   - No flush should occur
    # =========================================================

    # Subcase 1
    # 1. Cacheable LOAD fills line
    records.append(
        make_record(
            delay=10,
            address=0x000000008000_1000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )

    # 2. NC LOAD to same clean line
    records.append(
        make_record(
            delay=10,
            address=0x000000008000_1000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=1,
        )
    )

    records.append(
        make_record(
            delay=5,
            address=0x000000008000_1000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )

    # Subcase 2
    # 3. Cacheable LOAD fills line
    records.append(
        make_record(
            delay=10,
            address=0x000000008001_0000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )

    # 4. NC LOAD to same clean line
    records.append(
        make_record(
            delay=10,
            address=0x000000008001_0000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=1,
        )
    )
    records.append(
        make_record(
            delay=5,
            address=0x000000008001_0000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )

    # Subcase 3
    # 5. Cacheable LOAD fills line
    records.append(
        make_record(
            delay=10,
            address=0x000000008004_0000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )

    # 6. NC LOAD to same clean line
    records.append(
        make_record(
            delay=10,
            address=0x000000008004_0000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=1,
        )
    )
    
    records.append(
        make_record(
            delay=10,
            address=0x000000008004_0000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )

    write_trace(records, "NC_ON_CLEAN_HIT.bin")


def NC_ON_DIRTY_HIT() -> None:
    records = []

    # =========================================================
    # CASE: NC request on cache-hit dirty line
    #
    # Goal:
    #   Verify that dirty hit + NC access triggers flush first.
    #
    # Main check:
    #   dirty hit + NC request => flush before NC request proceeds
    # =========================================================

    # =========================================================
    # SUBCASE 1: NC LOAD on dirty hit, then cacheable LOAD
    # =========================================================
    records.append(
        make_record(
            delay=10,
            address=0x000000008000_1000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )
    records.append(
        make_record(
            delay=20,
            address=0x000000008000_1000,
            req_size=2,
            size_value_store=2,
            req_op=HPDCACHE_REQ_STORE,
            need_rsp=1,
            uncacheable=0,
            write_data=0x12345678,
        )
    )
    records.append(
        make_record(
            delay=10,
            address=0x0000000080001000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=1,
        )
    )
    records.append(
        make_record(
            delay=10,
            address=0x0000000080001000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )

    # =========================================================
    # SUBCASE 2: NC STORE on dirty hit, then cacheable LOAD
    # =========================================================
    records.append(
        make_record(
            delay=10,
            address=0x000000008001_0000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )
    records.append(
        make_record(
            delay=20,
            address=0x000000008001_0000,
            req_size=2,
            size_value_store=2,
            req_op=HPDCACHE_REQ_STORE,
            need_rsp=1,
            uncacheable=0,
            write_data=0x12345678,
        )
    )
    records.append(
        make_record(
            delay=20,
            address=0x000000008001_0000,
            req_size=2,
            size_value_store=2,
            req_op=HPDCACHE_REQ_STORE,
            need_rsp=1,
            uncacheable=1,
            write_data=0x12345678,
        )
    )
    records.append(
        make_record(
            delay=10,
            address=0x0000000080010000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )

    # =========================================================
    # SUBCASE 3: NC LOAD on dirty hit, then cacheable STORE
    # =========================================================
    records.append(
        make_record(
            delay=10,
            address=0x000000008008_0000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )
    records.append(
        make_record(
            delay=20,
            address=0x000000008008_0000,
            req_size=2,
            size_value_store=2,
            req_op=HPDCACHE_REQ_STORE,
            need_rsp=1,
            uncacheable=0,
            write_data=0x12345678,
        )
    )
    records.append(
        make_record(
            delay=10,
            address=0x0000000080080000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=1,
        )
    )
    records.append(
        make_record(
            delay=20,
            address=0x000000008008_0000,
            req_size=2,
            size_value_store=2,
            req_op=HPDCACHE_REQ_STORE,
            need_rsp=1,
            uncacheable=0,
            write_data=0x12345678,
        )
    )

    # =========================================================
    # SUBCASE 4: NC STORE on dirty hit, then cacheable STORE
    # =========================================================
    records.append(
        make_record(
            delay=10,
            address=0x000000008012_0000,
            req_size=2,
            size_value_store=0,
            req_op=HPDCACHE_REQ_LOAD,
            need_rsp=1,
            uncacheable=0,
        )
    )
    records.append(
        make_record(
            delay=20,
            address=0x000000008012_0000,
            req_size=2,
            size_value_store=2,
            req_op=HPDCACHE_REQ_STORE,
            need_rsp=1,
            uncacheable=0,
            write_data=0x12345678,
        )
    )
    records.append(
        make_record(
            delay=20,
            address=0x000000008012_0000,
            req_size=2,
            size_value_store=2,
            req_op=HPDCACHE_REQ_STORE,
            need_rsp=1,
            uncacheable=1,
            write_data=0x12345678,
        )
    )
    records.append(
        make_record(
            delay=20,
            address=0x000000008012_0000,
            req_size=2,
            size_value_store=2,
            req_op=HPDCACHE_REQ_STORE,
            need_rsp=1,
            uncacheable=0,
            write_data=0x12345678,
        )
    )

    write_trace(records, "NC_ON_DIRTY_HIT.bin")




if __name__ == "__main__":
    NC_ONLY_CONSECUTIVE()
    NC_MISS_ONLY()
    NC_ON_CLEAN_HIT()
    NC_ON_DIRTY_HIT()