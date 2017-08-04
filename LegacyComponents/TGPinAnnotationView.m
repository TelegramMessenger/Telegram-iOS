#import "TGPinAnnotationView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

@interface TGPinAnnotationView ()
{
    UIImageView *_arrowView;
}
@end

@implementation TGPinAnnotationView

- (instancetype)initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        _calloutWrapper = [[UIButton alloc] init];
        _calloutWrapper.adjustsImageWhenHighlighted = false;
        _calloutWrapper.exclusiveTouch = true;
        [_calloutWrapper setBackgroundImage:[TGComponentsImageNamed(@"CalloutBackground.png") resizableImageWithCapInsets:UIEdgeInsetsMake(8.5f, 8.5f, 8.5f, 8.5f)] forState:UIControlStateNormal];
        [_calloutWrapper setBackgroundImage:[TGComponentsImageNamed(@"CalloutBackground_Highlighted.png") resizableImageWithCapInsets:UIEdgeInsetsMake(8.5f, 8.5f, 8.5f, 8.5f)] forState:UIControlStateHighlighted];
        [_calloutWrapper addTarget:self action:@selector(calloutButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_calloutWrapper addTarget:self action:@selector(calloutButtonTouchedDown) forControlEvents:UIControlEventTouchDown];
        [_calloutWrapper addTarget:self action:@selector(calloutButtonTouchedUp) forControlEvents:UIControlEventTouchCancel];
        [_calloutWrapper addTarget:self action:@selector(calloutButtonTouchedUp) forControlEvents:UIControlEventTouchDragExit];
        [_calloutWrapper addTarget:self action:@selector(calloutButtonTouchedDown) forControlEvents:UIControlEventTouchDragEnter];
        [self addSubview:_calloutWrapper];
        
        _arrowView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 28, 13)];
        _arrowView.image = TGComponentsImageNamed(@"CalloutArrow.png");
        _arrowView.highlightedImage = TGComponentsImageNamed(@"CalloutArrow_Highlighted.png");
        [_calloutWrapper addSubview:_arrowView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        [_calloutWrapper addSubview:_titleLabel];
        
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        [_calloutWrapper addSubview:_subtitleLabel];
        
        _calloutWrapper.layer.rasterizationScale = TGScreenScaling();
        _calloutWrapper.layer.shouldRasterize = true;
    }
    return self;
}

- (void)calloutButtonPressed
{
    if (self.calloutPressed != nil)
        self.calloutPressed();
    
    [self calloutButtonTouchedUp];
}

- (void)calloutButtonTouchedUp
{
    _arrowView.highlighted = false;
}

- (void)calloutButtonTouchedDown
{
    _arrowView.highlighted = true;
}

#pragma mark - Properties

- (NSString *)title
{
    return _titleLabel.text;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
}

- (NSString *)subtitle
{
    return _subtitleLabel.text;
}

- (void)setSubtitle:(NSString *)subtitle
{
    _subtitleLabel.text = subtitle;
}

- (void)setSelected:(BOOL)selected
{
    if (self.selectable)
        [super setSelected:selected];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    if (self.selectable)
        [super setSelected:selected animated:animated];
}

#pragma mark - Layout

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    bool pointInside = [super pointInside:point withEvent:event];
    
    if (CGRectContainsPoint(_calloutWrapper.frame, point))
        pointInside = true;
    
    return pointInside;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _arrowView.frame = CGRectMake((_calloutWrapper.frame.size.width - _arrowView.frame.size.width) / 2, _calloutWrapper.frame.size.height - 0.5f, _arrowView.frame.size.width, _arrowView.frame.size.height);
    
    CGRect calloutFrame = _calloutWrapper.frame;
    calloutFrame.origin.x = CGFloor((self.frame.size.width - calloutFrame.size.width) / 2) - 8;
    calloutFrame.origin.y = -calloutFrame.size.height - 12;
    _calloutWrapper.frame = calloutFrame;

    _appeared = true;
}

@end
