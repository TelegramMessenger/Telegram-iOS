#include "mbs_mux_common.h"
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <vector>

using namespace subcodec::mux;

static int tests_run = 0, tests_passed = 0;

#define ASSERT(cond, msg) do { \
    tests_run++; \
    if (!(cond)) { fprintf(stderr, "FAIL [%s:%d]: %s\n", __func__, __LINE__, msg); return false; } \
    tests_passed++; \
} while(0)

/* Reference: produce output via EbspWriter for skip+blob sequence */
static std::vector<uint8_t> ref_ebsp(const uint32_t* skips,
                                      const uint8_t** blobs, const int* blob_bits,
                                      const bool* long_zero, const uint8_t* lead_zb,
                                      const uint8_t* trail_zb, int count) {
    std::vector<uint8_t> buf(count * 1024 + 4096, 0);
    EbspWriter w;
    w.out = buf.data();
    w.partial = 0;
    w.bits = 0;
    w.zero_count = 0;
    for (int i = 0; i < count; i++) {
        w.write_ue(skips[i]);
        w.copy_blob(blobs[i], blob_bits[i], long_zero[i], lead_zb[i], trail_zb[i]);
    }
    w.write_bits(1, 1);
    if (w.bits > 0) w.write_bits(0, 8 - w.bits);
    size_t len = static_cast<size_t>(w.out - buf.data());
    buf.resize(len);
    return buf;
}

/* Two-pass: produce output via RbspWriter + rbsp_to_ebsp_neon */
static std::vector<uint8_t> new_rbsp_ebsp(const uint32_t* skips,
                                           const uint8_t** blobs, const int* blob_bits,
                                           int count) {
    std::vector<uint8_t> rbsp(count * 1024 + 4096, 0);
    RbspWriter w;
    w.out = rbsp.data();
    w.partial = 0;
    w.bits = 0;
    for (int i = 0; i < count; i++) {
        w.write_ue(skips[i]);
        w.copy_blob(blobs[i], blob_bits[i]);
    }
    w.write_bits(1, 1);
    if (w.bits > 0) w.write_bits(0, 8 - w.bits);
    size_t rbsp_len = static_cast<size_t>(w.out - rbsp.data());

    std::vector<uint8_t> ebsp(rbsp_len * 2 + 16, 0);
    size_t ebsp_len = rbsp_to_ebsp_neon(rbsp.data(), rbsp_len, ebsp.data(), ebsp.size());
    ebsp.resize(ebsp_len);
    return ebsp;
}

static bool test_single_blob_aligned() {
    uint8_t blob[] = {0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE};
    uint32_t skip = 0;
    const uint8_t* bp = blob;
    int bits = 48;
    bool lz = false;
    uint8_t lzb = 0, tzb = 0;
    auto ref = ref_ebsp(&skip, &bp, &bits, &lz, &lzb, &tzb, 1);
    auto got = new_rbsp_ebsp(&skip, &bp, &bits, 1);
    ASSERT(ref == got, "single blob aligned mismatch");
    return true;
}

static bool test_single_blob_unaligned() {
    uint8_t blob[] = {0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE};
    for (uint32_t skip = 1; skip <= 100; skip++) {
        const uint8_t* bp = blob;
        int bits = 48;
        bool lz = false;
        uint8_t lzb = 0, tzb = 0;
        auto ref = ref_ebsp(&skip, &bp, &bits, &lz, &lzb, &tzb, 1);
        auto got = new_rbsp_ebsp(&skip, &bp, &bits, 1);
        ASSERT(ref == got, "unaligned mismatch");
    }
    return true;
}

static bool test_multi_blob_sequence() {
    uint8_t a[] = {0xAB, 0xCD, 0xEF, 0x01, 0x23};
    uint8_t b[] = {0x45, 0x67, 0x89, 0x0A, 0xBC, 0xDE, 0xF0};
    uint8_t c[] = {0x11, 0x22, 0x33};
    const uint8_t* blobs[] = {a, b, c};
    int bits[] = {40, 56, 24};
    uint32_t skips[] = {5, 0, 12};
    bool lz[] = {false, false, false};
    uint8_t lzb[] = {0, 0, 0}, tzb[] = {0, 0, 0};
    auto ref = ref_ebsp(skips, blobs, bits, lz, lzb, tzb, 3);
    auto got = new_rbsp_ebsp(skips, blobs, bits, 3);
    ASSERT(ref == got, "multi blob mismatch");
    return true;
}

