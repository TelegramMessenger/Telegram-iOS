#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OggOpusReader : NSObject

- (instancetype _Nullable)initWithPath:(NSString *)path;

- (int32_t)read:(void *)pcmData bufSize:(int)bufSize;

@end

NS_ASSUME_NONNULL_END
