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
        std::function<void (const TgVoipState &)> stateUpdated,
        std::function<void (const std::vector<uint8_t> &)> signalingDataEmitted
    );
    ~Manager();
    
    void start();
    void receiveSignalingData(const std::vector<uint8_t> &data);
    void setIncomingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink);
    void setOutgoingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink);
    
private:
    rtc::Thread *_thread;
    TgVoipEncryptionKey _encryptionKey;
    std::unique_ptr<rtc::Thread> _networkThread;
    std::unique_ptr<rtc::Thread> _mediaThread;
    std::function<void (const TgVoipState &)> _stateUpdated;
    std::function<void (const std::vector<uint8_t> &)> _signalingDataEmitted;
    std::unique_ptr<ThreadLocalObject<NetworkManager>> _networkManager;
    std::unique_ptr<ThreadLocalObject<MediaManager>> _mediaManager;
    
private:
};

#ifdef TGVOIP_NAMESPACE
}
#endif

#endif
