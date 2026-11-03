// Sources/SubcodecObjC/SCVideoToolboxDecoder.mm
#import "SCVideoToolboxDecoder.h"
#include "AnnexBSplitter.h"

#import <VideoToolbox/VideoToolbox.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

#include <vector>

static NSString* const kErrorDomain = @"SCVideoToolboxDecoder";

static NSError* makeVTError(NSString* msg, OSStatus status) {
    return [NSError errorWithDomain:kErrorDomain code:status
                           userInfo:@{NSLocalizedDescriptionKey:
                               [NSString stringWithFormat:@"%@ (OSStatus %d)", msg, (int)status]}];
}

static NSError* makeError(NSString* msg) {
    return [NSError errorWithDomain:kErrorDomain code:-1
                           userInfo:@{NSLocalizedDescriptionKey: msg}];
}

// Returns the LAST occurrence of the target NAL type in the data.
// This is important because buildStream() prepends subcodec's SPS/PPS before
// OpenH264's SPS/PPS, and we need OpenH264's (the last ones) for VideoToolbox.
static const uint8_t* findNAL(const uint8_t* data, size_t size,
                               uint8_t targetType, size_t* nalSize) {
    const uint8_t* found = nullptr;
    size_t foundSize = 0;

    for (size_t i = 0; i + 3 < size; ) {
        int sc_len = 0;
        if (i + 3 < size && data[i]==0 && data[i+1]==0 && data[i+2]==0 && data[i+3]==1)
            sc_len = 4;
        else if (i + 2 < size && data[i]==0 && data[i+1]==0 && data[i+2]==1)
            sc_len = 3;

        if (sc_len > 0) {
            const uint8_t* nalStart = data + i + sc_len;
            uint8_t nal_type = nalStart[0] & 0x1F;

            size_t nalEnd = size;
            for (size_t j = i + sc_len + 1; j + 2 < size; j++) {
                if (data[j]==0 && data[j+1]==0 &&
                    (data[j+2]==1 || (j + 3 < size && data[j+2]==0 && data[j+3]==1))) {
                    nalEnd = j;
                    break;
                }
            }

            if (nal_type == targetType) {
                found = nalStart;
                foundSize = nalEnd - (i + sc_len);
            }

            i = nalEnd;
        } else {
            i++;
        }
    }

    if (found) {
        *nalSize = foundSize;
    }
    return found;
}

static std::vector<uint8_t> annexBToAVCC(const uint8_t* data, size_t size) {
    std::vector<uint8_t> avcc;
    avcc.reserve(size);

    for (size_t i = 0; i + 3 < size; ) {
        int sc_len = 0;
        if (i + 3 < size && data[i]==0 && data[i+1]==0 && data[i+2]==0 && data[i+3]==1)
            sc_len = 4;
        else if (i + 2 < size && data[i]==0 && data[i+1]==0 && data[i+2]==1)
            sc_len = 3;

        if (sc_len > 0) {
            size_t nalStart = i + sc_len;

            size_t nalEnd = size;
            for (size_t j = nalStart + 1; j + 2 < size; j++) {
                if (data[j]==0 && data[j+1]==0 &&
                    (data[j+2]==1 || (j + 3 < size && data[j+2]==0 && data[j+3]==1))) {
                    nalEnd = j;
                    break;
                }
            }

            uint8_t nal_type = data[nalStart] & 0x1F;
            if (nal_type != 7 && nal_type != 8) {
                uint32_t nalLen = (uint32_t)(nalEnd - nalStart);
                uint8_t lenBuf[4] = {
                    (uint8_t)(nalLen >> 24), (uint8_t)(nalLen >> 16),
                    (uint8_t)(nalLen >> 8),  (uint8_t)(nalLen)
                };
                avcc.insert(avcc.end(), lenBuf, lenBuf + 4);
                avcc.insert(avcc.end(), data + nalStart, data + nalEnd);
            }

            i = nalEnd;
        } else {
            i++;
        }
    }
    return avcc;
}

struct DecodeContext {
    NSMutableArray<SCDecodedFrame *>* frames;
};

static void decompressionCallback(void* decompressionOutputRefCon,
                                   void* sourceFrameRefCon,
                                   OSStatus status,
                                   VTDecodeInfoFlags infoFlags,
                                   CVImageBufferRef imageBuffer,
                                   CMTime presentationTimeStamp,
                                   CMTime presentationDuration) {
    if (status != noErr || !imageBuffer) return;

    DecodeContext* ctx = (DecodeContext*)decompressionOutputRefCon;

    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)imageBuffer;

    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    int w = (int)CVPixelBufferGetWidth(pixelBuffer);
    int h = (int)CVPixelBufferGetHeight(pixelBuffer);

    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);

    NSMutableData* yData = [NSMutableData dataWithLength:w * h];
    NSMutableData* cbData = [NSMutableData dataWithLength:(w / 2) * (h / 2)];
    NSMutableData* crData = [NSMutableData dataWithLength:(w / 2) * (h / 2)];

    uint8_t* yDst = (uint8_t*)yData.mutableBytes;
    uint8_t* cbDst = (uint8_t*)cbData.mutableBytes;
    uint8_t* crDst = (uint8_t*)crData.mutableBytes;

    if (pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
        pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        uint8_t* yPlane = (uint8_t*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        size_t yStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        uint8_t* uvPlane = (uint8_t*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        size_t uvStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

        for (int r = 0; r < h; r++)
            memcpy(yDst + r * w, yPlane + r * yStride, w);

        int cw = w / 2;
        int ch = h / 2;
        for (int r = 0; r < ch; r++) {
            const uint8_t* uvRow = uvPlane + r * uvStride;
            for (int c = 0; c < cw; c++) {
                cbDst[r * cw + c] = uvRow[c * 2];
                crDst[r * cw + c] = uvRow[c * 2 + 1];
            }
        }
    } else if (pixelFormat == kCVPixelFormatType_420YpCbCr8Planar) {
        for (int p = 0; p < 3; p++) {
            uint8_t* src = (uint8_t*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, p);
            size_t stride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, p);
            int pw = (p == 0) ? w : w / 2;
            int ph = (p == 0) ? h : h / 2;
            uint8_t* dst = (p == 0) ? yDst : (p == 1) ? cbDst : crDst;
            for (int r = 0; r < ph; r++)
                memcpy(dst + r * pw, src + r * stride, pw);
        }
    }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    SCDecodedFrame* frame = [[SCDecodedFrame alloc] initWithWidth:w height:h
                                                                y:yData cb:cbData cr:crData];
    [ctx->frames addObject:frame];
}

