#import <CoreGraphics/CoreGraphics.h>

#import <WatchCommon/TGBridgeMediaAttachment.h>

@interface TGBridgeImageMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, assign) int64_t imageId;
@property (nonatomic, assign) CGSize dimensions;

@end
