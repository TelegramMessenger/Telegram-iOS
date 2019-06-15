#if TARGET_OS_WATCH
#import <WatchCommonWatch/TGBridgeMediaAttachment.h>
#else
#import <WatchCommon/TGBridgeMediaAttachment.h>
#endif

@interface TGBridgeUnsupportedMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, strong) NSString *compactTitle;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;

@end
