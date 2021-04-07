#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <BuildConfig/BuildConfig.h>

NS_ASSUME_NONNULL_BEGIN

@interface NotificationServiceImpl : NSObject

- (instancetype)initWithSerialDispatch:(void (^)(dispatch_block_t))serialDispatch countIncomingMessage:(void (^)(NSString *, int64_t, DeviceSpecificEncryptionParameters *, int64_t, int32_t))countIncomingMessage isLocked:(bool (^)(NSString *))isLocked lockedMessageText:(NSString *(^)(NSString *))lockedMessageText;

- (void)updateUnreadCount:(int32_t)unreadCount;
- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler;
- (void)serviceExtensionTimeWillExpire;

@end

NS_ASSUME_NONNULL_END
