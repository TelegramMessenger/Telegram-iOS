#import <LegacyComponents/LegacyComponents.h>
#import "TGMediaPickerGalleryPhotoItemView.h"

#import "LegacyComponentsInternal.h"
#import <LegacyComponents/TGFont.h>
#import <LegacyComponents/TGStringUtils.h>

#import <LegacyComponents/TGMediaAsset.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGPhotoEditorInterfaceAssets.h>

#import <LegacyComponents/TGModernGalleryZoomableScrollView.h>
#import <LegacyComponents/TGMessageImageViewOverlayView.h>
#import <LegacyComponents/TGImageView.h>

#import <LegacyComponents/TGMediaSelectionContext.h>
#import <LegacyComponents/PGPhotoEditorValues.h>

#import <LegacyComponents/TGMediaPickerGalleryVideoItem.h>

#import <LegacyComponents/TGMediaPickerGalleryPhotoItem.h>

#import "TGPhotoDrawingController.h"

#import <LegacyComponents/TGMenuView.h>

#import "TGPaintFaceDetector.h"
#import <AVFoundation/AVFoundation.h>
#import <math.h>

@interface TGMediaPickerGalleryLivePhotoVideoView : UIView

@property (nonatomic, strong) AVPlayer *player;

@end

@implementation TGMediaPickerGalleryLivePhotoVideoView

+ (Class)layerClass
{
    return [AVPlayerLayer class];
}

- (AVPlayer *)player
{
    return ((AVPlayerLayer *)self.layer).player;
}

- (void)setPlayer:(AVPlayer *)player
{
    ((AVPlayerLayer *)self.layer).player = player;
    ((AVPlayerLayer *)self.layer).videoGravity = AVLayerVideoGravityResizeAspectFill;
}

@end

@interface TGMediaPickerGalleryPhotoItemView () <UIGestureRecognizerDelegate>
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
    UIView<TGPhotoDrawingEntitiesView> *_entitiesView;
    
    SMetaDisposable *_adjustmentsDisposable;
    SMetaDisposable *_attributesDisposable;
    SMetaDisposable *_liveVideoItemDisposable;
    
    TGMenuContainerView *_tooltipContainerView;
    
    TGMediaLivePhotoMode _livePhotoMode;
    
    TGMediaPickerGalleryLivePhotoVideoView *_livePhotoVideoView;
    AVPlayer *_livePhotoPlayer;
    id _livePhotoDidPlayToEndObserver;
    UILongPressGestureRecognizer *_livePhotoPressGestureRecognizer;
    
    bool _livePhotoIsLoadingPlayer;
    bool _livePhotoPlaybackLooping;
    bool _livePhotoIsHolding;
    bool _livePhotoPendingPlayback;
    bool _livePhotoPendingPlaybackLooping;
        
    CADisplayLink *_livePhotoBounceDisplayLink;
    bool _livePhotoBounceManualReverse;
    bool _livePhotoBouncePlayingBackwards;
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

        _fileInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 20)];
        _fileInfoLabel.backgroundColor = [UIColor clearColor];
        _fileInfoLabel.font = TGSystemFontOfSize(13);
        _fileInfoLabel.textAlignment = NSTextAlignmentCenter;
        _fileInfoLabel.textColor = [UIColor whiteColor];
        
        _adjustmentsDisposable = [[SMetaDisposable alloc] init];
        _liveVideoItemDisposable = [[SMetaDisposable alloc] init];
        
        _livePhotoMode = TGMediaLivePhotoModeOff;
    }
    return self;
}

