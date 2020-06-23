#ifndef CODECS_APPLE_H
#define CODECS_APPLE_H

#include "rtc_base/thread.h"
#include "api/video_codecs/video_encoder_factory.h"
#include "api/video_codecs/video_decoder_factory.h"
#include "api/media_stream_interface.h"

#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

class VideoCapturerInterface {
public:
    virtual ~VideoCapturerInterface();
};

void configurePlatformAudio();
std::unique_ptr<webrtc::VideoEncoderFactory> makeVideoEncoderFactory();
std::unique_ptr<webrtc::VideoDecoderFactory> makeVideoDecoderFactory();
bool supportsH265Encoding();
rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> makeVideoSource(rtc::Thread *signalingThread, rtc::Thread *workerThread);
std::unique_ptr<VideoCapturerInterface> makeVideoCapturer(rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> source, bool useFrontCamera, std::function<void(bool)> isActiveUpdated);

#ifdef TGVOIP_NAMESPACE
}
#endif

#endif
