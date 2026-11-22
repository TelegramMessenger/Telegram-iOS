// Sources/SubcodecObjC/SCOpenH264Decoder.mm
#import "SCOpenH264Decoder.h"

#include "codec_api.h"
#include "codec_app_def.h"
#include "codec_def.h"

#include "AnnexBSplitter.h"

#include <cstring>
#include <vector>

static NSError* makeError(NSString* msg) {
    return [NSError errorWithDomain:@"SCOpenH264Decoder" code:-1
                           userInfo:@{NSLocalizedDescriptionKey: msg}];
}

@implementation SCOpenH264Decoder {
    ISVCDecoder* _decoder;
}

+ (nullable SCOpenH264Decoder *)createDecoderWithError:(NSError **)error {
    SCOpenH264Decoder* obj = [[SCOpenH264Decoder alloc] initInternal];
    if (!obj) {
        if (error) *error = makeError(@"Failed to create decoder");
    }
    return obj;
}

- (nullable instancetype)initInternal {
    self = [super init];
    if (!self) return nil;

    if (WelsCreateDecoder(&_decoder) != 0 || !_decoder) return nil;

    SDecodingParam decParam;
    memset(&decParam, 0, sizeof(decParam));
    decParam.sVideoProperty.eVideoBsType = VIDEO_BITSTREAM_AVC;
    if (_decoder->Initialize(&decParam) != 0) {
        WelsDestroyDecoder(_decoder);
        _decoder = nullptr;
        return nil;
    }

    return self;
}

- (void)dealloc {
    if (_decoder) {
        WelsDestroyDecoder(_decoder);
    }
}

- (nullable NSArray<SCDecodedFrame *> *)decodeStream:(NSData *)data
                                               error:(NSError **)error {
    auto packets = split_annex_b_frames((const uint8_t*)data.bytes, data.length);

    NSMutableArray<SCDecodedFrame *>* frames = [NSMutableArray array];

    for (auto& pkt : packets) {
        unsigned char* pDst[3] = {nullptr};
        SBufferInfo dstInfo;
        memset(&dstInfo, 0, sizeof(dstInfo));

        _decoder->DecodeFrameNoDelay(const_cast<unsigned char*>(pkt.data),
                                    (int)pkt.size, pDst, &dstInfo);

        if (dstInfo.iBufferStatus == 1) {
            int w = dstInfo.UsrData.sSystemBuffer.iWidth;
            int h = dstInfo.UsrData.sSystemBuffer.iHeight;
            int stride_y = dstInfo.UsrData.sSystemBuffer.iStride[0];
            int stride_uv = dstInfo.UsrData.sSystemBuffer.iStride[1];

            NSMutableData* yData = [NSMutableData dataWithLength:w * h];
            NSMutableData* cbData = [NSMutableData dataWithLength:(w / 2) * (h / 2)];
            NSMutableData* crData = [NSMutableData dataWithLength:(w / 2) * (h / 2)];

            uint8_t* yDst = (uint8_t*)yData.mutableBytes;
            uint8_t* cbDst = (uint8_t*)cbData.mutableBytes;
            uint8_t* crDst = (uint8_t*)crData.mutableBytes;

            for (int r = 0; r < h; r++)
                memcpy(yDst + r * w, pDst[0] + r * stride_y, w);
            for (int r = 0; r < h / 2; r++) {
                memcpy(cbDst + r * (w / 2), pDst[1] + r * stride_uv, w / 2);
                memcpy(crDst + r * (w / 2), pDst[2] + r * stride_uv, w / 2);
            }

            SCDecodedFrame* frame = [[SCDecodedFrame alloc] initWithWidth:w height:h
                                                                        y:yData cb:cbData cr:crData];
            [frames addObject:frame];
        }
    }

    return frames;
}

@end
