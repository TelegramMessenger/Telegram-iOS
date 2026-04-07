#include "mbs_mux_common.h"
#include <cstdio>
#include <cstring>
#include <cstdlib>

using namespace subcodec::mux;

static int tests_run = 0;
static int tests_passed = 0;

#define CHECK(cond, msg) do { \
    tests_run++; \
    if (!(cond)) { printf("FAIL: %s\n", msg); } \
    else { tests_passed++; } \
} while(0)

/* Test 1: flush_byte writes bytes and inserts EBSP escape */
static void test_flush_byte() {
    uint8_t buf[32] = {};
    EbspWriter w;
    w.out = buf;
    w.partial = 0;
    w.bits = 0;
    w.zero_count = 0;

    /* Write 00 00 03 — should insert escape: 00 00 03 03 */
    w.flush_byte(0x00);
    w.flush_byte(0x00);
    w.flush_byte(0x03);

    CHECK(w.out - buf == 4, "flush_byte: 00 00 03 → 4 bytes");
    CHECK(buf[0] == 0x00, "flush_byte: byte 0 = 0x00");
    CHECK(buf[1] == 0x00, "flush_byte: byte 1 = 0x00");
    CHECK(buf[2] == 0x03, "flush_byte: byte 2 = 0x03 (escape)");
    CHECK(buf[3] == 0x03, "flush_byte: byte 3 = 0x03 (payload)");

    /* Continue: write 0x01 — zero_count was reset, no escape */
    w.flush_byte(0x01);
    CHECK(w.out - buf == 5, "flush_byte: 5 bytes after 0x01");
    CHECK(buf[4] == 0x01, "flush_byte: byte 4 = 0x01");
}

/* Test 2: flush_byte with 00 00 00 → needs escape before the third 00 */
static void test_flush_byte_triple_zero() {
    uint8_t buf[32] = {};
    EbspWriter w;
    w.out = buf;
    w.partial = 0;
    w.bits = 0;
    w.zero_count = 0;

    w.flush_byte(0x00);
    w.flush_byte(0x00);
    w.flush_byte(0x00);

    CHECK(w.out - buf == 4, "triple zero: 4 bytes output");
    CHECK(buf[0] == 0x00, "triple zero: byte 0");
    CHECK(buf[1] == 0x00, "triple zero: byte 1");
    CHECK(buf[2] == 0x03, "triple zero: byte 2 = escape");
    CHECK(buf[3] == 0x00, "triple zero: byte 3 = payload");
}

/* Test 3: write_bits accumulates and flushes bytes */
static void test_write_bits() {
    uint8_t buf[32] = {};
    EbspWriter w;
    w.out = buf;
    w.partial = 0;
    w.bits = 0;
    w.zero_count = 0;

    /* Write 0b10110011 (0xB3) as 8 bits */
    w.write_bits(0xB3, 8);
    CHECK(w.out - buf == 1, "write_bits 8: flushed 1 byte");
    CHECK(w.bits == 0, "write_bits 8: 0 bits remaining");
    CHECK(buf[0] == 0xB3, "write_bits 8: byte = 0xB3");

    /* Write 0b1010 (4 bits) then 0b0011 (4 bits) → 0xA3 */
    w.write_bits(0xA, 4);
    CHECK(w.bits == 4, "write_bits 4: 4 bits pending");
    w.write_bits(0x3, 4);
    CHECK(w.out - buf == 2, "write_bits 4+4: flushed 2nd byte");
    CHECK(buf[1] == 0xA3, "write_bits 4+4: byte = 0xA3");
}

/* Test 4: write_bits with non-byte-aligned accumulation */
static void test_write_bits_unaligned() {
    uint8_t buf[32] = {};
    EbspWriter w;
    w.out = buf;
    w.partial = 0;
    w.bits = 0;
    w.zero_count = 0;

    /* Write 3 bits (0b101), then 13 bits (0b1100001010011) = total 16 bits = 2 bytes */
    /* Combined: 101_1100001010011 → 0b1011100001010011 → 0xB853 */
    w.write_bits(0x5, 3);      /* 101 */
    w.write_bits(0x1853, 13);  /* 1100001010011 */
    CHECK(w.out - buf == 2, "write_bits unaligned: 2 bytes");
    CHECK(buf[0] == 0xB8, "write_bits unaligned: byte 0 = 0xB8");
    CHECK(buf[1] == 0x53, "write_bits unaligned: byte 1 = 0x53");
}

