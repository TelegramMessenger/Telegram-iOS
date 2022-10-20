#import "TGClipboardGalleryPhotoItemView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGStringUtils.h"

#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>

#import <LegacyComponents/TGModernGalleryZoomableScrollView.h>
#import <LegacyComponents/TGMessageImageViewOverlayView.h>
#import <LegacyComponents/TGImageView.h>

#import <LegacyComponents/TGMediaSelectionContext.h>

#import "TGClipboardGalleryPhotoItem.h"

@interface TGClipboardGalleryPhotoItemView ()
{
    UIView *_temporaryRepView;
    
    SMetaDisposable *_attributesDisposable;
}
@end

@implementation TGClipboardGalleryPhotoItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _imageView = [[TGModernGalleryImageItemImageView alloc] init];
        [self.scrollView addSubview:_imageView];
    }
    return self;
}

- (void)dealloc
{
    [_attributesDisposable dispose];
}

- (void)setHiddenAsBeingEdited:(bool)hidden
{
    self.imageView.hidden = hidden;
    _temporaryRepView.hidden = hidden;
}

- (void)prepareForRecycle
{
    _imageView.hidden = false;
    [_imageView reset];
}

- (void)setItem:(TGClipboardGalleryPhotoItem *)item synchronously:(bool)synchronously
{
    [super setItem:item synchronously:synchronously];
    
    _imageSize = item.image.size;
    [self reset];
    
    if (item.image == nil)
    {
        [self.imageView reset];
    }
    else
    {
        __weak TGClipboardGalleryPhotoItemView *weakSelf = self;
        void (^fadeOutRepView)(void) = ^
        {
            __strong TGClipboardGalleryPhotoItemView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf->_temporaryRepView == nil)
                return;
            
            UIView *repView = strongSelf->_temporaryRepView;
            strongSelf->_temporaryRepView = nil;
            [UIView animateWithDuration:0.2f animations:^
             {
                 repView.alpha = 0.0f;
             } completion:^(__unused BOOL finished)
             {
                 [repView removeFromSuperview];
             }];
        };
        
        SSignal *assetSignal = [SSignal single:item.image];
        
        SSignal *imageSignal = assetSignal;
        if (item.editingContext != nil)
        {
            imageSignal = [[[item.editingContext imageSignalForItem:item.editableMediaItem] deliverOn:[SQueue mainQueue]] mapToSignal:^SSignal *(id result)
            {
                __strong TGClipboardGalleryPhotoItemView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return [SSignal complete];
                
                if (result == nil)
                {
                    return [[assetSignal deliverOn:[SQueue mainQueue]] afterNext:^(__unused id next)
                    {
                        fadeOutRepView();
                    }];
                }
                else if ([result isKindOfClass:[UIView class]])
                {
                    [strongSelf _setTemporaryRepView:result];
                    return [[SSignal single:nil] deliverOn:[SQueue mainQueue]];
                }
                else
                {
                    return [[[SSignal single:result] deliverOn:[SQueue mainQueue]] afterNext:^(__unused id next)
                    {
                        fadeOutRepView();
                    }];
                }
            }];
        }
        
        
        [self.imageView setSignal:[[imageSignal deliverOn:[SQueue mainQueue]] afterNext:^(id next)
        {
            __strong TGClipboardGalleryPhotoItemView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if ([next isKindOfClass:[UIImage class]])
                strongSelf->_imageSize = ((UIImage *)next).size;
            
            [strongSelf reset];
        }]];
    }
}

- (void)_setTemporaryRepView:(UIView *)view
{
    [_temporaryRepView removeFromSuperview];
    _temporaryRepView = view;
    
    _imageSize = TGScaleToSize(view.frame.size, self.containerView.frame.size);
    
    view.hidden = self.imageView.hidden;
    view.frame = CGRectMake((self.containerView.frame.size.width - _imageSize.width) / 2.0f, (self.containerView.frame.size.height - _imageSize.height) / 2.0f, _imageSize.width, _imageSize.height);
    
    [self.containerView addSubview:view];
}

- (void)singleTap
{
    if ([self.item conformsToProtocol:@protocol(TGModernGallerySelectableItem)])
    {
        TGMediaSelectionContext *selectionContext = ((id<TGModernGallerySelectableItem>)self.item).selectionContext;
        id<TGMediaSelectableItem> item = ((id<TGModernGallerySelectableItem>)self.item).selectableMediaItem;
        
        [selectionContext toggleItemSelection:item animated:true sender:nil success:nil];
    }
    else
    {
        id<TGModernGalleryItemViewDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(itemViewDidRequestInterfaceShowHide:)])
            [delegate itemViewDidRequestInterfaceShowHide:self];
    }
}

- (UIView *)footerView
{
    return nil;
}

- (SSignal *)contentAvailabilityStateSignal
{
    return [SSignal single:@true];
}

- (CGSize)contentSize
{
    return _imageSize;
}

- (UIView *)contentView
{
    return _imageView;
}

- (UIView *)transitionContentView
{
    if (_temporaryRepView != nil)
        return _temporaryRepView;
    
    return [self contentView];
}

- (UIView *)transitionView
{
    return self.containerView;
}

- (CGRect)transitionViewContentRect
{
    UIView *contentView = [self transitionContentView];
    return [contentView convertRect:contentView.bounds toView:[self transitionView]];
}

@end
