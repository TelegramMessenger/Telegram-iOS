#import <Foundation/Foundation.h>

@class TGDataItem;
@class TGLiveUploadActorData;

@interface TGBridgeAudioEncoder : NSObject

- (instancetype)initWithURL:(NSURL *)url;
- (void)startWithCompletion:(void (^)(TGDataItem *, int32_t))completion;

@end
