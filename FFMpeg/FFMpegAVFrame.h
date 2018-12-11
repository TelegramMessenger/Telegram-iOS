#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFMpegAVFrame : NSObject

@property (nonatomic, readonly) int32_t width;
@property (nonatomic, readonly) int32_t height;
@property (nonatomic, readonly) uint8_t **data;
@property (nonatomic, readonly) int *lineSize;
@property (nonatomic, readonly) int64_t pts;

- (instancetype)init;

- (void *)impl;

@end

NS_ASSUME_NONNULL_END
