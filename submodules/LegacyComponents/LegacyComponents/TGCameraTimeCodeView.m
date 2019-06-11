#import "TGCameraTimeCodeView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGTimerTarget.h>
#import <LegacyComponents/TGCameraInterfaceAssets.h>

@interface TGCameraTimeCodeView ()
{
    UIImageView *_dotView;
    UILabel *_timeLabel;
    
    NSUInteger _recordingDurationSeconds;
    NSTimer *_recordingTimer;
}
@end

@implementation TGCameraTimeCodeView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        static UIImage *dotImage = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(6, 6), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();

            CGContextSetFillColorWithColor(context, [TGCameraInterfaceAssets redColor].CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0, 0, 6, 6));

            dotImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _dotView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 7, 6, 6)];
        _dotView.layer.opacity = 0.0f;
        _dotView.image = dotImage;
        [self addSubview:_dotView];
        
        _timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        _timeLabel.backgroundColor = [UIColor clearColor];
        _timeLabel.font = [TGCameraInterfaceAssets normalFontOfSize:21];
        _timeLabel.text = @"00:00:00";
        _timeLabel.textAlignment = NSTextAlignmentCenter;
        _timeLabel.textColor = [TGCameraInterfaceAssets normalColor];
        [self addSubview:_timeLabel];
    }
    return self;
}

- (void)dealloc
{
    [self stopRecording];
}

- (void)_updateRecordingTime
{
    _timeLabel.text = [NSString stringWithFormat:@"%02d:%02d:%02d", (int)(_recordingDurationSeconds / 3600), (int)(_recordingDurationSeconds / 60) % 60, (int)(_recordingDurationSeconds % 60)];
}

- (void)startRecording
{
    [self reset];
    
    _recordingTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(recordingTimerEvent) interval:1.0 repeat:false];
    
    [self playBlinkAnimation];
}

- (void)stopRecording
{
    [_recordingTimer invalidate];
    _recordingTimer = nil;
    
    [self stopBlinkAnimation];
}

- (void)reset
{
    _timeLabel.text = @"00:00:00";
    _recordingDurationSeconds = 0;
}

- (void)recordingTimerEvent
{
    [_recordingTimer invalidate];
    _recordingTimer = nil;
    
    NSTimeInterval recordingDuration = (self.requestedRecordingDuration != nil) ? self.requestedRecordingDuration() : 0.0f;
    if (recordingDuration < _recordingDurationSeconds)
        return;
    
    CFAbsoluteTime currentTime = CACurrentMediaTime();
    NSUInteger currentDurationSeconds = (NSUInteger)recordingDuration;
    if (currentDurationSeconds == _recordingDurationSeconds)
    {
        _recordingTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(recordingTimerEvent) interval:MAX(0.01, _recordingDurationSeconds + 1.0 - currentTime) repeat:false];
    }
    else
    {
        _recordingDurationSeconds = currentDurationSeconds;
        [self _updateRecordingTime];
        _recordingTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(recordingTimerEvent) interval:1.0 repeat:false];
    }
}

- (void)playBlinkAnimation
{
    CAKeyframeAnimation *blinkAnim = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    blinkAnim.duration = 0.75f;
    blinkAnim.autoreverses = false;
    blinkAnim.fillMode = kCAFillModeForwards;
    blinkAnim.repeatCount = HUGE_VALF;
    blinkAnim.keyTimes = @[ @0.0f, @0.4f, @0.5f, @0.9f, @1.0f ];
    blinkAnim.values = @[ @1.0f, @1.0f, @0.0f, @0.0f, @1.0f ];
    
    [_dotView.layer addAnimation:blinkAnim forKey:@"opacity"];
}

- (void)stopBlinkAnimation
{
    [_dotView.layer removeAllAnimations];
}

- (void)setHidden:(BOOL)hidden
{
    self.alpha = hidden ? 0.0f : 1.0f;
    super.hidden = hidden;
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        super.hidden = false;
        
        [UIView animateWithDuration:0.25f animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
                self.hidden = hidden;
        }];
    }
    else
    {
        self.alpha = hidden ? 0.0f : 1.0f;
        super.hidden = hidden;
    }
}

- (void)layoutSubviews
{
    _dotView.frame = CGRectMake(CGFloor(self.frame.size.width / 2 - 48), 7, 6, 6);
}

@end
