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
    Manager(
        rtc::Thread *thread,
        TgVoipEncryptionKey encryptionKey,
        bool enableP2P,
        std::function<void (const TgVoipState &)> stateUpdated,
        std::function<void (bool)> videoStateUpdated,
        std::function<void (const std::vector<uint8_t> &)> signalingDataEmitted
    );
    ~Manager();
    
    void start();
    void receiveSignalingData(const std::vector<uint8_t> &data);
    void setSendVideo(bool sendVideo);
    void switchVideoCamera();
    void setIncomingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink);
    void setOutgoingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink);
    
private:
    rtc::Thread *_thread;
    TgVoipEncryptionKey _encryptionKey;
    bool _enableP2P;
    std::function<void (const TgVoipState &)> _stateUpdated;
    std::function<void (bool)> _videoStateUpdated;
    std::function<void (const std::vector<uint8_t> &)> _signalingDataEmitted;
    std::unique_ptr<ThreadLocalObject<NetworkManager>> _networkManager;
    std::unique_ptr<ThreadLocalObject<MediaManager>> _mediaManager;
    bool _isVideoRequested;
    
private:
};

#ifdef TGVOIP_NAMESPACE
}
#endif

#endif
