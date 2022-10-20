#import "TGCameraPreviewView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import <AVFoundation/AVFoundation.h>

#import <LegacyComponents/PGCamera.h>
#import <LegacyComponents/PGCameraCaptureSession.h>

@protocol TGCameraPreviewLayerView <NSObject>

@property (nonatomic, strong) NSString *videoGravity;
@property (nonatomic, readonly) AVCaptureConnection *connection;
- (CGPoint)captureDevicePointOfInterestForPoint:(CGPoint)point;

@optional
- (AVSampleBufferDisplayLayer *)displayLayer;
- (AVCaptureVideoPreviewLayer *)previewLayer;

@end


@interface TGCameraPreviewLayerWrapperView : UIView <TGCameraPreviewLayerView>
{
    __weak AVCaptureConnection *_connection;
}

@property (nonatomic, readonly) AVSampleBufferDisplayLayer *displayLayer;

- (void)enqueueSampleBuffer:(CMSampleBufferRef)buffer connection:(AVCaptureConnection *)connection;

@end


@interface TGCameraLegacyPreviewLayerWrapperView : UIView <TGCameraPreviewLayerView>

@property (nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;

@end


@interface TGCameraPreviewView ()
{
    UIView<TGCameraPreviewLayerView> *_wrapperView;
    UIView *_fadeView;
    UIView *_snapshotView;
    
    PGCamera *_camera;
}
@end

@implementation TGCameraPreviewView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor blackColor];
        self.clipsToBounds = true;

        _wrapperView = [[TGCameraLegacyPreviewLayerWrapperView alloc] init];
        [self addSubview:_wrapperView];
        
        _wrapperView.videoGravity = AVLayerVideoGravityResizeAspectFill;
        
        _fadeView = [[UIView alloc] initWithFrame:self.bounds];
        _fadeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _fadeView.backgroundColor = [UIColor blackColor];
        _fadeView.userInteractionEnabled = false;
        [self addSubview:_fadeView];
        
        if (@available(iOS 11.0, *)) {
            _fadeView.accessibilityIgnoresInvertColors = true;
        }
        
#if TARGET_IPHONE_SIMULATOR
        _fadeView.backgroundColor = [UIColor redColor];
#endif
    }
    return self;
}

- (AVCaptureConnection *)captureConnection
{
    return _wrapperView.connection;
}

- (AVSampleBufferDisplayLayer *)displayLayer
{
    return _wrapperView.displayLayer;
}

- (AVCaptureVideoPreviewLayer *)legacyPreviewLayer
{
    return _wrapperView.previewLayer;
}

- (void)setupWithCamera:(PGCamera *)camera
{
    _camera = camera;
    
    __weak TGCameraPreviewView *weakSelf = self;
    if ([_wrapperView isKindOfClass:[TGCameraPreviewLayerWrapperView class]])
    {
        [self.displayLayer flushAndRemoveImage];
        camera.captureSession.outputSampleBuffer = ^(CMSampleBufferRef buffer, AVCaptureConnection *connection)
        {
            __strong TGCameraPreviewView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [(TGCameraPreviewLayerWrapperView *)strongSelf->_wrapperView enqueueSampleBuffer:buffer connection:connection];
        };
    }
    else
    {
#if !TARGET_IPHONE_SIMULATOR
        [self.legacyPreviewLayer setSession:camera.captureSession];
#endif
    }
    
    camera.captureStarted = ^(bool resume)
    {
        __strong TGCameraPreviewView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (resume) {
            [strongSelf endResetTransitionAnimated:true];
        } else {
            if (strongSelf->_snapshotView != nil) {
                [strongSelf endTransitionAnimated:true];
            } else {
                [strongSelf fadeInAnimated:true];
            }
        }
    };
    
    camera.captureStopped = ^(bool pause)
    {
        __strong TGCameraPreviewView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (pause)
            [strongSelf beginResetTransitionAnimated:true];
        else
            [strongSelf fadeOutAnimated:true];
    };
}

- (void)invalidate
{
    if ([_wrapperView isKindOfClass:[TGCameraPreviewLayerWrapperView class]])
    {
        [self.displayLayer flushAndRemoveImage];
        _camera.captureSession.outputSampleBuffer = nil;
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.legacyPreviewLayer setSession:nil];
        });
    }
    _wrapperView = nil;
}

- (PGCamera *)camera
{
    return _camera;
}

- (void)fadeInAnimated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.3f delay:0.05f options:UIViewAnimationOptionCurveLinear animations:^
        {
            _fadeView.alpha = 0.0f;
        } completion:nil];
    }
    else
    {
        _fadeView.alpha = 0.0f;
    }
}

- (void)fadeOutAnimated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.3f animations:^
        {
            _fadeView.alpha = 1.0f;
        }];
    }
    else
    {
        _fadeView.alpha = 1.0f;
    }
}

