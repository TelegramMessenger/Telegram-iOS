#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@protocol TGVideoCameraMovieRecorderDelegate;

@interface TGVideoCameraMovieRecorder : NSObject

@property (nonatomic, assign) bool paused;

- (instancetype)initWithURL:(NSURL *)URL delegate:(id<TGVideoCameraMovieRecorderDelegate>)delegate callbackQueue:(dispatch_queue_t)queue;

- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings;
- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)audioSettings;


- (void)prepareToRecord;

- (void)appendVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)presentationTime;
- (void)appendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)finishRecording:(void(^)())completed;

- (NSTimeInterval)videoDuration;

@end

@protocol TGVideoCameraMovieRecorderDelegate <NSObject>
@required
- (void)movieRecorderDidFinishPreparing:(TGVideoCameraMovieRecorder *)recorder;
- (void)movieRecorder:(TGVideoCameraMovieRecorder *)recorder didFailWithError:(NSError *)error;
- (void)movieRecorderDidFinishRecording:(TGVideoCameraMovieRecorder *)recorder;
@end
