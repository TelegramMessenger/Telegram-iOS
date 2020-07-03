#include "VideoCaptureInterfaceImpl.h"

#include "CodecsApple.h"
#include "Manager.h"
#include "MediaManager.h"

#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

TgVoipVideoCaptureInterfaceObject::TgVoipVideoCaptureInterfaceObject() {
    _useFrontCamera = true;
    _isVideoEnabled = true;
    _videoSource = makeVideoSource(Manager::getMediaThread(), MediaManager::getWorkerThread());
    //this should outlive the capturer
    _videoCapturer = makeVideoCapturer(_videoSource, _useFrontCamera, [this](bool isActive) {
        if (this->_isActiveUpdated) {
            this->_isActiveUpdated(isActive);
        }
    });
}
    
TgVoipVideoCaptureInterfaceObject::~TgVoipVideoCaptureInterfaceObject() {
    if (_currentSink != nullptr) {
        _videoSource->RemoveSink(_currentSink.get());
    }
}

void TgVoipVideoCaptureInterfaceObject::switchCamera() {
    _useFrontCamera = !_useFrontCamera;
    _videoCapturer = makeVideoCapturer(_videoSource, _useFrontCamera, [this](bool isActive) {
        if (this->_isActiveUpdated) {
            this->_isActiveUpdated(isActive);
        }
    });
}

void TgVoipVideoCaptureInterfaceObject::setIsVideoEnabled(bool isVideoEnabled) {
    if (_isVideoEnabled != isVideoEnabled) {
        _isVideoEnabled = isVideoEnabled;
        _videoCapturer->setIsEnabled(isVideoEnabled);
    }
}
    
void TgVoipVideoCaptureInterfaceObject::setVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
    if (_currentSink != nullptr) {
        _videoSource->RemoveSink(_currentSink.get());
    }
    _currentSink = sink;
    if (_currentSink != nullptr) {
        _videoSource->AddOrUpdateSink(_currentSink.get(), rtc::VideoSinkWants());
    }
}
    
void TgVoipVideoCaptureInterfaceObject::setIsActiveUpdated(std::function<void (bool)> isActiveUpdated) {
    _isActiveUpdated = isActiveUpdated;
}

TgVoipVideoCaptureInterfaceImpl::TgVoipVideoCaptureInterfaceImpl() {
    _impl.reset(new ThreadLocalObject<TgVoipVideoCaptureInterfaceObject>(
        Manager::getMediaThread(),
        []() {
            return new TgVoipVideoCaptureInterfaceObject();
        }
    ));
}
    
TgVoipVideoCaptureInterfaceImpl::~TgVoipVideoCaptureInterfaceImpl() {
    
}

void TgVoipVideoCaptureInterfaceImpl::switchCamera() {
    _impl->perform([](TgVoipVideoCaptureInterfaceObject *impl) {
        impl->switchCamera();
    });
}

void TgVoipVideoCaptureInterfaceImpl::setIsVideoEnabled(bool isVideoEnabled) {
    _impl->perform([isVideoEnabled](TgVoipVideoCaptureInterfaceObject *impl) {
        impl->setIsVideoEnabled(isVideoEnabled);
    });
}
    
void TgVoipVideoCaptureInterfaceImpl::setVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
    _impl->perform([sink](TgVoipVideoCaptureInterfaceObject *impl) {
        impl->setVideoOutput(sink);
    });
}

}
