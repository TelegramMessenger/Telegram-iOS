#include "Manager.h"

#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

Manager::Manager(
    rtc::Thread *thread,
    TgVoipEncryptionKey encryptionKey,
    std::function<void (const TgVoipState &)> stateUpdated,
    std::function<void (const std::vector<uint8_t> &)> signalingDataEmitted
) :
_thread(thread),
_encryptionKey(encryptionKey),
_networkThread(rtc::Thread::CreateWithSocketServer()),
_mediaThread(rtc::Thread::Create()),
_stateUpdated(stateUpdated),
_signalingDataEmitted(signalingDataEmitted) {
    assert(_thread->IsCurrent());
    
    _networkThread->Start();
    _mediaThread->Start();
}

Manager::~Manager() {
    assert(_thread->IsCurrent());
}

void Manager::start() {
    auto weakThis = std::weak_ptr<Manager>(shared_from_this());
    _networkManager.reset(new ThreadLocalObject<NetworkManager>(_networkThread.get(), [networkThreadPtr = _networkThread.get(), encryptionKey = _encryptionKey, thread = _thread, weakThis]() {
        return new NetworkManager(
            networkThreadPtr,
            encryptionKey,
            [thread, weakThis](const NetworkManager::State &state) {
                thread->Invoke<void>(RTC_FROM_HERE, [weakThis, state]() {
                    auto strongThis = weakThis.lock();
                    if (strongThis == nullptr) {
                        return;
                    }
                    TgVoipState mappedState;
                    if (state.isReadyToSendData) {
                        mappedState = TgVoipState::Estabilished;
                    } else {
                        mappedState = TgVoipState::Reconnecting;
                    }
                    strongThis->_stateUpdated(mappedState);
                    
                    strongThis->_mediaManager->perform([state](MediaManager *mediaManager) {
                        mediaManager->setIsConnected(state.isReadyToSendData);
                    });
                });
            },
            [thread, weakThis](const rtc::CopyOnWriteBuffer &packet) {
                thread->PostTask(RTC_FROM_HERE, [weakThis, packet]() {
                    auto strongThis = weakThis.lock();
                    if (strongThis == nullptr) {
                        return;
                    }
                    strongThis->_mediaManager->perform([packet](MediaManager *mediaManager) {
                        mediaManager->receivePacket(packet);
                    });
                });
            },
            [thread, weakThis](const std::vector<uint8_t> &data) {
                thread->PostTask(RTC_FROM_HERE, [weakThis, data]() {
                    auto strongThis = weakThis.lock();
                    if (strongThis == nullptr) {
                        return;
                    }
                    strongThis->_signalingDataEmitted(data);
                });
            }
        );
    }));
    bool isOutgoing = _encryptionKey.isOutgoing;
    _mediaManager.reset(new ThreadLocalObject<MediaManager>(_mediaThread.get(), [mediaThreadPtr = _mediaThread.get(), isOutgoing, thread = _thread, weakThis]() {
        return new MediaManager(
            mediaThreadPtr,
            isOutgoing,
            [thread, weakThis](const rtc::CopyOnWriteBuffer &packet) {
                thread->PostTask(RTC_FROM_HERE, [weakThis, packet]() {
                    auto strongThis = weakThis.lock();
                    if (strongThis == nullptr) {
                        return;
                    }
                    strongThis->_networkManager->perform([packet](NetworkManager *networkManager) {
                        networkManager->sendPacket(packet);
                    });
                });
            }
        );
    }));
}

void Manager::receiveSignalingData(const std::vector<uint8_t> &data) {
    _networkManager->perform([data](NetworkManager *networkManager) {
        networkManager->receiveSignalingData(data);
    });
}

void Manager::setIncomingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
    _mediaManager->perform([sink](MediaManager *mediaManager) {
        mediaManager->setIncomingVideoOutput(sink);
    });
}

void Manager::setOutgoingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
    _mediaManager->perform([sink](MediaManager *mediaManager) {
        mediaManager->setOutgoingVideoOutput(sink);
    });
}

#ifdef TGVOIP_NAMESPACE
}
#endif
