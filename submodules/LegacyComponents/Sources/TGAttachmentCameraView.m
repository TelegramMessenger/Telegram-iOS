#import "TGAttachmentCameraView.h"
#import "TGImageUtils.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGMenuSheetView.h>
#import "TGAttachmentMenuCell.h"
#import "TGCameraController.h"

#import <LegacyComponents/PGCamera.h>
#import <LegacyComponents/TGCameraPreviewView.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>

#import <LegacyComponents/TGMenuSheetController.h>

#import <AVFoundation/AVFoundation.h>


@interface TGAttachmentCameraView ()
{
    UIView *_wrapperView;
    UIView *_fadeView;
    UIImageView *_iconView;
    UIImageView *_cornersView;
    UIView *_zoomedView;
    
    TGCameraPreviewView *_previewView;
    __weak PGCamera *_camera;
    
    UIInterfaceOrientation _innerInterfaceOrientation;
}
@end

@implementation TGAttachmentCameraView

- (instancetype)initForSelfPortrait:(bool)selfPortrait
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        
        _wrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 84.0f, 84.0f)];
        [self addSubview:_wrapperView];
        
        PGCamera *camera = nil;
        if ([PGCamera cameraAvailable])
        {
            camera = [[PGCamera alloc] initWithMode:PGCameraModePhoto position:selfPortrait ? PGCameraPositionFront : PGCameraPositionUndefined];
        }
        _camera = camera;
        
        _previewView = [[TGCameraPreviewView alloc] initWithFrame:CGRectMake(0, 0, 84.0f, 84.0f)];
        [_previewView fadeInAnimated:false];
        [_previewView beginTransitionWithSnapshotImage:[TGCameraController startImage] animated:false];
        [_wrapperView addSubview:_previewView];
        [camera attachPreviewView:_previewView];
        
        _iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Chat/Attach Menu/Camera"]];
        [self addSubview:_iconView];
        
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)]];
        
        [self setInterfaceOrientation:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation] animated:false];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleOrientationChange:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
        
        _fadeView = [[UIView alloc] initWithFrame:self.bounds];
        _fadeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _fadeView.backgroundColor = [UIColor blackColor];
        _fadeView.hidden = true;
        [self addSubview:_fadeView];
        
        if (!TGMenuSheetUseEffectView)
        {
            static dispatch_once_t onceToken;
            static UIImage *cornersImage;
            dispatch_once(&onceToken, ^
            {
                CGRect rect = CGRectMake(0, 0, TGAttachmentMenuCellCornerRadius * 2 + 1.0f, TGAttachmentMenuCellCornerRadius * 2 + 1.0f);
                
                UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
                CGContextRef context = UIGraphicsGetCurrentContext();
                
                CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                CGContextFillRect(context, rect);
                
                CGContextSetBlendMode(context, kCGBlendModeClear);
                
                CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                CGContextFillEllipseInRect(context, rect);
                
                cornersImage = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(TGAttachmentMenuCellCornerRadius, TGAttachmentMenuCellCornerRadius, TGAttachmentMenuCellCornerRadius, TGAttachmentMenuCellCornerRadius)];
                
                UIGraphicsEndImageContext();
            });
            
            _cornersView = [[UIImageView alloc] initWithImage:cornersImage];
            _cornersView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _cornersView.frame = _previewView.bounds;
            [_previewView addSubview:_cornersView];
        }
        
        _zoomedView = [[UIView alloc] initWithFrame:self.bounds];
        _zoomedView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _zoomedView.backgroundColor = [UIColor whiteColor];
        _zoomedView.alpha = 0.0f;
        _zoomedView.userInteractionEnabled = false;
        [self addSubview:_zoomedView];
        
        if (@available(iOS 11.0, *)) {
            _fadeView.accessibilityIgnoresInvertColors = true;
            _iconView.accessibilityIgnoresInvertColors = true;
        }
    }
    return self;
}

