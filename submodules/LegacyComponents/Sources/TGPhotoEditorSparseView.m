#import "TGPhotoEditorSparseView.h"

@implementation TGPhotoEditorSparseView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    if (view == self)
        return nil;
    
    return view;
}

@end
