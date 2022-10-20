#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FFMpegAVCodecContext;

@interface FFMpegPacket : NSObject

@property (nonatomic, readonly) int64_t pts;
@property (nonatomic, readonly) int64_t dts;
@property (nonatomic, readonly) int64_t duration;
@property (nonatomic, readonly) int32_t streamIndex;
@property (nonatomic, readonly) int32_t size;
@property (nonatomic, readonly) uint8_t *data;

- (void *)impl;
- (int32_t)sendToDecoder:(FFMpegAVCodecContext *)codecContext;

@end

NS_ASSUME_NONNULL_END
