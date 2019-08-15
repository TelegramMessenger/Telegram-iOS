#import <Foundation/Foundation.h>

@interface TGBridgeAudioEncoder : NSObject

- (instancetype)initWithURL:(NSURL *)url;
- (void)startWithCompletion:(void (^)(NSString *, int32_t))completion;

@end
