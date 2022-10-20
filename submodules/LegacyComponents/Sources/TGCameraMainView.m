#import "TGCameraMainView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGModernButton.h>

#import "TGCameraShutterButton.h"
#import "TGCameraFlipButton.h"
#import "TGCameraModeControl.h"
#import "TGCameraTimeCodeView.h"
#import "TGCameraZoomView.h"
#import "TGCameraToastView.h"

#import "TGMediaPickerPhotoCounterButton.h"
#import "TGMediaPickerPhotoStripView.h"

@implementation TGCameraCornersView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.contentMode = UIViewContentModeScaleToFill;
        
        static UIImage *cornersImage = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            CGSize size = CGSizeMake(50.0, 50.0);
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(50.0, 50.0), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();

            CGContextSetAlpha(context, 0.5);
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            CGFloat width = 1.0;
            CGFloat length = 24.0;
            CGContextFillRect(context, CGRectMake(0, 0, length, width));
            CGContextFillRect(context, CGRectMake(0, 0, width, length));
            
            CGContextFillRect(context, CGRectMake(size.width - length, 0, length, width));
            CGContextFillRect(context, CGRectMake(size.width - width, 0, width, length));
            
            CGContextFillRect(context, CGRectMake(0, size.height - width, length, width));
            CGContextFillRect(context, CGRectMake(0, size.height - length, width, length));
            
            CGContextFillRect(context, CGRectMake(size.width - length, size.height - width, length, width));
            CGContextFillRect(context, CGRectMake(size.width - width, size.height - length, width, length));
            
            cornersImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:25 topCapHeight:25];
            UIGraphicsEndImageContext();
        });
        
        self.image = cornersImage;
        self.userInteractionEnabled = false;
    }
    return self;
}

@end

@interface TGCameraMainView ()
{
    
}
@end

@implementation TGCameraMainView

@dynamic thumbnailSignalForItem;
@dynamic editingContext;

- (instancetype)initWithFrame:(CGRect)frame avatar:(bool)avatar hasUltrawideCamera:(bool)hasUltrawideCamera hasTelephotoCamera:(bool)hasTelephotoCamera {
    self = [super init];
    if (self != nil) {
    }
    return self;
}

- (void)setResults:(NSArray *)__unused results {
}

#pragma mark - Mode

- (void)setInterfaceHiddenForVideoRecording:(bool)__unused hidden animated:(bool)__unused animated
{
}

- (void)setCameraMode:(PGCameraMode)mode
{
    PGCameraMode previousMode = _modeControl.cameraMode;
    [_modeControl setCameraMode:mode animated:true];
    [self updateForCameraModeChangeWithPreviousMode:previousMode];
}

- (void)setToastMessage:(NSString *)message animated:(bool)animated
{
    [_toastView setText:message animated:animated];
}

- (void)updateForCameraModeChangeWithPreviousMode:(PGCameraMode)__unused previousMode
{
    switch (_modeControl.cameraMode)
    {
        case PGCameraModePhoto:
        case PGCameraModeSquarePhoto:
        case PGCameraModePhotoScan:
        {
            [_shutterButton setButtonMode:TGCameraShutterButtonNormalMode animated:true];
            [_timecodeView setHidden:true animated:true];
            [_flipButton setHidden:_modeControl.cameraMode == PGCameraModePhotoScan animated:true];
        }
            break;
            
        case PGCameraModeVideo:
        case PGCameraModeSquareVideo:
        {
            [_shutterButton setButtonMode:TGCameraShutterButtonVideoMode animated:true];
            [_timecodeView setHidden:false animated:true];
        }
            break;
            
        case PGCameraModeSquareSwing:
        {
            [_shutterButton setButtonMode:TGCameraShutterButtonVideoMode animated:true];
            [_timecodeView setHidden:true animated:true];
        }
            break;
            
        default:
            break;
    }
    
    [_zoomView hideAnimated:true];
}

- (void)updateForCameraModeChangeAfterResize
{
}

- (void)setHasModeControl:(bool)hasModeControl
{
    if (!hasModeControl)
        [_modeControl removeFromSuperview];
}

#pragma mark - Flash

- (void)setHasFlash:(bool)__unused hasFlash
{
    
}

- (void)setFlashMode:(PGCameraFlashMode)__unused mode
{
    
}

- (void)setFlashActive:(bool)__unused active
{
    
}

- (void)setFlashUnavailable:(bool)__unused unavailable
{
    
}

#pragma mark - Actions

- (void)setDoneButtonHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        _doneButton.hidden = false;
        [UIView animateWithDuration:0.3 animations:^
        {
            _doneButton.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
                _doneButton.hidden = hidden;
        }];
    }
    else
    {
        _doneButton.hidden = hidden;
        _doneButton.alpha = hidden ? 0.0f : 1.0f;
    }
}

- (void)setShutterButtonHighlighted:(bool)highlighted
{
    [_shutterButton setHighlighted:highlighted];
}

- (void)setShutterButtonEnabled:(bool)enabled
{
    [_shutterButton setEnabled:enabled animated:true];
}

