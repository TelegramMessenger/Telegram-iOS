#import "TGMenuSheetDimView.h"
#import "TGMenuSheetView.h"

#import "LegacyComponentsInternal.h"

@interface TGMenuSheetCutoutView : UIImageView

@end

@implementation TGMenuSheetCutoutView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        static dispatch_once_t onceToken;
        static UIImage *image;
        dispatch_once(&onceToken, ^
        {
            CGRect rect = CGRectMake(0, 0, TGMenuSheetCornerRadius * 2, TGMenuSheetCornerRadius * 2);
            
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGContextSetFillColorWithColor(context, [TGMenuSheetDimView backgroundColor].CGColor);
            CGContextFillRect(context, rect);
            
            CGContextSetBlendMode(context, kCGBlendModeClear);
            
            CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
            CGContextFillEllipseInRect(context, rect);
            
            image = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(TGMenuSheetCornerRadius, TGMenuSheetCornerRadius, TGMenuSheetCornerRadius, TGMenuSheetCornerRadius)];
            
            UIGraphicsEndImageContext();
        });
        
        self.image = image;
    }
    return self;
}

@end


@interface TGMenuSheetDimView ()
{
    UIView *_topView;
    UIView *_leftView;
    UIView *_rightView;
    UIView *_bottomView;
    UIView *_firstDividerView;
    UIView *_secondDividerView;
    
    UIView *_firstCutoutView;
    UIView *_secondCutoutView;
    UIView *_thirdCutoutView;
}

@property (nonatomic, weak) TGMenuSheetView *menuView;

@end

@implementation TGMenuSheetDimView

- (instancetype)initWithActionMenuView:(TGMenuSheetView *)menuView
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.menuView = menuView;
        
        void (^setupView)(UIView *) = ^(UIView *view)
        {
            view.userInteractionEnabled = false;
            view.backgroundColor = [TGMenuSheetDimView backgroundColor];
        };
        
        if (TGMenuSheetUseEffectView)
        {
            _topView = [[UIView alloc] initWithFrame:CGRectZero];
            [self addSubview:_topView];
            
            _leftView = [[UIView alloc] initWithFrame:CGRectZero];
            [self addSubview:_leftView];
            
            _rightView = [[UIView alloc] initWithFrame:CGRectZero];
            [self addSubview:_rightView];
            
            _bottomView = [[UIView alloc] initWithFrame:CGRectZero];
            [self addSubview:_bottomView];
            
            for (UIView *view in self.subviews)
                setupView(view);
            
            _firstDividerView = [[UIView alloc] initWithFrame:CGRectZero];
            setupView(_firstDividerView);
            
            _secondDividerView = [[UIView alloc] initWithFrame:CGRectZero];
            setupView(_secondDividerView);
            
            _firstCutoutView = [[TGMenuSheetCutoutView alloc] initWithFrame:CGRectZero];
            _secondCutoutView = [[TGMenuSheetCutoutView alloc] initWithFrame:CGRectZero];
            _thirdCutoutView = [[TGMenuSheetCutoutView alloc] initWithFrame:CGRectZero];
        }
        else
        {
            _topView = [[UIView alloc] initWithFrame:CGRectZero];
            [self addSubview:_topView];
            setupView(_topView);
        }
        
        if (@available(iOS 11.0, *)) {
            self.accessibilityIgnoresInvertColors = true;
        }
    }
    return self;
}

- (void)setTheaterMode:(bool)theaterMode animated:(bool)animated
{
    void (^changeBlock)(void) = ^
    {
        _topView.backgroundColor = theaterMode ? [TGMenuSheetDimView theaterBackgroundColor] : [TGMenuSheetDimView backgroundColor];
    };
    
    if (animated)
        [UIView animateWithDuration:0.5 animations:changeBlock];
    else
        changeBlock();
}

