// Sources/SubcodecObjC/AnnexBSplitter.h
// Internal shared header — not in public include/ directory
#pragma once

#include <cstdint>
#include <vector>

struct AnnexBFrame {
    const uint8_t *data;
    size_t size;
};

inline std::vector<AnnexBFrame> split_annex_b_frames(const uint8_t* data, size_t size) {
    std::vector<AnnexBFrame> frames;
    size_t frame_start = 0;
    bool current_has_slice = false;

    for (size_t i = 0; i + 3 < size; ) {
        int sc_len = 0;
        if (i + 3 < size && data[i] == 0 && data[i+1] == 0 && data[i+2] == 0 && data[i+3] == 1)
            sc_len = 4;
        else if (i + 2 < size && data[i] == 0 && data[i+1] == 0 && data[i+2] == 1)
            sc_len = 3;

        if (sc_len > 0 && i > 0) {
            uint8_t nal_type = data[i + sc_len] & 0x1F;
            if ((nal_type == 1 || nal_type == 5) && i > frame_start) {
                if (current_has_slice) {
                    frames.push_back({data + frame_start, i - frame_start});
                    frame_start = i;
                    current_has_slice = false;
                }
                current_has_slice = true;
            }
        }

        if (sc_len > 0) i += sc_len + 1;
        else i++;
    }

    if (frame_start < size) {
        frames.push_back({data + frame_start, size - frame_start});
    }

    return frames;
}
