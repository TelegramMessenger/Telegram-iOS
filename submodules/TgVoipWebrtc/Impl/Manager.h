#ifndef TGVOIP_WEBRTC_MANAGER_H
#define TGVOIP_WEBRTC_MANAGER_H

#include "ThreadLocalObject.h"
#include "NetworkManager.h"
#include "MediaManager.h"
#include "TgVoip.h"

#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

class Manager : public std::enable_shared_from_this<Manager> {
public:
    enum class VideoState {
        possible,
        outgoingRequested,
        incomingRequested,
        active
    };
    
    static rtc::Thread *getMediaThread();
    
    Manager(
        rtc::Thread *thread,
        TgVoipEncryptionKey encryptionKey,
        bool enableP2P,
        std::vector<TgVoipRtcServer> const &rtcServers,
        std::shared_ptr<TgVoipVideoCaptureInterface> videoCapture,
        std::function<void (const TgVoipState &, VideoState)> stateUpdated,
        std::function<void (bool)> remoteVideoIsActiveUpdated,
        std::function<void (const std::vector<uint8_t> &)> signalingDataEmitted
    );
    ~Manager();
    
    void start();
    void receiveSignalingData(const std::vector<uint8_t> &data);
    void requestVideo(std::shared_ptr<TgVoipVideoCaptureInterface> videoCapture);
    void setMuteOutgoingAudio(bool mute);
    void notifyIsLocalVideoActive(bool isActive);
    void setIncomingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink);
    
private:
    rtc::Thread *_thread;
    TgVoipEncryptionKey _encryptionKey;
    bool _enableP2P;
    std::vector<TgVoipRtcServer> _rtcServers;
    std::shared_ptr<TgVoipVideoCaptureInterface> _videoCapture;
    std::function<void (const TgVoipState &, VideoState)> _stateUpdated;
    std::function<void (bool)> _remoteVideoIsActiveUpdated;
    std::function<void (const std::vector<uint8_t> &)> _signalingDataEmitted;
    std::unique_ptr<ThreadLocalObject<NetworkManager>> _networkManager;
    std::unique_ptr<ThreadLocalObject<MediaManager>> _mediaManager;
    TgVoipState _state;
    VideoState _videoState;
    bool _didConnectOnce;
    
private:
};

#ifdef TGVOIP_NAMESPACE
}
#endif

#endif
