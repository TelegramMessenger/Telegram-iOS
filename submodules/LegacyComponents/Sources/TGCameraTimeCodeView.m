#import "TGCameraTimeCodeView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGTimerTarget.h>
#import <LegacyComponents/TGCameraInterfaceAssets.h>

@interface TGCameraTimeCodeView ()
{
    UIView *_backgroundView;
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
        _backgroundView = [[UIView alloc] init];
        _backgroundView.clipsToBounds = true;
        _backgroundView.layer.cornerRadius = 4.0;
        _backgroundView.backgroundColor = [TGCameraInterfaceAssets redColor];
        _backgroundView.alpha = 0.0;
        [self addSubview:_backgroundView];
        
        _timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        _timeLabel.backgroundColor = [UIColor clearColor];
        _timeLabel.font = [TGCameraInterfaceAssets regularFontOfSize:21];
        _timeLabel.text = @"00:00";
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
    if (_recordingDurationSeconds > 60 * 60) {
        _timeLabel.text = [NSString stringWithFormat:@"%02d:%02d:%02d", (int)(_recordingDurationSeconds / 3600), (int)(_recordingDurationSeconds / 60) % 60, (int)(_recordingDurationSeconds % 60)];
    } else {
        _timeLabel.text = [NSString stringWithFormat:@"%02d:%02d", (int)(_recordingDurationSeconds / 60) % 60, (int)(_recordingDurationSeconds % 60)];
    }
    [_timeLabel sizeToFit];
    
    CGFloat inset = 8.0f;
    CGFloat backgroundWidth = _timeLabel.frame.size.width + inset * 2.0;
    _backgroundView.frame = CGRectMake(floor((self.frame.size.width - backgroundWidth) / 2.0), 0.0, backgroundWidth, 28.0);
    
    _timeLabel.frame = CGRectMake(floor((self.frame.size.width - _timeLabel.frame.size.width) / 2.0), floor((28 - _timeLabel.frame.size.height) / 2.0), _timeLabel.frame.size.width, _timeLabel.frame.size.height);
}

- (void)startRecording
{
    [self reset];
    
    _recordingTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(recordingTimerEvent) interval:1.0 repeat:false];
}

- (void)stopRecording
{
    [_recordingTimer invalidate];
    _recordingTimer = nil;
}

- (void)reset
{
    _recordingDurationSeconds = 0;
    [self _updateRecordingTime];
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
    [self _updateRecordingTime];
}

@end
