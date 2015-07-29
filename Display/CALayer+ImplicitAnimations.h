#import <UIKit/UIKit.h>

@interface CALayer (ImplicitAnimations)

+ (void)beginRecordingChanges;
+ (NSArray *)endRecordingChanges;

@end

@interface CALayerAnimation : NSObject

@property (nonatomic, weak, readonly) CALayer *layer;

@property (nonatomic, readonly) CGRect startBounds;
@property (nonatomic, readonly) CGRect endBounds;

@property (nonatomic, readonly) CGPoint startPosition;
@property (nonatomic, readonly) CGPoint endPosition;

@end