- (void)dealloc
{
    TGCameraPreviewView *previewView = _previewView;
    if (previewView.superview == _wrapperView && _camera != nil)
        [self stopPreview];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)removeCorners {
    [_cornersView removeFromSuperview];
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    _pallete = pallete;
    
    _zoomedView.backgroundColor = pallete.backgroundColor;
    _cornersView.image = pallete.cornersImage;
}

- (void)setZoomedProgress:(CGFloat)progress
{
    _zoomedView.alpha = progress;
}

- (TGCameraPreviewView *)previewView
{
    return _previewView;
}

- (bool)previewViewAttached
{
    return _previewView.superview == _wrapperView;
}

- (void)detachPreviewView
{
    [UIView animateWithDuration:0.1f animations:^
    {
        _cornersView.alpha = 0.0f;
    }];
    _iconView.alpha = 0.0f;
}

- (void)attachPreviewViewAnimated:(bool)animated
{
    [_wrapperView addSubview:_previewView];
    [self setNeedsLayout];
    
    if (animated)
    {
        _iconView.alpha = 0.0f;
        [UIView animateWithDuration:0.2 animations:^
        {
            _iconView.alpha = 1.0f;
        }];
    }
}

- (void)willAttachPreviewView
{
    [UIView animateWithDuration:0.1f delay:0.1f options:kNilOptions animations:^
    {
        _cornersView.alpha = 1.0f;
    } completion:nil];
}

- (void)tapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (_pressed)
            _pressed();
    }
}

- (void)startPreview
{
    PGCamera *camera = _camera;
    [camera startCaptureForResume:false completion:nil];
}

- (void)stopPreview
{
    PGCamera *camera = _camera;
    [camera stopCaptureForPause:false completion:nil];
    _camera = nil;
}

- (void)pausePreview
{
    TGCameraPreviewView *previewView = _previewView;
    if (previewView.superview != _wrapperView)
        return;
    
    PGCamera *camera = _camera;
    [camera stopCaptureForPause:true completion:nil];
}

- (void)resumePreview
{
    TGCameraPreviewView *previewView = _previewView;
    if (previewView.superview != _wrapperView)
        return;
    
    PGCamera *camera = _camera;
    [camera startCaptureForResume:true completion:nil];
}

- (void)handleOrientationChange:(NSNotification *)__unused notification
{
    [self setInterfaceOrientation:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation] animated:true];
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)orientation animated:(bool)animated
{
    void(^block)(void) = ^
    {
        CGAffineTransform transform = CGAffineTransformMakeRotation(-1 * TGRotationForInterfaceOrientation(orientation));
        CGFloat scale = 1.0;
        if (self.frame.size.width != 0.0) {
            scale = self.frame.size.height / self.frame.size.width;
        }
        if (_innerInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
            transform = CGAffineTransformScale(transform, scale, scale);
        } else if (_innerInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
            transform = CGAffineTransformScale(transform, scale, scale);
        }
        _wrapperView.transform = transform;
        [self layoutSubviews];
    };
    
    _innerInterfaceOrientation = orientation;
    
    if (animated)
        [UIView animateWithDuration:0.3f animations:block];
    else
        block();
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _wrapperView.bounds = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    _wrapperView.center = CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
    
    TGCameraPreviewView *previewView = _previewView;
    if (previewView.superview == _wrapperView)
        previewView.frame = self.bounds;
    
//    if (_innerInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
//        _wrapperView.frame = CGRectOffset(_wrapperView.frame, 0, 100.0);
//    } else if (_innerInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
//        _wrapperView.frame = CGRectOffset(_wrapperView.frame, 0, -100.0);
//    }
    
    _iconView.frame = CGRectMake(self.frame.size.width - _iconView.frame.size.width - 3.0, 3.0 - TGScreenPixel, _iconView.frame.size.width, _iconView.frame.size.height);
}

- (void)saveStartImage:(void (^)(void))completion {
    [_camera captureNextFrameCompletion:^(UIImage *frameImage) {
        [[SQueue concurrentDefaultQueue] dispatch:^{
            [TGCameraController generateStartImageWithImage:frameImage];
            TGDispatchOnMainThread(^{
                completion();
            });
        }];
    }];
}

@end
