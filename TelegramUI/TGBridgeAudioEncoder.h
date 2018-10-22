#import <Foundation/Foundation.h>

@class TGDataItem;
@class TGLiveUploadActorData;

@interface TGBridgeAudioEncoder : NSObject

- (instancetype)initWithURL:(NSURL *)url;
- (void)startWithCompletion:(void (^)(NSString *, int32_t))completion;

@end
