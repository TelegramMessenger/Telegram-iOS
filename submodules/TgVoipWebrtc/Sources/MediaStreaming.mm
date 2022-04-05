#import <TgVoipWebrtc/MediaStreaming.h>

#import "MediaUtils.h"

#include "StaticThreads.h"
#include "group/StreamingMediaContext.h"

#include "api/video/video_sink_interface.h"
#include "sdk/objc/native/src/objc_frame_buffer.h"
#include "api/video/video_frame.h"

#import "components/video_frame_buffer/RTCCVPixelBuffer.h"
#import "platform/darwin/TGRTCCVPixelBuffer.h"

#include <memory>

namespace {

class BroadcastPartTaskImpl : public tgcalls::BroadcastPartTask {
public:
    BroadcastPartTaskImpl(id<OngoingGroupCallBroadcastPartTask> task) {
        _task = task;
    }
    
    virtual ~BroadcastPartTaskImpl() {
    }
    
    virtual void cancel() override {
        [_task cancel];
    }
    
private:
    id<OngoingGroupCallBroadcastPartTask> _task;
};

class VideoSinkAdapter : public rtc::VideoSinkInterface<webrtc::VideoFrame> {
public:
    VideoSinkAdapter(void (^frameReceived)(webrtc::VideoFrame const &)) {
        _frameReceived = [frameReceived copy];
    }

    void OnFrame(const webrtc::VideoFrame& nativeVideoFrame) override {
        @autoreleasepool {
            if (_frameReceived) {
                _frameReceived(nativeVideoFrame);
            }
        }
    }

private:
    void (^_frameReceived)(webrtc::VideoFrame const &);
};

}

@interface MediaStreamingVideoSink : NSObject {
    std::shared_ptr<VideoSinkAdapter> _adapter;
}

@end


@implementation MediaStreamingVideoSink

- (instancetype)initWithSink:(void (^_Nonnull)(CallVideoFrameData * _Nonnull))sink {
    self = [super init];
    if (self != nil) {
        void (^storedSink)(CallVideoFrameData * _Nonnull) = [sink copy];

        _adapter.reset(new VideoSinkAdapter(^(webrtc::VideoFrame const &videoFrame) {
            id<CallVideoFrameBuffer> mappedBuffer = nil;

            bool mirrorHorizontally = false;
            bool mirrorVertically = false;

            if (videoFrame.video_frame_buffer()->type() == webrtc::VideoFrameBuffer::Type::kNative) {
                id<RTC_OBJC_TYPE(RTCVideoFrameBuffer)> nativeBuffer = static_cast<webrtc::ObjCFrameBuffer *>(videoFrame.video_frame_buffer().get())->wrapped_frame_buffer();
                if ([nativeBuffer isKindOfClass:[RTC_OBJC_TYPE(RTCCVPixelBuffer) class]]) {
                    RTCCVPixelBuffer *pixelBuffer = (RTCCVPixelBuffer *)nativeBuffer;
                    mappedBuffer = [[CallVideoFrameNativePixelBuffer alloc] initWithPixelBuffer:pixelBuffer.pixelBuffer];
                }
                if ([nativeBuffer isKindOfClass:[TGRTCCVPixelBuffer class]]) {
                    if (((TGRTCCVPixelBuffer *)nativeBuffer).shouldBeMirrored) {
                        switch (videoFrame.rotation()) {
                            case webrtc::kVideoRotation_0:
                            case webrtc::kVideoRotation_180:
                                mirrorHorizontally = true;
                                break;
                            case webrtc::kVideoRotation_90:
                            case webrtc::kVideoRotation_270:
                                mirrorVertically = true;
                                break;
                            default:
                                break;
                        }
                    }
                }
            } else if (videoFrame.video_frame_buffer()->type() == webrtc::VideoFrameBuffer::Type::kNV12) {
                rtc::scoped_refptr<webrtc::NV12BufferInterface> nv12Buffer = (webrtc::NV12BufferInterface *)videoFrame.video_frame_buffer().get();
                mappedBuffer = [[CallVideoFrameNV12Buffer alloc] initWithBuffer:nv12Buffer];
            } else if (videoFrame.video_frame_buffer()->type() == webrtc::VideoFrameBuffer::Type::kI420) {
                rtc::scoped_refptr<webrtc::I420BufferInterface> i420Buffer = (webrtc::I420BufferInterface *)videoFrame.video_frame_buffer().get();
                mappedBuffer = [[CallVideoFrameI420Buffer alloc] initWithBuffer:i420Buffer];
            }

            if (storedSink && mappedBuffer) {
                storedSink([[CallVideoFrameData alloc] initWithBuffer:mappedBuffer frame:videoFrame mirrorHorizontally:mirrorHorizontally mirrorVertically:mirrorVertically]);
            }
        }));
    }
    return self;
}

- (std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>)sink {
    return _adapter;
}

@end

@interface MediaStreamingContext () {
    id<OngoingCallThreadLocalContextQueueWebrtc> _queue;
    
    id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull _requestCurrentTime)(void (^ _Nonnull)(int64_t));
    id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull _requestAudioBroadcastPart)(int64_t, int64_t, void (^ _Nonnull)(OngoingGroupCallBroadcastPart * _Nullable));
    id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull _requestVideoBroadcastPart)(int64_t, int64_t, int32_t, OngoingGroupCallRequestedVideoQuality, void (^ _Nonnull)(OngoingGroupCallBroadcastPart * _Nullable));
    
    std::unique_ptr<tgcalls::StreamingMediaContext> _context;
    
    int _nextSinkId;
    NSMutableDictionary<NSNumber *, MediaStreamingVideoSink *> *_sinks;
}

@end

