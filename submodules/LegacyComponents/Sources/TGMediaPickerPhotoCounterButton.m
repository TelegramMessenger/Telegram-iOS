#import "TGMediaPickerPhotoCounterButton.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGFont.h"
#import "TGStringUtils.h"
#import "TGPhotoEditorInterfaceAssets.h"

#import "POPSpringAnimation.h"

const CGFloat TGPhotoCounterButtonMaskFade = 18;

@interface TGMediaPickerPhotoCounterButton ()
{
    UIView *_wrapperView;
    UIImageView *_backgroundView;
    UILabel *_countLabel;
    UIImageView *_crossIconView;
    
    bool _processing;
    UIView *_processingMaskView;
    UILabel *_processingLabel;
}
@end

@implementation TGMediaPickerPhotoCounterButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.exclusiveTouch = true;
        
        _internalHidden = true;
        
        _wrapperView = [[UIView alloc] initWithFrame:self.bounds];
        _wrapperView.alpha = 0.0f;
        _wrapperView.hidden = true;
        _wrapperView.userInteractionEnabled = false;
        [self addSubview:_wrapperView];
        
        _backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(13, 0, 38, 38)];
    
        static dispatch_once_t onceToken;
        static UIImage *backgroundImage;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(38.0f, 38.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.3f).CGColor);
            
            CGContextFillEllipseInRect(context, CGRectMake(3.5f, 1.0f, 31.0f, 31.0f));
            
            CGFloat lineWidth = 1.5f;
            if (TGScreenScaling() == 3.0f)
                lineWidth = 5.0f / 3.0f;
            CGContextSetLineWidth(context, lineWidth);
            CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
            CGContextStrokeEllipseInRect(context, CGRectMake(3.0f, 1.0f, 31.0f, 31.0f));
            
            backgroundImage = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(38.0f / 4.0f, 38.0f / 4.0f, 38.0f / 4.0f, 38.0f / 4.0f)];
            UIGraphicsEndImageContext();
        });
        
        _backgroundView.image = backgroundImage;
        [_wrapperView addSubview:_backgroundView];
    
        _countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, -0.5f, frame.size.width + 1.0, frame.size.height)];
        _countLabel.backgroundColor = [UIColor clearColor];
        _countLabel.font = [TGFont roundedFontOfSize:18];
        _countLabel.text = [TGStringUtils stringWithLocalizedNumber:0];
        _countLabel.textColor = [UIColor whiteColor];
        [_wrapperView addSubview:_countLabel];
        
        _crossIconView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _wrapperView.bounds.size.width - 1.0f, _wrapperView.bounds.size.height - 5.0f)];
        _crossIconView.alpha = 0.0f;
        _crossIconView.contentMode = UIViewContentModeCenter;
        _crossIconView.hidden = true;
        _crossIconView.image = TGComponentsImageNamed(@"ImagePickerPhotoCounter_Close");
        [_wrapperView addSubview:_crossIconView];
        
        CGFloat maskWidth = 50.0f;
        if (iosMajorVersion() >= 7)
            maskWidth += CGCeil([TGLocalized(@"MediaPicker.Processing") sizeWithAttributes:@{ NSFontAttributeName:TGSystemFontOfSize(16) }].width);
        else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            maskWidth += CGCeil([TGLocalized(@"MediaPicker.Processing") sizeWithFont:TGSystemFontOfSize(16)].width);
#pragma clang diagnostic pop
        }
        
        _processingMaskView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, maskWidth, 38)];
        [_wrapperView addSubview:_processingMaskView];

        CGFloat maskFade = TGPhotoCounterButtonMaskFade / maskWidth;
        CAGradientLayer *maskLayer = [CAGradientLayer layer];
        maskLayer.colors = @[ (id)[UIColor clearColor].CGColor, (id)[UIColor whiteColor].CGColor, (id)[UIColor whiteColor].CGColor ];
        maskLayer.locations = @[ @0.0f, @(maskFade), @1.0f ];
        maskLayer.startPoint = CGPointMake(0.0f, 0.5f);
        maskLayer.endPoint = CGPointMake(1.0f, 0.5f);
        maskLayer.frame = CGRectMake(0, 0, _processingMaskView.frame.size.width, _processingMaskView.frame.size.height);
        _processingMaskView.layer.mask = maskLayer;
        
        _processingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _processingLabel.backgroundColor = [UIColor clearColor];
        _processingLabel.font = [TGFont systemFontOfSize:16];
        _processingLabel.textColor = [UIColor whiteColor];
        [_processingMaskView addSubview:_processingLabel];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (!_internalHidden)
        return [super hitTest:point withEvent:event];
    
    return nil;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self _layoutCountLabelWithProcessingLabelWidth:_processingLabel.frame.size.width sizeToFit:false];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];

    if (highlighted)
        _wrapperView.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
}

