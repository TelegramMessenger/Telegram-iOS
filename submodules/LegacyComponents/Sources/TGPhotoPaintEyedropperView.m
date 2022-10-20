#import "TGPhotoPaintEyedropperView.h"

#import "TGImageUtils.h"

@interface TGPhotoPaintEyedropperIndicatorView : UIView

@property (nonatomic, strong) UIColor *color;

@end

@implementation TGPhotoPaintEyedropperIndicatorView

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = false;
        self.userInteractionEnabled = false;
    }
    return self;
}

- (void)setColor:(UIColor *)color {
    _color = color;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGFloat lineWidth = 1.0f + TGScreenPixel;
    
    CGContextSetFillColorWithColor(context, _color.CGColor);
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    
    CGContextSaveGState(context);
    
    CGContextScaleCTM(context, 0.333333, 0.333333);
    CGContextSetLineWidth(context, lineWidth * 3.0);
    
    TGDrawSvgPath(context, @"M75,0.5 C54.4273931,0.5 35.8023931,8.83869653 22.3205448,22.3205448 C8.83869653,35.8023931 0.5,54.4273931 0.5,75 C0.5,94.6543797 10.7671345,116.856807 23.8111444,136.192682 C42.4188317,163.77591 66.722394,185.676747 75,185.676747 C83.277606,185.676747 107.581168,163.77591 126.188856,136.192682 C139.232866,116.856807 149.5,94.6543797 149.5,75 C149.5,54.4273931 141.161303,35.8023931 127.679455,22.3205448 C114.197607,8.83869653 95.5726069,0.5 75,0.5 Z");
    
    TGDrawSvgPath(context, @"M75,0.5 C54.4273931,0.5 35.8023931,8.83869653 22.3205448,22.3205448 C8.83869653,35.8023931 0.5,54.4273931 0.5,75 C0.5,94.6543797 10.7671345,116.856807 23.8111444,136.192682 C42.4188317,163.77591 66.722394,185.676747 75,185.676747 C83.277606,185.676747 107.581168,163.77591 126.188856,136.192682 C139.232866,116.856807 149.5,94.6543797 149.5,75 C149.5,54.4273931 141.161303,35.8023931 127.679455,22.3205448 C114.197607,8.83869653 95.5726069,0.5 75,0.5 S");
    
    CGContextRestoreGState(context);
    
    CGContextSetLineWidth(context, lineWidth);
    CGContextFillEllipseInRect(context, CGRectMake(20.0, 68.0, 11.0, 11.0));
    CGContextStrokeEllipseInRect(context, CGRectMake(20.0, 68.0, 11.0, 11.0));
}

@end

@interface TGPhotoPaintEyedropperView() <UIGestureRecognizerDelegate>

@end

@implementation TGPhotoPaintEyedropperView
{
    TGPhotoPaintEyedropperIndicatorView *_indicatorView;
    
    UITapGestureRecognizer *_tapGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil) {
        _indicatorView = [[TGPhotoPaintEyedropperIndicatorView alloc] initWithFrame:CGRectMake(0.0, 0.0, 51.0, 81.0)];
        _indicatorView.layer.anchorPoint = CGPointMake(0.5, 0.92);
        [self addSubview:_indicatorView];
        
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [self addGestureRecognizer:_tapGestureRecognizer];
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGestureRecognizer.delegate = self;
        [self addGestureRecognizer:_panGestureRecognizer];
    }
    return self;
}

- (void)setColor:(UIColor *)color {
    _color = color;
    _indicatorView.color = color;
}

- (void)handleTap:(UITapGestureRecognizer *)gestureRecognizer {
    CGPoint location = [gestureRecognizer locationInView:self];
    [self layoutIndicator:location];
    self.locationChanged(location, true);
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer {
    CGPoint location = [gestureRecognizer locationInView:self];
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateChanged:
        {
            [self layoutIndicator:location];
            self.locationChanged(location, false);
           
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        {
            [self layoutIndicator:location];
            self.locationChanged(location, true);
        }
            break;
            
        default:
            break;
    }
}

- (void)update {
    CGPoint location = CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
    self.locationChanged(location, false);
    [self layoutIndicator:location];
}

- (void)present {
    self.hidden = false;
    
    _indicatorView.alpha = 0.0f;
    _indicatorView.transform = CGAffineTransformMakeScale(0.2, 0.2);
    [UIView animateWithDuration:0.2 animations:^
    {
        _indicatorView.alpha = 1.0f;
        _indicatorView.transform = CGAffineTransformIdentity;
    } completion:^(__unused BOOL finished)
    {
    }];
}

- (void)dismiss {
    if (self.hidden)
        return;
    
    [UIView animateWithDuration:0.15 animations:^
    {
        _indicatorView.alpha = 0.0f;
        _indicatorView.transform = CGAffineTransformMakeScale(0.2, 0.2);
    } completion:^(__unused BOOL finished)
    {
        self.hidden = true;
    }];
}

- (void)layoutIndicator:(CGPoint)point {
    _indicatorView.center = CGPointMake(point.x, point.y);
}

@end