@implementation SCVideoToolboxDecoder

+ (nullable SCVideoToolboxDecoder *)createDecoderWithError:(NSError **)error {
    return [[SCVideoToolboxDecoder alloc] init];
}

- (nullable NSArray<SCDecodedFrame *> *)decodeStream:(NSData *)data
                                               error:(NSError **)error {
    const uint8_t* bytes = (const uint8_t*)data.bytes;
    size_t length = data.length;

    auto packets = split_annex_b_frames(bytes, length);
    if (packets.empty()) {
        if (error) *error = makeError(@"No frames found in stream");
        return nil;
    }

    size_t spsSize = 0, ppsSize = 0;
    const uint8_t* spsNAL = findNAL(packets[0].data, packets[0].size, 7, &spsSize);
    const uint8_t* ppsNAL = findNAL(packets[0].data, packets[0].size, 8, &ppsSize);

    if (!spsNAL || !ppsNAL) {
        if (error) *error = makeError(@"SPS or PPS not found in stream");
        return nil;
    }

    const uint8_t* paramSets[2] = { spsNAL, ppsNAL };
    size_t paramSizes[2] = { spsSize, ppsSize };

    CMVideoFormatDescriptionRef formatDesc = NULL;
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
        kCFAllocatorDefault, 2, paramSets, paramSizes, 4, &formatDesc);

    if (status != noErr) {
        if (error) *error = makeVTError(@"CMVideoFormatDescriptionCreateFromH264ParameterSets failed", status);
        return nil;
    }

    DecodeContext ctx;
    ctx.frames = [NSMutableArray array];

    VTDecompressionOutputCallbackRecord callbackRecord;
    callbackRecord.decompressionOutputCallback = decompressionCallback;
    callbackRecord.decompressionOutputRefCon = &ctx;

    NSDictionary* destAttrs = @{
        (NSString*)kCVPixelBufferPixelFormatTypeKey:
            @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
    };

    VTDecompressionSessionRef session = NULL;
    status = VTDecompressionSessionCreate(
        kCFAllocatorDefault, formatDesc, NULL,
        (__bridge CFDictionaryRef)destAttrs,
        &callbackRecord, &session);

    if (status != noErr) {
        CFRelease(formatDesc);
        if (error) *error = makeVTError(@"VTDecompressionSessionCreate failed", status);
        return nil;
    }

    NSError* decodeError = nil;

    for (auto& pkt : packets) {
        auto avcc = annexBToAVCC(pkt.data, pkt.size);
        if (avcc.empty()) continue;

        CMBlockBufferRef blockBuf = NULL;
        status = CMBlockBufferCreateWithMemoryBlock(
            kCFAllocatorDefault, NULL, avcc.size(), kCFAllocatorDefault,
            NULL, 0, avcc.size(), kCMBlockBufferAssureMemoryNowFlag, &blockBuf);

        if (status != noErr) {
            decodeError = makeVTError(@"CMBlockBufferCreateWithMemoryBlock failed", status);
            break;
        }

        status = CMBlockBufferReplaceDataBytes(avcc.data(), blockBuf, 0, avcc.size());
        if (status != noErr) {
            CFRelease(blockBuf);
            decodeError = makeVTError(@"CMBlockBufferReplaceDataBytes failed", status);
            break;
        }

        CMSampleBufferRef sampleBuf = NULL;
        size_t sampleSize = avcc.size();
        status = CMSampleBufferCreate(
            kCFAllocatorDefault, blockBuf, true, NULL, NULL,
            formatDesc, 1, 0, NULL, 1, &sampleSize, &sampleBuf);

        CFRelease(blockBuf);

        if (status != noErr) {
            decodeError = makeVTError(@"CMSampleBufferCreate failed", status);
            break;
        }

        VTDecodeInfoFlags flagsOut = 0;
        status = VTDecompressionSessionDecodeFrame(
            session, sampleBuf,
            kVTDecodeFrame_1xRealTimePlayback,
            NULL, &flagsOut);
        CFRelease(sampleBuf);

        if (status != noErr) {
            decodeError = makeVTError(@"VTDecompressionSessionDecodeFrame failed", status);
            break;
        }
    }

    VTDecompressionSessionWaitForAsynchronousFrames(session);

    VTDecompressionSessionInvalidate(session);
    CFRelease(session);
    CFRelease(formatDesc);

    if (decodeError) {
        if (error) *error = decodeError;
        return nil;
    }

    return ctx.frames;
}

@end
