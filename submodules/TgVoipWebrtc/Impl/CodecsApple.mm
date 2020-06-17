#import "CodecsApple.h"

#include "absl/strings/match.h"
#include "api/audio_codecs/audio_decoder_factory_template.h"
#include "api/audio_codecs/audio_encoder_factory_template.h"
#include "api/audio_codecs/opus/audio_decoder_opus.h"
#include "api/audio_codecs/opus/audio_encoder_opus.h"
#include "api/rtp_parameters.h"
#include "api/task_queue/default_task_queue_factory.h"
#include "media/base/codec.h"
#include "media/base/media_constants.h"
#include "media/engine/webrtc_media_engine.h"
#include "modules/audio_device/include/audio_device_default.h"
#include "rtc_base/task_utils/repeating_task.h"
#include "system_wrappers/include/field_trial.h"
#include "api/video/builtin_video_bitrate_allocator_factory.h"
#include "api/video/video_bitrate_allocation.h"

#include "sdk/objc/components/video_codec/RTCVideoEncoderFactoryH264.h"
#include "sdk/objc/components/video_codec/RTCVideoDecoderFactoryH264.h"
#include "sdk/objc/components/video_codec/RTCDefaultVideoEncoderFactory.h"
#include "sdk/objc/components/video_codec/RTCDefaultVideoDecoderFactory.h"
#include "sdk/objc/native/api/video_encoder_factory.h"
#include "sdk/objc/native/api/video_decoder_factory.h"

#include "sdk/objc/native/src/objc_video_track_source.h"
#include "api/video_track_source_proxy.h"
#include "sdk/objc/api/RTCVideoRendererAdapter.h"
#include "sdk/objc/native/api/video_frame.h"
#include "api/media_types.h"

#import "VideoCameraCapturer.h"

@interface VideoCapturerInterfaceImplReference : NSObject {
    VideoCameraCapturer *_videoCapturer;
}

@end

@implementation VideoCapturerInterfaceImplReference

- (instancetype)initWithSource:(rtc::scoped_refptr<webrtc::VideoTrackSourceInterface>)source {
    self = [super init];
    if (self != nil) {
        assert([NSThread isMainThread]);
        
        _videoCapturer = [[VideoCameraCapturer alloc] initWithSource:source];
        
        AVCaptureDevice *frontCamera = nil;
        for (AVCaptureDevice *device in [VideoCameraCapturer captureDevices]) {
            if (device.position == AVCaptureDevicePositionFront) {
                frontCamera = device;
                break;
            }
        }
        
        if (frontCamera == nil) {
            return nil;
        }
        
        NSArray<AVCaptureDeviceFormat *> *sortedFormats = [[VideoCameraCapturer supportedFormatsForDevice:frontCamera] sortedArrayUsingComparator:^NSComparisonResult(AVCaptureDeviceFormat* lhs, AVCaptureDeviceFormat *rhs) {
            int32_t width1 = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription).width;
            int32_t width2 = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription).width;
            return width1 < width2 ? NSOrderedAscending : NSOrderedDescending;
        }];
        
        AVCaptureDeviceFormat *bestFormat = nil;
        for (AVCaptureDeviceFormat *format in sortedFormats) {
            CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            if (dimensions.width >= 1000 || dimensions.height >= 1000) {
                bestFormat = format;
                break;
            }
        }
        
        if (bestFormat == nil) {
            assert(false);
            return nil;
        }
        
        AVFrameRateRange *frameRateRange = [[bestFormat.videoSupportedFrameRateRanges sortedArrayUsingComparator:^NSComparisonResult(AVFrameRateRange *lhs, AVFrameRateRange *rhs) {
            if (lhs.maxFrameRate < rhs.maxFrameRate) {
                return NSOrderedAscending;
            } else {
                return NSOrderedDescending;
            }
        }] lastObject];
        
        if (frameRateRange == nil) {
            assert(false);
            return nil;
        }
        
        [_videoCapturer startCaptureWithDevice:frontCamera format:bestFormat fps:30];
    }
    return self;
}

- (void)dealloc {
    assert([NSThread isMainThread]);
    
    [_videoCapturer stopCapture];
}

@end

@interface VideoCapturerInterfaceImplHolder : NSObject

@property (nonatomic) void *reference;

@end

@implementation VideoCapturerInterfaceImplHolder

@end

#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

class VideoCapturerInterfaceImpl: public VideoCapturerInterface {
public:
    VideoCapturerInterfaceImpl(rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source) :
    _source(source) {
        _implReference = [[VideoCapturerInterfaceImplHolder alloc] init];
        VideoCapturerInterfaceImplHolder *implReference = _implReference;
        dispatch_async(dispatch_get_main_queue(), ^{
            VideoCapturerInterfaceImplReference *value = [[VideoCapturerInterfaceImplReference alloc] initWithSource:source];
            if (value != nil) {
                implReference.reference = (void *)CFBridgingRetain(value);
            }
        });
    }
    
    virtual ~VideoCapturerInterfaceImpl() {
        VideoCapturerInterfaceImplHolder *implReference = _implReference;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (implReference.reference != nil) {
                CFBridgingRelease(implReference.reference);
            }
        });
    }
    
private:
    rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> _source;
    VideoCapturerInterfaceImplHolder *_implReference;
};

VideoCapturerInterface::~VideoCapturerInterface() {
}

std::unique_ptr<webrtc::VideoEncoderFactory> makeVideoEncoderFactory() {
    return webrtc::ObjCToNativeVideoEncoderFactory([[RTCDefaultVideoEncoderFactory alloc] init]);
}

std::unique_ptr<webrtc::VideoDecoderFactory> makeVideoDecoderFactory() {
    return webrtc::ObjCToNativeVideoDecoderFactory([[RTCDefaultVideoDecoderFactory alloc] init]);
}

rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> makeVideoSource(rtc::Thread *signalingThread, rtc::Thread *workerThread) {
    rtc::scoped_refptr<webrtc::ObjCVideoTrackSource> objCVideoTrackSource(new rtc::RefCountedObject<webrtc::ObjCVideoTrackSource>());
    return webrtc::VideoTrackSourceProxy::Create(signalingThread, workerThread, objCVideoTrackSource);
}

std::unique_ptr<VideoCapturerInterface> makeVideoCapturer(rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source) {
    return std::make_unique<VideoCapturerInterfaceImpl>(source);
}

#ifdef TGVOIP_NAMESPACE
}
#endif
