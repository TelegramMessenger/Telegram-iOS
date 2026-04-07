#pragma once
#include "types.h"
#include <cstdint>

// .mbs binary format constants (MB type codes in serialized frame data)
inline constexpr uint32_t MBS_MAGIC_V6   = 0x3653424D;  // 'MBS6' — pre-merged blobs
inline constexpr int      MBS_MB_SKIP    = 0;
inline constexpr int      MBS_MB_P16x16  = 1;
inline constexpr int      MBS_MB_I16x16  = 2;
