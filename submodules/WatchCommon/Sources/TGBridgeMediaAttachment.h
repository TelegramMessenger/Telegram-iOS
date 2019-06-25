#if TARGET_OS_WATCH
#import <WatchCommonWatch/TGBridgeCommon.h>
#else
#import <WatchCommon/TGBridgeCommon.h>
#endif

@interface TGBridgeMediaAttachment : NSObject <NSCoding>

@property (nonatomic, readonly) NSInteger mediaType;

+ (NSInteger)mediaType;

@end

extern NSString *const TGBridgeMediaAttachmentTypeKey;
