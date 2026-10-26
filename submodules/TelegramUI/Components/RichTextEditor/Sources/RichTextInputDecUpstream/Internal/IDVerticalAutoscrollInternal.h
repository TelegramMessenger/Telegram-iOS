#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDVerticalAutoscroll.h"

NS_ASSUME_NONNULL_BEGIN

@protocol IDVerticalAutoscrollTimer <NSObject>
- (void)setFireDate:(NSDate *)date;
- (void)invalidate;
@end

typedef id<IDVerticalAutoscrollTimer> _Nonnull
    (^IDVerticalAutoscrollTimerFactory)(
        NSDate *fireDate,
        NSTimeInterval interval,
        dispatch_block_t callback);

@interface IDVerticalAutoscroll (Internal)
- (instancetype)initWithTimerFactory:
    (IDVerticalAutoscrollTimerFactory)timerFactory;
@end

NS_ASSUME_NONNULL_END

#endif