- (void)dealloc
{
    [self stopAndCleanupLivePhotoPlayback];
    
    [_adjustmentsDisposable dispose];
    [_attributesDisposable dispose];
    [_facesDisposable dispose];
    [_liveVideoItemDisposable dispose];
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
    
    [self stopAndCleanupLivePhotoPlayback];
    _livePhotoMode = TGMediaLivePhotoModeOff;
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
    
    [self stopAndCleanupLivePhotoPlayback];
    _livePhotoMode = TGMediaLivePhotoModeOff;
    
    if (_entitiesView == nil) {
        _entitiesView = [item.stickersContext drawingEntitiesViewWithSize:item.asset.originalSize];
        _entitiesView.userInteractionEnabled = false;
        [_contentWrapperView addSubview:_entitiesView];
    }
    
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
            [_adjustmentsDisposable setDisposable:[[adjustmentsSignal deliverOn:[SQueue mainQueue]] startStrictWithNext:^(__unused id<TGMediaEditAdjustments> next)
            {
                __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf layoutEntities];
                [strongSelf->_entitiesView setupWithEntitiesData:next.paintingData.entitiesData];
            } file:__FILE_NAME__ line:__LINE__]];
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
            [strongSelf layoutLivePhotoVideoView];

        }]];
        
//        if (!item.asFile) {
//            [_facesDisposable setDisposable:[[TGPaintFaceDetector detectFacesInItem:item.editableMediaItem editingContext:item.editingContext] startStrictWithNext:nil file:__FILE_NAME__ line:__LINE__]];
//            
//            return;
//        }
        
        _fileInfoLabel.text = nil;
        
        if (_attributesDisposable == nil)
            _attributesDisposable = [[SMetaDisposable alloc] init];
        
        if ([item.asset isKindOfClass:[TGMediaAsset class]])
        {
            [_attributesDisposable setDisposable:[[[TGMediaAssetImageSignals fileAttributesForAsset:(TGMediaAsset *)item.asset] deliverOn:[SQueue mainQueue]] startStrictWithNext:^(TGMediaAssetImageFileAttributes *next)
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
            } file:__FILE_NAME__ line:__LINE__]];
        }
    }
}

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
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