- (void)setInternalHidden:(bool)internalHidden
{
    [self setInternalHidden:internalHidden animated:false completion:nil];
}

- (void)setInternalHidden:(bool)internalHidden animated:(bool)animated completion:(void (^)(void))completion
{
    if (_internalHidden == internalHidden)
        return;
    
    _internalHidden = internalHidden;
    
    if (animated)
    {
        _wrapperView.hidden = false;
        
        if (!internalHidden)
        {
            [UIView animateWithDuration:0.12f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^
            {
                _wrapperView.transform = CGAffineTransformMakeScale(1.2f, 1.2f);
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    [UIView animateWithDuration:0.08f delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^
                    {
                        _wrapperView.transform = CGAffineTransformIdentity;
                    } completion:nil];
                }
            }];
            
            [UIView animateWithDuration:0.2f animations:^
            {
                _wrapperView.alpha = 1.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _wrapperView.hidden = internalHidden;
                    if (completion != nil)
                        completion();
                }
            }];
        }
        else
        {
            _countLabel.transform = CGAffineTransformIdentity;
            _crossIconView.transform = CGAffineTransformIdentity;
            
            [UIView animateWithDuration:0.12f delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^
            {
                _wrapperView.transform = CGAffineTransformMakeScale(0.01f, 0.01f);
            } completion:^(BOOL finished)
            {
                if (finished)
                {
                    _wrapperView.transform = CGAffineTransformIdentity;
                    _wrapperView.hidden = true;
                    
                    if (completion != nil)
                        completion();
                }
            }];
            
            [UIView animateWithDuration:0.1f animations:^
            {
                _wrapperView.alpha = 0.0f;
            } completion:nil];
        }
    }
    else
    {
        _wrapperView.alpha = internalHidden ? 0.0f : 1.0f;
        _wrapperView.hidden = internalHidden;
        if (completion != nil)
            completion();
    }
}

