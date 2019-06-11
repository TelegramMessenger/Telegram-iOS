#import "TGFullscreenContainerView.h"

#import <LegacyComponents/LegacyComponents.h>

@implementation TGFullscreenContainerView

- (void)setFrame:(CGRect)frame
{
    CGSize screenSize = TGScreenSize();
    
    frame.origin = CGPointZero;
    
    if (ABS(frame.size.width - screenSize.width) < FLT_EPSILON)
        frame.size.height = screenSize.height;
    else if (ABS(frame.size.width - screenSize.height) < FLT_EPSILON)
        frame.size.height = screenSize.width;
    
    [super setFrame:frame];
}

- (void)setCenter:(CGPoint)center
{
    CGSize screenSize = TGScreenSize();
    
    if (ABS(center.x - screenSize.width / 2.0f) < FLT_EPSILON)
        center.y = screenSize.height / 2.0f;
    else if (ABS(center.x - screenSize.height / 2.0f) < FLT_EPSILON)
        center.y = screenSize.width / 2.0f;
    
    [super setCenter:center];
}

- (void)setBounds:(CGRect)bounds
{
    CGSize screenSize = TGScreenSize();
    
    if (ABS(bounds.size.width - screenSize.width) < FLT_EPSILON)
        bounds.size.height = screenSize.height;
    else if (ABS(bounds.size.width - screenSize.height) < FLT_EPSILON)
        bounds.size.height = screenSize.width;
    
    [super setBounds:bounds];
}

@end
