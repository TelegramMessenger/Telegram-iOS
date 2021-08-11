#import "TGCameraFlashControl.h"

#import "LegacyComponentsInternal.h"

#import "TGImageUtils.h"

#import "UIControl+HitTestEdgeInsets.h"

#import "TGCameraInterfaceAssets.h"
#import <LegacyComponents/TGModernButton.h>

#import "POPBasicAnimation.h"

const CGFloat TGCameraFlashControlHeight = 44.0f;

@interface TGCameraFlashIcon: UIView
{
    bool _active;
    CGFloat _progress;
    bool _on;
}
@end

@implementation TGCameraFlashIcon

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.contentMode = UIViewContentModeRedraw;
        self.opaque = false;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setOn:(bool)on animated:(bool)animated {
    _on = on;
    if (animated) {
        POPBasicAnimation *animation = [POPBasicAnimation animation];
        animation.property = [POPAnimatableProperty propertyWithName:@"progress" initializer:^(POPMutableAnimatableProperty *prop)
        {
            prop.readBlock = ^(TGCameraFlashIcon *view, CGFloat values[])
            {
                if (view != nil) {
                    values[0] = view->_progress;
                }
            };
            
            prop.writeBlock = ^(TGCameraFlashIcon *view, const CGFloat values[])
            {
                view->_progress = values[0];
                [view setNeedsDisplay];
            };
            
            prop.threshold = 0.03f;
        }];
        animation.fromValue = @(_progress);
        animation.toValue = @(on ? 1.0 : 0.0);
        animation.duration = 0.2;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [self pop_addAnimation:animation forKey:@"progress"];
    } else {
        _progress = on ? 1.0 : 0.0;
        [self setNeedsDisplay];
    }
}

- (void)setActive:(bool)active {
    _active = active;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)__unused rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect bounds = CGRectMake(0, 0, rect.size.width, rect.size.height);
    
    CGContextClearRect(context, bounds);
    
    UIImage *iconImage = [UIImage imageNamed:@"Camera/Flash"];
    
    if (_active && _on) {
        CGContextSetFillColorWithColor(context, [TGCameraInterfaceAssets accentColor].CGColor);
        CGContextFillEllipseInRect(context, CGRectInset(bounds, 2.5, 2.5));
        
        [TGTintedImage(iconImage, [UIColor blackColor]) drawInRect:CGRectMake(0, 0, 30, 30)];
    } else {
        CGContextSetLineWidth(context, 1.0);
        CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:1.0 alpha:0.5].CGColor);
        CGContextStrokeEllipseInRect(context, CGRectInset(bounds, 3.0, 3.0));
        
        [TGTintedImage(iconImage, [UIColor whiteColor]) drawInRect:CGRectMake(0, 0, 30, 30)];
    }
    
    CGFloat lineProgress = 1.0 - _progress;
    
    if (lineProgress > 0.0) {
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathMoveToPoint(path, NULL, 5, 5);
        CGPathAddLineToPoint(path, NULL, 5 + (bounds.size.width - 10.0) * lineProgress, 5 + (bounds.size.height - 10.0) * lineProgress);
        
        CGPathRef strokedPath = CGPathCreateCopyByStrokingPath(path, NULL, 2.0f, kCGLineCapRound, kCGLineJoinMiter, 10);
        CGContextAddPath(context, strokedPath);
        CGPathRelease(strokedPath);
        CGPathRelease(path);
        
        CGContextSetBlendMode(context, kCGBlendModeCopy);
        CGContextSetStrokeColorWithColor(context, [UIColor clearColor].CGColor);
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextDrawPath(context, kCGPathFillStroke);
    }
}

@end

@interface TGCameraFlashControl ()
{
    TGCameraFlashIcon *_icon;
    UIButton *_button;
}
@end

@implementation TGCameraFlashControl

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.mode = PGCameraFlashModeOff;
        
        self.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -10, -10, -10);
        
        _icon = [[TGCameraFlashIcon alloc] initWithFrame:CGRectMake(7, 7, 30, 30)];
        _icon.userInteractionEnabled = false;
        [self addSubview:_icon];
        
        _button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
        _button.adjustsImageWhenHighlighted = false;
        _button.contentMode = UIViewContentModeCenter;
        _button.exclusiveTouch = true;
        _button.hitTestEdgeInsets = UIEdgeInsetsMake(0, -10, 0, -10);
        _button.tag = -1;
        [_button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_button];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    
    if ([view isKindOfClass:[UIButton class]])
        return view;
    
    return nil;
}

- (void)buttonPressed:(UIButton *)sender
{
    if (_mode == PGCameraFlashModeOff) {
        self.mode = PGCameraFlashModeAuto;
        [_icon setOn:true animated:true];
    } else {
        self.mode = PGCameraFlashModeOff;
        [_icon setOn:false animated:true];
    }

    if (self.modeChanged != nil)
        self.modeChanged(self.mode);
}

- (void)setFlashUnavailable:(bool)unavailable
{
    self.userInteractionEnabled = !unavailable;
    self.alpha = unavailable ? 0.4 : 1.0;
}

- (void)setFlashActive:(bool)active
{
    [_icon setActive:active];
}

- (void)setMode:(PGCameraFlashMode)mode
{
    _mode = mode;
    [_icon setOn:mode == PGCameraFlashModeAuto animated:true];
}

- (void)setHidden:(BOOL)hidden
{
    self.alpha = hidden ? 0.0f : 1.0f;
    super.hidden = hidden;
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        super.hidden = false;
        self.userInteractionEnabled = false;
        
        [UIView animateWithDuration:0.25f
                         animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            self.userInteractionEnabled = true;
             
            if (finished)
                self.hidden = hidden;
        }];
    }
    else
    {
        self.alpha = hidden ? 0.0f : 1.0f;
        super.hidden = hidden;
    }
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    _interfaceOrientation = interfaceOrientation;
}

@end
