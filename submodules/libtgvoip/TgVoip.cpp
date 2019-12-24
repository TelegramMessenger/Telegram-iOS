#import "TgVoip.h"

#import "VoIPController.h"
#import "VoIPServerConfig.h"

class TgVoipImpl : public TgVoip {
public:
    tgvoip::VoIPController *controller_;
    std::function<void(TgVoipState)> stateUpdated_;
    std::function<void(int)> signalBarsUpdated_;
    
    TgVoipImpl(
        TgVoipCrypto const &crypto,
        std::vector<TgVoipEndpoint> const &endpoints,
        TgVoipPersistentState const &persistentState,
        std::unique_ptr<TgVoipProxy> const &proxy,
        TgVoipConfig const &config,
        TgVoipEncryptionKey const &encryptionKey,
        TgVoipNetworkType initialNetworkType
    ) {
        tgvoip::VoIPController::crypto.sha1 = crypto.sha1;
        tgvoip::VoIPController::crypto.sha256 = crypto.sha256;
        tgvoip::VoIPController::crypto.rand_bytes = crypto.rand_bytes;
        tgvoip::VoIPController::crypto.aes_ige_encrypt = crypto.aes_ige_encrypt;
        tgvoip::VoIPController::crypto.aes_ige_decrypt = crypto.aes_ige_decrypt;
        tgvoip::VoIPController::crypto.aes_ctr_encrypt = crypto.aes_ctr_encrypt;
        
        controller_ = new tgvoip::VoIPController();
        controller_->implData = this;
        
        controller_->SetPersistentState(persistentState.value);
        
        if (proxy != nullptr) {
            controller_->SetProxy(tgvoip::PROXY_SOCKS5, proxy->host, proxy->port, proxy->login, proxy->password);
        }
        
        auto callbacks = tgvoip::VoIPController::Callbacks();
        callbacks.connectionStateChanged = &TgVoipImpl::controllerStateCallback;
        callbacks.groupCallKeyReceived = NULL;
        callbacks.groupCallKeySent = NULL;
        callbacks.signalBarCountChanged = &TgVoipImpl::signalBarsCallback;
        callbacks.upgradeToGroupCallRequested = NULL;
        controller_->SetCallbacks(callbacks);
        
        std::vector<tgvoip::Endpoint> mappedEndpoints;
        for (auto endpoint : endpoints) {
            bool isIpv6 = false;
            struct in6_addr addrIpV6;
            if (inet_pton(AF_INET6, endpoint.host.c_str(), &addrIpV6)) {
                isIpv6 = true;
            }
            
            tgvoip::Endpoint::Type mappedType = tgvoip::Endpoint::Type::UDP_RELAY;
            switch (endpoint.type) {
                case TgVoipEndpointType::UdpRelay:
                    mappedType = tgvoip::Endpoint::Type::UDP_RELAY;
                    break;
                case TgVoipEndpointType::Lan:
                    mappedType = tgvoip::Endpoint::Type::UDP_P2P_LAN;
                    break;
                case TgVoipEndpointType::Inet:
                    mappedType = tgvoip::Endpoint::Type::UDP_P2P_INET;
                    break;
                case TgVoipEndpointType::TcpRelay:
                    mappedType = tgvoip::Endpoint::Type::TCP_RELAY;
                    break;
                default:
                    mappedType = tgvoip::Endpoint::Type::UDP_RELAY;
                    break;
            }
            
            tgvoip::IPv4Address address(isIpv6 ? std::string() : endpoint.host);
            tgvoip::IPv6Address addressv6(isIpv6 ? endpoint.host : std::string());
            
            mappedEndpoints.push_back(tgvoip::Endpoint(endpoint.endpointId, endpoint.port, address, addressv6, mappedType, endpoint.peerTag));
        }
        
        int mappedDataSaving = tgvoip::DATA_SAVING_NEVER;
        switch (config.dataSaving) {
            case TgVoipDataSaving::Mobile:
                mappedDataSaving = tgvoip::DATA_SAVING_MOBILE;
                break;
            case TgVoipDataSaving::Always:
                mappedDataSaving = tgvoip::DATA_SAVING_ALWAYS;
                break;
            default:
                mappedDataSaving = tgvoip::DATA_SAVING_NEVER;
                break;
        }
        
        tgvoip::VoIPController::Config mappedConfig(
            config.initializationTimeout,
            config.receiveTimeout,
            mappedDataSaving,
            config.enableAEC,
            config.enableNS,
            config.enableAGC,
            config.enableCallUpgrade
        );
        mappedConfig.logFilePath = config.logPath;
        mappedConfig.statsDumpFilePath = "";

        controller_->SetConfig(mappedConfig);
        
        setNetworkType(initialNetworkType);
        
        std::vector<uint8_t> encryptionKeyValue = encryptionKey.value;
        controller_->SetEncryptionKey((char *)(encryptionKeyValue.data()), encryptionKey.isOutgoing);
        controller_->SetRemoteEndpoints(mappedEndpoints, config.enableP2P, config.maxApiLayer);
        
        controller_->Start();
        
        controller_->Connect();
    }
    
    ~TgVoipImpl() {
        
    }
    
    void setStateUpdated(std::function<void(TgVoipState)> stateUpdated) {
        stateUpdated_ = stateUpdated;
    }
    
    void setSignalBarsUpdated(std::function<void(int)> signalBarsUpdated) {
        signalBarsUpdated_ = signalBarsUpdated;
    }
    
