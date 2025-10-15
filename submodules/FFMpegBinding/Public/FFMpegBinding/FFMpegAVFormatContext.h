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

typedef struct FFMpegAVIndexEntry {
    int64_t pos;
    int64_t timestamp;
    bool isKeyframe;
    int32_t size;
} FFMpegAVIndexEntry;

extern int FFMpegCodecIdH264;
extern int FFMpegCodecIdHEVC;
extern int FFMpegCodecIdMPEG4;
extern int FFMpegCodecIdVP9;
extern int FFMpegCodecIdVP8;
extern int FFMpegCodecIdAV1;

@class FFMpegAVCodecContext;

@interface FFMpegAVFormatContext : NSObject

- (instancetype)init;

- (void)setIOContext:(FFMpegAVIOContext *)ioContext;
- (bool)openInputWithDirectFilePath:(NSString * _Nullable)directFilePath;
- (bool)findStreamInfo;
- (void)seekFrameForStreamIndex:(int32_t)streamIndex pts:(int64_t)pts positionOnKeyframe:(bool)positionOnKeyframe;
- (void)seekFrameForStreamIndex:(int32_t)streamIndex byteOffset:(int64_t)byteOffset;
- (bool)readFrameIntoPacket:(FFMpegPacket *)packet;
- (NSArray<NSNumber *> *)streamIndicesForType:(FFMpegAVFormatStreamType)type;
- (bool)isAttachedPicAtStreamIndex:(int32_t)streamIndex;
- (int)codecIdAtStreamIndex:(int32_t)streamIndex;
- (double)duration;
- (int64_t)startTimeAtStreamIndex:(int32_t)streamIndex;
- (int64_t)durationAtStreamIndex:(int32_t)streamIndex;
- (int)numberOfIndexEntriesAtStreamIndex:(int32_t)streamIndex;
- (bool)fillIndexEntryAtStreamIndex:(int32_t)streamIndex entryIndex:(int32_t)entryIndex outEntry:(FFMpegAVIndexEntry * _Nonnull)outEntry;
- (bool)codecParamsAtStreamIndex:(int32_t)streamIndex toContext:(FFMpegAVCodecContext *)context;
- (FFMpegFpsAndTimebase)fpsAndTimebaseForStreamIndex:(int32_t)streamIndex defaultTimeBase:(CMTime)defaultTimeBase;
- (FFMpegStreamMetrics)metricsForStreamAtIndex:(int32_t)streamIndex;

- (void)forceVideoCodecId:(int)videoCodecId;

@end

NS_ASSUME_NONNULL_END
