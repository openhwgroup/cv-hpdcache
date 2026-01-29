/**
 *  Copyright 2023,2024 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *  Copyright 2025 Inria, Universite Grenoble-Alpes, TIMA
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/**
 *  Author     : Cesar Fuguet
 *  Date       : October, 2024
 *  Description: Class definitions for hpdcache_fault_injection
 */
#ifndef __HPDCACHE_FAULT_INJECTION_H__
#define __HPDCACHE_FAULT_INJECTION_H__

#include <sstream>
#include <verilated.h>
#include "hpdcache_test_defs.h"
#include "Vhpdcache_wrapper.h"
#include "svdpi.h"

using namespace sc_dt;

class hpdcache_fault_injection
{
public:

    enum class domain_e : int {
        CACHE_DIR = 0,
        CACHE_DAT = 1
    };

private:

    static constexpr int DATA_ROWS = CONF_HPDCACHE_WAYS/CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD;
    static constexpr int DATA_COLS = CONF_HPDCACHE_ACCESS_WORDS;

    svScope dirScopes[CONF_HPDCACHE_WAYS];
    svScope datScopes[DATA_ROWS][DATA_COLS];

    static inline constexpr int getDir(int way)
    {
        return way;
    }

    static inline constexpr int getDatRow(int way)
    {
        return way / CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD;
    }

    static inline constexpr int getDatCol(int word)
    {
        return word % CONF_HPDCACHE_ACCESS_WORDS;
    }

    static inline constexpr int getParBits(int wordWidth)
    {
        if (wordWidth < 64) return 7;
        return 8;
    }

    svScope getScope(domain_e domain, int set, int way, int word=0)
    {
        int x, y;
        svScope ret = nullptr;
        switch (domain) {
#if CONF_HPDCACHE_ECC_DIR_ENABLE
            case domain_e::CACHE_DIR:
                x = getDir(way);
                ret = dirScopes[x];
                break;
#endif
#if CONF_HPDCACHE_ECC_DATA_ENABLE
            case domain_e::CACHE_DAT:
                x = getDatRow(way);
                y = getDatCol(word);
                ret = datScopes[x][y];
                break;
#endif
            default:
                break;
        }
        return ret;
    }

public:

    hpdcache_fault_injection()
    {
#if CONF_HPDCACHE_ECC_DIR_ENABLE
        for (int w = 0; w < CONF_HPDCACHE_WAYS; w++) {
            char hier_name[256];
            snprintf(hier_name, 256,
                     "i_top.hpdcache_wrapper.i_hpdcache"
                     ".hpdcache_ctrl_i.hpdcache_memctrl_i"
                     ".gen_dir_sram[%d].dir_sram.gen_sram_ecc"
                     ".i_sram.i_sram",
                     w);
            svScope scope = svGetScopeFromName(hier_name);
            assert(scope != nullptr);
            dirScopes[w] = scope;
        }
#endif

#if CONF_HPDCACHE_ECC_DATA_ENABLE
        for (int w = 0; w < CONF_HPDCACHE_WAYS/CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD; w++) {
            for (int m = 0; m < CONF_HPDCACHE_ACCESS_WORDS; m++) {
                char hier_name[256];
                snprintf(hier_name, 256,
                         "i_top.hpdcache_wrapper.i_hpdcache"
                         ".hpdcache_ctrl_i.hpdcache_memctrl_i"
                         ".gen_data_sram_row[%d]"
                         ".gen_data_sram_col[%d]"
                         ".data_sram.gen_sram_ecc.ram_i.i_sram",
                         w, m);
                svScope scope = svGetScopeFromName(hier_name);
                assert(scope != nullptr);
                datScopes[w][m] = scope;
            }
        }
#endif

        assert((HPDCACHE_WORD_WIDTH == 64) || (HPDCACHE_WORD_WIDTH == 32));
    }

    void injectDirFault(int set, int way, sc_bv<64> mask, int cycles=0)
    {
#if CONF_HPDCACHE_ECC_DIR_ENABLE
        //  dir entry bits: valid (1) + dirty (1) + fetch (1) + wback (1) + tag (tag width)
        static constexpr int DirBits = HPDCACHE_TAG_WIDTH + 4;
        static constexpr int ParBits = getParBits(DirBits);
        static constexpr int WordBits = DirBits + ParBits;

        svScope scope = getScope(domain_e::CACHE_DIR, set, way);
        svSetScope(scope);

        svLogicVecVal lv[SV_PACKED_DATA_NELEMS(WordBits)];
        memset(lv, 0, sizeof(svLogicVecVal)*SV_PACKED_DATA_NELEMS(WordBits));
        for (int b = 0; b < SV_PACKED_DATA_NELEMS(WordBits); b++) {
            int loIdx = b << 5;
            int hiIdx = (b + 1) << 5;
            if (hiIdx > WordBits) {
                hiIdx = WordBits;
            }
            if (loIdx < WordBits) {
                lv[b].aval = mask.range(hiIdx - 1, loIdx).to_uint();
            }
        }
        Vhpdcache_wrapper::publicSramSetMask(set, lv);
#endif
    }

    void injectDatFault(int set, int way, int word, sc_bv<72> mask, int cycles=0)
    {
#if CONF_HPDCACHE_ECC_DATA_ENABLE
        static constexpr int ParBits = getParBits(CONF_HPDCACHE_WORD_WIDTH);
        static constexpr int WordBits = CONF_HPDCACHE_WORD_WIDTH + ParBits;
        static constexpr int RamBits = WordBits*CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD;

        svScope scope = getScope(domain_e::CACHE_DAT, set, way, word);
        svSetScope(scope);

        int ramWord = way % CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD;
        int ramOffset = ramWord * WordBits;
        int wordOffset = ramOffset & 0x1f;
        int bits = WordBits;

        svLogicVecVal lv[SV_PACKED_DATA_NELEMS(RamBits)];
        memset(lv, 0, sizeof(svLogicVecVal)*SV_PACKED_DATA_NELEMS(RamBits));

        // head bits
        int b = (ramOffset >> 5);
        int loIdx = 0;
        int hiIdx = bits >= 32 ? 32 - wordOffset : bits;
        lv[b++].aval = mask.range(hiIdx - 1, loIdx).to_uint() << wordOffset;
        bits -= hiIdx;

        // middle bits
        while (bits >= 32) {
            loIdx = hiIdx;
            hiIdx = loIdx + 32;
            lv[b++].aval = mask.range(hiIdx - 1, loIdx).to_uint();
            bits -= 32;
        }

        // tail bits
        if (bits) {
            loIdx = hiIdx;
            hiIdx = loIdx + bits;
            lv[b].aval = mask.range(hiIdx - 1, loIdx).to_uint();
        }

        int cacheIdx = (set*CONF_HPDCACHE_CL_WORDS + word)/CONF_HPDCACHE_ACCESS_WORDS;
        Vhpdcache_wrapper::publicSramBeSetMask(cacheIdx, lv);
#endif
    }

    void injectActiveFaults()
    {

    }
};

#endif /* __HPDCACHE_FAULT_INJECTION_H__ */
// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en : fdm=marker
