#include <cassert>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <vector>
#include "sprite_extractor.h"
#include "types.h"

using namespace subcodec;

static void test_basic_extraction() {
    const int sprite_size = 64;
    const int num_frames = 4;
    const char* path = "/tmp/test_sprite_extractor.mbs";

    auto ext_result = SpriteExtractor::create(
        {.sprite_size = sprite_size, .qp = 26}, path);
    assert(ext_result.has_value());
    auto& ext = *ext_result;

    int chroma_size = sprite_size / 2;

    for (int f = 0; f < num_frames; f++) {
        // Create solid-color YUV frame (different luma per frame)
        std::vector<uint8_t> y(sprite_size * sprite_size, static_cast<uint8_t>(40 + f * 30));
        std::vector<uint8_t> cb(chroma_size * chroma_size, 128);
        std::vector<uint8_t> cr(chroma_size * chroma_size, 128);
        std::vector<uint8_t> alpha(sprite_size * sprite_size, 255);

        auto result = ext.add_frame(
            y.data(), sprite_size,
            cb.data(), chroma_size,
            cr.data(), chroma_size,
            alpha.data(), sprite_size);
        assert(result.has_value());
    }

    auto fin = ext.finalize();
    assert(fin.has_value());

    // Load and verify structure
    auto load_result = MbsSprite::load(path);
    assert(load_result.has_value());
    auto& sprite = *load_result;

    int padded_mbs = (sprite_size + 2 * 16) / 16;
    assert(sprite.width_mbs == padded_mbs);
    assert(sprite.height_mbs == padded_mbs);
    assert(sprite.num_frames == num_frames);
    assert(sprite.qp == 26);
    assert(sprite.frames.size() == (size_t)num_frames);

    for (int f = 0; f < num_frames; f++) {
        assert(sprite.frames[f].merged_rows.size() > 0);
    }

    printf("test_basic_extraction: PASS\n");
}

static int test_alpha_extraction() {
    printf("test_alpha_extraction...\n");

    int ss = 64, stride = ss, chroma_ss = ss / 2;
    std::vector<uint8_t> y(ss * ss), cb(chroma_ss * chroma_ss, 128),
                         cr(chroma_ss * chroma_ss, 128), alpha(ss * ss, 255);

    auto ext = SpriteExtractor::create({.sprite_size = ss, .qp = 26},
                                        "/tmp/test_alpha_extract.mbs");
    assert(ext.has_value());

    for (int f = 0; f < 4; f++) {
        memset(y.data(), 40 + f * 30, y.size());
        memset(alpha.data(), 200 + f * 10, alpha.size());
        auto r = ext->add_frame(y.data(), stride, cb.data(), chroma_ss,
                                 cr.data(), chroma_ss, alpha.data(), stride);
        assert(r.has_value());
    }

    auto fin = ext->finalize();
    assert(fin.has_value());

    auto loaded = MbsSprite::load("/tmp/test_alpha_extract.mbs");
    assert(loaded.has_value());
    assert(loaded->num_frames == 4);
    assert(loaded->width_mbs == 6);
    assert(loaded->height_mbs == 6);
    for (int f = 0; f < 4; f++) {
        assert(loaded->frames[f].merged_rows.size() == 6);
    }

    printf("  PASS\n");
    return 0;
}

static void test_validation() {
    // sprite_size not multiple of 16
    auto r1 = SpriteExtractor::create({.sprite_size = 50, .qp = 26}, "/tmp/bad.mbs");
    assert(!r1.has_value());

    // sprite_size zero
    auto r2 = SpriteExtractor::create({.sprite_size = 0, .qp = 26}, "/tmp/bad.mbs");
    assert(!r2.has_value());

    printf("test_validation: PASS\n");
}

int main() {
    test_basic_extraction();
    test_validation();
    test_alpha_extraction();
    printf("All tests passed.\n");
    return 0;
}
