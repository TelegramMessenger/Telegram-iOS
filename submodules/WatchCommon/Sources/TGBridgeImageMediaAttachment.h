#import <CoreGraphics/CoreGraphics.h>

#if TARGET_OS_WATCH
#import <WatchCommonWatch/TGBridgeMediaAttachment.h>
#else
#import <WatchCommon/TGBridgeMediaAttachment.h>
#endif

@interface TGBridgeImageMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, assign) int64_t imageId;
@property (nonatomic, assign) CGSize dimensions;

@end