- (void)blink
{
    [UIView animateWithDuration:0.07f delay:0.0f options:UIViewAnimationOptionCurveLinear animations:^
    {
        _fadeView.alpha = 1.0f;
    } completion:^(BOOL finished)
    {
        [UIView animateWithDuration:0.15f delay:0.0f options:UIViewAnimationOptionCurveLinear animations:^
        {
            _fadeView.alpha = 0.0f;
        } completion:^(BOOL finished)
        {    
            
        }];
    }];
}

- (void)beginTransitionWithSnapshotImage:(UIImage *)image animated:(bool)animated
{
    [_snapshotView removeFromSuperview];
    
    UIImageView *snapshotView = [[UIImageView alloc] initWithFrame:_wrapperView.frame];
    snapshotView.contentMode = UIViewContentModeScaleAspectFill;
    snapshotView.image = image;
    [self insertSubview:snapshotView aboveSubview:_wrapperView];
    
    if (@available(iOS 11.0, *)) {
        snapshotView.accessibilityIgnoresInvertColors = true;
    }
    
    _snapshotView = snapshotView;
    
    if (animated)
    {
        _snapshotView.alpha = 0.0f;
        [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
        {
            _snapshotView.alpha = 1.0f;
        } completion:nil];
    }
}

- (void)endTransitionAnimated:(bool)animated
{
    if (animated)
    {
        UIView *snapshotView = _snapshotView;
        _snapshotView = nil;
        
        [UIView animateWithDuration:0.4f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            snapshotView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            [snapshotView removeFromSuperview];
        }];
    }
    else
    {
        [_snapshotView removeFromSuperview];
        _snapshotView = nil;
    }
}

- (bool)hasTransitionSnapshot {
    return _snapshotView != nil;
}

- (void)beginResetTransitionAnimated:(bool)animated
{
    if (iosMajorVersion() < 7)
        return;
    
    [_snapshotView removeFromSuperview];
    
    _snapshotView = [_wrapperView snapshotViewAfterScreenUpdates:false];
    _snapshotView.frame = _wrapperView.frame;
    [self insertSubview:_snapshotView aboveSubview:_wrapperView];
    
    if (animated)
    {
        _snapshotView.alpha = 0.0f;
        [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
        {
            _snapshotView.alpha = 1.0f;
        } completion:nil];
    }
}

- (void)endResetTransitionAnimated:(bool)animated
{
    if (iosMajorVersion() < 7)
        return;
    
    if (animated)
    {
        UIView *snapshotView = _snapshotView;
        _snapshotView = nil;
        
        [UIView animateWithDuration:0.4f delay:0.05f options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            snapshotView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            [snapshotView removeFromSuperview];
        }];
    }
    else
    {
        [_snapshotView removeFromSuperview];
        _snapshotView = nil;
    }
}

- (CGPoint)devicePointOfInterestForPoint:(CGPoint)point
{
    return [_wrapperView captureDevicePointOfInterestForPoint:point];
}

- (void)layoutSubviews
{
    _wrapperView.frame = self.bounds;
    
    if (_snapshotView != nil)
    {
        CGSize imageSize = _snapshotView.frame.size;
        if ([_snapshotView isKindOfClass:[UIImageView class]]) {
            imageSize = ((UIImageView *)_snapshotView).image.size;
        }
        
        CGSize size = TGScaleToFill(imageSize, _wrapperView.frame.size);
        _snapshotView.frame = CGRectMake(floor((self.frame.size.width - size.width) / 2.0f), floor((self.frame.size.height - size.height) / 2.0f), size.width, size.height);
    }
}

@end


@implementation TGCameraPreviewLayerWrapperView

- (NSString *)videoGravity
{
    return [self displayLayer].videoGravity;
}

- (void)setVideoGravity:(NSString *)videoGravity
{
    self.displayLayer.videoGravity = videoGravity;
}

- (AVCaptureConnection *)connection
{
    return _connection;
}

- (CGPoint)captureDevicePointOfInterestForPoint:(CGPoint)point
{
    return CGPointZero;
}

- (void)enqueueSampleBuffer:(CMSampleBufferRef)buffer connection:(AVCaptureConnection *)connection
{
    _connection = connection;
    
    //self.orientation = connection.videoOrientation;
    //self.mirrored = connection.videoMirrored;
    
    [self.displayLayer enqueueSampleBuffer:buffer];
}

- (AVSampleBufferDisplayLayer *)displayLayer
{
    return (AVSampleBufferDisplayLayer *)self.layer;
}

+ (Class)layerClass
{
    return [AVSampleBufferDisplayLayer class];
}

@end


@implementation TGCameraLegacyPreviewLayerWrapperView

- (NSString *)videoGravity
{
    return self.previewLayer.videoGravity;
}

- (void)setVideoGravity:(NSString *)videoGravity
{
    self.previewLayer.videoGravity = videoGravity;
}

- (AVCaptureConnection *)connection
{
    return self.previewLayer.connection;
}

- (CGPoint)captureDevicePointOfInterestForPoint:(CGPoint)point
{
    return [self.previewLayer captureDevicePointOfInterestForPoint:point];
}

- (AVCaptureVideoPreviewLayer *)previewLayer
{
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

+ (Class)layerClass
{
    return [AVCaptureVideoPreviewLayer class];
}

@end
