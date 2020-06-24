#include <mutex>

#include "TgVoip.h"

#include "rtc_base/logging.h"

#include "Manager.h"

#include <stdarg.h>
#include <iostream>

#import <Foundation/Foundation.h>

#include <sys/time.h>

#ifndef TGVOIP_USE_CUSTOM_CRYPTO
/*extern "C" {
#include <openssl/sha.h>
#include <openssl/aes.h>
#include <openssl/modes.h>
#include <openssl/rand.h>
#include <openssl/crypto.h>
}

static void tgvoip_openssl_aes_ige_encrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
    AES_KEY akey;
    AES_set_encrypt_key(key, 32*8, &akey);
    AES_ige_encrypt(in, out, length, &akey, iv, AES_ENCRYPT);
}

static void tgvoip_openssl_aes_ige_decrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
    AES_KEY akey;
    AES_set_decrypt_key(key, 32*8, &akey);
    AES_ige_encrypt(in, out, length, &akey, iv, AES_DECRYPT);
}

static void tgvoip_openssl_rand_bytes(uint8_t* buffer, size_t len){
    RAND_bytes(buffer, (int)len);
}

static void tgvoip_openssl_sha1(uint8_t* msg, size_t len, uint8_t* output){
    SHA1(msg, len, output);
}

static void tgvoip_openssl_sha256(uint8_t* msg, size_t len, uint8_t* output){
    SHA256(msg, len, output);
}

static void tgvoip_openssl_aes_ctr_encrypt(uint8_t* inout, size_t length, uint8_t* key, uint8_t* iv, uint8_t* ecount, uint32_t* num){
    AES_KEY akey;
    AES_set_encrypt_key(key, 32*8, &akey);
    CRYPTO_ctr128_encrypt(inout, inout, length, &akey, iv, ecount, num, (block128_f) AES_encrypt);
}

static void tgvoip_openssl_aes_cbc_encrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
    AES_KEY akey;
    AES_set_encrypt_key(key, 256, &akey);
    AES_cbc_encrypt(in, out, length, &akey, iv, AES_ENCRYPT);
}

static void tgvoip_openssl_aes_cbc_decrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
    AES_KEY akey;
    AES_set_decrypt_key(key, 256, &akey);
    AES_cbc_encrypt(in, out, length, &akey, iv, AES_DECRYPT);
}

CryptoFunctions Layer92::crypto={
        tgvoip_openssl_rand_bytes,
        tgvoip_openssl_sha1,
        tgvoip_openssl_sha256,
        tgvoip_openssl_aes_ige_encrypt,
        tgvoip_openssl_aes_ige_decrypt,
        tgvoip_openssl_aes_ctr_encrypt,
        tgvoip_openssl_aes_cbc_encrypt,
        tgvoip_openssl_aes_cbc_decrypt
};*/
#endif


#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

class LogSinkImpl : public rtc::LogSink {
public:
    LogSinkImpl() {
    }
    virtual ~LogSinkImpl() {
    }
    
    virtual void OnLogMessage(const std::string &msg, rtc::LoggingSeverity severity, const char *tag) override {
        OnLogMessage(std::string(tag) + ": " + msg);
    }
    
    virtual void OnLogMessage(const std::string &message, rtc::LoggingSeverity severity) override {
        OnLogMessage(message);
    }
    
    virtual void OnLogMessage(const std::string &message) override {
        time_t rawTime;
        time(&rawTime);
        struct tm timeinfo;
        localtime_r(&rawTime, &timeinfo);
        
        timeval curTime;
        gettimeofday(&curTime, nullptr);
        int32_t milliseconds = curTime.tv_usec / 1000;
        
        _data << (timeinfo.tm_year + 1900);
        _data << "-" << (timeinfo.tm_mon + 1);
        _data << "-" << (timeinfo.tm_mday);
        _data << " " << timeinfo.tm_hour;
        _data << ":" << timeinfo.tm_min;
        _data << ":" << timeinfo.tm_sec;
        _data << ":" << milliseconds;
        _data << " " << message;
    }
    
public:
    std::ostringstream _data;
};

static rtc::Thread *makeManagerThread() {
    static std::unique_ptr<rtc::Thread> value = rtc::Thread::Create();
    value->SetName("WebRTC-Manager", nullptr);
    value->Start();
    return value.get();
}


static rtc::Thread *getManagerThread() {
    static rtc::Thread *value = makeManagerThread();
    return value;
}

