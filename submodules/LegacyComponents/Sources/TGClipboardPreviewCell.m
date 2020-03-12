#import "TGClipboardPreviewCell.h"

#import <LegacyComponents/TGMediaEditingContext.h>
#import <LegacyComponents/TGMediaSelectionContext.h>

#import <LegacyComponents/TGCheckButtonView.h>

#import <LegacyComponents/TGModernGalleryTransitionView.h>

NSString *const TGClipboardPreviewCellIdentifier = @"TGClipboardPreviewCell";
const CGFloat TGClipboardCellCornerRadius = 5.5f;

@interface TGClipboardPreviewCell () <TGModernGalleryTransitionView>
{
    TGCheckButtonView *_checkButton;
    UIImageView *_cornersView;
    
    SMetaDisposable *_itemSelectedDisposable;
}
@end

@implementation TGClipboardPreviewCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor whiteColor];
        self.clipsToBounds = true;
        
        _imageView = [[TGImageView alloc] initWithFrame:self.bounds];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        [self addSubview:_imageView];
        
        _cornersView = [[UIImageView alloc] init];
        _cornersView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _cornersView.frame = self.bounds;
        [self addSubview:_cornersView];
    }
    return self;
}

- (void)setCornersImage:(UIImage *)cornersImage
{
    _cornersView.image = cornersImage;
}

- (void)setImage:(UIImage *)image signal:(SSignal *)signal hasCheck:(bool)hasCheck
{
    _image = image;
    
    if (self.selectionContext != nil)
    {
        if (_checkButton == nil && hasCheck)
        {
            _checkButton = [[TGCheckButtonView alloc] initWithStyle:TGCheckButtonStyleMedia];
            [_checkButton addTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_checkButton];
        }
        
        if (_itemSelectedDisposable == nil)
            _itemSelectedDisposable = [[SMetaDisposable alloc] init];
        
        [self setChecked:[self.selectionContext isItemSelected:(id<TGMediaSelectableItem>)_image] animated:false];
        __weak TGClipboardPreviewCell *weakSelf = self;
        [_itemSelectedDisposable setDisposable:[[self.selectionContext itemInformativeSelectedSignal:(id<TGMediaSelectableItem>)_image] startWithNext:^(TGMediaSelectionChange *next)
        {
            __strong TGClipboardPreviewCell *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (next.sender != strongSelf->_checkButton)
                [strongSelf setChecked:next.selected animated:next.animated];
        }]];
        
        _checkButton.hidden = !hasCheck;
    }
    
    if (_image == nil)
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
    [_checkButton setSelected:!_checkButton.selected animated:true];
    
    [self.selectionContext setItem:(id<TGMediaSelectableItem>)_image selected:_checkButton.selected animated:false sender:_checkButton];
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
    if (hidden != _imageView.hidden)
    {
        _imageView.hidden = hidden;
        
        if (animated)
        {
            if (!hidden)
            {
                for (UIView *view in self.subviews)
                {
                    if (view != _imageView && view != _cornersView)
                        view.alpha = 0.0f;
                }
            }
            
            [UIView animateWithDuration:0.2 animations:^
             {
                 if (!hidden)
                 {
                     for (UIView *view in self.subviews)
                     {
                         if (view != _imageView && view != _cornersView)
                             view.alpha = 1.0f;
                     }
                 }
             }];
        }
        else
        {
            for (UIView *view in self.subviews)
            {
                if (view != _imageView && view != _cornersView)
                    view.alpha = hidden ? 0.0f : 1.0f;
            }
        }
    }
}

- (void)layoutSubviews
{
    _imageView.frame = self.bounds;
    
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
}

- (UIImage *)transitionImage
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
    
    CGRect rect = self.bounds;
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) cornerRadius:TGClipboardCellCornerRadius] addClip];
    
    CGContextScaleCTM(context, scale, scale);
    [self.imageView.image drawInRect:CGRectMake((scaledBoundsSize.width - self.imageView.image.size.width) / 2,
                                                (scaledBoundsSize.height - self.imageView.image.size.height) / 2,
                                                self.imageView.image.size.width,
                                                self.imageView.image.size.height)];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
