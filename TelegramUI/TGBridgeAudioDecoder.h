#import <Foundation/Foundation.h>

@interface TGBridgeAudioDecoder : NSObject

- (instancetype)initWithURL:(NSURL *)url outputUrl:(NSURL *)outputURL;
- (void)startWithCompletion:(void (^)(void))completion;

@end
