#include <cstdio>
#include <cstring>
#include <vector>
#include <span>

#include "codec_api.h"
#include "codec_app_def.h"
#include "codec_def.h"

#include "frame_writer.h"
#include "types.h"
#include "mbs_mux_common.h"

using namespace subcodec;

/* Decode an Annex B stream, return decoded frames */
struct decoded_frame_t {
    int width, height;
    std::vector<uint8_t> y, cb, cr;
};

static int decode_stream(const uint8_t* data, size_t size,
                         decoded_frame_t* out, int max_frames) {
    ISVCDecoder* decoder = nullptr;
    if (WelsCreateDecoder(&decoder) != 0 || !decoder) return -1;

    SDecodingParam decParam;
    memset(&decParam, 0, sizeof(decParam));
    decParam.sVideoProperty.eVideoBsType = VIDEO_BITSTREAM_AVC;
    if (decoder->Initialize(&decParam) != 0) {
        WelsDestroyDecoder(decoder);
        return -1;
    }

    /* Feed entire buffer as one packet */
    unsigned char* pDst[3] = {nullptr};
    SBufferInfo dstInfo;
    memset(&dstInfo, 0, sizeof(dstInfo));
    decoder->DecodeFrameNoDelay(
        const_cast<unsigned char*>(data), (int)size, pDst, &dstInfo);

    int decoded = 0;
    if (dstInfo.iBufferStatus == 1 && decoded < max_frames) {
        int w = dstInfo.UsrData.sSystemBuffer.iWidth;
        int h = dstInfo.UsrData.sSystemBuffer.iHeight;
        int sy = dstInfo.UsrData.sSystemBuffer.iStride[0];
        int suv = dstInfo.UsrData.sSystemBuffer.iStride[1];

        out[decoded].width = w;
        out[decoded].height = h;
        out[decoded].y.resize(w * h);
        out[decoded].cb.resize(w / 2 * h / 2);
        out[decoded].cr.resize(w / 2 * h / 2);

        for (int r = 0; r < h; r++)
            memcpy(out[decoded].y.data() + r * w, pDst[0] + r * sy, w);
        for (int r = 0; r < h / 2; r++) {
            memcpy(out[decoded].cb.data() + r * (w / 2), pDst[1] + r * suv, w / 2);
            memcpy(out[decoded].cr.data() + r * (w / 2), pDst[2] + r * suv, w / 2);
        }
        decoded++;
    }

    WelsDestroyDecoder(decoder);
    return decoded;
}

int main(void) {
    printf("=== I_PCM IDR Frame Test ===\n\n");

    /* Create a 3x2 MB frame (48x32 pixels) with known pixel pattern */
    constexpr int W_MBS = 3, H_MBS = 2;
    constexpr int W_PX = W_MBS * 16, H_PX = H_MBS * 16;
    constexpr int CW = W_PX / 2, CH = H_PX / 2;

    uint8_t src_y[W_PX * H_PX];
    uint8_t src_cb[CW * CH];
    uint8_t src_cr[CW * CH];

    /* Fill with a recognizable gradient pattern */
    for (int y = 0; y < H_PX; y++)
        for (int x = 0; x < W_PX; x++)
            src_y[y * W_PX + x] = (uint8_t)((x * 5 + y * 3) % 256);
    for (int y = 0; y < CH; y++)
        for (int x = 0; x < CW; x++) {
            src_cb[y * CW + x] = (uint8_t)((100 + x * 7) % 256);
            src_cr[y * CW + x] = (uint8_t)((200 + y * 11) % 256);
        }

    /* Write SPS+PPS+I_PCM IDR */
    mux::build_ct_lut();
    mux::build_ue_lut();

    FrameParams fp{};
    fp.width_mbs = W_MBS;
    fp.height_mbs = H_MBS;
    fp.qp = 26;
    fp.log2_max_frame_num = 8;

    std::vector<uint8_t> buf(W_MBS * H_MBS * 600 + 4096);
    std::span<uint8_t> out{buf.data(), buf.size()};

    size_t offset = frame_writer::write_headers(out, fp);
    if (offset == 0) { fprintf(stderr, "FAIL: write_headers\n"); return 1; }

    auto idr_result = mux::write_idr_ipcm(
        W_MBS, H_MBS, fp.log2_max_frame_num,
        src_y, W_PX, src_cb, CW, src_cr, CW,
        out.subspan(offset));
    if (!idr_result) {
        fprintf(stderr, "FAIL: write_idr_ipcm error\n");
        return 1;
    }
    offset += *idr_result;
    printf("  Stream size: %zu bytes (SPS+PPS+IDR)\n", offset);

    /* Decode and verify pixels */
    decoded_frame_t dec;
    int count = decode_stream(buf.data(), offset, &dec, 1);
    if (count != 1) {
        fprintf(stderr, "FAIL: decoded %d frames (expected 1)\n", count);
        return 1;
    }

    if (dec.width != W_PX || dec.height != H_PX) {
        fprintf(stderr, "FAIL: decoded %dx%d (expected %dx%d)\n",
                dec.width, dec.height, W_PX, H_PX);
        return 1;
    }

    /* Compare Y */
    int mismatches = 0;
    for (int y = 0; y < H_PX; y++) {
        for (int x = 0; x < W_PX; x++) {
            uint8_t expected = src_y[y * W_PX + x];
            uint8_t actual = dec.y[y * W_PX + x];
            if (expected != actual) {
                if (mismatches < 5)
                    printf("  Y mismatch (%d,%d): expected=%d actual=%d\n",
                           x, y, expected, actual);
                mismatches++;
            }
        }
    }

    /* Compare Cb */
    for (int y = 0; y < CH; y++)
        for (int x = 0; x < CW; x++)
            if (src_cb[y * CW + x] != dec.cb[y * CW + x]) mismatches++;

    /* Compare Cr */
    for (int y = 0; y < CH; y++)
        for (int x = 0; x < CW; x++)
            if (src_cr[y * CW + x] != dec.cr[y * CW + x]) mismatches++;

    printf("  Pixel mismatches: %d\n", mismatches);
    if (mismatches == 0) {
        printf("PASS: I_PCM IDR round-trip\n");
        return 0;
    } else {
        printf("FAIL: pixel mismatches\n");
        return 1;
    }
}
