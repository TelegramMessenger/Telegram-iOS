#if TARGET_OS_WATCH
#import <WatchCommonWatch/TGBridgeMediaAttachment.h>
#else
#import <WatchCommon/TGBridgeMediaAttachment.h>
#endif

@interface TGBridgeContactMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, assign) int32_t uid;
@property (nonatomic, strong) NSString *firstName;
@property (nonatomic, strong) NSString *lastName;
@property (nonatomic, strong) NSString *phoneNumber;
@property (nonatomic, strong) NSString *prettyPhoneNumber;

- (NSString *)displayName;

@end
