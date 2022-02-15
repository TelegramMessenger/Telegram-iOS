#import "TGMediaPickerGalleryPhotoItemView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGStringUtils.h"

#import <LegacyComponents/TGMediaAsset.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>

#import <LegacyComponents/TGModernGalleryZoomableScrollView.h>
#import <LegacyComponents/TGMessageImageViewOverlayView.h>
#import <LegacyComponents/TGImageView.h>

#import <LegacyComponents/TGMediaSelectionContext.h>
#import <LegacyComponents/PGPhotoEditorValues.h>

#import <LegacyComponents/TGMediaPickerGalleryVideoItem.h>

#import "TGMediaPickerGalleryPhotoItem.h"

#import "TGPhotoEntitiesContainerView.h"
#import "TGPhotoPaintController.h"

#import <LegacyComponents/TGMenuView.h>

#import "TGPaintFaceDetector.h"

@interface TGMediaPickerGalleryPhotoItemView ()
{
    TGMediaPickerGalleryFetchResultItem *_fetchItem;
    SMetaDisposable *_facesDisposable;
    
    UILabel *_fileInfoLabel;
    
    TGMessageImageViewOverlayView *_progressView;
    bool _progressVisible;
    void (^_currentAvailabilityObserver)(bool);
    
    UIView *_temporaryRepView;
    
    UIView *_contentView;
    UIView *_contentWrapperView;
    TGPhotoEntitiesContainerView *_entitiesContainerView;
    
    SMetaDisposable *_adjustmentsDisposable;
    SMetaDisposable *_attributesDisposable;
    
    TGMenuContainerView *_tooltipContainerView;
}

@property (nonatomic, strong) TGMediaPickerGalleryPhotoItem *item;

@end

@implementation TGMediaPickerGalleryPhotoItemView

@dynamic item;
@synthesize safeAreaInset = _safeAreaInset;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _facesDisposable = [[SMetaDisposable alloc] init];
        
        __weak TGMediaPickerGalleryPhotoItemView *weakSelf = self;
        _imageView = [[TGModernGalleryImageItemImageView alloc] init];
        _imageView.clipsToBounds = true;
        _imageView.progressChanged = ^(CGFloat value)
        {
            __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
            [strongSelf setProgressVisible:value < 1.0f - FLT_EPSILON value:value animated:true];
        };
        _imageView.availabilityStateChanged = ^(bool available)
        {
            __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                if (strongSelf->_currentAvailabilityObserver)
                    strongSelf->_currentAvailabilityObserver(available);
            }
        };
        [self.scrollView addSubview:_imageView];
        
        _contentView = [[UIView alloc] init];
        [_imageView addSubview:_contentView];
        
        _contentWrapperView = [[UIView alloc] init];
        [_contentView addSubview:_contentWrapperView];
        
        _entitiesContainerView = [[TGPhotoEntitiesContainerView alloc] init];
        _entitiesContainerView.userInteractionEnabled = false;
        [_contentWrapperView addSubview:_entitiesContainerView];
        
        _fileInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 20)];
        _fileInfoLabel.backgroundColor = [UIColor clearColor];
        _fileInfoLabel.font = TGSystemFontOfSize(13);
        _fileInfoLabel.textAlignment = NSTextAlignmentCenter;
        _fileInfoLabel.textColor = [UIColor whiteColor];
        
        _adjustmentsDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_adjustmentsDisposable dispose];
    [_attributesDisposable dispose];
    [_facesDisposable dispose];
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
    [self setProgressVisible:false value:0.0f animated:false];
}

- (id<TGModernGalleryItem>)item {
    if (_fetchItem != nil) {
        return _fetchItem;
    } else {
        return _item;
    }
}

