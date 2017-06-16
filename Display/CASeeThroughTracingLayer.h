#import <UIKit/UIKit.h>

@interface CASeeThroughTracingLayer : CALayer

@property (nonatomic, copy) void (^updateRelativePosition)(CGPoint);

@end

@interface CASeeThroughTracingView : UIView

@end
