#include <mutex>

#include "TgVoip.h"

#include "Controller.h"
#include "Layer92.h"
#include "Message.h"

#include <stdarg.h>
#include <iostream>

#ifndef TGVOIP_USE_CUSTOM_CRYPTO
extern "C" {
#include <openssl/sha.h>
#include <openssl/aes.h>
#include <openssl/modes.h>
#include <openssl/rand.h>
#include <openssl/crypto.h>
}

void tgvoip_openssl_aes_ige_encrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
    AES_KEY akey;
    AES_set_encrypt_key(key, 32*8, &akey);
    AES_ige_encrypt(in, out, length, &akey, iv, AES_ENCRYPT);
}

void tgvoip_openssl_aes_ige_decrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
    AES_KEY akey;
    AES_set_decrypt_key(key, 32*8, &akey);
    AES_ige_encrypt(in, out, length, &akey, iv, AES_DECRYPT);
}

void tgvoip_openssl_rand_bytes(uint8_t* buffer, size_t len){
    RAND_bytes(buffer, (int)len);
}

void tgvoip_openssl_sha1(uint8_t* msg, size_t len, uint8_t* output){
    SHA1(msg, len, output);
}

void tgvoip_openssl_sha256(uint8_t* msg, size_t len, uint8_t* output){
    SHA256(msg, len, output);
}

void tgvoip_openssl_aes_ctr_encrypt(uint8_t* inout, size_t length, uint8_t* key, uint8_t* iv, uint8_t* ecount, uint32_t* num){
    AES_KEY akey;
    AES_set_encrypt_key(key, 32*8, &akey);
    CRYPTO_ctr128_encrypt(inout, inout, length, &akey, iv, ecount, num, (block128_f) AES_encrypt);
}

void tgvoip_openssl_aes_cbc_encrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
    AES_KEY akey;
    AES_set_encrypt_key(key, 256, &akey);
    AES_cbc_encrypt(in, out, length, &akey, iv, AES_ENCRYPT);
}

void tgvoip_openssl_aes_cbc_decrypt(uint8_t* in, uint8_t* out, size_t length, uint8_t* key, uint8_t* iv){
    AES_KEY akey;
    AES_set_decrypt_key(key, 256, &akey);
    AES_cbc_encrypt(in, out, length, &akey, iv, AES_DECRYPT);
}

const char * openssl_version() {
    return SSLeay_version(SSLEAY_VERSION);
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
};
#endif


#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

class TgVoipImpl : public TgVoip, public sigslot::has_slots<> {
public:
    TgVoipImpl(
            std::vector<TgVoipEndpoint> const &endpoints,
            TgVoipPersistentState const &persistentState,
            std::unique_ptr<TgVoipProxy> const &proxy,
            TgVoipConfig const &config,
            TgVoipEncryptionKey const &encryptionKey,
            TgVoipNetworkType initialNetworkType
#ifdef TGVOIP_USE_CUSTOM_CRYPTO
    ,
        TgVoipCrypto const &crypto
#endif
#ifdef TGVOIP_USE_CALLBACK_AUDIO_IO
            ,
            TgVoipAudioDataCallbacks const &audioDataCallbacks
#endif
    ) {
#ifdef TGVOIP_USE_CUSTOM_CRYPTO
        tgvoip::VoIPController::crypto.sha1 = crypto.sha1;
        tgvoip::VoIPController::crypto.sha256 = crypto.sha256;
        tgvoip::VoIPController::crypto.rand_bytes = crypto.rand_bytes;
        tgvoip::VoIPController::crypto.aes_ige_encrypt = crypto.aes_ige_encrypt;
        tgvoip::VoIPController::crypto.aes_ige_decrypt = crypto.aes_ige_decrypt;
        tgvoip::VoIPController::crypto.aes_ctr_encrypt = crypto.aes_ctr_encrypt;
#endif

//        std::cerr << "OpenSSL version: " << openssl_version() << std::endl;  // to verify because of WebRTC BoringSSL

        EncryptionKey encryptionKeyValue;
        memcpy(encryptionKeyValue, encryptionKey.value.data(), 256);
        controller_ = new Controller(encryptionKey.isOutgoing, encryptionKeyValue, 5, 3);

#ifdef TGVOIP_USE_CALLBACK_AUDIO_IO
        audioCallbacks = audioDataCallbacks;
        controller_->SignalRecord.connect(this, &TgVoipImpl::record);
        controller_->SignalPlay.connect(this, &TgVoipImpl::play);
#ifdef TGVOIP_PREPROCESSED_OUTPUT
        controller_->SignalPreprocessed.connect(this, &TgVoipImpl::preprocessed);
#endif
#endif

        if (proxy != nullptr) {
            controller_->SetProxy(rtc::ProxyType::PROXY_SOCKS5, rtc::SocketAddress(proxy->host, proxy->port),
                    proxy->login, proxy->password);
        }

        controller_->SignalNewState.connect(this, &TgVoipImpl::controllerStateCallback);
        controller_->Start();

        for (const auto &endpoint : endpoints) {
            rtc::SocketAddress addr(endpoint.host.ipv4, endpoint.port);
            Controller::EndpointType type;
            switch (endpoint.type) {
                case TgVoipEndpointType::UdpRelay:
                    type = Controller::EndpointType::UDP;
                    break;
                case TgVoipEndpointType::Lan:
                case TgVoipEndpointType::Inet:
                    type = Controller::EndpointType::P2P;
                    break;
                case TgVoipEndpointType::TcpRelay:
                    type = Controller::EndpointType::TCP;
                    break;
                default:
                    type = Controller::EndpointType::UDP;
                    break;
            }
            controller_->AddEndpoint(addr, endpoint.peerTag, type);
        }

        setNetworkType(initialNetworkType);

        switch (config.dataSaving) {
            case TgVoipDataSaving::Mobile:
                controller_->SetDataSaving(true);
                break;
            case TgVoipDataSaving::Always:
                controller_->SetDataSaving(true);
                break;
            default:
                controller_->SetDataSaving(false);
                break;
        }
    }