- (void)setSelectedCount:(NSInteger)count animated:(bool)animated
{
    NSInteger currentCount = MAX(0, [_countLabel.text integerValue]);
    bool increasing = count > currentCount;
    
    _countLabel.text = [NSString stringWithFormat:@"%@", [TGStringUtils stringWithLocalizedNumber:count]];
    [self _layoutCountLabelWithProcessingLabelWidth:_processingLabel.frame.size.width sizeToFit:true];
    
    if (self.selected || !animated)
        return;
    
    [UIView animateWithDuration:0.12 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^
    {
        _wrapperView.transform = increasing ? CGAffineTransformMakeScale(1.2f, 1.2f) : CGAffineTransformMakeScale(0.8f, 0.8f);
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^
            {
                _wrapperView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    }];
}

- (void)setActiveNumber:(NSInteger)number animated:(bool)__unused animated
{
    CGFloat currentWidth = _processingLabel.frame.size.width;
    _processingLabel.text = [NSString stringWithFormat:TGLocalized(@"MediaPicker.Processing"), [NSString stringWithFormat:TGLocalized(@"MediaPicker.Nof"), [TGStringUtils stringWithLocalizedNumber:number]]];
    [_processingLabel sizeToFit];
    
    if (currentWidth == _processingLabel.frame.size.width)
        return;
    
    CGFloat diff = currentWidth - _processingLabel.frame.size.width;
    
    if (![self _useRtlLayout])
    {
        _processingLabel.frame = CGRectMake(diff, 9, _processingLabel.frame.size.width, _processingLabel.frame.size.height);
        _processingMaskView.frame = CGRectMake(_countLabel.frame.origin.x - currentWidth - 4.5f, _processingMaskView.frame.origin.y, _processingMaskView.frame.size.width, _processingMaskView.frame.size.height);
    }
    else
    {
        _processingLabel.frame = CGRectMake(diff, 9, _processingLabel.frame.size.width, _processingLabel.frame.size.height);
        _processingMaskView.frame = CGRectMake(currentWidth + 19 + 13 + 4.5f, 0, _processingMaskView.frame.size.width, _processingMaskView.frame.size.height);
    }
    
    [UIView animateWithDuration:0.3f delay:0.0f options:7 << 16 animations:^
    {
        [self _layoutProcessingViewsWithWidth:_processingLabel.frame.size.width];
    } completion:nil];
}

- (void)_layoutProcessingViewsWithWidth:(CGFloat)width
{
    CGFloat backgroundExtension = 0.0f;
    if (![self _useRtlLayout])
    {
        _processingLabel.frame = CGRectMake(TGPhotoCounterButtonMaskFade, _processingLabel.frame.origin.y, _processingLabel.frame.size.width, _processingLabel.frame.size.height);
        _processingMaskView.frame = CGRectMake(_countLabel.frame.origin.x - width - 4.5f - TGPhotoCounterButtonMaskFade, _processingMaskView.frame.origin.y, _processingMaskView.frame.size.width, _processingMaskView.frame.size.height);
        
        backgroundExtension = width > 0 ? width + 4.5f : 0;
    }
    else
    {
        _processingLabel.frame = CGRectMake(TGPhotoCounterButtonMaskFade, _processingLabel.frame.origin.y, _processingLabel.frame.size.width, _processingLabel.frame.size.height);
        _processingMaskView.frame = CGRectMake(-width + 19, _processingMaskView.frame.origin.y, _processingMaskView.frame.size.width, _processingMaskView.frame.size.height);
        [self _layoutCountLabelWithProcessingLabelWidth:_processingLabel.frame.size.width sizeToFit:false];
        
        backgroundExtension = width > 0 ? width : 0;
    }
    
    _backgroundView.frame = CGRectMake(13 - backgroundExtension, _backgroundView.frame.origin.y, 38 + backgroundExtension, _backgroundView.frame.size.height);
}

- (void)_layoutCountLabelWithProcessingLabelWidth:(CGFloat)processingLabelWidth sizeToFit:(bool)sizeToFit
{
    CGAffineTransform transform = _countLabel.transform;
    _countLabel.transform = CGAffineTransformIdentity;
    if (sizeToFit)
        [_countLabel sizeToFit];
    
    CGFloat labelWidth = ceilf(_countLabel.frame.size.width);
    CGFloat labelOrigin = 0.0f;

    if (![self _useRtlLayout])
    {
        labelOrigin = 12 + TGScreenPixel + (38 - labelWidth) / 2;
        
//        if ([_countLabel.text isEqualToString:@"1"] || [_countLabel.text isEqualToString:@"4"])
//            labelOrigin -= 2 * TGScreenPixel;
    }
    else
    {
        labelOrigin = (processingLabelWidth > 0) ? -processingLabelWidth + 19 + 13 - 4.5f: 64 - 38 + (38 - labelWidth) / 2.0f - 13;
    }
    
    _countLabel.frame = CGRectMake(labelOrigin, 5.0 + TGScreenPixel, labelWidth, _countLabel.frame.size.height);
    _countLabel.transform = transform;
}

- (void)cancelledProcessingAnimated:(bool)animated completion:(void (^)(void))completion
{
    void (^changeBlock)(void) = ^
    {
        if (![self _useRtlLayout])
        {
            _processingLabel.frame = CGRectMake(-_processingLabel.frame.size.width, _processingLabel.frame.origin.y, _processingLabel.frame.size.width, _processingLabel.frame.size.height);
            _processingMaskView.frame = CGRectMake(_countLabel.frame.origin.x - 4.5f, _processingMaskView.frame.origin.y, _processingMaskView.frame.size.width, _processingMaskView.frame.size.height);
        }
        else
        {
            _processingLabel.frame = CGRectMake(-_processingLabel.frame.size.width, _processingLabel.frame.origin.y, _processingLabel.frame.size.width, _processingLabel.frame.size.height);
            _processingMaskView.frame = CGRectMake(19 + TGPhotoCounterButtonMaskFade, _processingMaskView.frame.origin.y, _processingMaskView.frame.size.width, _processingMaskView.frame.size.height);
            [self _layoutCountLabelWithProcessingLabelWidth:0 sizeToFit:false];
        }
        
        _backgroundView.frame = CGRectMake(13, _backgroundView.frame.origin.y, 38, _backgroundView.frame.size.height);
    };
    
    void (^completionBlock)(BOOL) = ^(__unused BOOL finished)
    {
        _processingLabel.frame = CGRectZero;
        
        if (completion != nil)
            completion();
    };
    
    if (animated)
    {
        [UIView animateWithDuration:0.3f animations:changeBlock completion:completionBlock];
    }
    else
    {
        changeBlock();
        completionBlock(true);
    }
}

- (bool)_useRtlLayout
{
    return (TGIsRTL() && ![TGLocalized(@"MediaPicker.Processing") isEqualToString:@"Processing %@"]);
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    _wrapperView.transform = CGAffineTransformIdentity;
    
    [super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    
    if (!CGRectContainsPoint(self.bounds, [touch locationInView:self]))
    {
        _wrapperView.transform = CGAffineTransformIdentity;
    }
    else
    {
        _wrapperView.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
    }
    
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    
    if (!CGRectContainsPoint(self.bounds, [touch locationInView:self]))
    {
        _wrapperView.transform = CGAffineTransformIdentity;
    }
    else
    {
        _wrapperView.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
    }
    
    [super touchesMoved:touches withEvent:event];
}

- (void)setSelected:(BOOL)selected
{
    [self setSelected:selected animated:false];
}

- (void)setSelected:(bool)selected animated:(bool)animated
{
    if (animated)
    {
        _crossIconView.hidden = false;
        _countLabel.hidden = false;

        if (selected)
        {
            _crossIconView.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_4);
            _countLabel.transform = CGAffineTransformIdentity;
        }
        
        CGFloat crossStartRotation = [[_crossIconView.layer valueForKeyPath:@"transform.rotation.z"] floatValue];
        CGFloat labelStartRotation = [[_countLabel.layer valueForKeyPath:@"transform.rotation.z"] floatValue];
        
        if (self.selected != selected)
        {
            crossStartRotation = selected ? (CGFloat)M_PI_4 : 0;
            labelStartRotation = selected ? 0 : (CGFloat)-M_PI_4;
        }
        
        POPSpringAnimation *crossAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
        crossAnimation.springSpeed = 12;
        crossAnimation.springBounciness = 7;
        crossAnimation.fromValue = @(crossStartRotation);
        crossAnimation.toValue = selected ? @0 : @(M_PI_4);
        [_crossIconView.layer pop_addAnimation:crossAnimation forKey:@"rotation"];

        POPSpringAnimation *labelAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
        labelAnimation.springSpeed = 12;
        labelAnimation.springBounciness = 7;
        labelAnimation.fromValue = @(labelStartRotation);
        labelAnimation.toValue = selected ? @(-M_PI_4) : @0;
        [_countLabel.layer pop_addAnimation:labelAnimation forKey:@"rotation"];
        
        [UIView animateWithDuration:0.2f
                         animations:^
        {
            _wrapperView.transform = CGAffineTransformIdentity;
            _crossIconView.alpha = selected ? 1.0f : 0.0f;
            _countLabel.alpha = selected ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                _crossIconView.hidden = !selected;
                _countLabel.hidden = selected;
            }
        }];
    }
    else
    {
        [_crossIconView pop_removeAllAnimations];
        [_countLabel pop_removeAllAnimations];
        _crossIconView.alpha = selected ? 1.0f : 0.0f;
        _countLabel.alpha = selected ? 0.0f : 1.0f;
        _crossIconView.hidden = !selected;
        _countLabel.hidden = selected;
    }
    
    [super setSelected:selected];
}