- (void)livePhotoModeButtonPressed
{
    TGMediaLivePhotoMode nextMode = (TGMediaLivePhotoMode)((_livePhotoMode + 1) % 4);
    
    
    if (self.item.editingContext != nil)
    {
        id<TGMediaEditableItem> item = ((id<TGModernGalleryEditableItem>)self.item).editableMediaItem;
        [self.item.editingContext setLivePhotoMode:nextMode forItem:item];
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
    [self layoutLivePhotoVideoView];
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
    
    CGSize fittedContentSize = [TGPhotoDrawingController fittedContentSize:cropRect orientation:orientation originalSize:originalSize];
    CGRect fittedCropRect = [TGPhotoDrawingController fittedCropRect:cropRect originalSize:originalSize keepOriginalSize:false];
    _contentWrapperView.frame = CGRectMake(0.0f, 0.0f, fittedContentSize.width, fittedContentSize.height);
    
    CGFloat contentScale = _contentView.bounds.size.width / fittedCropRect.size.width;
    _contentWrapperView.transform = CGAffineTransformMakeScale(contentScale, contentScale);
    _contentWrapperView.frame = CGRectMake(0.0f, 0.0f, _contentView.bounds.size.width, _contentView.bounds.size.height);
    
    CGRect rect = [TGPhotoDrawingController fittedCropRect:cropRect originalSize:originalSize keepOriginalSize:true];
    _entitiesView.frame = CGRectMake(0, 0, rect.size.width, rect.size.height);
    _entitiesView.transform = CGAffineTransformMakeRotation(rotation);
    
    CGSize fittedOriginalSize = TGScaleToSize(originalSize, [TGPhotoDrawingController maximumPaintingSize]);
    CGSize rotatedSize = TGRotatedContentSize(fittedOriginalSize, rotation);
    CGPoint centerPoint = CGPointMake(rotatedSize.width / 2.0f, rotatedSize.height / 2.0f);
    
    CGFloat scale = fittedOriginalSize.width / originalSize.width;
    CGPoint offset = TGPaintSubtractPoints(centerPoint, [TGPhotoDrawingController fittedCropRect:cropRect centerScale:scale]);
    
    CGPoint boundsCenter = TGPaintCenterOfRect(_contentWrapperView.bounds);
    _entitiesView.center = TGPaintAddPoints(boundsCenter, offset);
}

- (bool)isCurrentAssetLivePhoto
{
    if (![self.item.asset isKindOfClass:[TGMediaAsset class]])
        return false;
    
    return (((TGMediaAsset *)self.item.asset).subtypes & TGMediaAssetSubtypePhotoLive) != 0;
}

- (void)layoutLivePhotoVideoView
{
    if (_livePhotoVideoView != nil)
        _livePhotoVideoView.frame = _imageView.bounds;
}

- (void)setLivePhotoMode:(TGMediaLivePhotoMode)mode
{
    if (_livePhotoMode == mode)
        return;
    
    _livePhotoMode = mode;
    
    if (_livePhotoMode == TGMediaLivePhotoModeLive)
    {
        [self ensureLivePhotoPressRecognizer];
        [self ensureLivePhotoPlayer];
        [self playLivePhotoVideoLooping:false fromStart:true];
    }
    else if (_livePhotoMode == TGMediaLivePhotoModeLoop)
    {
        [self stopLivePhotoBounceIfNeeded];
        [self removeLivePhotoPressRecognizer];
        [self ensureLivePhotoPlayer];
        [self playLivePhotoVideoLooping:true fromStart:true];
    }
    else if (_livePhotoMode == TGMediaLivePhotoModeBounce)
    {
        [self removeLivePhotoPressRecognizer];
        [self ensureLivePhotoPlayer];
        [self playLivePhotoVideoLooping:false fromStart:true];
    }
    else
    {
        [self stopLivePhotoBounceIfNeeded];
        [self stopAndHideLivePhotoVideo:true];
        [self removeLivePhotoPressRecognizer];
    }
}

- (void)ensureLivePhotoPlayer
{
    if (_livePhotoPlayer != nil || _livePhotoIsLoadingPlayer || ![self isCurrentAssetLivePhoto])
        return;
    
    _livePhotoIsLoadingPlayer = true;
    
    __weak TGMediaPickerGalleryPhotoItemView *weakSelf = self;
    [_liveVideoItemDisposable setDisposable:[[[TGMediaAssetImageSignals playerItemForVideoAsset:(TGMediaAsset *)self.item.asset] deliverOn:[SQueue mainQueue]] startStrictWithNext:^(AVPlayerItem *playerItem)
    {
        __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
        if (strongSelf == nil || ![playerItem isKindOfClass:[AVPlayerItem class]])
            return;
        
        strongSelf->_livePhotoIsLoadingPlayer = false;
        
        [strongSelf removeLivePhotoPlaybackObserver];
        
        strongSelf->_livePhotoPlayer = [AVPlayer playerWithPlayerItem:playerItem];
        strongSelf->_livePhotoPlayer.actionAtItemEnd = AVPlayerActionAtItemEndPause;
        strongSelf->_livePhotoPlayer.muted = true;
        
        [strongSelf ensureLivePhotoVideoView];
        strongSelf->_livePhotoVideoView.player = strongSelf->_livePhotoPlayer;
        
        __weak TGMediaPickerGalleryPhotoItemView *observerWeakSelf = strongSelf;
        strongSelf->_livePhotoDidPlayToEndObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:playerItem queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note)
        {
            __strong TGMediaPickerGalleryPhotoItemView *observerStrongSelf = observerWeakSelf;
            [observerStrongSelf livePhotoPlayerItemDidPlayToEnd];
        }];
        
        if (strongSelf->_livePhotoPendingPlayback)
        {
            bool shouldLoop = strongSelf->_livePhotoPendingPlaybackLooping;
            strongSelf->_livePhotoPendingPlayback = false;
            [strongSelf playLivePhotoVideoLooping:shouldLoop fromStart:true];
        }
    } file:__FILE_NAME__ line:__LINE__]];
}

