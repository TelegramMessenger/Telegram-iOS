#import "TGNeoBackgroundViewModel.h"
#import <UIKit/UIKit.h>

@interface TGNeoBackgroundViewModel ()
{
    bool _outgoing;
}
@end

@implementation TGNeoBackgroundViewModel

- (instancetype)initWithOutgoing:(bool)outgoing
{
    self = [super init];
    if (self != nil)
    {
        _outgoing = outgoing;
    }
    return self;
}

- (void)drawInContext:(CGContextRef)context
{
    UIImage *backgroundImage = _outgoing ? [TGNeoBackgroundViewModel outgoingBubbleImage] : [TGNeoBackgroundViewModel incomingBubbleImage];
    [backgroundImage drawInRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) blendMode:kCGBlendModeCopy alpha:1.0f];
}

+ (UIImage *)incomingBubbleImage
{
    static dispatch_once_t onceToken;
    static UIImage *image;
    dispatch_once(&onceToken, ^
    {
        image = [[UIImage imageNamed:@"ChatBubbleIncoming"] resizableImageWithCapInsets:UIEdgeInsetsMake(13, 13, 16, 13) resizingMode:UIImageResizingModeStretch];
    });
    return image;
}

+ (UIImage *)outgoingBubbleImage
{
    static dispatch_once_t onceToken;
    static UIImage *image;
    dispatch_once(&onceToken, ^
    {
        image = [[UIImage imageNamed:@"ChatBubbleOutgoing"] resizableImageWithCapInsets:UIEdgeInsetsMake(13, 13, 16, 13) resizingMode:UIImageResizingModeStretch];
    });
    return image;
}

@end
