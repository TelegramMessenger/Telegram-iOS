#include "sprite_encode.h"
#include "h264_parser.h"

#include "codec_api.h"
#include "codec_app_def.h"
#include "codec_def.h"

#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <vector>

namespace subcodec {

struct SpriteEncoder::Impl {
    ISVCEncoder* enc = nullptr;
    FrameParams parse_params{};
    int half_width = 0;      // single sprite padded width
    int half_height = 0;     // single sprite padded height
    int canvas_width = 0;    // double-wide: half_width * 2
    int canvas_height = 0;   // same as half_height
    int half_width_mbs = 0;
    int half_height_mbs = 0;
    int canvas_width_mbs = 0;
    H264Parser parser;

    ~Impl() {
        if (enc) {
            enc->Uninitialize();
            WelsDestroySVCEncoder(enc);
        }
    }
};

// Find a slice NAL (type 1 or 5) in Annex B bitstream and parse it.
static std::expected<std::vector<MacroblockData>, Error>
find_and_parse_slice(H264Parser& parser,
                     const uint8_t* data, size_t data_size,
                     const FrameParams& params) {
    size_t pos = 0;
    while (pos + 4 < data_size) {
        int sc_len = 0;
        if (data[pos] == 0 && data[pos+1] == 0 && data[pos+2] == 0 && data[pos+3] == 1)
            sc_len = 4;
        else if (data[pos] == 0 && data[pos+1] == 0 && data[pos+2] == 1)
            sc_len = 3;

        if (sc_len == 0) { pos++; continue; }

        uint8_t nal_type = data[pos + sc_len] & 0x1F;

        // Find end of this NAL
        size_t next_pos = pos + sc_len + 1;
        while (next_pos + 3 <= data_size) {
            if (data[next_pos] == 0 && data[next_pos+1] == 0 &&
                ((next_pos + 2 < data_size && data[next_pos+2] == 1) ||
                 (next_pos + 3 < data_size && data[next_pos+2] == 0 && data[next_pos+3] == 1)))
                break;
            next_pos++;
        }
        size_t nal_end = (next_pos + 3 <= data_size) ? next_pos : data_size;

        if (nal_type == 1 || nal_type == 5) {
            const uint8_t* nal_data = data + pos;
            size_t nal_size = nal_end - pos;

            // Ensure 4-byte start code for parser
            std::vector<uint8_t> normalized;
            if (sc_len == 3) {
                normalized.push_back(0x00);
                normalized.insert(normalized.end(), nal_data, nal_data + nal_size);
                nal_data = normalized.data();
                nal_size = normalized.size();
            }

            return parser.parse_slice({nal_data, nal_size}, params);
        }

        pos = nal_end;
    }
    return std::unexpected(Error::PARSE_ERROR);
}

SpriteEncoder::SpriteEncoder() = default;
SpriteEncoder::~SpriteEncoder() = default;
SpriteEncoder::SpriteEncoder(SpriteEncoder&&) noexcept = default;
SpriteEncoder& SpriteEncoder::operator=(SpriteEncoder&&) noexcept = default;

std::expected<SpriteEncoder, Error> SpriteEncoder::create(const Params& params) {
    if (params.width <= 0 || params.height <= 0 ||
        params.width % 16 != 0 || params.height % 16 != 0)
        return std::unexpected(Error::INVALID_INPUT);

    constexpr int padding_px = 16;
    int padded_width = params.width + 2 * padding_px;
    int padded_height = params.height + 2 * padding_px;
    int canvas_width = padded_width * 2;
    int canvas_height = padded_height;

    ISVCEncoder* enc = nullptr;
    if (WelsCreateSVCEncoder(&enc) != 0 || !enc)
        return std::unexpected(Error::ENCODE_ERROR);

    SEncParamExt eparam;
    enc->GetDefaultParams(&eparam);
    eparam.iUsageType = CAMERA_VIDEO_REAL_TIME;
    eparam.iPicWidth = canvas_width;
    eparam.iPicHeight = canvas_height;
    eparam.fMaxFrameRate = 30.0f;
    eparam.iRCMode = RC_OFF_MODE;
    eparam.iEntropyCodingModeFlag = 0;  // CAVLC
    eparam.iSpatialLayerNum = 1;
    eparam.iTemporalLayerNum = 1;
    eparam.bEnableFrameSkip = false;
    eparam.iMultipleThreadIdc = 1;
    eparam.sSpatialLayers[0].uiProfileIdc = PRO_BASELINE;
    eparam.sSpatialLayers[0].iVideoWidth = canvas_width;
    eparam.sSpatialLayers[0].iVideoHeight = canvas_height;
    eparam.sSpatialLayers[0].fFrameRate = 30.0f;
    eparam.sSpatialLayers[0].iSpatialBitrate = 500000;
    eparam.sSpatialLayers[0].iMaxSpatialBitrate = 500000;
    eparam.sSpatialLayers[0].sSliceArgument.uiSliceMode = SM_SINGLE_SLICE;
    eparam.sSpatialLayers[0].iDLayerQp = params.qp;
    eparam.uiIntraPeriod = 0;  // Only first frame is IDR
    eparam.iNumRefFrame = 1;
    eparam.iLoopFilterDisableIdc = 1;
    eparam.bSubcodecMode = true;  // Enable subcodec sprite-compositing constraints
    eparam.bEnableAdaptiveQuant = false;
    eparam.iMinQp = params.qp;
    eparam.iMaxQp = params.qp;

    if (enc->InitializeExt(&eparam) != 0) {
        WelsDestroySVCEncoder(enc);
        return std::unexpected(Error::ENCODE_ERROR);
    }

    int videoFormat = videoFormatI420;
    enc->SetOption(ENCODER_OPTION_DATAFORMAT, &videoFormat);

    auto impl = std::make_unique<Impl>();
    impl->enc = enc;
    impl->half_width = padded_width;
    impl->half_height = padded_height;
    impl->canvas_width = canvas_width;
    impl->canvas_height = canvas_height;
    impl->half_width_mbs = padded_width / 16;
    impl->half_height_mbs = padded_height / 16;
    impl->canvas_width_mbs = canvas_width / 16;

    // Parse params use canvas dimensions (what OpenH264 actually encoded)
    impl->parse_params.width_mbs = static_cast<uint16_t>(impl->canvas_width_mbs);
    impl->parse_params.height_mbs = static_cast<uint16_t>(impl->half_height_mbs);
    impl->parse_params.log2_max_frame_num = 4;
    impl->parse_params.pic_order_cnt_type = 0;
    impl->parse_params.log2_max_pic_order_cnt_lsb = 5;
    impl->parse_params.qp = static_cast<uint8_t>(params.qp);

    SpriteEncoder se;
    se.impl_ = std::move(impl);
    return se;
}

std::expected<EncodeResult, Error> SpriteEncoder::encode(
    const uint8_t* y, int y_stride,
    const uint8_t* cb, int cb_stride,
    const uint8_t* cr, int cr_stride,
    const uint8_t* alpha, int alpha_stride,
    int frame_index,
    std::vector<uint8_t>* out_nal_data) {

    if (!impl_ || !y || !cb || !cr || !alpha)
        return std::unexpected(Error::INVALID_INPUT);

    int hw = impl_->half_width;
    int hh = impl_->half_height;
    int cw = impl_->canvas_width;
    int ch = impl_->canvas_height;
    int half_chroma_w = hw / 2;
    int half_chroma_h = hh / 2;
    int canvas_chroma_w = cw / 2;
    int canvas_chroma_h = ch / 2;

    // Build double-wide YUV canvas
    // Left half: color Y/Cb/Cr; Right half: alpha as luma, Cb=Cr=128
    std::vector<uint8_t> canvas_y(cw * ch, 0);
    std::vector<uint8_t> canvas_cb(canvas_chroma_w * canvas_chroma_h, 128);
    std::vector<uint8_t> canvas_cr(canvas_chroma_w * canvas_chroma_h, 128);

    // Copy color luma to left half
    for (int row = 0; row < hh; row++)
        memcpy(canvas_y.data() + row * cw, y + row * y_stride, hw);

    // Copy alpha as luma to right half
    for (int row = 0; row < hh; row++)
        memcpy(canvas_y.data() + row * cw + hw, alpha + row * alpha_stride, hw);

    // Copy color chroma to left half (right half stays at 128)
    for (int row = 0; row < half_chroma_h; row++) {
        memcpy(canvas_cb.data() + row * canvas_chroma_w, cb + row * cb_stride, half_chroma_w);
        memcpy(canvas_cr.data() + row * canvas_chroma_w, cr + row * cr_stride, half_chroma_w);
    }

    SSourcePicture pic;
    memset(&pic, 0, sizeof(pic));
    pic.iColorFormat = videoFormatI420;
    pic.iPicWidth = cw;
    pic.iPicHeight = ch;
    pic.iStride[0] = cw;
    pic.iStride[1] = canvas_chroma_w;
    pic.iStride[2] = canvas_chroma_w;
    pic.pData[0] = canvas_y.data();
    pic.pData[1] = canvas_cb.data();
    pic.pData[2] = canvas_cr.data();
    pic.uiTimeStamp = frame_index * 33;

    SFrameBSInfo info;
    memset(&info, 0, sizeof(info));
    int rv = impl_->enc->EncodeFrame(&pic, &info);
    if (rv != cmResultSuccess) {
        fprintf(stderr, "SpriteEncoder: EncodeFrame failed frame %d (rv=%d)\n", frame_index, rv);
        return std::unexpected(Error::ENCODE_ERROR);
    }

    if (info.eFrameType == videoFrameTypeSkip) {
        fprintf(stderr, "SpriteEncoder: unexpected skip frame %d\n", frame_index);
        return std::unexpected(Error::ENCODE_ERROR);
    }

    // Collect all NAL data
    std::vector<uint8_t> frame_nals;
    for (int layer = 0; layer < info.iLayerNum; layer++) {
        SLayerBSInfo* layerInfo = &info.sLayerInfo[layer];
        uint8_t* buf = layerInfo->pBsBuf;
        for (int nal = 0; nal < layerInfo->iNalCount; nal++) {
            int nalLen = layerInfo->pNalLengthInByte[nal];
            frame_nals.insert(frame_nals.end(), buf, buf + nalLen);
            buf += nalLen;
        }
    }

    // Optionally return NAL data copy
    if (out_nal_data) {
        *out_nal_data = frame_nals;
    }

    // Parse full double-wide slice into macroblock data
    auto parse_result = find_and_parse_slice(
        impl_->parser, frame_nals.data(), frame_nals.size(), impl_->parse_params);
    if (!parse_result) {
        fprintf(stderr, "SpriteEncoder: parse failed frame %d\n", frame_index);
        return std::unexpected(parse_result.error());
    }

    auto& all_mbs = *parse_result;
    int hwm = impl_->half_width_mbs;
    int hhm = impl_->half_height_mbs;
    int cwm = impl_->canvas_width_mbs;

    // Split into color (left half) and alpha (right half)
    std::vector<MacroblockData> color(hwm * hhm);
    std::vector<MacroblockData> alpha_mbs(hwm * hhm);

    for (int mb_y = 0; mb_y < hhm; mb_y++) {
        for (int mb_x = 0; mb_x < hwm; mb_x++) {
            color[mb_y * hwm + mb_x] = all_mbs[mb_y * cwm + mb_x];
            alpha_mbs[mb_y * hwm + mb_x] = all_mbs[mb_y * cwm + hwm + mb_x];
        }
    }

    // For IDR frames, mark padding MBs as SKIP in both halves
    if (frame_index == 0) {
        int padding = 1;  // matches iPaddingMbs set in create
        for (int mb_y = 0; mb_y < hhm; mb_y++) {
            for (int mb_x = 0; mb_x < hwm; mb_x++) {
                if (mb_x < padding || mb_x >= hwm - padding ||
                    mb_y < padding || mb_y >= hhm - padding) {
                    MacroblockData& cmb = color[mb_y * hwm + mb_x];
                    cmb = MacroblockData{};
                    cmb.mb_type = MbType::SKIP;
                    MacroblockData& amb = alpha_mbs[mb_y * hwm + mb_x];
                    amb = MacroblockData{};
                    amb.mb_type = MbType::SKIP;
                }
            }
        }
    }

    return EncodeResult{std::move(color), std::move(alpha_mbs)};
}

} // namespace subcodec