/* Test 5: write_bits triggers EBSP escape mid-stream */
static void test_write_bits_ebsp() {
    uint8_t buf[32] = {};
    EbspWriter w;
    w.out = buf;
    w.partial = 0;
    w.bits = 0;
    w.zero_count = 0;

    /* Write 24 bits: 0x000001 → should produce 00 00 03 01 */
    w.write_bits(0x000001, 24);
    CHECK(w.out - buf == 4, "write_bits EBSP: 4 bytes (with escape)");
    CHECK(buf[0] == 0x00, "write_bits EBSP: byte 0");
    CHECK(buf[1] == 0x00, "write_bits EBSP: byte 1");
    CHECK(buf[2] == 0x03, "write_bits EBSP: byte 2 = escape");
    CHECK(buf[3] == 0x01, "write_bits EBSP: byte 3 = payload");
}

/* Test 6: ue_lut matches bs_write_ue reference for values 0-4095 */
static void test_ue_lut() {
    build_ue_lut();

    for (uint32_t val = 0; val < 4096; val++) {
        /* Reference: use bs_write_ue into a zeroed buffer */
        uint8_t ref_buf[8] = {};
        bs_t b;
        bs_init(&b, ref_buf, sizeof(ref_buf));
        bs_write_ue(&b, val);
        int ref_bits = static_cast<int>((b.p - b.start) * 8 + (8 - b.bits_left));

        /* Extract bit pattern from reference */
        uint32_t ref_pattern = 0;
        for (int i = 0; i < ref_bits; i++) {
            int byte_idx = i / 8;
            int bit_idx = 7 - (i % 8);
            ref_pattern = (ref_pattern << 1) | ((ref_buf[byte_idx] >> bit_idx) & 1);
        }

        const auto& entry = ue_lut[val];
        if (entry.len != ref_bits || entry.pattern != ref_pattern) {
            printf("FAIL: ue_lut[%u]: got pattern=0x%X len=%d, expected pattern=0x%X len=%d\n",
                   val, entry.pattern, entry.len, ref_pattern, ref_bits);
            tests_run++;
            return;
        }
    }
    tests_run++;
    tests_passed++;
}

/* Test 7: EbspWriter write_ue produces same bytes as bs_write_ue + rbsp_to_ebsp */
static void test_write_ue_output() {
    build_ue_lut();

    /* Write a sequence of skip runs through both paths and compare */
    uint32_t test_vals[] = {0, 1, 2, 5, 10, 42, 100, 255, 1000, 4095};

    /* Reference path: bs_write_ue into RBSP, then rbsp_to_ebsp */
    uint8_t rbsp[256] = {};
    bs_t b;
    bs_init(&b, rbsp, sizeof(rbsp));
    for (auto val : test_vals) {
        bs_write_ue(&b, val);
    }
    int rbsp_len = bs_pos(&b);
    uint8_t ref_ebsp[512] = {};
    size_t ref_len = rbsp_to_ebsp(rbsp, rbsp_len, ref_ebsp, sizeof(ref_ebsp));

    /* New path: EbspWriter with write_ue */
    uint8_t new_ebsp[512] = {};
    EbspWriter w;
    w.out = new_ebsp;
    w.partial = 0;
    w.bits = 0;
    w.zero_count = 0;
    for (auto val : test_vals) {
        w.write_ue(val);
    }
    /* Flush partial byte (pad with zeros, like RBSP trailing) */
    if (w.bits > 0) {
        w.write_bits(0, 8 - w.bits);
    }
    size_t new_len = static_cast<size_t>(w.out - new_ebsp);

    CHECK(new_len == ref_len, "write_ue output length matches reference");
    CHECK(memcmp(new_ebsp, ref_ebsp, ref_len) == 0, "write_ue output bytes match reference");
}