- (void)layoutSubviews
{
    if (!TGMenuSheetUseEffectView)
    {
        _topView.frame = CGRectMake(-self.frame.size.width, -self.frame.size.height, self.frame.size.width * 3, self.frame.size.height * 3);
        return;
    }

    TGMenuSheetView *menuView = self.menuView;
    if (menuView == nil)
        return;

    NSMutableArray *rects = [[NSMutableArray alloc] init];
    __block NSValue *unionRect = nil;
    UIEdgeInsets edgeInsets = menuView.edgeInsets;
    CGFloat spacing = menuView.interSectionSpacing;
    
    void (^addRect)(NSValue *) = ^(NSValue *rectValue)
    {
        if (rectValue == nil)
            return;
        
        [rects addObject:rectValue];
        
        if (unionRect == nil)
            unionRect = rectValue;
        else
            unionRect = [NSValue valueWithCGRect:CGRectUnion(unionRect.CGRectValue, rectValue.CGRectValue)];
    };
    
    addRect(menuView.headerFrame);
    addRect(menuView.mainFrame);
    addRect(menuView.footerFrame);
    
    CGFloat menuWidth = unionRect.CGRectValue.size.width;
    CGFloat topEdge = self.frame.size.height - menuView.menuHeight;
    CGFloat leftEdge = edgeInsets.left;
    CGFloat rightEdge = menuView.menuWidth - edgeInsets.right;
    CGFloat bottomEdge = self.frame.size.height - edgeInsets.bottom;
    
    CGRect firstRect = [rects.firstObject CGRectValue];
    
    _topView.frame = CGRectMake(leftEdge, -self.frame.size.height, menuWidth, self.frame.size.height + topEdge + firstRect.origin.y);
    _leftView.frame = CGRectMake(0, -self.frame.size.height, leftEdge, self.frame.size.height * 3);
    _rightView.frame = CGRectMake(rightEdge, -self.frame.size.height, edgeInsets.right, self.frame.size.height * 3);
    _bottomView.frame = CGRectMake(leftEdge, bottomEdge, menuWidth, self.frame.size.height);
    
    switch (rects.count)
    {
        case 1:
        {
            CGRect rect = [rects.firstObject CGRectValue];
            
            if (_firstCutoutView.superview == nil)
                [self addSubview:_firstCutoutView];
            _firstCutoutView.frame = CGRectMake(leftEdge, topEdge + rect.origin.y, rect.size.width, rect.size.height);
        }
            break;
        
        case 2:
        {
            CGRect rect1 = [rects.firstObject CGRectValue];
            CGRect rect2 = [rects.lastObject CGRectValue];
            
            if (_firstCutoutView.superview == nil)
                [self addSubview:_firstCutoutView];
            _firstCutoutView.frame = CGRectMake(leftEdge, topEdge + rect1.origin.y, rect1.size.width, rect1.size.height);
            
            if (_secondCutoutView.superview == nil)
                [self addSubview:_secondCutoutView];
            _secondCutoutView.frame = CGRectMake(leftEdge, topEdge + rect2.origin.y, rect2.size.width, rect2.size.height);
            
            if (_firstDividerView.superview == nil)
                [self addSubview:_firstDividerView];
            _firstDividerView.frame = CGRectMake(leftEdge, topEdge + CGRectGetMaxY(rect1), menuWidth, spacing);
        }
            break;
        
        case 3:
        {
            CGRect rect1 = [rects.firstObject CGRectValue];
            CGRect rect2 = [rects[1] CGRectValue];
            CGRect rect3 = [rects.lastObject CGRectValue];
            
            if (_firstCutoutView.superview == nil)
                [self addSubview:_firstCutoutView];
            _firstCutoutView.frame = CGRectMake(leftEdge, topEdge + rect1.origin.y, rect1.size.width, rect1.size.height);
            
            if (_secondCutoutView.superview == nil)
                [self addSubview:_secondCutoutView];
            _secondCutoutView.frame = CGRectMake(leftEdge, topEdge + rect2.origin.y, rect2.size.width, rect2.size.height);
            
            if (_thirdCutoutView.superview == nil)
                [self addSubview:_thirdCutoutView];
            _thirdCutoutView.frame = CGRectMake(leftEdge, topEdge + rect3.origin.y, rect3.size.width, rect3.size.height);
            
            if (_firstDividerView.superview == nil)
                [self addSubview:_firstDividerView];
            _firstDividerView.frame = CGRectMake(leftEdge, topEdge + CGRectGetMaxY(rect1), menuWidth, spacing);
            
            if (_secondDividerView.superview == nil)
                [self addSubview:_secondDividerView];
            _secondDividerView.frame = CGRectMake(leftEdge, rect3.origin.y - edgeInsets.top, menuWidth, spacing);
        }
            break;
        
        default:
            break;
    }
}

+ (UIColor *)backgroundColor
{
    return [UIColor colorWithWhite:0.0f alpha:0.4f];
}

+ (UIColor *)theaterBackgroundColor
{
    return [UIColor colorWithWhite:0.0f alpha:0.65f];
}

@end
