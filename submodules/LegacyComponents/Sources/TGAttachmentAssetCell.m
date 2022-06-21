#import "TGAttachmentAssetCell.h"
#import <LegacyComponents/TGMediaSelectionContext.h>

#import "LegacyComponentsInternal.h"

@interface TGAttachmentAssetCell ()
{
    SMetaDisposable *_itemSelectedDisposable;
    bool _ignoreSetSelected;
}
@end

@implementation TGAttachmentAssetCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _imageView = [[TGImageView alloc] initWithFrame:self.bounds];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        [self addSubview:_imageView];
        
        static dispatch_once_t onceToken;
        static UIImage *gradientImage;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 20.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGColorRef colors[2] = {
                CGColorRetain(UIColorRGBA(0x000000, 0.0f).CGColor),
                CGColorRetain(UIColorRGBA(0x000000, 0.8f).CGColor)
            };
            
            CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 2, NULL);
            CGFloat locations[2] = {0.0f, 1.0f};
            
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, (CGFloat const *)&locations);
            
            CFRelease(colorsArray);
            CFRelease(colors[0]);
            CFRelease(colors[1]);
            
            CGColorSpaceRelease(colorSpace);
            
            CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, 20.0f), 0);
            
            CFRelease(gradient);
            
            gradientImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _gradientView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _gradientView.image = gradientImage;
        _gradientView.hidden = true;
        [self addSubview:_gradientView];
        
        if (@available(iOS 11.0, *)) {
            _imageView.accessibilityIgnoresInvertColors = true;
            _gradientView.accessibilityIgnoresInvertColors = true;
        }
        
        [self bringSubviewToFront:_cornersView];
    }
    return self;
}

- (void)dealloc
{
    [_itemSelectedDisposable dispose];
}

- (void)setAsset:(TGMediaAsset *)asset signal:(SSignal *)signal
{
    _asset = asset;
    
    if (self.selectionContext != nil)
    {
        if (_checkButton == nil)
        {
            _checkButton = [[TGCheckButtonView alloc] initWithStyle:TGCheckButtonStyleMedia];
            [_checkButton addTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_checkButton];
            
            if (@available(iOS 11.0, *)) {
                _checkButton.accessibilityIgnoresInvertColors = true;
            }
        }
        
        if (_itemSelectedDisposable == nil)
            _itemSelectedDisposable = [[SMetaDisposable alloc] init];
        
        [self setChecked:[self.selectionContext isItemSelected:(id<TGMediaSelectableItem>)asset] animated:false];
        __weak TGAttachmentAssetCell *weakSelf = self;
        [_itemSelectedDisposable setDisposable:[[self.selectionContext itemInformativeSelectedSignal:(id<TGMediaSelectableItem>)asset] startWithNext:^(TGMediaSelectionChange *next)
        {
            __strong TGAttachmentAssetCell *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (next.sender != strongSelf->_checkButton)
                [strongSelf setChecked:next.selected animated:next.animated];
        }]];
    }
    
    if (_asset == nil)
    {
        [_imageView reset];
        return;
    }
    
    [self setSignal:signal];
}


- (void)setSignal:(SSignal *)signal
{
    if (signal != nil)
        [_imageView setSignal:signal];
    else
        [_imageView reset];
}

- (void)checkButtonPressed
{
    _ignoreSetSelected = true;
    
    [self.selectionContext setItem:(id<TGMediaSelectableItem>)self.asset selected:!_checkButton.selected animated:true sender:_checkButton];
    
    bool value = [self.selectionContext isItemSelected:(id<TGMediaSelectableItem>)self.asset];
    if (value != _checkButton.selected) {
        [_checkButton setSelected:value animated:true];
    }
    
    _ignoreSetSelected = false;
}

- (void)setChecked:(bool)checked animated:(bool)animated
{
    [_checkButton setSelected:checked animated:animated];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [_imageView reset];
    _asset = nil;
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (hidden != self.imageView.hidden)
    {
        self.imageView.hidden = hidden;
        
        if (animated)
        {
            if (!hidden)
            {
                for (UIView *view in self.subviews)
                {
                    if (view != self.imageView && view != _cornersView)
                        view.alpha = 0.0f;
                }
            }
            
            [UIView animateWithDuration:0.2 animations:^
            {
                if (!hidden)
                {
                    for (UIView *view in self.subviews)
                    {
                        if (view != self.imageView && view != _cornersView)
                            view.alpha = 1.0f;
                    }
                }
            }];
        }
        else
        {
            for (UIView *view in self.subviews)
            {
                if (view != self.imageView && view != _cornersView)
                    view.alpha = hidden ? 0.0f : 1.0f;
            }
        }
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_checkButton != nil)
    {
        CGFloat offset = 0.0f;
        if (self.superview != nil)
        {
            CGRect rect = [self.superview convertRect:self.frame toView:self.superview.superview];
            if (rect.origin.x < 0)
                offset = rect.origin.x * -1;
            else if (CGRectGetMaxX(rect) > self.superview.frame.size.width)
                offset = self.superview.frame.size.width - CGRectGetMaxX(rect);
        }
        
        CGFloat x = MAX(0, MIN(self.bounds.size.width - _checkButton.frame.size.width, self.bounds.size.width - _checkButton.frame.size.width + offset));
        _checkButton.frame = CGRectMake(x, 0, _checkButton.frame.size.width, _checkButton.frame.size.height);
    }
    
    if (!_gradientView.hidden)
        _gradientView.frame = CGRectMake(0, self.frame.size.height - 20.0f, self.frame.size.width, 20.0f);
}

@end
