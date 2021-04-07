#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OggOpusFrame : NSObject

@property (nonatomic, readonly) int numSamples;
@property (nonatomic, strong, readonly) NSData *data;

@end

@interface OggOpusReader : NSObject

- (instancetype _Nullable)initWithPath:(NSString *)path;

- (int32_t)read:(void *)pcmData bufSize:(int)bufSize;

+ (NSArray<OggOpusFrame *> * _Nullable)extractFrames:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