    void setNetworkType(TgVoipNetworkType networkType) {
        int mappedType = tgvoip::NET_TYPE_UNKNOWN;
        
        switch (networkType) {
            case TgVoipNetworkType::Unknown:
                mappedType = tgvoip::NET_TYPE_UNKNOWN;
                break;
            case TgVoipNetworkType::Gprs:
                mappedType = tgvoip::NET_TYPE_GPRS;
                break;
            case TgVoipNetworkType::Edge:
                mappedType = tgvoip::NET_TYPE_EDGE;
                break;
            case TgVoipNetworkType::ThirdGeneration:
                mappedType = tgvoip::NET_TYPE_3G;
                break;
            case TgVoipNetworkType::Hspa:
                mappedType = tgvoip::NET_TYPE_HSPA;
                break;
            case TgVoipNetworkType::Lte:
                mappedType = tgvoip::NET_TYPE_LTE;
                break;
            case TgVoipNetworkType::WiFi:
                mappedType = tgvoip::NET_TYPE_WIFI;
                break;
            case TgVoipNetworkType::Ethernet:
                mappedType = tgvoip::NET_TYPE_ETHERNET;
                break;
            case TgVoipNetworkType::OtherHighSpeed:
                mappedType = tgvoip::NET_TYPE_OTHER_HIGH_SPEED;
                break;
            case TgVoipNetworkType::OtherLowSpeed:
                mappedType = tgvoip::NET_TYPE_OTHER_LOW_SPEED;
                break;
            case TgVoipNetworkType::OtherMobile:
                mappedType = tgvoip::NET_TYPE_OTHER_MOBILE;
                break;
            case TgVoipNetworkType::Dialup:
                mappedType = tgvoip::NET_TYPE_DIALUP;
                break;
            default:
                mappedType = tgvoip::NET_TYPE_UNKNOWN;
                break;
        }
        
        controller_->SetNetworkType(mappedType);
    }

    void setMuteMicrophone(bool muteMicrophone) {
        controller_->SetMicMute(muteMicrophone);
    }
    
    std::string getVersion() {
        return controller_->GetVersion();
    }
    
    TgVoipPersistentState getPersistentState() {
        std::vector<uint8_t> persistentStateValue = controller_->GetPersistentState();
        TgVoipPersistentState persistentState = {
            .value = persistentStateValue
        };
        
        return persistentState;
    }
    
    std::string getDebugInfo() {
        return controller_->GetDebugString();
    }
    
    TgVoipFinalState stop() {
        controller_->Stop();
        
        auto debugLog = controller_->GetDebugLog();
        
        tgvoip::VoIPController::TrafficStats stats;
        controller_->GetStats(&stats);
        
        TgVoipTrafficStats trafficStats = {
            .bytesSentWifi = stats.bytesSentWifi,
            .bytesReceivedWifi = stats.bytesRecvdWifi,
            .bytesSentMobile = stats.bytesSentMobile,
            .bytesReceivedMobile = stats.bytesRecvdMobile
        };
        
        std::vector<uint8_t> persistentStateValue = controller_->GetPersistentState();
        TgVoipPersistentState persistentState = {
            .value = persistentStateValue
        };
        
        TgVoipFinalState finalState = {
            .persistentState = persistentState,
            .debugLog = debugLog,
            .trafficStats = trafficStats,
            .isRatingSuggested = controller_->NeedRate()
        };
        
        delete controller_;
        controller_ = NULL;
        
        return finalState;
    }
    
    static void controllerStateCallback(tgvoip::VoIPController *controller, int state) {
        TgVoipImpl *self = (TgVoipImpl *)controller->implData;
        if (self->stateUpdated_) {
            TgVoipState mappedState;
            switch (state) {
                case tgvoip::STATE_WAIT_INIT:
                    mappedState = TgVoipState::WaitInit;
                    break;
                case tgvoip::STATE_WAIT_INIT_ACK:
                    mappedState = TgVoipState::WaitInitAck;
                    break;
                case tgvoip::STATE_ESTABLISHED:
                    mappedState = TgVoipState::Estabilished;
                    break;
                case tgvoip::STATE_FAILED:
                    mappedState = TgVoipState::Failed;
                    break;
                case tgvoip::STATE_RECONNECTING:
                    mappedState = TgVoipState::Reconnecting;
                    break;
                default:
                    mappedState = TgVoipState::Estabilished;
                    break;
            }
            
            self->stateUpdated_(mappedState);
        }
    }

    static void signalBarsCallback(tgvoip::VoIPController *controller, int signalBars) {
        TgVoipImpl *self = (TgVoipImpl *)controller->implData;
        if (self->signalBarsUpdated_) {
            self->signalBarsUpdated_(signalBars);
        }
    }
};

std::function<void(std::string const &)> globalLoggingFunction;

void __tgvoip_call_tglog(const char *format, ...){
    va_list vaArgs;
    va_start(vaArgs, format);

    va_list vaCopy;
    va_copy(vaCopy, vaArgs);
    const int length = std::vsnprintf(NULL, 0, format, vaCopy);
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
    tgvoip::ServerConfig::GetSharedInstance()->Update(serverConfig);
}

TgVoip *TgVoip::makeInstance(
    TgVoipCrypto const &crypto,
    TgVoipConfig const &config,
    TgVoipPersistentState const &persistentState,
    std::vector<TgVoipEndpoint> const &endpoints,
    std::unique_ptr<TgVoipProxy> const &proxy,
    TgVoipNetworkType initialNetworkType,
    TgVoipEncryptionKey const &encryptionKey
) {
    return new TgVoipImpl(
        crypto,
        endpoints,
        persistentState,
        proxy,
        config,
        encryptionKey,
        initialNetworkType
    );
}

TgVoip::~TgVoip() {
}