- (void)setItem:(TGMediaPickerGalleryPhotoItem *)item synchronously:(bool)synchronously
{
    if ([item isKindOfClass:[TGMediaPickerGalleryFetchResultItem class]]) {
        _fetchItem = (TGMediaPickerGalleryFetchResultItem *)item;
        item = (TGMediaPickerGalleryPhotoItem *)[_fetchItem backingItem];
    }
    
    [super setItem:item synchronously:synchronously];
    
    _entitiesContainerView.stickersContext = item.stickersContext;
    
    _imageSize = item.asset.originalSize;
    [self reset];
    
    if (item.asset == nil)
    {
        [self.imageView reset];
    }
    else
    {
        __weak TGMediaPickerGalleryPhotoItemView *weakSelf = self;
        void (^fadeOutRepView)(void) = ^
        {
            __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
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

        SSignal *assetSignal = [SSignal single:nil];
        if ([item.asset isKindOfClass:[TGMediaAsset class]])
        {
            assetSignal = [TGMediaAssetImageSignals imageForAsset:(TGMediaAsset *)item.asset imageType:(item.immediateThumbnailImage != nil) ? TGMediaAssetImageTypeScreen : TGMediaAssetImageTypeFastScreen size:CGSizeMake(1280, 1280)];
        }
        else
        {
            assetSignal = [item.asset screenImageSignal:0.0];
        }
        
        SSignal *imageSignal = assetSignal;
        if (item.editingContext != nil)
        {
            imageSignal = [[[item.editingContext imageSignalForItem:item.editableMediaItem] deliverOn:[SQueue mainQueue]] mapToSignal:^SSignal *(id result)
            {
                __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
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
            
            SSignal *adjustmentsSignal = [item.editingContext adjustmentsSignalForItem:item.editableMediaItem];
            [_adjustmentsDisposable setDisposable:[[adjustmentsSignal deliverOn:[SQueue mainQueue]] startWithNext:^(__unused id<TGMediaEditAdjustments> next)
            {
                __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf layoutEntities];
                [strongSelf->_entitiesContainerView setupWithPaintingData:next.paintingData];
            }]];
        }
        
        if (item.immediateThumbnailImage != nil)
        {
            imageSignal = [[SSignal single:item.immediateThumbnailImage] then:imageSignal];
            item.immediateThumbnailImage = nil;
        }
        
        [self.imageView setSignal:[[imageSignal deliverOn:[SQueue mainQueue]] afterNext:^(id next)
        {
            __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if ([next isKindOfClass:[UIImage class]])
            {
                strongSelf->_imageSize = ((UIImage *)next).size;
                [strongSelf layoutEntities];
            }
            
            [strongSelf reset];

        }]];
        
        if (!item.asFile) {
            [_facesDisposable setDisposable:[[TGPaintFaceDetector detectFacesInItem:item.editableMediaItem editingContext:item.editingContext] startWithNext:nil]];
            
            return;
        }
        
        _fileInfoLabel.text = nil;
        
        if (_attributesDisposable == nil)
            _attributesDisposable = [[SMetaDisposable alloc] init];
        
        if ([item.asset isKindOfClass:[TGMediaAsset class]])
        {
            [_attributesDisposable setDisposable:[[[TGMediaAssetImageSignals fileAttributesForAsset:(TGMediaAsset *)item.asset] deliverOn:[SQueue mainQueue]] startWithNext:^(TGMediaAssetImageFileAttributes *next)
            {
                __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                NSString *extension = next.fileName.pathExtension.uppercaseString;
                NSString *fileSize = [TGStringUtils stringForFileSize:next.fileSize precision:2];
                NSString *dimensions = [NSString stringWithFormat:@"%dx%d", (int)next.dimensions.width, (int)next.dimensions.height];
                
                if (next.fileSize > 0) {
                    strongSelf->_fileInfoLabel.text = [NSString stringWithFormat:@"%@ • %@ • %@", extension, fileSize, dimensions];
                } else {
                    strongSelf->_fileInfoLabel.text = dimensions;
                }
            }]];
        }
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
    
    [self layoutEntities];
}

- (void)setProgressVisible:(bool)progressVisible value:(CGFloat)value animated:(bool)animated
{
    _progressVisible = progressVisible;
    
    if (progressVisible && _progressView == nil)
    {
        _progressView = [[TGMessageImageViewOverlayView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 50.0f, 50.0f)];
        _progressView.userInteractionEnabled = false;
        
        _progressView.frame = (CGRect){{CGFloor((self.frame.size.width - _progressView.frame.size.width) / 2.0f), CGFloor((self.frame.size.height - _progressView.frame.size.height) / 2.0f)}, _progressView.frame.size};
    }
    
    if (progressVisible)
    {
        if (_progressView.superview == nil)
            [self.containerView addSubview:_progressView];
        
        _progressView.alpha = 1.0f;
    }
    else if (_progressView.superview != nil)
    {
        if (animated)
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _progressView.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                    [_progressView removeFromSuperview];
            }];
        }
        else
            [_progressView removeFromSuperview];
    }
    
    [_progressView setProgress:value cancelEnabled:false animated:animated];
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
    if (((TGMediaPickerGalleryItem *)self.item).asFile)
        return _fileInfoLabel;
    
    return nil;
}

- (SSignal *)contentAvailabilityStateSignal
{
    __weak TGMediaPickerGalleryPhotoItemView *weakSelf = self;
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            [subscriber putNext:@([strongSelf->_imageView isAvailableNow])];
            strongSelf->_currentAvailabilityObserver = ^(bool available)
            {
                [subscriber putNext:@(available)];
            };
        }

        return nil;
    }];
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