- (void)setHidden:(BOOL)hidden
{
    self.alpha = hidden ? 0.0f : 1.0f;
    super.hidden = hidden;
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    [self setHidden:hidden delay:0 animated:animated];
}

- (void)setHidden:(bool)hidden delay:(NSTimeInterval)delay animated:(bool)animated
{
    if (animated)
    {
        super.hidden = false;
        
        [UIView animateWithDuration:0.2f delay:delay options:UIViewAnimationOptionCurveLinear animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
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

@end


@interface TGMediaPickerGroupButton ()
{
    UIView *_wrapperView;
    UIImageView *_backgroundView;
    UIImageView *_iconView;
    
    bool _position;
}

@end

@implementation TGMediaPickerGroupButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.exclusiveTouch = true;
        
        _wrapperView = [[UIView alloc] initWithFrame:self.bounds];
        _wrapperView.userInteractionEnabled = false;
        [self addSubview:_wrapperView];
        
        _backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0, 38, 38)];
        _backgroundView.image = [TGPhotoEditorInterfaceAssets groupIconBackground];
        [_wrapperView addSubview:_backgroundView];
        
        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(-TGScreenPixel, -2.0f, _wrapperView.bounds.size.width, _wrapperView.bounds.size.height)];
        _iconView.contentMode = UIViewContentModeCenter;
        _iconView.image = [TGPhotoEditorInterfaceAssets ungroupIcon];
        [_wrapperView addSubview:_iconView];
    }
    return self;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    _backgroundView.image = selected ? [TGPhotoEditorInterfaceAssets groupIconBackgroundActive] : [TGPhotoEditorInterfaceAssets groupIconBackground];
    _iconView.image = selected ? [TGPhotoEditorInterfaceAssets groupIcon] : [TGPhotoEditorInterfaceAssets ungroupIcon];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    _wrapperView.transform = CGAffineTransformIdentity;
    
    [super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    
    if (!CGRectContainsPoint(self.bounds, [touch locationInView:self]))
    {
        _wrapperView.transform = CGAffineTransformIdentity;
    }
    else
    {
        [UIView animateWithDuration:0.12f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            _wrapperView.transform = CGAffineTransformMakeScale(1.2f, 1.2f);
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                [UIView animateWithDuration:0.08f delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^
                {
                    _wrapperView.transform = CGAffineTransformIdentity;
                } completion:nil];
            }
        }];
    }
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    
    if (!CGRectContainsPoint(self.bounds, [touch locationInView:self]))
        _wrapperView.transform = CGAffineTransformIdentity;
    else
        _wrapperView.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
    
    [super touchesMoved:touches withEvent:event];
}

