#ifndef VIDEO_CAPTURE_INTERFACE_IMPL_H
#define VIDEO_CAPTURE_INTERFACE_IMPL_H

#include "TgVoip.h"
#include <memory>
#include "ThreadLocalObject.h"
#include "api/media_stream_interface.h"

#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

class VideoCapturerInterface;

class TgVoipVideoCaptureInterfaceObject {
public:
    TgVoipVideoCaptureInterfaceObject();
    ~TgVoipVideoCaptureInterfaceObject();
    
    void switchCamera();
    void setVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink);
    void setIsActiveUpdated(std::function<void (bool)> isActiveUpdated);
    
public:
    rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> _videoSource;
    std::unique_ptr<VideoCapturerInterface> _videoCapturer;
    
private:
    std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> _currentSink;
    std::function<void (bool)> _isActiveUpdated;
    bool _useFrontCamera;
};

class TgVoipVideoCaptureInterfaceImpl : public TgVoipVideoCaptureInterface {
public:
    TgVoipVideoCaptureInterfaceImpl();
    virtual ~TgVoipVideoCaptureInterfaceImpl();
    
    virtual void switchCamera();
    virtual void setVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink);
    
public:
    std::unique_ptr<ThreadLocalObject<TgVoipVideoCaptureInterfaceObject>> _impl;
};

#ifdef TGVOIP_NAMESPACE
}
#endif

#endif