class TgVoipImpl : public TgVoip, public sigslot::has_slots<> {
public:
    TgVoipImpl(
            std::vector<TgVoipEndpoint> const &endpoints,
            TgVoipPersistentState const &persistentState,
            std::unique_ptr<TgVoipProxy> const &proxy,
            std::vector<TgVoipRtcServer> const &rtcServers,
            TgVoipConfig const &config,
            TgVoipEncryptionKey const &encryptionKey,
            bool isVideo,
            TgVoipNetworkType initialNetworkType,
            std::function<void(TgVoipState)> stateUpdated,
            std::function<void(bool)> videoStateUpdated,
            std::function<void(bool)> remoteVideoIsActiveUpdated,
            std::function<void(const std::vector<uint8_t> &)> signalingDataEmitted
    ) :
    _stateUpdated(stateUpdated),
    _signalingDataEmitted(signalingDataEmitted) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            rtc::LogMessage::LogToDebug(rtc::LS_INFO);
            rtc::LogMessage::SetLogToStderr(true);
        });
        rtc::LogMessage::AddLogToStream(&_logSink, rtc::LS_INFO);
        
        bool enableP2P = config.enableP2P;
        
        _manager.reset(new ThreadLocalObject<Manager>(getManagerThread(), [encryptionKey = encryptionKey, enableP2P = enableP2P, isVideo, stateUpdated, videoStateUpdated, remoteVideoIsActiveUpdated, signalingDataEmitted, rtcServers](){
            return new Manager(
                getManagerThread(),
                encryptionKey,
                enableP2P,
                rtcServers,
                isVideo,
                [stateUpdated](const TgVoipState &state) {
                    stateUpdated(state);
                },
                [videoStateUpdated](bool isActive) {
                    videoStateUpdated(isActive);
                },
                [remoteVideoIsActiveUpdated](bool isActive) {
                    remoteVideoIsActiveUpdated(isActive);
                },
                [signalingDataEmitted](const std::vector<uint8_t> &data) {
                    signalingDataEmitted(data);
                }
            );
        }));
        _manager->perform([](Manager *manager) {
            manager->start();
        });
    }

    ~TgVoipImpl() override {
        rtc::LogMessage::RemoveLogToStream(&_logSink);
    }
    
    void receiveSignalingData(const std::vector<uint8_t> &data) override {
        _manager->perform([data](Manager *manager) {
            manager->receiveSignalingData(data);
        });
    };
    
    void setSendVideo(bool sendVideo) override {
        _manager->perform([sendVideo](Manager *manager) {
            manager->setSendVideo(sendVideo);
        });
    };
    
    void switchVideoCamera() override {
        _manager->perform([](Manager *manager) {
            manager->switchVideoCamera();
        });
    }

    void setNetworkType(TgVoipNetworkType networkType) override {
        /*message::NetworkType mappedType;

        switch (networkType) {
            case TgVoipNetworkType::Unknown:
                mappedType = message::NetworkType::nUnknown;
                break;
            case TgVoipNetworkType::Gprs:
                mappedType = message::NetworkType::nGprs;
                break;
            case TgVoipNetworkType::Edge:
                mappedType = message::NetworkType::nEdge;
                break;
            case TgVoipNetworkType::ThirdGeneration:
                mappedType = message::NetworkType::n3gOrAbove;
                break;
            case TgVoipNetworkType::Hspa:
                mappedType = message::NetworkType::n3gOrAbove;
                break;
            case TgVoipNetworkType::Lte:
                mappedType = message::NetworkType::n3gOrAbove;
                break;
            case TgVoipNetworkType::WiFi:
                mappedType = message::NetworkType::nHighSpeed;
                break;
            case TgVoipNetworkType::Ethernet:
                mappedType = message::NetworkType::nHighSpeed;
                break;
            case TgVoipNetworkType::OtherHighSpeed:
                mappedType = message::NetworkType::nHighSpeed;
                break;
            case TgVoipNetworkType::OtherLowSpeed:
                mappedType = message::NetworkType::nEdge;
                break;
            case TgVoipNetworkType::OtherMobile:
                mappedType = message::NetworkType::n3gOrAbove;
                break;
            case TgVoipNetworkType::Dialup:
                mappedType = message::NetworkType::nGprs;
                break;
            default:
                mappedType = message::NetworkType::nUnknown;
                break;
        }

        controller_->SetNetworkType(mappedType);*/
    }

    void setMuteMicrophone(bool muteMicrophone) override {
        _manager->perform([muteMicrophone](Manager *manager) {
            manager->setMuteOutgoingAudio(muteMicrophone);
        });
    }
    
    void setIncomingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) override {
        _manager->perform([sink](Manager *manager) {
            manager->setIncomingVideoOutput(sink);
        });
    }
    
    void setOutgoingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) override {
        _manager->perform([sink](Manager *manager) {
            manager->setOutgoingVideoOutput(sink);
        });
    }

    void setAudioOutputGainControlEnabled(bool enabled) override {
    }

    void setEchoCancellationStrength(int strength) override {
    }

    std::string getLastError() override {
        return "";  // TODO: not implemented
    }

    std::string getDebugInfo() override {
        return "";  // TODO: not implemented
    }

    int64_t getPreferredRelayId() override {
        return 0;  // we don't have endpoint ids
    }

    TgVoipTrafficStats getTrafficStats() override {
        return TgVoipTrafficStats{};  // TODO: not implemented
    }

    TgVoipPersistentState getPersistentState() override {
        return TgVoipPersistentState{};  // we dont't have such information
    }

    TgVoipFinalState stop() override {
        TgVoipFinalState finalState;
        finalState.debugLog = _logSink._data.str();
        finalState.isRatingSuggested = false;

        return finalState;
    }

    /*void controllerStateCallback(Controller::State state) {
        if (onStateUpdated_) {
            TgVoipState mappedState;
            switch (state) {
                case Controller::State::WaitInit:
                    mappedState = TgVoipState::WaitInit;
                    break;
                case Controller::State::WaitInitAck:
                    mappedState = TgVoipState::WaitInitAck;
                    break;
                case Controller::State::Established:
                    mappedState = TgVoipState::Estabilished;
                    break;
                case Controller::State::Failed:
                    mappedState = TgVoipState::Failed;
                    break;
                case Controller::State::Reconnecting:
                    mappedState = TgVoipState::Reconnecting;
                    break;
                default:
                    mappedState = TgVoipState::Estabilished;
                    break;
            }

            onStateUpdated_(mappedState);
        }
    }*/