/* Reference helper: write skip_run + blob through old bs_t + rbsp_to_ebsp path */
static size_t ref_skip_blob(uint32_t skip_val, const uint8_t* blob, int blob_bits,
                            uint8_t* out, size_t out_size) {
    uint8_t rbsp[4096] = {};
    bs_t b;
    bs_init(&b, rbsp, sizeof(rbsp));
    bs_write_ue(&b, skip_val);
    bs_copy_bits(&b, blob, 0, blob_bits);
    /* Pad to byte boundary */
    while (((b.p - b.start) * 8 + (8 - b.bits_left)) % 8 != 0) {
        bs_write_u1(&b, 0);
    }
    size_t rbsp_len = static_cast<size_t>(bs_pos(&b));
    return rbsp_to_ebsp(rbsp, rbsp_len, out, out_size);
}

/* New path helper: write skip_run + blob through EbspWriter */
static size_t new_skip_blob(uint32_t skip_val, const uint8_t* blob, int blob_bits,
                            uint8_t* out, size_t out_size) {
    EbspWriter w;
    w.out = out;
    w.partial = 0;
    w.bits = 0;
    w.zero_count = 0;
    w.write_ue(skip_val);
    w.copy_blob(blob, blob_bits);
    /* Pad to byte boundary */
    if (w.bits > 0) {
        w.write_bits(0, 8 - w.bits);
    }
    return static_cast<size_t>(w.out - out);
}

/* Test 8: copy_blob aligned (bits == 0 before blob) */
static void test_copy_blob_aligned() {
    build_ue_lut();

    uint8_t blob[] = {0xAB, 0xCD, 0xEF, 0x01, 0x23};
    int blob_bits = 40;

    /* Reference: rbsp_to_ebsp on the raw blob bytes */
    uint8_t ref[32] = {};
    size_t ref_len = rbsp_to_ebsp(blob, 5, ref, sizeof(ref));

    /* New path: copy_blob with bits=0 */
    uint8_t out[32] = {};
    EbspWriter w;
    w.out = out;
    w.partial = 0;
    w.bits = 0;
    w.zero_count = 0;
    w.copy_blob(blob, blob_bits);
    size_t out_len = static_cast<size_t>(w.out - out);

    CHECK(out_len == ref_len, "copy_blob aligned: length matches");
    CHECK(memcmp(out, ref, ref_len) == 0, "copy_blob aligned: bytes match");
}

/* Test 9: copy_blob non-aligned (bits != 0 before blob) — various skip runs */
static void test_copy_blob_unaligned() {
    build_ue_lut();

    /* Test with several skip values to exercise different bit alignments */
    uint32_t skip_vals[] = {0, 1, 2, 5, 10, 42, 100};
    uint8_t blob[] = {0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x00, 0x02, 0xFF};
    int blob_bits = 64;  /* 8 full bytes, includes 00 00 02 which triggers EBSP */

    for (auto skip : skip_vals) {
        uint8_t ref[64] = {};
        size_t ref_len = ref_skip_blob(skip, blob, blob_bits, ref, sizeof(ref));

        uint8_t out[64] = {};
        size_t out_len = new_skip_blob(skip, blob, blob_bits, out, sizeof(out));

        char msg[128];
        snprintf(msg, sizeof(msg), "copy_blob skip=%u: length matches (ref=%zu new=%zu)",
                 skip, ref_len, out_len);
        CHECK(out_len == ref_len, msg);

        snprintf(msg, sizeof(msg), "copy_blob skip=%u: bytes match", skip);
        CHECK(memcmp(out, ref, ref_len) == 0, msg);
    }
}

/* Test 10: copy_blob with non-byte-aligned blob_bits */
static void test_copy_blob_partial_bits() {
    build_ue_lut();

    uint8_t blob[] = {0xFF, 0x80};  /* 0xFF followed by 1 bit (MSB of 0x80) */
    int blob_bits = 9;
    uint32_t skip_vals[] = {0, 3, 7};

    for (auto skip : skip_vals) {
        uint8_t ref[64] = {};
        size_t ref_len = ref_skip_blob(skip, blob, blob_bits, ref, sizeof(ref));

        uint8_t out[64] = {};
        size_t out_len = new_skip_blob(skip, blob, blob_bits, out, sizeof(out));

        char msg[128];
        snprintf(msg, sizeof(msg), "copy_blob partial skip=%u: length matches", skip);
        CHECK(out_len == ref_len, msg);

        snprintf(msg, sizeof(msg), "copy_blob partial skip=%u: bytes match", skip);
        CHECK(memcmp(out, ref, ref_len) == 0, msg);
    }
}

