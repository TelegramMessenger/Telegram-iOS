#ifndef LottieAnimation_h
#define LottieAnimation_h

#import <Foundation/Foundation.h>

#import "LottieRenderTree.h"

#ifdef __cplusplus
extern "C" {
#endif

@interface LottieAnimation : NSObject

@property (nonatomic, readonly) NSInteger frameCount;
@property (nonatomic, readonly) NSInteger framesPerSecond;
@property (nonatomic, readonly) CGSize size;

- (instancetype _Nullable)initWithData:(NSData * _Nonnull)data;

- (NSData * _Nonnull)toJson;

@end

#ifdef __cplusplus
}
#endif

#endif /* LottieAnimation_h */
