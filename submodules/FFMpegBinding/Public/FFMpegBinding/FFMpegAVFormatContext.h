#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@class FFMpegAVIOContext;
@class FFMpegPacket;

typedef enum FFMpegAVFormatStreamType {
    FFMpegAVFormatStreamTypeVideo,
    FFMpegAVFormatStreamTypeAudio
} FFMpegAVFormatStreamType;

typedef struct FFMpegFpsAndTimebase {
    CMTime fps;
    CMTime timebase;
} FFMpegFpsAndTimebase;

typedef struct FFMpegStreamMetrics {
    int32_t width;
    int32_t height;
    double rotationAngle;
    uint8_t *extradata;
    int32_t extradataSize;
} FFMpegStreamMetrics;

extern int FFMpegCodecIdH264;
extern int FFMpegCodecIdHEVC;
extern int FFMpegCodecIdMPEG4;
extern int FFMpegCodecIdVP9;

@class FFMpegAVCodecContext;

@interface FFMpegAVFormatContext : NSObject

- (instancetype)init;

- (void)setIOContext:(FFMpegAVIOContext *)ioContext;
- (bool)openInput;
- (bool)findStreamInfo;
- (void)seekFrameForStreamIndex:(int32_t)streamIndex pts:(int64_t)pts positionOnKeyframe:(bool)positionOnKeyframe;
- (bool)readFrameIntoPacket:(FFMpegPacket *)packet;
- (NSArray<NSNumber *> *)streamIndicesForType:(FFMpegAVFormatStreamType)type;
- (bool)isAttachedPicAtStreamIndex:(int32_t)streamIndex;
- (int)codecIdAtStreamIndex:(int32_t)streamIndex;
- (int64_t)durationAtStreamIndex:(int32_t)streamIndex;
- (bool)codecParamsAtStreamIndex:(int32_t)streamIndex toContext:(FFMpegAVCodecContext *)context;
- (FFMpegFpsAndTimebase)fpsAndTimebaseForStreamIndex:(int32_t)streamIndex defaultTimeBase:(CMTime)defaultTimeBase;
- (FFMpegStreamMetrics)metricsForStreamAtIndex:(int32_t)streamIndex;

- (void)forceVideoCodecId:(int)videoCodecId;

@end

NS_ASSUME_NONNULL_END