    ~TgVoipImpl() override {
        stop();
    }

    void setOnStateUpdated(std::function<void(TgVoipState)> onStateUpdated) override {
        std::lock_guard<std::mutex> lock(m_onStateUpdated);
        onStateUpdated_ = onStateUpdated;
    }

    void setOnSignalBarsUpdated(std::function<void(int)> onSignalBarsUpdated) override {
        std::lock_guard<std::mutex> lock(m_onSignalBarsUpdated);
        onSignalBarsUpdated_ = onSignalBarsUpdated;
    }

    void setNetworkType(TgVoipNetworkType networkType) override {
        message::NetworkType mappedType;

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

        controller_->SetNetworkType(mappedType);
    }

    void setMuteMicrophone(bool muteMicrophone) override {
        controller_->SetMute(muteMicrophone);
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
        TgVoipFinalState finalState = {
        };

        delete controller_;
        controller_ = nullptr;

        return finalState;
    }

    void controllerStateCallback(Controller::State state) {
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
    }

private:
#ifdef TGVOIP_USE_CALLBACK_AUDIO_IO
    TgVoipAudioDataCallbacks audioCallbacks;

    void play(const int16_t *data, size_t size) {
        if (!audioCallbacks.output)
            return;
        int16_t buf[size];
        memcpy(buf, data, size * 2);
        audioCallbacks.output(buf, size);
    }

    void record(int16_t *data, size_t size) {
        if (audioCallbacks.input)
            audioCallbacks.input(data, size);
    }

    void preprocessed(const int16_t *data, size_t size) {
        if (!audioCallbacks.preprocessed)
            return;
        int16_t buf[size];
        memcpy(buf, data, size * 2);
        audioCallbacks.preprocessed(buf, size);
    }
#endif

private:
    Controller *controller_;
    std::function<void(TgVoipState)> onStateUpdated_;
    std::function<void(int)> onSignalBarsUpdated_;
    std::mutex m_onStateUpdated, m_onSignalBarsUpdated;
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
        TgVoipNetworkType initialNetworkType,
        TgVoipEncryptionKey const &encryptionKey
#ifdef TGVOIP_USE_CUSTOM_CRYPTO
,
    TgVoipCrypto const &crypto
#endif
#ifdef TGVOIP_USE_CALLBACK_AUDIO_IO
        ,
        TgVoipAudioDataCallbacks const &audioDataCallbacks
#endif
) {
    return new TgVoipImpl(
            endpoints,
            persistentState,
            proxy,
            config,
            encryptionKey,
            initialNetworkType
#ifdef TGVOIP_USE_CUSTOM_CRYPTO
    ,
        crypto
#endif
#ifdef TGVOIP_USE_CALLBACK_AUDIO_IO
            ,
            audioDataCallbacks
#endif
    );
}

TgVoip::~TgVoip() = default;

#ifdef TGVOIP_NAMESPACE
}
#endif