private:
    std::unique_ptr<ThreadLocalObject<Manager>> _manager;
    std::function<void(TgVoipState)> _stateUpdated;
    std::function<void(const std::vector<uint8_t> &)> _signalingDataEmitted;
    
    LogSinkImpl _logSink;
};

std::function<void(std::string const &)> globalLoggingFunction;

void __tgvoip_call_tglog(const char *format, ...){
    va_list vaArgs;
    va_start(vaArgs, format);

    va_list vaCopy;
    va_copy(vaCopy, vaArgs);
    const int length = std::vsnprintf(nullptr, 0, format, vaCopy);
    va_end(vaCopy);

    std::vector<char> zc(length + 1);
    std::vsnprintf(zc.data(), zc.size(), format, vaArgs);
    va_end(vaArgs);

    if (globalLoggingFunction != nullptr) {
        globalLoggingFunction(std::string(zc.data(), zc.size()));
    }
}

void TgVoip::setLoggingFunction(std::function<void(std::string const &)> loggingFunction) {
    globalLoggingFunction = loggingFunction;
}

void TgVoip::setGlobalServerConfig(const std::string &serverConfig) {
}

int TgVoip::getConnectionMaxLayer() {
    return 92;  // TODO: retrieve from LayerBase
}

std::string TgVoip::getVersion() {
    return "";  // TODO: version not known while not released
}

TgVoip *TgVoip::makeInstance(
        TgVoipConfig const &config,
        TgVoipPersistentState const &persistentState,
        std::vector<TgVoipEndpoint> const &endpoints,
        std::unique_ptr<TgVoipProxy> const &proxy,
        std::vector<TgVoipRtcServer> const &rtcServers,
        TgVoipNetworkType initialNetworkType,
        TgVoipEncryptionKey const &encryptionKey,
        bool isVideo,
        std::function<void(TgVoipState)> stateUpdated,
        std::function<void(bool)> videoStateUpdated,
        std::function<void(bool)> remoteVideoIsActiveUpdated,
        std::function<void(const std::vector<uint8_t> &)> signalingDataEmitted
) {
    return new TgVoipImpl(
            endpoints,
            persistentState,
            proxy,
            rtcServers,
            config,
            encryptionKey,
            isVideo,
            initialNetworkType,
            stateUpdated,
            videoStateUpdated,
            remoteVideoIsActiveUpdated,
            signalingDataEmitted
    );
}

TgVoip::~TgVoip() = default;

#ifdef TGVOIP_NAMESPACE
}
#endif
