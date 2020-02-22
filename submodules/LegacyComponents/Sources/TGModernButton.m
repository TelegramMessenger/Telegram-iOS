#import "TGModernButton.h"

#import "LegacyComponentsInternal.h"

@interface TGModernButton ()
{
    bool _animateHighlight;
    
    UIColor *_titleColor;
    
    UIImageView *_highlightImageView;
    UIView *_highlightBackgroundView;
}

@end

@implementation TGModernButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _modernHighlight = true;
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (self.alpha > FLT_EPSILON && !self.hidden)
    {
        CGRect bounds = self.bounds;
        bounds.origin.x -= _extendedEdgeInsets.left;
        bounds.size.width += _extendedEdgeInsets.left + _extendedEdgeInsets.right;
        bounds.origin.y -= _extendedEdgeInsets.top;
        bounds.size.height += _extendedEdgeInsets.top + _extendedEdgeInsets.bottom;
        if (CGRectContainsPoint(bounds, point))
            return self;
    }
    
    return [super hitTest:point withEvent:event];
}

- (void)setModernHighlight:(bool)modernHighlight
{
    _modernHighlight = modernHighlight;
    if (!_modernHighlight) {
        self.alpha = 1.0f;
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    _animateHighlight = true;
    [super touchesMoved:touches withEvent:event];
    _animateHighlight = false;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    _animateHighlight = true;
    [super touchesCancelled:touches withEvent:event];
    _animateHighlight = false;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    _animateHighlight = true;
    [super touchesEnded:touches withEvent:event];
    _animateHighlight = false;
}

- (void)setHighlightImage:(UIImage *)highlightImage
{
    _highlightImage = highlightImage;
    
    if (_highlightImage != nil && _highlightImageView == nil)
    {
        _highlightImageView = [[UIImageView alloc] init];
        _highlightImageView.alpha = 0.0f;
        [self insertSubview:_highlightImageView belowSubview:self.titleLabel];
    }
    
    _highlightImageView.image = _highlightImage;
    if (_stretchHighlightImage)
        _highlightImageView.frame = self.bounds;
    else
    {
        _highlightImageView.frame = CGRectMake(CGFloor((self.bounds.size.width - _highlightImage.size.width) / 2.0f), CGFloor((self.bounds.size.height - _highlightImage.size.height) / 2.0f), _highlightImage.size.width, _highlightImage.size.height);
    }
}

- (void)setHighlightBackgroundColor:(UIColor *)highlightBackgroundColor
{
    _highlightBackgroundColor = highlightBackgroundColor;
    
    if (_highlightBackgroundColor != nil && _highlightBackgroundView == nil)
    {
        _highlightBackgroundView = [[UIView alloc] init];
        _highlightBackgroundView.alpha = 0.0f;
        [self insertSubview:_highlightBackgroundView atIndex:0];
    }
    
    _highlightBackgroundView.backgroundColor = _highlightBackgroundColor;
    CGRect frame = self.bounds;
    frame.origin.x -= _backgroundSelectionInsets.left;
    frame.origin.y -= _backgroundSelectionInsets.top;
    frame.size.width += _backgroundSelectionInsets.left + _backgroundSelectionInsets.right;
    frame.size.height += _backgroundSelectionInsets.top + _backgroundSelectionInsets.bottom;
    _highlightBackgroundView.frame = frame;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    if (_highlightImageView != nil)
    {
        if (_stretchHighlightImage)
            _highlightImageView.frame = self.bounds;
        else
        {
            _highlightImageView.frame = CGRectMake(CGFloor((frame.size.width - _highlightImage.size.width) / 2.0f), CGFloor((frame.size.height - _highlightImage.size.height) / 2.0f), _highlightImage.size.width, _highlightImage.size.height);
        }
    }
    
    if (_highlightBackgroundView != nil)
    {
        CGRect frame = self.bounds;
        frame.origin.x -= _backgroundSelectionInsets.left;
        frame.origin.y -= _backgroundSelectionInsets.top;
        frame.size.width += _backgroundSelectionInsets.left + _backgroundSelectionInsets.right;
        frame.size.height += _backgroundSelectionInsets.top + _backgroundSelectionInsets.bottom;
        _highlightBackgroundView.frame = frame;
    }
}

- (void)_setHighligtedAnimated:(bool)__unused highlighted animated:(bool)__unused animated
{
    
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    if (_highlitedChanged && (highlighted || !_animateHighlight))
        _highlitedChanged(highlighted);
    
    if (_modernHighlight)
    {
        if (_highlightImage != nil)
        {
            CGFloat alpha = (highlighted ? 1.0f : 0.0f);
            
            if (ABS(alpha - _highlightImageView.alpha) > FLT_EPSILON)
            {
                if (_animateHighlight)
                {
                    [UIView animateWithDuration:0.2 animations:^
                    {
                        _highlightImageView.alpha = alpha;
                    } completion:^(BOOL finished)
                    {
                        if (finished && !highlighted && _highlitedChanged)
                            _highlitedChanged(highlighted);
                    }];
                }
                else
                    _highlightImageView.alpha = alpha;
            }
        }
        else if (_highlightBackgroundColor != nil)
        {
            CGFloat alpha = (highlighted ? 1.0f : 0.0f);
            
            if (ABS(alpha - _highlightBackgroundView.alpha) > FLT_EPSILON)
            {
                if (_animateHighlight)
                {
                    [UIView animateWithDuration:0.2 animations:^
                    {
                        _highlightBackgroundView.alpha = alpha;
                    } completion:^(BOOL finished)
                    {
                        if (finished && !highlighted && _highlitedChanged)
                            _highlitedChanged(highlighted);
                    }];
                }
                else
                    _highlightBackgroundView.alpha = alpha;
            }
        }
        else
        {
            CGFloat alpha = (highlighted ? 0.4f : 1.0f) * (self.fadeDisabled ? 0.5f : (self.enabled ? 1.0f : 0.5f));
            
            if (ABS(alpha - self.alpha) > FLT_EPSILON)
            {
                if (_animateHighlight)
                {
                    [UIView animateWithDuration:0.2 animations:^
                    {
                        self.alpha = alpha;
                    } completion:^(BOOL finished)
                    {
                        if (finished && !highlighted && _highlitedChanged)
                            _highlitedChanged(highlighted);
                    }];
                }
                else
                    self.alpha = alpha;
            }
        }
    }
    else
    {
        [self _setHighligtedAnimated:highlighted animated:_animateHighlight && !highlighted];
    }
}

- (void)setTitleColor:(UIColor *)color
{
    _titleColor = color;
    
    if (iosMajorVersion() >= 7)
        [self setTintColor:color];
    else
        [self setTitleColor:color forState:UIControlStateNormal];
    
    if (_modernHighlight && _highlightImage == nil && _highlightBackgroundColor == nil)
    {
        CGFloat alpha = (self.highlighted ? 0.4f : 1.0f) * (self.fadeDisabled ? 0.5f : (self.enabled ? 1.0f : 0.5f));
        self.alpha = alpha;
    }
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    
    if (_modernHighlight && _highlightImage == nil)
    {
        CGFloat alpha = (self.highlighted ? 0.4f : 1.0f) * (self.fadeDisabled ? 0.5f : (self.enabled ? 1.0f : 0.5f));
        self.alpha = alpha;
    }
}

- (void)setFadeDisabled:(bool)fadeDisabled {
    _fadeDisabled = fadeDisabled;
    if (_modernHighlight && _highlightImage == nil)
    {
        CGFloat alpha = (self.highlighted ? 0.4f : 1.0f) * (self.fadeDisabled ? 0.5f : (self.enabled ? 1.0f : 0.5f));
        self.alpha = alpha;
    }
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    
    if (_modernHighlight && _highlightImage == nil)
        [self setTitleColor:self.tintColor forState:UIControlStateNormal];
}

- (CGFloat)stateAlpha {
    CGFloat alpha = (self.highlighted ? 0.4f : 1.0f) * (self.fadeDisabled ? 0.5f : (self.enabled ? 1.0f : 0.5f));
    return alpha;
}

@end