/* Test 11: copy_blob with multiple skip+blob sequences (simulates real mux) */
static void test_copy_blob_sequence() {
    build_ue_lut();

    /* Simulate: skip(5) + blob_a + skip(0) + blob_b + skip(12) + blob_c */
    uint8_t blob_a[] = {0x12, 0x34, 0x56};
    uint8_t blob_b[] = {0x00, 0x00, 0x01, 0xAB};  /* EBSP-triggering content */
    uint8_t blob_c[] = {0xFF, 0xEE, 0xDD};

    /* Reference path */
    uint8_t rbsp[256] = {};
    bs_t b;
    bs_init(&b, rbsp, sizeof(rbsp));
    bs_write_ue(&b, 5);
    bs_copy_bits(&b, blob_a, 0, 24);
    bs_write_ue(&b, 0);
    bs_copy_bits(&b, blob_b, 0, 32);
    bs_write_ue(&b, 12);
    bs_copy_bits(&b, blob_c, 0, 24);
    while (((b.p - b.start) * 8 + (8 - b.bits_left)) % 8 != 0)
        bs_write_u1(&b, 0);
    size_t rbsp_len = static_cast<size_t>(bs_pos(&b));
    uint8_t ref[512] = {};
    size_t ref_len = rbsp_to_ebsp(rbsp, rbsp_len, ref, sizeof(ref));

    /* New path */
    uint8_t out[512] = {};
    EbspWriter w;
    w.out = out;
    w.partial = 0;
    w.bits = 0;
    w.zero_count = 0;
    w.write_ue(5);
    w.copy_blob(blob_a, 24);
    w.write_ue(0);
    w.copy_blob(blob_b, 32);
    w.write_ue(12);
    w.copy_blob(blob_c, 24);
    if (w.bits > 0)
        w.write_bits(0, 8 - w.bits);
    size_t out_len = static_cast<size_t>(w.out - out);

    CHECK(out_len == ref_len, "copy_blob sequence: length matches");
    CHECK(memcmp(out, ref, ref_len) == 0, "copy_blob sequence: bytes match");
}

/* Test 12: copy_blob with escape-free blob (no 16+ consecutive zero bits) —
 * verify correctness at all 8 bit alignments.
 * Uses skip values that produce bit offsets 0-7 after write_ue. */
static void test_copy_blob_escape_free() {
    build_ue_lut();

    /* Blob with no two consecutive zero bytes — definitely no 16-bit zero run */
    uint8_t blob[] = {0xAB, 0x01, 0xCD, 0x02, 0xEF, 0x03, 0x45, 0x67,
                      0x89, 0x01, 0xAB, 0x02, 0xCD, 0x03, 0xEF, 0x04};
    int blob_bits = 128;

    /* Test at many skip values to exercise all bit alignments */
    uint32_t skip_vals[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 14, 30, 62, 100, 254, 510, 1022};

    for (auto skip : skip_vals) {
        uint8_t ref[256] = {};
        size_t ref_len = ref_skip_blob(skip, blob, blob_bits, ref, sizeof(ref));

        uint8_t out[256] = {};
        size_t out_len = new_skip_blob(skip, blob, blob_bits, out, sizeof(out));

        char msg[128];
        snprintf(msg, sizeof(msg), "copy_blob escape-free skip=%u: length (ref=%zu new=%zu)",
                 skip, ref_len, out_len);
        CHECK(out_len == ref_len, msg);

        snprintf(msg, sizeof(msg), "copy_blob escape-free skip=%u: bytes match", skip);
        CHECK(memcmp(out, ref, ref_len) == 0, msg);
    }
}

/* Test 13: copy_blob with incoming zero_count=2 and escape-free blob starting with byte <= 3.
 * The fast path must still handle boundary escaping. */
