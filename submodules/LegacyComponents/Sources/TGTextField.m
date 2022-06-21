#import "TGTextField.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

@implementation TGTextField

- (void)drawPlaceholderInRect:(CGRect)rect
{
    if (_placeholderColor == nil || _placeholderFont == nil)
        [super drawPlaceholderInRect:rect];
    else
    {
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), _placeholderColor.CGColor);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CGSize placeholderSize = [self.placeholder sizeWithFont:_placeholderFont];
#pragma clang diagnostic pop
        
        CGPoint placeholderOrigin = CGPointMake(0.0f, CGFloor((rect.size.height - placeholderSize.height) / 2.0f) - TGRetinaPixel);
        if (self.textAlignment == NSTextAlignmentCenter)
            placeholderOrigin.x = CGFloor((rect.size.width - placeholderSize.width) / 2.0f);
        else if (self.textAlignment == NSTextAlignmentRight)
            placeholderOrigin.x = rect.size.width - placeholderSize.width;
        
        placeholderOrigin.y += TGScreenPixel + _placeholderOffset;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.placeholder drawAtPoint:placeholderOrigin withFont:_placeholderFont];
#pragma clang diagnostic pop
    }
}

- (CGRect)textRectForBounds:(CGRect)bounds
{
    CGRect rect = [super textRectForBounds:bounds];
    rect.origin.x += _leftInset;
    rect.size.width -= _leftInset + _rightInset;
    rect.origin.y = CGFloor((self.bounds.size.height - rect.size.height) / 2.0f);
    return rect;
}

- (CGRect)editingRectForBounds:(CGRect)bounds
{
    return CGRectOffset([self textRectForBounds:bounds], 0.0f, TGScreenPixel + _editingRectOffset);
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds
{
    return [self textRectForBounds:bounds];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    
    if (self.window != nil && _movedToWindow)
        _movedToWindow();
}

- (BOOL)becomeFirstResponder
{
    return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
    return [super resignFirstResponder];
}

- (void)deleteBackward {
    bool notify = self.text.length == 0;
    [super deleteBackward];
    
    if (self.clearAllOnNextBackspace)
    {
        self.text = @"";
        self.clearAllOnNextBackspace = false;
    }
    
    if (notify) {
        if (_deleteBackwardEmpty) {
            _deleteBackwardEmpty();
        }
    }
}

@end
