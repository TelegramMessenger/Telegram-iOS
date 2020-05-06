#ifndef DEMO_CONTROLLER_H
#define DEMO_CONTROLLER_H


#include "Connector.h"
#include "MediaEngineWebrtc.h"
#include "Layer92.h"

#include "rtc_base/copy_on_write_buffer.h"
#include "rtc_base/socket_address.h"
#include "rtc_base/task_utils/repeating_task.h"
#include "rtc_base/third_party/sigslot/sigslot.h"

class Controller : public sigslot::has_slots<> {
public:
    enum EndpointType {
        UDP,
        TCP,
        P2P,
    };

    enum State {
        Starting,
        WaitInit,
        WaitInitAck,
        Established,
        Failed,
        Reconnecting,
    };

    explicit Controller(bool is_outgoing, const EncryptionKey& encryption_key, size_t init_timeout, size_t reconnect_timeout);
    ~Controller() override;
    void AddEndpoint(const rtc::SocketAddress& address, const Relay::PeerTag& peer_tag, EndpointType type);
    void Start();
    void SetNetworkType(message::NetworkType network_type);
    void SetDataSaving(bool data_saving);
    void SetMute(bool mute);
    void SetProxy(rtc::ProxyType type, const rtc::SocketAddress& addr, const std::string& username,
                  const std::string& password);

    static std::map<message::NetworkType, MediaEngineWebrtc::NetworkParams> network_params;
    static MediaEngineWebrtc::NetworkParams default_network_params;
    static MediaEngineWebrtc::NetworkParams datasaving_network_params;
    sigslot::signal2<int16_t *, size_t> SignalRecord;
#ifdef TGVOIP_PREPROCESSED_OUTPUT
    sigslot::signal2<const int16_t *, size_t> SignalPreprocessed;
#endif
    sigslot::signal2<const int16_t *, size_t> SignalPlay;
    sigslot::signal1<State> SignalNewState;

private:
    std::unique_ptr<rtc::Thread> thread;
    std::unique_ptr<Connector> connector;
    std::unique_ptr<MediaEngineWebrtc> media;
#ifdef TGVOIP_PREPROCESSED_OUTPUT
    std::unique_ptr<MediaEngineWebrtc> preproc;
#endif
    State state;
    webrtc::RepeatingTaskHandle repeatable;
    int64_t last_recv_time;
    int64_t last_send_time;
    const bool is_outgoing;
    const size_t init_timeout;
    const size_t reconnect_timeout;
    bool local_datasaving;
    bool final_datasaving;
    message::NetworkType local_network_type;
    message::NetworkType final_network_type;

    template <class Closure> void StartRepeating(Closure&& closure);
    void StopRepeating();
    void NewMessage(const message::Base& msg);
    void SetFail();
    void Play(const int16_t *data, size_t size);
    void Record(int16_t *data, size_t size);
#ifdef TGVOIP_PREPROCESSED_OUTPUT
    void Preprocessed(const int16_t *data, size_t size);
#endif
    void SendRtp(rtc::CopyOnWriteBuffer packet);
    void UpdateNetworkParams(const message::RtpStream& rtp);
};


#endif //DEMO_CONTROLLER_H