static void test_copy_blob_boundary_escape() {
    build_ue_lut();

    /* Blob starting with 0x01 — if incoming zero_count >= 2, needs escape */
    uint8_t blob[] = {0x01, 0xFF, 0xAB, 0xCD, 0xEF, 0x12, 0x34, 0x56};
    int blob_bits = 64;

    /* Manually set up writer with zero_count = 2 (simulating prior 00 00 output) */
    uint8_t ref_buf[64] = {};
    uint8_t new_buf[64] = {};

    /* Reference: flush_byte by byte */
    {
        EbspWriter w;
        w.out = ref_buf;
        w.partial = 0;
        w.bits = 0;
        w.zero_count = 2;  /* incoming: two 0x00 bytes were written */
        w.copy_blob(blob, blob_bits);
        if (w.bits > 0) w.write_bits(0, 8 - w.bits);
    }

    /* New path should produce identical output */
    {
        EbspWriter w;
        w.out = new_buf;
        w.partial = 0;
        w.bits = 0;
        w.zero_count = 2;
        w.copy_blob(blob, blob_bits);
        if (w.bits > 0) w.write_bits(0, 8 - w.bits);
    }

    /* Must be identical — both should have inserted 0x03 before the 0x01 */
    CHECK(ref_buf[0] == 0x03, "boundary escape: ref inserts 0x03");
    CHECK(ref_buf[1] == 0x01, "boundary escape: ref payload 0x01");
    CHECK(memcmp(ref_buf, new_buf, 64) == 0, "boundary escape: new matches ref");
}

/* Test 14: copy_blob with non-aligned writer + escape-free blob, large blob.
 * Exercises the bulk shift-copy path. */
static void test_copy_blob_nonaligned_large() {
    build_ue_lut();

    /* 200-byte blob with no consecutive zero bytes */
    uint8_t blob[200];
    for (int i = 0; i < 200; i++) {
        blob[i] = static_cast<uint8_t>((i * 37 + 13) & 0xFF);
        if (blob[i] == 0) blob[i] = 1;  /* ensure no zero bytes at all */
    }
    int blob_bits = 200 * 8;

    /* Test all bit offsets 1-7 using different skip values */
    /* ue(0)=1bit, ue(1)=3bits, ue(2)=3bits, ue(3)=5bits,
     * ue(4)=5bits, ue(5)=5bits, ue(6)=5bits, ue(7)=7bits */
    uint32_t skip_vals[] = {0, 1, 3, 7, 15, 31, 63};

    for (auto skip : skip_vals) {
        uint8_t ref[512] = {};
        size_t ref_len = ref_skip_blob(skip, blob, blob_bits, ref, sizeof(ref));

        uint8_t out[512] = {};
        size_t out_len = new_skip_blob(skip, blob, blob_bits, out, sizeof(out));

        char msg[128];
        snprintf(msg, sizeof(msg), "copy_blob nonaligned large skip=%u: length (ref=%zu new=%zu)",
                 skip, ref_len, out_len);
        CHECK(out_len == ref_len, msg);

        snprintf(msg, sizeof(msg), "copy_blob nonaligned large skip=%u: bytes match", skip);
        CHECK(memcmp(out, ref, ref_len) == 0, msg);
    }
}

/* Test 15: Directly exercise the 5-arg copy_blob fast path overload.
 * Compares output of 5-arg (fast path) vs 2-arg (reference) at various alignments. */
