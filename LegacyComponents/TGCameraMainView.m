#import "TGCameraMainView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGModernButton.h>

#import "TGCameraShutterButton.h"
#import "TGCameraModeControl.h"
#import "TGCameraTimeCodeView.h"
#import "TGCameraZoomView.h"
#import "TGCameraSegmentsView.h"

@implementation TGCameraMainView

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

- (void)updateForCameraModeChangeWithPreviousMode:(PGCameraMode)__unused previousMode
{
    switch (_modeControl.cameraMode)
    {
        case PGCameraModePhoto:
        case PGCameraModeSquare:
        {
            [_shutterButton setButtonMode:TGCameraShutterButtonNormalMode animated:true];
            [_timecodeView setHidden:true animated:true];
            [_segmentsView setHidden:true animated:true delay:0.0];
        }
            break;
            
        case PGCameraModeVideo:
        {
            [_shutterButton setButtonMode:TGCameraShutterButtonVideoMode animated:true];
            [_timecodeView setHidden:false animated:true];
            [_segmentsView setHidden:true animated:true delay:0.0];
        }
            break;
            
        case PGCameraModeClip:
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
    if (_modeControl.cameraMode == PGCameraModeClip)
        [_segmentsView setHidden:false animated:true delay:0.1];
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

- (void)cancelButtonPressed
{
    if (self.cancelPressed != nil)
        self.cancelPressed();
}

- (void)doneButtonPressed
{
    if (self.donePressed != nil)
        self.donePressed();
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
}

- (void)zoomChangingEnded
{
    [_zoomView interactionEnded];
}

- (void)setHasZoom:(bool)hasZoom
{
    if (!hasZoom)
        [_zoomView hideAnimated:true];
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

- (void)setStartedSegmentCapture
{
    [_segmentsView startCurrentSegment];
}

- (void)setCurrentSegmentLength:(CGFloat)length
{
    [_segmentsView setCurrentSegment:length];
}

- (void)setCommitSegmentCapture
{
    [_segmentsView commitCurrentSegmentWithCompletion:nil];
}

- (void)previewLastSegment
{
    [_segmentsView highlightLastSegment];
}

- (void)removeLastSegment
{
    [_segmentsView removeLastSegment];
}

#pragma mark - 

- (void)showMomentCaptureDismissWarningWithCompletion:(void (^)(bool dismiss))completion
{
    if (completion != nil)
        completion(true);
}

- (void)layoutPreviewRelativeViews
{
    
}

@end
