#import "NotificationCenterUtils.h"

#import <ObjCRuntimeUtils/RuntimeUtils.h>
#import <UIKit/UIKit.h>

static NSMutableArray *notificationHandlers() {
    static NSMutableArray *array = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        array = [[NSMutableArray alloc] init];
    });
    return array;
}

@interface NSNotificationCenter (_a65afc19)

@end

@implementation NSNotificationCenter (_a65afc19)

- (void)_a65afc19_postNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    if ([NSThread isMainThread]) {
        for (NotificationHandlerBlock handler in notificationHandlers())
        {
            if (handler(aName, anObject, aUserInfo, ^{
                [self _a65afc19_postNotificationName:aName object:anObject userInfo:aUserInfo];
            })) {
                return;
            }
        }
    }
    
    [self _a65afc19_postNotificationName:aName object:anObject userInfo:aUserInfo];
}

@end

@interface CATransaction (Swizzle)

+ (void)swizzle_flush;

@end

@implementation CATransaction (Swizzle)

+ (void)swizzle_flush {
    //printf("===flush\n");
    
    [self swizzle_flush];
}

@end

@implementation NotificationCenterUtils

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [RuntimeUtils swizzleInstanceMethodOfClass:[NSNotificationCenter class] currentSelector:@selector(postNotificationName:object:userInfo:) newSelector:@selector(_a65afc19_postNotificationName:object:userInfo:)];
        
        //[RuntimeUtils swizzleClassMethodOfClass:[CATransaction class] currentSelector:@selector(flush) newSelector:@selector(swizzle_flush)];
    });
}

+ (void)addNotificationHandler:(NotificationHandlerBlock)handler {
    [notificationHandlers() addObject:[handler copy]];
}

@end
