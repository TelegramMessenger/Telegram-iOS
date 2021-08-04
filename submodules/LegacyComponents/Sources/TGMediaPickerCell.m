#import "TGMediaPickerCell.h"
#import "LegacyComponentsInternal.h"
#import <LegacyComponents/TGImageView.h>

#import <LegacyComponents/TGMediaSelectionContext.h>

#import <LegacyComponents/TGModernGalleryTransitionView.h>

#import <LegacyComponents/TGMediaAssetsController.h>

@interface TGMediaPickerCell () <TGModernGalleryTransitionView>
{
    SMetaDisposable *_itemSelectedDisposable;
}
@end

@implementation TGMediaPickerCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.clipsToBounds = true;
        self.backgroundColor = [UIColor whiteColor];
        self.layer.zPosition = -1.0f;
        
        _imageView = [[TGImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = true;
        [self addSubview:_imageView];
        
        if (@available(iOS 11.0, *)) {
            _imageView.accessibilityIgnoresInvertColors = true;
        }
        
        _typeIconView = [[UIImageView alloc] init];
        _typeIconView.contentMode = UIViewContentModeCenter;
        [self addSubview:_typeIconView];
        
        self.isAccessibilityElement = true;
    }
    return self;
}

- (void)setPallete:(TGMediaAssetsPallete *)pallete
{
    if (pallete == nil || _pallete == pallete)
        return;
    
    _pallete = pallete;
    self.backgroundColor = pallete.backgroundColor;
}

- (void)dealloc
{
    [_itemSelectedDisposable dispose];
}

- (void)setItem:(NSObject *)item signal:(SSignal *)signal
{
    _item = item;
    
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
        
        __weak TGMediaPickerCell *weakSelf = self;
        [self setChecked:[self.selectionContext isItemSelected:(id<TGMediaSelectableItem>)item] animated:false];
        [_itemSelectedDisposable setDisposable:[[self.selectionContext itemInformativeSelectedSignal:(id<TGMediaSelectableItem>)item] startWithNext:^(TGMediaSelectionChange *next)
        {
            __strong TGMediaPickerCell *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (next.sender != strongSelf->_checkButton)
                [strongSelf setChecked:next.selected animated:next.animated];
        }]];
    }
    
    if (_item == nil)
    {
        [_imageView reset];
        return;
    }
    
    [_imageView setSignal:signal];
}

- (void)checkButtonPressed
{
    [self.selectionContext setItem:(id<TGMediaSelectableItem>)self.item selected:!_checkButton.selected animated:false sender:_checkButton];
    bool value = [self.selectionContext isItemSelected:(id<TGMediaSelectableItem>)self.item];
    if (value != _checkButton.selected) {
        [_checkButton setSelected:value animated:true];
    }
}

- (void)setChecked:(bool)checked animated:(bool)animated
{
    [_checkButton setSelected:checked animated:animated];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [_imageView reset];
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (hidden == self.imageView.hidden)
        return;
    
    self.imageView.hidden = hidden;
    
    if (animated)
    {
        if (!hidden)
        {
            for (UIView *view in self.subviews)
            {
                if (view != self.imageView)
                    view.alpha = 0.0f;
            }
        }
        
        [UIView animateWithDuration:0.2 animations:^
        {
            if (!hidden)
            {
                for (UIView *view in self.subviews)
                {
                    if (view != self.imageView)
                        view.alpha = 1.0f;
                }
            }
        }];
    }
    else
    {
        for (UIView *view in self.subviews)
        {
            if (view != self.imageView)
                view.alpha = hidden ? 0.0f : 1.0f;
        }
    }
}

- (UIImage *)transitionImage
{
    if (fabs(self.imageView.image.size.width - self.imageView.image.size.height) > FLT_EPSILON)
    {
        CGFloat scale = 1.0f;
        CGSize scaledBoundsSize = CGSizeZero;
        CGSize scaledImageSize = CGSizeZero;
        
        if (self.imageView.image.size.width > self.imageView.image.size.height)
        {
            scale = self.frame.size.height / self.imageView.image.size.height;
            scaledBoundsSize = CGSizeMake(self.frame.size.width / scale, self.imageView.image.size.height);
            
            scaledImageSize = CGSizeMake(self.imageView.image.size.width * scale, self.imageView.image.size.height * scale);
            
            if (scaledImageSize.width < self.frame.size.width)
            {
                scale = self.frame.size.width / self.imageView.image.size.width;
                scaledBoundsSize = CGSizeMake(self.imageView.image.size.width, self.frame.size.height / scale);
            }
        }
        else
        {
            scale = self.frame.size.width / self.imageView.image.size.width;
            scaledBoundsSize = CGSizeMake(self.imageView.image.size.width, self.frame.size.height / scale);
            
            scaledImageSize = CGSizeMake(self.imageView.image.size.width * scale, self.imageView.image.size.height * scale);
            
            if (scaledImageSize.width < self.frame.size.width)
            {
                scale = self.frame.size.height / self.imageView.image.size.height;
                scaledBoundsSize = CGSizeMake(self.frame.size.width / scale, self.imageView.image.size.height);
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(self.frame.size.width, self.frame.size.height), true, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextScaleCTM(context, scale, scale);
        [self.imageView.image drawInRect:CGRectMake((scaledBoundsSize.width - self.imageView.image.size.width) / 2,
                                                    (scaledBoundsSize.height - self.imageView.image.size.height) / 2,
                                                    self.imageView.image.size.width,
                                                    self.imageView.image.size.height)];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return image;
    }
    
    return self.imageView.image;
}

- (void)layoutSubviews
{
    CGAffineTransform transform = _imageView.transform;
    _imageView.transform = CGAffineTransformIdentity;
    _imageView.frame = self.bounds;
    _imageView.transform = transform;
    
    _typeIconView.frame = CGRectMake(2.0, self.frame.size.height - 19 - 2, 19, 19);
    
    _checkButton.frame = (CGRect){ { self.frame.size.width - _checkButton.frame.size.width - 2, 2 }, _checkButton.frame.size };
}

@end