- (void)ensureLivePhotoVideoView
{
    if (_livePhotoVideoView != nil)
        return;
    
    _livePhotoVideoView = [[TGMediaPickerGalleryLivePhotoVideoView alloc] initWithFrame:_imageView.bounds];
    _livePhotoVideoView.alpha = 0.0f;
    _livePhotoVideoView.userInteractionEnabled = false;
    [_imageView insertSubview:_livePhotoVideoView aboveSubview:_contentView];
}

- (void)ensureLivePhotoPressRecognizer
{
    if (_livePhotoPressGestureRecognizer != nil)
        return;
    
    _livePhotoPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLivePhotoPress:)];
    _livePhotoPressGestureRecognizer.minimumPressDuration = 0.2f;
    _livePhotoPressGestureRecognizer.cancelsTouchesInView = false;
    _livePhotoPressGestureRecognizer.delegate = self;
    [self.scrollView addGestureRecognizer:_livePhotoPressGestureRecognizer];
}

- (void)removeLivePhotoPressRecognizer
{
    if (_livePhotoPressGestureRecognizer == nil)
        return;
    
    [self.scrollView removeGestureRecognizer:_livePhotoPressGestureRecognizer];
    _livePhotoPressGestureRecognizer = nil;
    _livePhotoIsHolding = false;
}

- (void)handleLivePhotoPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (_livePhotoMode != TGMediaLivePhotoModeLive || !self.gesturesEnabled)
        return;
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
            _livePhotoIsHolding = true;
            [self playLivePhotoVideoLooping:true fromStart:true];
            break;
        
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            _livePhotoIsHolding = false;
            [self stopAndHideLivePhotoVideo:true];
            break;
        
        default:
            break;
    }
}

- (void)playLivePhotoVideoLooping:(bool)looping fromStart:(bool)fromStart
{
    if (_livePhotoMode == TGMediaLivePhotoModeOff || ![self isCurrentAssetLivePhoto])
        return;
    
    [self ensureLivePhotoPlayer];
    [self ensureLivePhotoVideoView];
    
    if (_livePhotoPlayer == nil)
    {
        _livePhotoPendingPlayback = true;
        _livePhotoPendingPlaybackLooping = looping;
        return;
    }
    
    _livePhotoPlaybackLooping = looping;
    _livePhotoPendingPlayback = false;
    
    void (^playBlock)(void) = ^
    {
        _livePhotoVideoView.alpha = 1.0f;
        [_livePhotoPlayer play];
    };
    
    if (fromStart)
    {
        [_livePhotoPlayer seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(__unused BOOL finished)
        {
            playBlock();
        }];
    }
    else
    {
        playBlock();
    }
}

- (void)livePhotoPlayerItemDidPlayToEnd
{
    if (_livePhotoMode == TGMediaLivePhotoModeLoop)
    {
        [self playLivePhotoVideoLooping:true fromStart:true];
    }
    else if (_livePhotoMode == TGMediaLivePhotoModeBounce)
    {
        [self startLivePhotoBounceReversePlayback];
    }
    else if (_livePhotoPlaybackLooping && _livePhotoIsHolding)
    {
        [self playLivePhotoVideoLooping:true fromStart:true];
    }
    else
    {
        [self stopAndHideLivePhotoVideo:true];
    }
}

- (void)stopAndHideLivePhotoVideo:(bool)animated
{
    [self stopLivePhotoBounceIfNeeded];
    
    _livePhotoPlaybackLooping = false;
    _livePhotoPendingPlayback = false;
    _livePhotoPendingPlaybackLooping = false;
    
    [_livePhotoPlayer pause];
    
    if (_livePhotoPlayer != nil)
        [_livePhotoPlayer seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    
    if (_livePhotoVideoView == nil)
        return;
    
    if (animated)
    {
        [UIView animateWithDuration:0.2f animations:^
        {
            _livePhotoVideoView.alpha = 0.0f;
        }];
    }
    else
    {
        _livePhotoVideoView.alpha = 0.0f;
    }
}

- (void)removeLivePhotoPlaybackObserver
{
    if (_livePhotoDidPlayToEndObserver != nil)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:_livePhotoDidPlayToEndObserver];
        _livePhotoDidPlayToEndObserver = nil;
    }
}

