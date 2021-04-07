#import "TGModernBackToolbarButton.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"

@interface TGModernBackToolbarButton ()
{
    float _labelOffset;
    float _arrowOffset;
}

@property (nonatomic, strong) UIImageView *arrowView;

@end

@implementation TGModernBackToolbarButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        if (iosMajorVersion() >= 7)
        {
            _arrowOffset = 0.0f;
            _labelOffset = 1.0f;
        }
        else
        {
            _arrowOffset = -1.0f;
            _labelOffset = 0.0f;
        }
        
        [self setButtonTitle:TGLocalized(@"Common.Back")];
        
        _arrowView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"NavigationBackArrow.png"]];
        [self addSubview:_arrowView];
    }
    return self;
}

- (instancetype)initWithLightMode
{
    self = [self initWithFrame:CGRectZero];
    if (self != nil)
    {
        [self setTitleColor:TGAccentColor()];
        _arrowView.image = [UIImage imageNamed:@"NavigationBackArrowLight.png"];
        
        _arrowOffset = -1.0f;
        _labelOffset = 0.0f;
    }
    return self;
}

- (UIEdgeInsets)alignmentRectInsets
{
    UIEdgeInsets insets = UIEdgeInsetsZero;
    insets = UIEdgeInsetsMake(0, 8.0f, 0, 0);
    return insets;
}

- (void)sizeToFit
{
    [self.buttonTitleLabel sizeToFit];
    
    CGRect frame = self.frame;
    frame.size.height = _arrowView.frame.size.height;
    frame.size.width = _arrowView.frame.size.width + 7 + self.buttonTitleLabel.frame.size.width;
    self.frame = frame;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect arrowFrame = _arrowView.frame;
    arrowFrame.origin = CGPointMake(0, _arrowOffset + CGFloor((self.frame.size.height - arrowFrame.size.height) / 2) + 1);
    _arrowView.frame = arrowFrame;
    
    CGRect labelFrame = self.buttonTitleLabel.frame;
    labelFrame.origin = CGPointMake(arrowFrame.origin.x + arrowFrame.size.width + 7, _labelOffset + CGFloor((self.frame.size.height - labelFrame.size.height)));
    self.buttonTitleLabel.frame = labelFrame;
}

- (void)setHighlighted:(BOOL)highlighted
{
    _arrowView.alpha = highlighted ? 0.4f : 1.0f;
    
    [super setHighlighted:highlighted];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (self.alpha > FLT_EPSILON && !self.hidden && CGRectContainsPoint(CGRectInset(self.bounds, -5, -5), point))
        return self;
    
    return [super hitTest:point withEvent:event];
}

@end