static bool test_blob_with_zeros() {
    /* Blob containing sequences that would trigger EBSP escaping */
    uint8_t blob[] = {0x00, 0x00, 0x01, 0xFF, 0x00, 0x00, 0x03, 0xAA};
    uint32_t skip = 3;
    const uint8_t* bp = blob;
    int bits = 64;
    bool lz = true;
    uint8_t lzb = 16, tzb = 0;
    auto ref = ref_ebsp(&skip, &bp, &bits, &lz, &lzb, &tzb, 1);
    auto got = new_rbsp_ebsp(&skip, &bp, &bits, 1);
    ASSERT(ref == got, "blob with zeros mismatch");
    return true;
}

static bool test_large_blob_all_alignments() {
    /* 200-byte blob at all 8 bit alignments */
    uint8_t blob[200];
    for (int i = 0; i < 200; i++) blob[i] = static_cast<uint8_t>((i * 37 + 13) & 0xFF);

    for (uint32_t skip = 0; skip <= 15; skip++) {
        const uint8_t* bp = blob;
        int bits = 200 * 8;
        bool lz = false;
        uint8_t lzb = 0, tzb = 0;
        auto ref = ref_ebsp(&skip, &bp, &bits, &lz, &lzb, &tzb, 1);
        auto got = new_rbsp_ebsp(&skip, &bp, &bits, 1);
        ASSERT(ref == got, "large blob alignment mismatch");
    }
    return true;
}

static bool test_rbsp_to_ebsp_neon_vs_scalar() {
    /* Generate random RBSP data and verify NEON matches scalar */
    srand(42);
    for (int trial = 0; trial < 20; trial++) {
        int len = 100 + rand() % 2000;
        std::vector<uint8_t> rbsp(len);
        for (int i = 0; i < len; i++) rbsp[i] = static_cast<uint8_t>(rand() & 0xFF);

        std::vector<uint8_t> ebsp_ref(len * 2 + 16);
        std::vector<uint8_t> ebsp_neon(len * 2 + 16);

        size_t ref_len = rbsp_to_ebsp(rbsp.data(), len, ebsp_ref.data(), ebsp_ref.size());
        size_t neon_len = rbsp_to_ebsp_neon(rbsp.data(), len, ebsp_neon.data(), ebsp_neon.size());

        ASSERT(ref_len == neon_len, "length mismatch");
        ASSERT(memcmp(ebsp_ref.data(), ebsp_neon.data(), ref_len) == 0, "content mismatch");
    }
    return true;
}

static bool test_partial_bits() {
    /* Blob with non-byte-aligned bit count */
    uint8_t blob[] = {0xAB, 0xCD};
    for (uint32_t skip = 0; skip <= 10; skip++) {
        const uint8_t* bp = blob;
        int bits = 13; /* 1 byte + 5 bits */
        bool lz = false;
        uint8_t lzb = 0, tzb = 0;
        auto ref = ref_ebsp(&skip, &bp, &bits, &lz, &lzb, &tzb, 1);
        auto got = new_rbsp_ebsp(&skip, &bp, &bits, 1);
        ASSERT(ref == got, "partial bits mismatch");
    }
    return true;
}

int main() {
    build_ue_lut();

    test_single_blob_aligned();
    test_single_blob_unaligned();
    test_multi_blob_sequence();
    test_blob_with_zeros();
    test_large_blob_all_alignments();
    test_rbsp_to_ebsp_neon_vs_scalar();
    test_partial_bits();

    printf("\n%d/%d tests passed\n", tests_passed, tests_run);
    if (tests_passed == tests_run) {
        printf("PASS\n");
        return 0;
    }
    printf("FAIL\n");
    return 1;
}
