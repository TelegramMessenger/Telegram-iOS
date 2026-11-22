#pragma once

#include <cstdint>
#include <memory>
#include <expected>
#include <filesystem>
#include "error.h"

namespace subcodec {

class SpriteExtractor {
public:
    struct Params {
        int sprite_size;       // content size in pixels (must be multiple of 16)
        int qp = 26;           // quantization parameter
    };

    static std::expected<SpriteExtractor, Error> create(
        const Params& params, const std::filesystem::path& output_path);

    std::expected<void, Error> add_frame(
        const uint8_t* y, int y_stride,
        const uint8_t* cb, int cb_stride,
        const uint8_t* cr, int cr_stride,
        const uint8_t* alpha, int alpha_stride);

    std::expected<void, Error> finalize();

    ~SpriteExtractor();
    SpriteExtractor(SpriteExtractor&&) noexcept;
    SpriteExtractor& operator=(SpriteExtractor&&) noexcept;

private:
    SpriteExtractor();
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace subcodec
