#import "TGPaintPanGestureRecognizer.h"

#import <UIKit/UIGestureRecognizerSubclass.h>

@implementation TGPaintPanGestureRecognizer

- (void)touchesBegan:(NSSet *)inTouches withEvent:(UIEvent *)event
{
    _touches = [inTouches copy];
    [super touchesBegan:inTouches withEvent:event];
    
    if (inTouches.count == 1 && self.shouldRecognizeTap != nil && self.shouldRecognizeTap())
        self.state = UIGestureRecognizerStateBegan;
}

- (void)touchesMoved:(NSSet *)inTouches withEvent:(UIEvent *)event
{
    _touches = [inTouches copy];
    if (inTouches.count > 1) {
        self.state = UIGestureRecognizerStateCancelled;
    } else {
        [super touchesMoved:inTouches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)inTouches withEvent:(UIEvent *)event
{
    _touches = [inTouches copy];
    [super touchesEnded:inTouches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)inTouches withEvent:(UIEvent *)event
{
    _touches = [inTouches copy];
    [super touchesCancelled:inTouches withEvent:event];
}

@end
