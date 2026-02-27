#import <AVFoundation/AVFoundation.h>

@interface PGCameraMovieWriter : NSObject

@property (nonatomic, copy) void(^finishedWithMovieAtURL)(NSURL *url, CGAffineTransform transform, CGSize dimensions, NSTimeInterval duration, bool success);

@property (nonatomic, readonly) NSTimeInterval currentDuration;
@property (nonatomic, readonly) bool isRecording;
@property (nonatomic, assign) bool liveUpload;

- (instancetype)initWithVideoTransform:(CGAffineTransform)videoTransform videoOutputSettings:(NSDictionary *)videoSettings audioOutputSettings:(NSDictionary *)audioSettings;

- (void)startRecording;
- (void)stopRecordingWithCompletion:(void (^)(void))completion;

- (void)_processSampleBuffer:(CMSampleBufferRef)sampleBuffer;

+ (NSString *)outputFileType;

@end
