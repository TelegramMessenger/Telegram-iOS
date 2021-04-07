#import "TGPassportScanView.h"
#import "PGCamera.h"
#import "TGCameraPreviewView.h"

#import "TGPassportOCR.h"

#import "LegacyComponentsInternal.h"

#import "TGTimerTarget.h"

@interface TGPassportScanView ()
{
    PGCamera *_camera;
    TGCameraPreviewView *_previewView;
    
    NSTimer *_timer;
    SMetaDisposable *_ocrDisposable;
}
@end

@implementation TGPassportScanView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _camera = [[PGCamera alloc] initWithMode:PGCameraModePhoto position:PGCameraPositionRear];
        _previewView = [[TGCameraPreviewView alloc] initWithFrame:self.bounds];
        [self addSubview:_previewView];
        
        [_camera attachPreviewView:_previewView];
        
        _ocrDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_ocrDisposable dispose];
}

- (void)start
{
    [_camera startCaptureForResume:false completion:nil];
    
    _timer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(handleNextFrame) interval:0.5 repeat:false];
    NSLog(@"SS_scheduledFirst");
}

- (void)stop
{
    [_camera stopCaptureForPause:false completion:nil];
    _camera = nil;
    
    [_timer invalidate];
    _timer = nil;
}

- (void)pause
{
    [_camera stopCaptureForPause:true completion:nil];
}

- (void)handleNextFrame
{
    __weak TGPassportScanView *weakSelf = self;
    [_camera captureNextFrameCompletion:^(UIImage *image)
    {
        [_ocrDisposable setDisposable:[[[TGPassportOCR recognizeDataInImage:image shouldBeDriversLicense:false] deliverOn:[SQueue mainQueue]] startWithNext:^(TGPassportMRZ *next)
        {
            __strong TGPassportScanView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (next != nil)
            {
                [strongSelf->_camera stopCaptureForPause:true completion:nil];
            
                if (strongSelf.finishedWithMRZ != nil)
                    strongSelf.finishedWithMRZ(next);
            }
            else
            {
                strongSelf->_timer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(handleNextFrame) interval:0.45 repeat:false];
            }
        }]];
    }];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _previewView.frame = self.bounds;
}

@end
