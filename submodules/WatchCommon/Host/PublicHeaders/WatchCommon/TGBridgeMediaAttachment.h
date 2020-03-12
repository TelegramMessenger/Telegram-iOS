#import <WatchCommon/TGBridgeCommon.h>

@interface TGBridgeMediaAttachment : NSObject <NSCoding>

@property (nonatomic, readonly) NSInteger mediaType;

+ (NSInteger)mediaType;

@end

extern NSString *const TGBridgeMediaAttachmentTypeKey;
