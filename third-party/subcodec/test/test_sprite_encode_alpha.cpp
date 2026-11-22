#include "sprite_encode.h"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <vector>

using namespace subcodec;

#define SPRITE_PX 64

static int test_alpha_encode() {
    printf("test_alpha_encode...\n");

    int padded = 96;
    int half_chroma = padded / 2;

    std::vector<uint8_t> y(padded * padded);
    std::vector<uint8_t> cb(half_chroma * half_chroma, 128);
    std::vector<uint8_t> cr(half_chroma * half_chroma, 128);
    for (int r = 0; r < padded; r++)
        for (int c = 0; c < padded; c++)
            y[r * padded + c] = static_cast<uint8_t>((r + c) % 256);

    std::vector<uint8_t> alpha(padded * padded, 255);

    auto enc = SpriteEncoder::create({SPRITE_PX, SPRITE_PX, 26});
    assert(enc.has_value());

    auto result = enc->encode(y.data(), padded, cb.data(), half_chroma,
                              cr.data(), half_chroma, alpha.data(), padded, 0);
    assert(result.has_value());
    assert(result->color.size() == 36);  // 6x6
    assert(result->alpha.size() == 36);

    auto result2 = enc->encode(y.data(), padded, cb.data(), half_chroma,
                               cr.data(), half_chroma, alpha.data(), padded, 1);
    assert(result2.has_value());
    assert(result2->color.size() == 36);
    assert(result2->alpha.size() == 36);

    for (const auto& mb : result2->alpha) {
        if (mb.mb_type != MbType::SKIP)
            assert(mb.cbp_chroma == 0);
    }

    printf("  PASS\n");
    return 0;
}

int main() { return test_alpha_encode(); }
