#include "sprite_extractor.h"
#include "sprite_encode.h"
#include "mbs_encode.h"
#include "mbs_format.h"

#include <cstdio>
#include <cstring>
#include <vector>

namespace subcodec {


struct SpriteExtractor::Impl {
    SpriteEncoder encoder;
    FILE* file = nullptr;
    std::filesystem::path output_path;
    FrameParams frame_params{};
    uint16_t frame_count = 0;
    int sprite_size = 0;
    int padded_size = 0;
    int padded_stride = 0;
    // Reusable padded YUV buffers
    std::vector<uint8_t> pad_y;
    std::vector<uint8_t> pad_cb;
    std::vector<uint8_t> pad_cr;
    std::vector<uint8_t> pad_alpha;
    bool failed = false;

    Impl(SpriteEncoder&& enc) : encoder(std::move(enc)) {}

    ~Impl() {
        if (file) {
            fclose(file);
            // Remove partial file if finalize() was never called
            std::filesystem::remove(output_path);
        }
    }
};

SpriteExtractor::SpriteExtractor() = default;
SpriteExtractor::~SpriteExtractor() = default;
SpriteExtractor::SpriteExtractor(SpriteExtractor&&) noexcept = default;
SpriteExtractor& SpriteExtractor::operator=(SpriteExtractor&&) noexcept = default;

std::expected<SpriteExtractor, Error> SpriteExtractor::create(
    const Params& params, const std::filesystem::path& output_path) {

    if (params.sprite_size <= 0 || params.sprite_size % 16 != 0)
        return std::unexpected(Error::INVALID_INPUT);

    constexpr int padding_px = 16;
    int padded_size = params.sprite_size + 2 * padding_px;

    auto enc_result = SpriteEncoder::create({params.sprite_size, params.sprite_size, params.qp});
    if (!enc_result)
        return std::unexpected(enc_result.error());

    FILE* f = fopen(output_path.c_str(), "wb");
    if (!f)
        return std::unexpected(Error::IO_ERROR);

    auto impl = std::make_unique<Impl>(std::move(*enc_result));
    impl->file = f;
    impl->output_path = output_path;
    impl->sprite_size = params.sprite_size;
    impl->padded_size = padded_size;

    uint16_t width_mbs = static_cast<uint16_t>(padded_size / 16);
    uint16_t height_mbs = static_cast<uint16_t>(padded_size / 16);

    impl->frame_params.width_mbs = width_mbs;
    impl->frame_params.height_mbs = height_mbs;
    impl->frame_params.qp = static_cast<uint8_t>(params.qp);

    // Allocate padded YUV buffers (reused across frames)
    impl->padded_stride = padded_size;
    int chroma_size = (padded_size / 2) * (padded_size / 2);
    impl->pad_y.resize(padded_size * padded_size);
    impl->pad_cb.resize(chroma_size);
    impl->pad_cr.resize(chroma_size);
    impl->pad_alpha.resize(padded_size * padded_size, 0);  // black = transparent

    // Write MBS v6 header with num_frames=0 (patched in finalize)
    uint32_t magic = MBS_MAGIC_V6;
    uint16_t num_frames = 0;
    uint8_t qp = static_cast<uint8_t>(params.qp);
    uint8_t zero = 0;
    uint8_t flags = 0;  // reserved
    bool ok = true;
    ok &= fwrite(&magic,        4, 1, f) == 1;
    ok &= fwrite(&width_mbs,    2, 1, f) == 1;
    ok &= fwrite(&height_mbs,   2, 1, f) == 1;
    ok &= fwrite(&num_frames,   2, 1, f) == 1;
    ok &= fwrite(&qp,           1, 1, f) == 1;
    ok &= fwrite(&zero,         1, 1, f) == 1;  // qp_delta_idr
    ok &= fwrite(&zero,         1, 1, f) == 1;  // qp_delta_p
    ok &= fwrite(&flags,        1, 1, f) == 1;  // flags (reserved)

    if (!ok) {
        fclose(f);
        impl->file = nullptr;
        std::filesystem::remove(output_path);
        return std::unexpected(Error::IO_ERROR);
    }

    SpriteExtractor ext;
    ext.impl_ = std::move(impl);
    return ext;
}

std::expected<void, Error> SpriteExtractor::add_frame(
    const uint8_t* y, int y_stride,
    const uint8_t* cb, int cb_stride,
    const uint8_t* cr, int cr_stride,
    const uint8_t* alpha, int alpha_stride) {

    if (!impl_ || !impl_->file || impl_->failed)
        return std::unexpected(Error::INVALID_INPUT);

    int ss = impl_->sprite_size;
    constexpr int pp = 16;
    int ps = impl_->padded_size;
    int chroma_pp = pp / 2;
    int chroma_ss = ss / 2;
    int chroma_ps = ps / 2;

    // Clear padded buffers to black (Y=0, Cb=128, Cr=128)
    memset(impl_->pad_y.data(), 0, impl_->pad_y.size());
    memset(impl_->pad_cb.data(), 128, impl_->pad_cb.size());
    memset(impl_->pad_cr.data(), 128, impl_->pad_cr.size());

    // Copy luma
    for (int row = 0; row < ss; row++) {
        memcpy(impl_->pad_y.data() + (row + pp) * ps + pp,
               y + row * y_stride, ss);
    }

    // Copy chroma
    for (int row = 0; row < chroma_ss; row++) {
        memcpy(impl_->pad_cb.data() + (row + chroma_pp) * chroma_ps + chroma_pp,
               cb + row * cb_stride, chroma_ss);
        memcpy(impl_->pad_cr.data() + (row + chroma_pp) * chroma_ps + chroma_pp,
               cr + row * cr_stride, chroma_ss);
    }

    // Clear alpha padding to 0 (transparent) then copy alpha content
    memset(impl_->pad_alpha.data(), 0, impl_->pad_alpha.size());
    for (int row = 0; row < ss; row++) {
        memcpy(impl_->pad_alpha.data() + (row + pp) * ps + pp,
               alpha + row * alpha_stride, ss);
    }

    // Encode with OpenH264 + parse into MacroblockData
    auto encode_result = impl_->encoder.encode(
        impl_->pad_y.data(), ps,
        impl_->pad_cb.data(), chroma_ps,
        impl_->pad_cr.data(), chroma_ps,
        impl_->pad_alpha.data(), ps,
        impl_->frame_count, nullptr);

    if (!encode_result) {
        impl_->failed = true;
        return std::unexpected(encode_result.error());
    }

    // MBS-encode color+alpha as merged frame
    auto merged_mbs = mbs::encode_frame_merged(
        impl_->frame_params, encode_result->color.data(),
        impl_->frame_params, encode_result->alpha.data(),
        impl_->frame_params.width_mbs, 1 /* padding */);
    if (merged_mbs.data.empty()) {
        impl_->failed = true;
        return std::unexpected(Error::ENCODE_ERROR);
    }

    // Write [frame_data_size][merged_row_data] to file
    uint32_t sz = static_cast<uint32_t>(merged_mbs.data.size());
    bool ok = true;
    ok &= fwrite(&sz, 4, 1, impl_->file) == 1;
    ok &= fwrite(merged_mbs.data.data(), 1, merged_mbs.data.size(), impl_->file)
          == merged_mbs.data.size();

    if (!ok) {
        impl_->failed = true;
        return std::unexpected(Error::IO_ERROR);
    }

    impl_->frame_count++;
    return {};
}

std::expected<void, Error> SpriteExtractor::finalize() {
    if (!impl_ || !impl_->file)
        return std::unexpected(Error::INVALID_INPUT);

    if (impl_->failed) {
        fclose(impl_->file);
        impl_->file = nullptr;
        std::filesystem::remove(impl_->output_path);
        return std::unexpected(Error::IO_ERROR);
    }

    // Patch num_frames in header (offset 8: magic(4) + width(2) + height(2))
    fseek(impl_->file, 8, SEEK_SET);
    uint16_t nf = impl_->frame_count;
    bool ok = fwrite(&nf, 2, 1, impl_->file) == 1;

    fclose(impl_->file);
    impl_->file = nullptr;

    if (!ok) {
        std::filesystem::remove(impl_->output_path);
        return std::unexpected(Error::IO_ERROR);
    }

    return {};
}

} // namespace subcodec
