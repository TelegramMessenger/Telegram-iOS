#ifndef __TGVOIP_H
#define __TGVOIP_H

#include <functional>
#include <vector>
#include <string>
#include <memory>

namespace rtc {
template <typename VideoFrameT>
class VideoSinkInterface;
}

namespace webrtc {
class VideoFrame;
}

#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

struct TgVoipProxy {
    std::string host;
    uint16_t port;
    std::string login;
    std::string password;
};

struct TgVoipRtcServer {
    std::string host;
    uint16_t port;
    std::string login;
    std::string password;
    bool isTurn;
};

enum class TgVoipEndpointType {
    Inet,
    Lan,
    UdpRelay,
    TcpRelay
};

struct TgVoipEdpointHost {
    std::string ipv4;
    std::string ipv6;
};

struct TgVoipEndpoint {
    int64_t endpointId;
    TgVoipEdpointHost host;
    uint16_t port;
    TgVoipEndpointType type;
    unsigned char peerTag[16];
};

enum class TgVoipNetworkType {
    Unknown,
    Gprs,
    Edge,
    ThirdGeneration,
    Hspa,
    Lte,
    WiFi,
    Ethernet,
    OtherHighSpeed,
    OtherLowSpeed,
    OtherMobile,
    Dialup
};

enum class TgVoipDataSaving {
    Never,
    Mobile,
    Always
};

struct TgVoipPersistentState {
    std::vector<uint8_t> value;
};

struct TgVoipConfig {
    double initializationTimeout;
    double receiveTimeout;
    TgVoipDataSaving dataSaving;
    bool enableP2P;
    bool enableAEC;
    bool enableNS;
    bool enableAGC;
    bool enableCallUpgrade;
#ifndef _WIN32
    std::string logPath;
#else
    std::wstring logPath;
#endif
    int maxApiLayer;
};

struct TgVoipEncryptionKey {
    std::vector<uint8_t> value;
    bool isOutgoing;
};

enum class TgVoipState {
    WaitInit,
    WaitInitAck,
    Estabilished,
    Failed,
    Reconnecting
};

struct TgVoipTrafficStats {
    uint64_t bytesSentWifi;
    uint64_t bytesReceivedWifi;
    uint64_t bytesSentMobile;
    uint64_t bytesReceivedMobile;
};

struct TgVoipFinalState {
    TgVoipPersistentState persistentState;
    std::string debugLog;
    TgVoipTrafficStats trafficStats;
    bool isRatingSuggested;
};

struct TgVoipAudioDataCallbacks {
    std::function<void(int16_t*, size_t)> input;
    std::function<void(int16_t*, size_t)> output;
    std::function<void(int16_t*, size_t)> preprocessed;
};

class TgVoip {
protected:
    TgVoip() = default;

public:
    static void setLoggingFunction(std::function<void(std::string const &)> loggingFunction);
    static void setGlobalServerConfig(std::string const &serverConfig);
    static int getConnectionMaxLayer();
    static std::string getVersion();
    static TgVoip *makeInstance(
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
    );

    virtual ~TgVoip();

    virtual void setNetworkType(TgVoipNetworkType networkType) = 0;
    virtual void setMuteMicrophone(bool muteMicrophone) = 0;
    virtual void setAudioOutputGainControlEnabled(bool enabled) = 0;
    virtual void setEchoCancellationStrength(int strength) = 0;
    
    virtual void setIncomingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) = 0;
    virtual void setOutgoingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) = 0;

    virtual std::string getLastError() = 0;
    virtual std::string getDebugInfo() = 0;
    virtual int64_t getPreferredRelayId() = 0;
    virtual TgVoipTrafficStats getTrafficStats() = 0;
    virtual TgVoipPersistentState getPersistentState() = 0;
    
    virtual void receiveSignalingData(const std::vector<uint8_t> &data) = 0;
    virtual void setSendVideo(bool sendVideo) = 0;
    virtual void switchVideoCamera() = 0;

    virtual TgVoipFinalState stop() = 0;
};

#ifdef TGVOIP_NAMESPACE
}
#endif

#endif
