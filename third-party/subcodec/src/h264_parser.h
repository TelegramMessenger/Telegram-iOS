#pragma once

#include <cstdint>
#include <cstddef>
#include <span>
#include <expected>
#include <vector>
#include "types.h"
#include "error.h"

namespace subcodec {

class H264Parser {
public:
    std::expected<std::vector<MacroblockData>, Error> parse_slice(
        std::span<const uint8_t> nal_data,
        const FrameParams& params);

    std::expected<std::vector<MacroblockData>, Error> parse_slice_ex(
        std::span<const uint8_t> nal_data,
        const FrameParams& params,
        int* out_slice_qp_delta = nullptr);

private:
    std::vector<uint8_t> rbsp_buf_;
    std::vector<MbContext> ctx_row_;
};

} // namespace subcodec
