#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, FFMpegMP4StreamWriterVideoCodec) {
    FFMpegMP4StreamWriterVideoCodecH264 = 0,
    FFMpegMP4StreamWriterVideoCodecHEVC = 1
};

@interface FFMpegMP4StreamWriter : NSObject

@property (nonatomic, readonly) int64_t headerEnd;
@property (nonatomic, readonly) bool wroteMoovAtEnd;
@property (nonatomic, readonly, nullable) NSString *lastError;
@property (nonatomic, copy, nullable) void (^writeObserver)(int64_t fileSize, bool finalizing);

- (instancetype _Nullable)initWithPath:(NSString *)path reservedMoovSize:(int64_t)reservedMoovSize;

- (int)addVideoStreamWithCodec:(FFMpegMP4StreamWriterVideoCodec)codec width:(int32_t)width height:(int32_t)height extradata:(NSData *)extradata timescale:(int32_t)timescale;
- (int)addAudioStreamWithSampleRate:(int32_t)sampleRate channels:(int32_t)channels bitrate:(int32_t)bitrate initialPadding:(int32_t)initialPadding extradata:(NSData *)extradata;
- (bool)writeHeader;
- (bool)writePacketWithStreamIndex:(int)streamIndex data:(NSData *)data pts:(int64_t)pts dts:(int64_t)dts duration:(int64_t)duration isKeyframe:(bool)isKeyframe;
- (bool)finish;

@end

NS_ASSUME_NONNULL_END
