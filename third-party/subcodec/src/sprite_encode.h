#pragma once

#include <cstdint>
#include <cstddef>
#include <memory>
#include <vector>
#include <expected>
#include "types.h"
#include "error.h"

namespace subcodec {

struct EncodeResult {
    std::vector<MacroblockData> color;
    std::vector<MacroblockData> alpha;
};

class SpriteEncoder {
public:
    struct Params {
        int width = 0;    // Content width in pixels (multiple of 16)
        int height = 0;   // Content height in pixels (multiple of 16)
        int qp = 26;
    };

    static std::expected<SpriteEncoder, Error> create(const Params& params);
    ~SpriteEncoder();

    SpriteEncoder(SpriteEncoder&&) noexcept;
    SpriteEncoder& operator=(SpriteEncoder&&) noexcept;

    std::expected<EncodeResult, Error> encode(
        const uint8_t* y, int y_stride,
        const uint8_t* cb, int cb_stride,
        const uint8_t* cr, int cr_stride,
        const uint8_t* alpha, int alpha_stride,
        int frame_index,
        std::vector<uint8_t>* out_nal_data = nullptr);

private:
    SpriteEncoder();
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace subcodec
