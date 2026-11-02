// CVE-2026-9119 (chromium:502661101, upstream WebRTC ff1be2e852): back to normal audio after comfort noise, NetEq's
// Normal crossfaded 1 ms of comfort noise (48 samples at 48 kHz) into the decoded output whatever the output's length,
// so a short decoded frame from the peer overran the output's heap buffer; after an expand it read past the expanded
// audio the same way. The overrun is only caught with the crossfading code instrumented:
//
//   ./build-input/bazel-9.2.0-darwin-arm64 test //third-party/webrtc:neteq_normal_test --test_output=all \
//     --per_file_copt=third-party/webrtc/webrtc/modules/audio_coding/neteq/.*@-fsanitize=address \
//     --linkopt=-fsanitize=address

#include <cstdio>
#include <vector>

#include "api/neteq/neteq.h"
#include "modules/audio_coding/neteq/audio_multi_vector.h"
#include "modules/audio_coding/neteq/background_noise.h"
#include "modules/audio_coding/neteq/decoder_database.h"
#include "modules/audio_coding/neteq/normal.h"

namespace {

int g_failures = 0;

#define CHECK_TRUE(cond)                                                  \
    do {                                                                  \
        if (!(cond)) {                                                    \
            std::printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);   \
            g_failures++;                                                 \
        }                                                                 \
    } while (0)

// A decoded frame of `frames` samples after comfort noise, with no comfort noise decoder active (the crossfade then
// runs over the decoded audio itself), as upstream's `Normal.LastModeRfc3389CngSmallInput`.
void testShortFrameAfterComfortNoise(int fsHz, size_t frames) {
    webrtc::DecoderDatabase db(rtc::scoped_refptr<webrtc::AudioDecoderFactory>(), absl::nullopt);
    webrtc::BackgroundNoise bgn(1);
    webrtc::Normal normal(fsHz, &db, bgn, /*expand=*/nullptr, /*statistics=*/nullptr);
    webrtc::AudioMultiVector output(1);
    std::vector<int16_t> input(frames, 1000);
    int result = normal.Process(input.data(), input.size(), webrtc::NetEq::Mode::kRfc3389Cng, &output);
    CHECK_TRUE(result == static_cast<int>(frames));
    CHECK_TRUE(output.Size() == frames);
}

}  // namespace

int main() {
    testShortFrameAfterComfortNoise(48000, 10);
    testShortFrameAfterComfortNoise(48000, 1);
    testShortFrameAfterComfortNoise(16000, 10);
    // A frame of at least 1 ms takes the whole crossfade, as before.
    testShortFrameAfterComfortNoise(48000, 480);

    if (g_failures != 0) {
        std::printf("%d check(s) failed\n", g_failures);
        return 1;
    }
    std::printf("All NetEq Normal checks passed\n");
    return 0;
}