- (void)stopAndCleanupLivePhotoPlayback
{
    [self removeLivePhotoPressRecognizer];
    [self stopAndHideLivePhotoVideo:false];
    
    [self removeLivePhotoPlaybackObserver];
    [_liveVideoItemDisposable setDisposable:nil];
    
    _livePhotoPlayer = nil;
    [_livePhotoVideoView removeFromSuperview];
    _livePhotoVideoView = nil;
    _livePhotoIsLoadingPlayer = false;
}

- (void)startLivePhotoBounceReversePlayback
{
    if (_livePhotoPlayer == nil || _livePhotoMode != TGMediaLivePhotoModeBounce || _livePhotoBouncePlayingBackwards)
        return;
        
    AVPlayerItem *item = _livePhotoPlayer.currentItem;
    if (item == nil)
        return;
    
    _livePhotoBounceManualReverse = false;
    _livePhotoBouncePlayingBackwards = true;
    
    if ([item canPlayReverse])
    {
        //_livePhotoPlayer.rate = -1.0f;
        [self startLivePhotoBounceMonitor];
        [_livePhotoPlayer playImmediatelyAtRate:-1.0];
        return;
    }
    
    _livePhotoBounceManualReverse = true;
    [_livePhotoPlayer pause];
    [self startLivePhotoBounceMonitor];
}

- (void)startLivePhotoBounceMonitor
{
    _livePhotoBounceDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(livePhotoBounceTick:)];
    _livePhotoBounceDisplayLink.preferredFramesPerSecond = 30;
    
    [_livePhotoBounceDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopLivePhotoBounceIfNeeded
{
    _livePhotoBouncePlayingBackwards = false;
    
    [_livePhotoBounceDisplayLink invalidate];
    _livePhotoBounceDisplayLink = nil;
    _livePhotoBounceManualReverse = false;
    
    if (_livePhotoPlayer.rate < 0.0f)
        [_livePhotoPlayer pause];
}

- (void)livePhotoBounceTick:(CADisplayLink *)displayLink
{
    if (_livePhotoPlayer == nil || _livePhotoMode != TGMediaLivePhotoModeBounce)
    {
        [self stopLivePhotoBounceIfNeeded];
        return;
    }
    
    CMTime currentTime = _livePhotoPlayer.currentTime;
    Float64 currentSeconds = CMTimeGetSeconds(currentTime);
    if (!isfinite(currentSeconds))
        return;
    
    if (_livePhotoBounceManualReverse)
    {
        CGFloat step = MAX(1.0f / 45.0f, displayLink.duration);
        Float64 targetSeconds = MAX(0.0, currentSeconds - step);
        CMTime targetTime = CMTimeMakeWithSeconds(targetSeconds, NSEC_PER_SEC);
        [_livePhotoPlayer seekToTime:targetTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        currentSeconds = targetSeconds;
    }
    
    bool reachedStart = currentSeconds <= 0.02;
    if (!_livePhotoBounceManualReverse && _livePhotoPlayer.rate > -FLT_EPSILON && currentSeconds <= 0.12)
        reachedStart = true;
    
    if (reachedStart)
    {
        _livePhotoBouncePlayingBackwards = false;
        [self stopLivePhotoBounceIfNeeded];
        [self playLivePhotoVideoLooping:false fromStart:false];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)__unused otherGestureRecognizer
{
    if (gestureRecognizer == _livePhotoPressGestureRecognizer)
        return true;
    
    return false;
}

@end