static void test_copy_blob_fast_path_direct() {
    build_ue_lut();

    /* Escape-free blob: no two consecutive zero bytes */
    uint8_t blob[] = {0xAB, 0x01, 0xCD, 0x02, 0xEF, 0x03, 0x45, 0x67,
                      0x89, 0x01, 0xAB, 0x02, 0xCD, 0x03, 0xEF, 0x04};
    int blob_bits = 128;

    /* Test at various skip values for different bit alignments */
    uint32_t skip_vals[] = {0, 1, 2, 3, 5, 7, 14, 30, 100};

    for (auto skip : skip_vals) {
        /* Reference: 2-arg copy_blob (old path) */
        uint8_t ref[256] = {};
        EbspWriter wr;
        wr.out = ref;
        wr.partial = 0;
        wr.bits = 0;
        wr.zero_count = 0;
        wr.write_ue(skip);
        wr.copy_blob(blob, blob_bits);  /* 2-arg: old path */
        if (wr.bits > 0) wr.write_bits(0, 8 - wr.bits);
        size_t ref_len = static_cast<size_t>(wr.out - ref);

        /* New: 5-arg copy_blob (fast path, has_long_zero_run=false) */
        uint8_t out[256] = {};
        EbspWriter wn;
        wn.out = out;
        wn.partial = 0;
        wn.bits = 0;
        wn.zero_count = 0;
        wn.write_ue(skip);
        wn.copy_blob(blob, blob_bits, false, 0, 0);  /* 5-arg: fast path */
        if (wn.bits > 0) wn.write_bits(0, 8 - wn.bits);
        size_t out_len = static_cast<size_t>(wn.out - out);

        char msg[128];
        snprintf(msg, sizeof(msg), "fast path direct skip=%u: length (ref=%zu new=%zu)",
                 skip, ref_len, out_len);
        CHECK(out_len == ref_len, msg);

        snprintf(msg, sizeof(msg), "fast path direct skip=%u: bytes match", skip);
        CHECK(memcmp(out, ref, ref_len) == 0, msg);
    }

    /* Also test with incoming zero_count = 2 (boundary escape case) */
    {
        uint8_t ref[256] = {};
        EbspWriter wr;
        wr.out = ref;
        wr.partial = 0;
        wr.bits = 0;
        wr.zero_count = 2;
        wr.copy_blob(blob, blob_bits);
        if (wr.bits > 0) wr.write_bits(0, 8 - wr.bits);
        size_t ref_len = static_cast<size_t>(wr.out - ref);

        uint8_t out[256] = {};
        EbspWriter wn;
        wn.out = out;
        wn.partial = 0;
        wn.bits = 0;
        wn.zero_count = 2;
        wn.copy_blob(blob, blob_bits, false, 0, 0);
        if (wn.bits > 0) wn.write_bits(0, 8 - wn.bits);
        size_t out_len = static_cast<size_t>(wn.out - out);

        CHECK(out_len == ref_len, "fast path direct zero_count=2: length matches");
        CHECK(memcmp(out, ref, ref_len) == 0, "fast path direct zero_count=2: bytes match");
    }

    /* Also test with non-aligned + zero_count = 2 */
    {
        uint8_t ref[256] = {};
        EbspWriter wr;
        wr.out = ref;
        wr.partial = 0x5;  /* 3 bits pending */
        wr.bits = 3;
        wr.zero_count = 2;
        wr.copy_blob(blob, blob_bits);
        if (wr.bits > 0) wr.write_bits(0, 8 - wr.bits);
        size_t ref_len = static_cast<size_t>(wr.out - ref);

        uint8_t out[256] = {};
        EbspWriter wn;
        wn.out = out;
        wn.partial = 0x5;
        wn.bits = 3;
        wn.zero_count = 2;
        wn.copy_blob(blob, blob_bits, false, 0, 0);
        if (wn.bits > 0) wn.write_bits(0, 8 - wn.bits);
        size_t out_len = static_cast<size_t>(wn.out - out);

        CHECK(out_len == ref_len, "fast path direct nonaligned+zc2: length matches");
        CHECK(memcmp(out, ref, ref_len) == 0, "fast path direct nonaligned+zc2: bytes match");
    }
}

int main() {
    test_flush_byte();
    test_flush_byte_triple_zero();
    test_write_bits();
    test_write_bits_unaligned();
    test_write_bits_ebsp();
    test_ue_lut();
    test_write_ue_output();
    test_copy_blob_aligned();
    test_copy_blob_unaligned();
    test_copy_blob_partial_bits();
    test_copy_blob_sequence();
    test_copy_blob_escape_free();
    test_copy_blob_boundary_escape();
    test_copy_blob_nonaligned_large();
    test_copy_blob_fast_path_direct();

    printf("%d/%d tests passed\n", tests_passed, tests_run);
    if (tests_passed != tests_run) {
        printf("FAIL\n");
        return 1;
    }
    printf("PASS\n");
    return 0;
}
