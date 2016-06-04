#import <UIKit/UIKit.h>

@interface CALayer (ImplicitAnimations)

+ (void)beginRecordingChanges;
+ (NSArray *)endRecordingChanges;

+ (void)overrideAnimationSpeed:(CGFloat)speed block:(void (^)())block;

@end

@interface CALayerAnimation : NSObject

@property (nonatomic, weak, readonly) CALayer *layer;

@property (nonatomic, readonly) CGRect startBounds;
@property (nonatomic, readonly) CGRect endBounds;

@property (nonatomic, readonly) CGPoint startPosition;
@property (nonatomic, readonly) CGPoint endPosition;

@end