@implementation MediaStreamingContext

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue
    requestCurrentTime:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(void (^ _Nonnull)(int64_t)))requestCurrentTime
    requestAudioBroadcastPart:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(int64_t, int64_t, void (^ _Nonnull)(OngoingGroupCallBroadcastPart * _Nullable)))requestAudioBroadcastPart
    requestVideoBroadcastPart:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(int64_t, int64_t, int32_t, OngoingGroupCallRequestedVideoQuality, void (^ _Nonnull)(OngoingGroupCallBroadcastPart * _Nullable)))requestVideoBroadcastPart {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        
        _requestCurrentTime = [requestCurrentTime copy];
        _requestAudioBroadcastPart = [requestAudioBroadcastPart copy];
        _requestVideoBroadcastPart = [requestVideoBroadcastPart copy];
        
        _sinks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
}

- (void)resetContext {
    tgcalls::StreamingMediaContext::StreamingMediaContextArguments arguments;
    arguments.threads = tgcalls::StaticThreads::getThreads();
    arguments.isUnifiedBroadcast = true;
    arguments.requestCurrentTime = [requestCurrentTime = _requestCurrentTime](std::function<void(int64_t)> completion) -> std::shared_ptr<tgcalls::BroadcastPartTask> {
        id<OngoingGroupCallBroadcastPartTask> task = requestCurrentTime(^(int64_t result) {
            completion(result);
        });
        return std::make_shared<BroadcastPartTaskImpl>(task);
    };
    arguments.requestAudioBroadcastPart = nullptr;
    arguments.requestVideoBroadcastPart = [requestVideoBroadcastPart = _requestVideoBroadcastPart](int64_t timestampMilliseconds, int64_t durationMilliseconds, int32_t channelId, tgcalls::VideoChannelDescription::Quality quality, std::function<void(tgcalls::BroadcastPart &&)> completion) -> std::shared_ptr<tgcalls::BroadcastPartTask> {
        OngoingGroupCallRequestedVideoQuality mappedQuality;
        switch (quality) {
            case tgcalls::VideoChannelDescription::Quality::Thumbnail: {
                mappedQuality = OngoingGroupCallRequestedVideoQualityThumbnail;
                break;
            }
            case tgcalls::VideoChannelDescription::Quality::Medium: {
                mappedQuality = OngoingGroupCallRequestedVideoQualityMedium;
                break;
            }
            case tgcalls::VideoChannelDescription::Quality::Full: {
                mappedQuality = OngoingGroupCallRequestedVideoQualityFull;
                break;
            }
            default: {
                mappedQuality = OngoingGroupCallRequestedVideoQualityThumbnail;
                break;
            }
        }
        id<OngoingGroupCallBroadcastPartTask> task = requestVideoBroadcastPart(timestampMilliseconds, durationMilliseconds, channelId, mappedQuality, ^(OngoingGroupCallBroadcastPart * _Nullable part) {
            tgcalls::BroadcastPart parsedPart;
            parsedPart.timestampMilliseconds = part.timestampMilliseconds;

            parsedPart.responseTimestamp = part.responseTimestamp;

            tgcalls::BroadcastPart::Status mappedStatus;
            switch (part.status) {
                case OngoingGroupCallBroadcastPartStatusSuccess: {
                    mappedStatus = tgcalls::BroadcastPart::Status::Success;
                    break;
                }
                case OngoingGroupCallBroadcastPartStatusNotReady: {
                    mappedStatus = tgcalls::BroadcastPart::Status::NotReady;
                    break;
                }
                case OngoingGroupCallBroadcastPartStatusResyncNeeded: {
                    mappedStatus = tgcalls::BroadcastPart::Status::ResyncNeeded;
                    break;
                }
                default: {
                    mappedStatus = tgcalls::BroadcastPart::Status::NotReady;
                    break;
                }
            }
            parsedPart.status = mappedStatus;

            parsedPart.data.resize(part.oggData.length);
            [part.oggData getBytes:parsedPart.data.data() length:part.oggData.length];

            completion(std::move(parsedPart));
        });
        return std::make_shared<BroadcastPartTaskImpl>(task);
    };
    
    arguments.updateAudioLevel = nullptr;
    
    _context = std::make_unique<tgcalls::StreamingMediaContext>(std::move(arguments));
    
    for (MediaStreamingVideoSink *storedSink in _sinks.allValues) {
        _context->addVideoSink("unified", [storedSink sink]);
    }
}

- (void)start {
    [self resetContext];
}

- (void)stop {
    _context.reset();
}

- (GroupCallDisposable * _Nonnull)addVideoOutput:(void (^_Nonnull)(CallVideoFrameData * _Nonnull))sink {
    int sinkId = _nextSinkId;
    _nextSinkId += 1;

    MediaStreamingVideoSink *storedSink = [[MediaStreamingVideoSink alloc] initWithSink:sink];
    _sinks[@(sinkId)] = storedSink;

    if (_context) {
        _context->addVideoSink("unified", [storedSink sink]);
    }

    __weak MediaStreamingContext *weakSelf = self;
    id<OngoingCallThreadLocalContextQueueWebrtc> queue = _queue;
    return [[GroupCallDisposable alloc] initWithBlock:^{
        [queue dispatch:^{
            __strong MediaStreamingContext *strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            [strongSelf->_sinks removeObjectForKey:@(sinkId)];
        }];
    }];
}

- (void)getAudio:(int16_t * _Nonnull)audioSamples numSamples:(NSInteger)numSamples numChannels:(NSInteger)numChannels samplesPerSecond:(NSInteger)samplesPerSecond {
    if (_context) {
        _context->getAudio(audioSamples, (size_t)numSamples, (size_t)numChannels, (uint32_t)samplesPerSecond);
    } else {
        memset(audioSamples, 0, numSamples * numChannels * sizeof(int16_t));
    }
}

@end
