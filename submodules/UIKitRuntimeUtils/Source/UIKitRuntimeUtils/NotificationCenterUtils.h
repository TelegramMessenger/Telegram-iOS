#import <Foundation/Foundation.h>

typedef bool (^NotificationHandlerBlock)(NSString *, id, NSDictionary *, void (^)());

@interface NotificationCenterUtils : NSObject

+ (void)addNotificationHandler:(NotificationHandlerBlock)handler;

@end
