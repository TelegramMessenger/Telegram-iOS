#pragma once

#include <expected>

namespace subcodec {

enum class Error {
    OUT_OF_SPACE,
    PARSE_ERROR,
    INVALID_INPUT,
    IO_ERROR,
    ENCODE_ERROR,
};

} // namespace subcodec
