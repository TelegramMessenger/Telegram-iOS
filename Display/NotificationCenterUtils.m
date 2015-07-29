#import "NotificationCenterUtils.h"

#import "RuntimeUtils.h"

static NSMutableArray *notificationHandlers()
{
    static NSMutableArray *array = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        array = [[NSMutableArray alloc] init];
    });
    return array;
}

@interface NSNotificationCenter (_a65afc19)

@end

@implementation NSNotificationCenter (_a65afc19)

- (void)_a65afc19_postNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    for (NotificationHandlerBlock handler in notificationHandlers())
    {
        if (handler(aName, anObject, aUserInfo))
            return;
    }
    
    [self _a65afc19_postNotificationName:aName object:anObject userInfo:aUserInfo];
}

@end

@implementation NotificationCenterUtils

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [RuntimeUtils swizzleInstanceMethodOfClass:[NSNotificationCenter class] currentSelector:@selector(postNotificationName:object:userInfo:) newSelector:@selector(_a65afc19_postNotificationName:object:userInfo:)];
    });
}

+ (void)addNotificationHandler:(bool (^)(NSString *, id, NSDictionary *))handler
{
    [notificationHandlers() addObject:[handler copy]];
}

@end