- (void)shutterButtonPressed
{
    if (self.shutterPressed != nil)
        self.shutterPressed(false);
}

- (void)shutterButtonReleased
{
    if (self.shutterReleased != nil)
        self.shutterReleased(false);
}

- (void)shutterButtonPanGesture:(UIPanGestureRecognizer *)gestureRecognizer {
    if (self.shutterPanGesture != nil)
        self.shutterPanGesture(gestureRecognizer);
}

- (void)cancelButtonPressed
{
    if (self.cancelPressed != nil)
        self.cancelPressed();
}

- (void)doneButtonPressed
{
    [_photoCounterButton setSelected:false animated:true];
    [_selectedPhotosView setHidden:true animated:true];
    
    if (self.resultPressed != nil)
        self.resultPressed(-1);
}

- (void)flipButtonPressed
{
    if (self.cameraFlipped != nil)
        self.cameraFlipped();
}

#pragma mark - Zoom

- (void)setZoomLevel:(CGFloat)zoomLevel displayNeeded:(bool)displayNeeded
{
    [_zoomView setZoomLevel:zoomLevel displayNeeded:displayNeeded];
    [_zoomModeView setZoomLevel:zoomLevel animated:true];
    [_zoomWheelView setZoomLevel:zoomLevel];
}

- (void)zoomChangingEnded
{
    [_zoomView interactionEnded];
}

- (void)setHasZoom:(bool)hasZoom
{
    if (!hasZoom)
        [_zoomView hideAnimated:true];
    
    [_zoomModeView setHidden:!hasZoom animated:true];
}

#pragma mark - Video

- (void)setRecordingVideo:(bool)recordingVideo animated:(bool)animated
{
    [_shutterButton setButtonMode:recordingVideo ? TGCameraShutterButtonRecordingMode : TGCameraShutterButtonVideoMode animated:animated];
    if (recordingVideo)
    {
        [_timecodeView startRecording];
    }
    else
    {
        [_timecodeView stopRecording];
        [_timecodeView reset];
    }
    [self setInterfaceHiddenForVideoRecording:recordingVideo animated:animated];
}

#pragma mark - 

- (UIInterfaceOrientation)interfaceOrientation
{
    return _interfaceOrientation;
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)orientation animated:(bool)__unused animated
{
    _interfaceOrientation = orientation;
}

#pragma mark - 

- (void)showMomentCaptureDismissWarningWithCompletion:(void (^)(bool dismiss))completion
{
    if (completion != nil)
        completion(true);
}

#pragma mark -

- (void)setDocumentFrameHidden:(bool)hidden
{
    
}

- (void)setThumbnailSignalForItem:(SSignal *(^)(id))thumbnailSignalForItem
{
    [_selectedPhotosView setThumbnailSignalForItem:thumbnailSignalForItem];
}

- (void)setSelectedItemsModel:(TGMediaPickerGallerySelectedItemsModel *)selectedItemsModel
{
    _selectedPhotosView.selectedItemsModel = selectedItemsModel;
    [_selectedPhotosView reloadData];
    
    if (selectedItemsModel != nil && _selectedPhotosView != nil)
        _photoCounterButton.userInteractionEnabled = true;
}

- (void)photoCounterButtonPressed
{
    [_photoCounterButton setSelected:!_photoCounterButton.selected animated:true];
    [_selectedPhotosView setHidden:!_photoCounterButton.selected animated:true];
}

- (void)updateSelectionInterface:(NSUInteger)selectedCount counterVisible:(bool)counterVisible animated:(bool)animated
{
    if (counterVisible)
    {
        bool animateCount = animated && !(counterVisible && _photoCounterButton.internalHidden);
        [_photoCounterButton setSelectedCount:selectedCount animated:animateCount];
        [_photoCounterButton setInternalHidden:false animated:animated completion:nil];
    }
    else
    {
        bool animate = animated || (selectedCount == 0 && !counterVisible);
        __weak TGMediaPickerPhotoCounterButton *weakButton = _photoCounterButton;
        [_photoCounterButton setInternalHidden:true animated:animate completion:^
         {
             __strong TGMediaPickerPhotoCounterButton *strongButton = weakButton;
             if (strongButton != nil)
             {
                 strongButton.selected = false;
                 [strongButton setSelectedCount:selectedCount animated:false];
             }
         }];
        [_selectedPhotosView setHidden:true animated:animated];
    }
}

- (void)updateSelectedPhotosView:(bool)reload incremental:(bool)incremental add:(bool)add index:(NSInteger)index
{
    if (_selectedPhotosView == nil)
        return;
    
    if (!reload)
        return;
    
    if (incremental)
    {
        if (add)
            [_selectedPhotosView insertItemAtIndex:index];
        else
            [_selectedPhotosView deleteItemAtIndex:index];
    }
    else
    {
        [_selectedPhotosView reloadData];
    }
}

- (void)setEditingContext:(TGMediaEditingContext *)editingContext
{
    _selectedPhotosView.editingContext = editingContext;
}

@end
