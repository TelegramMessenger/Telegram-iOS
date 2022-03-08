#ifndef TgVoipWebrtc_MediaStreaming_h
#define TgVoipWebrtc_MediaStreaming_h

#import <Foundation/Foundation.h>

#import <TgVoipWebrtc/OngoingCallThreadLocalContext.h>

@interface MediaStreamingContext : NSObject

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue
    requestCurrentTime:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(void (^ _Nonnull)(int64_t)))requestAudioBroadcastPart
    requestAudioBroadcastPart:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(int64_t, int64_t, void (^ _Nonnull)(OngoingGroupCallBroadcastPart * _Nullable)))requestAudioBroadcastPart
    requestVideoBroadcastPart:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(int64_t, int64_t, int32_t, OngoingGroupCallRequestedVideoQuality, void (^ _Nonnull)(OngoingGroupCallBroadcastPart * _Nullable)))requestVideoBroadcastPart;

- (void)start;
- (void)stop;

- (GroupCallDisposable * _Nonnull)addVideoOutput:(void (^_Nonnull)(CallVideoFrameData * _Nonnull))sink;
- (void)getAudio:(int16_t * _Nonnull)audioSamples numSamples:(NSInteger)numSamples numChannels:(NSInteger)numChannels samplesPerSecond:(NSInteger)samplesPerSecond;

@end

#endif
