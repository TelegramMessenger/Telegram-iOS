#pragma once

#include <cstdint>
#include <cstddef>
#include <span>
#include <expected>
#include "types.h"
#include "error.h"
#include "bs.h"

namespace subcodec::frame_writer {

size_t write_headers(std::span<uint8_t> output, const FrameParams& params);

int16_t median3(int16_t a, int16_t b, int16_t c);

void predict_mv(const MbContext* left, const MbContext* above,
                const MbContext* above_right, int16_t* mvp);

void write_mb_p16x16(bs_t* b, const MacroblockData& mb,
                     const MbContext* left, const MbContext* above,
                     const MbContext* above_right,
                     MbContext& out_ctx);

void write_mb_i16x16(bs_t* b, const MacroblockData& mb,
                     const MbContext* left, const MbContext* above,
                     MbContext& out_ctx);

std::expected<size_t, Error> write_p_frame_ex(
    std::span<uint8_t> output,
    const FrameParams& params,
    const MacroblockData* mbs,
    int frame_num);

std::expected<size_t, Error> write_idr_frame_ex(
    std::span<uint8_t> output,
    const FrameParams& params,
    const MacroblockData* mbs);

} // namespace subcodec::frame_writer