- (void)toggleSendAsGif
{
    CGSize originalSize = self.item.asset.originalSize;
    PGPhotoEditorValues *adjustments = (PGPhotoEditorValues *)[self.item.editingContext adjustmentsForItem:self.item.editableMediaItem];
    CGRect cropRect = adjustments.cropRect;
    if (cropRect.size.width < FLT_EPSILON)
        cropRect = CGRectMake(0.0f, 0.0f, originalSize.width, originalSize.height);
    
    PGPhotoEditorValues *updatedAdjustments = [PGPhotoEditorValues editorValuesWithOriginalSize:originalSize cropRect:cropRect cropRotation:adjustments.cropRotation cropOrientation:adjustments.cropOrientation cropLockedAspectRatio:adjustments.cropLockedAspectRatio cropMirrored:adjustments.cropMirrored toolValues:adjustments.toolValues paintingData:adjustments.paintingData sendAsGif:!adjustments.sendAsGif];
    [self.item.editingContext setAdjustments:updatedAdjustments forItem:self.item.editableMediaItem];
    
    bool sendAsGif = !adjustments.sendAsGif;
    if (sendAsGif)
    {
        if (UIInterfaceOrientationIsPortrait([[LegacyComponentsGlobals provider] applicationStatusBarOrientation]))
        {
            UIView *parentView = [self.delegate itemViewDidRequestInterfaceView:self];
            
            _tooltipContainerView = [[TGMenuContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, parentView.frame.size.width, parentView.frame.size.height)];
            [parentView addSubview:_tooltipContainerView];
            
            NSMutableArray *actions = [[NSMutableArray alloc] init];
            [actions addObject:[[NSDictionary alloc] initWithObjectsAndKeys:TGLocalized(@"MediaPicker.LivePhotoDescription"), @"title", nil]];
            _tooltipContainerView.menuView.forceArrowOnTop = true;
            _tooltipContainerView.menuView.multiline = true;
            [_tooltipContainerView.menuView setButtonsAndActions:actions watcherHandle:nil];
            _tooltipContainerView.menuView.buttonHighlightDisabled = true;
            [_tooltipContainerView.menuView sizeToFit];
            
            CGRect iconViewFrame = CGRectMake(12, 188 + _safeAreaInset.top, 40, 40);
            [_tooltipContainerView showMenuFromRect:iconViewFrame animated:false];
        }
    }
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    [self layoutEntities];
}

- (void)layoutEntities {
    if (self.item == nil) {
        return;
    }
    TGVideoEditAdjustments *adjustments = (TGVideoEditAdjustments *)[self.item.editingContext adjustmentsForItem:self.item.editableMediaItem];
    CGRect cropRect = CGRectMake(0, 0, self.item.asset.originalSize.width, self.item.asset.originalSize.height);
    CGFloat rotation = 0.0;
    UIImageOrientation orientation = UIImageOrientationUp;
    bool mirrored = false;
    if (adjustments != nil)
    {
        cropRect = adjustments.cropRect;
        orientation = adjustments.cropOrientation;
        rotation = adjustments.cropRotation;
        mirrored = adjustments.cropMirrored;
    }
    
    [self _layoutPlayerViewWithCropRect:cropRect orientation:orientation rotation:rotation mirrored:mirrored];
}

- (void)_layoutPlayerViewWithCropRect:(CGRect)cropRect orientation:(UIImageOrientation)orientation rotation:(CGFloat)rotation mirrored:(bool)mirrored
{
    CGSize originalSize = self.item.asset.originalSize;
    
    CGSize rotatedCropSize = cropRect.size;
    if (orientation == UIImageOrientationLeft || orientation == UIImageOrientationRight)
        rotatedCropSize = CGSizeMake(rotatedCropSize.height, rotatedCropSize.width);
    
    CGSize containerSize = _imageSize;
    CGSize fittedSize = TGScaleToSize(rotatedCropSize, containerSize);
    CGRect previewFrame = CGRectMake((containerSize.width - fittedSize.width) / 2, (containerSize.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(TGRotationForOrientation(orientation));
    _contentView.transform = rotationTransform;
    _contentView.frame = previewFrame;
    
    CGSize fittedContentSize = [TGPhotoPaintController fittedContentSize:cropRect orientation:orientation originalSize:originalSize];
    CGRect fittedCropRect = [TGPhotoPaintController fittedCropRect:cropRect originalSize:originalSize keepOriginalSize:false];
    _contentWrapperView.frame = CGRectMake(0.0f, 0.0f, fittedContentSize.width, fittedContentSize.height);
    
    CGFloat contentScale = _contentView.bounds.size.width / fittedCropRect.size.width;
    _contentWrapperView.transform = CGAffineTransformMakeScale(contentScale, contentScale);
    _contentWrapperView.frame = CGRectMake(0.0f, 0.0f, _contentView.bounds.size.width, _contentView.bounds.size.height);
    
    CGRect rect = [TGPhotoPaintController fittedCropRect:cropRect originalSize:originalSize keepOriginalSize:true];
    _entitiesContainerView.frame = CGRectMake(0, 0, rect.size.width, rect.size.height);
    _entitiesContainerView.transform = CGAffineTransformMakeRotation(rotation);
    
    CGSize fittedOriginalSize = TGScaleToSize(originalSize, [TGPhotoPaintController maximumPaintingSize]);
    CGSize rotatedSize = TGRotatedContentSize(fittedOriginalSize, rotation);
    CGPoint centerPoint = CGPointMake(rotatedSize.width / 2.0f, rotatedSize.height / 2.0f);
    
    CGFloat scale = fittedOriginalSize.width / originalSize.width;
    CGPoint offset = TGPaintSubtractPoints(centerPoint, [TGPhotoPaintController fittedCropRect:cropRect centerScale:scale]);
    
    CGPoint boundsCenter = TGPaintCenterOfRect(_contentWrapperView.bounds);
    _entitiesContainerView.center = TGPaintAddPoints(boundsCenter, offset);
}

@end
