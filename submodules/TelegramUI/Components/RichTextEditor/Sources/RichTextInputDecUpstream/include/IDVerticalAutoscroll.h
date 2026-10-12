#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, IDVerticalAutoscrollDirection) {
    IDVerticalAutoscrollDirectionUp = 1UL << 2,
    IDVerticalAutoscrollDirectionDown = 1UL << 3,
};

@class IDVerticalAutoscroll;

@protocol IDVerticalAutoscrollTarget <NSObject>
- (void)updateVerticalAutoscroll:
    (IDVerticalAutoscroll *)autoscroll;
@end

@protocol IDVerticalAutoscrollContainerPolicy <NSObject>
@optional
- (BOOL)id_shouldAutoscroll;
@end

@interface IDVerticalAutoscroll : NSObject

@property(nonatomic, weak, readonly, nullable)
    id<IDVerticalAutoscrollTarget> target;
@property(nonatomic, strong, readonly, nullable)
    UIScrollView *id_scrollContainer;
@property(nonatomic, readonly) CGPoint point;
@property(nonatomic, readonly)
    IDVerticalAutoscrollDirection directions;
@property(nonatomic, readonly) NSTimeInterval repeatInterval;
@property(nonatomic, readonly) NSUInteger count;
@property(nonatomic, getter=isActive, readonly) BOOL active;
@property(nonatomic, getter=isDisabled) BOOL disabled;

- (BOOL)startWithTarget:
    (nullable id<IDVerticalAutoscrollTarget>)target
        scrollContainer:(nullable UIScrollView *)scrollContainer
                  point:(CGPoint)point
             directions:
    (IDVerticalAutoscrollDirection)directions
         repeatInterval:(NSTimeInterval)repeatInterval;
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END

#endif