- (void)setHidden:(BOOL)hidden
{
    self.alpha = hidden ? 0.0f : 1.0f;
    super.hidden = hidden;
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    [self setHidden:hidden delay:0 animated:animated];
}

- (void)setHidden:(bool)hidden delay:(NSTimeInterval)delay animated:(bool)animated
{
    if (animated)
    {
        super.hidden = false;
        
        [UIView animateWithDuration:0.2f delay:delay options:UIViewAnimationOptionCurveLinear animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
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

- (void)setInternalHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^
        {
            _wrapperView.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            self.userInteractionEnabled = !hidden;
        }];
    }
    else
    {
        _wrapperView.alpha = hidden ? 0.0f : 1.0f;
        self.userInteractionEnabled = !hidden;
    }
}

@end


@interface TGMediaPickerCameraButton ()
{
    UIView *_wrapperView;
    UIImageView *_backgroundView;
    
    bool _position;
}

@end


@implementation TGMediaPickerCameraButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.exclusiveTouch = true;
        
        _wrapperView = [[UIView alloc] initWithFrame:self.bounds];
        _wrapperView.userInteractionEnabled = false;
        [self addSubview:_wrapperView];
        
        _backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
        _backgroundView.image = [TGPhotoEditorInterfaceAssets cameraIcon];
        _backgroundView.contentMode = UIViewContentModeCenter;
        [_wrapperView addSubview:_backgroundView];
    }
    return self;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    _wrapperView.transform = CGAffineTransformIdentity;
    
    [super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    
    if (!CGRectContainsPoint(self.bounds, [touch locationInView:self]))
    {
        _wrapperView.transform = CGAffineTransformIdentity;
    }
    else
    {
        [UIView animateWithDuration:0.12f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^
         {
             _wrapperView.transform = CGAffineTransformMakeScale(1.2f, 1.2f);
         } completion:^(BOOL finished)
         {
             if (finished)
             {
                 [UIView animateWithDuration:0.08f delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^
                  {
                      _wrapperView.transform = CGAffineTransformIdentity;
                  } completion:nil];
             }
         }];
    }
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    
    if (!CGRectContainsPoint(self.bounds, [touch locationInView:self]))
        _wrapperView.transform = CGAffineTransformIdentity;
    else
        _wrapperView.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
    
    [super touchesMoved:touches withEvent:event];
}

- (void)setHidden:(BOOL)hidden
{
    self.alpha = hidden ? 0.0f : 1.0f;
    super.hidden = hidden;
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    [self setHidden:hidden delay:0 animated:animated];
}

- (void)setHidden:(bool)hidden delay:(NSTimeInterval)delay animated:(bool)animated
{
    if (animated)
    {
        super.hidden = false;
        
        [UIView animateWithDuration:0.2f delay:delay options:UIViewAnimationOptionCurveLinear animations:^
         {
             self.alpha = hidden ? 0.0f : 1.0f;
         } completion:^(BOOL finished)
         {
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

- (void)setInternalHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^
         {
             _wrapperView.alpha = hidden ? 0.0f : 1.0f;
         } completion:^(BOOL finished)
         {
             self.userInteractionEnabled = !hidden;
         }];
    }
    else
    {
        _wrapperView.alpha = hidden ? 0.0f : 1.0f;
        self.userInteractionEnabled = !hidden;
    }
}

@end
