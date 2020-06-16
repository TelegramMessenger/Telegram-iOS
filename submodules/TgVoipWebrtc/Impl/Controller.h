#ifndef DEMO_CONTROLLER_H
#define DEMO_CONTROLLER_H


#include "Connector.h"
#include "MediaEngineWebrtc.h"

#include "rtc_base/copy_on_write_buffer.h"
#include "rtc_base/socket_address.h"
#include "rtc_base/task_utils/repeating_task.h"
#include "rtc_base/third_party/sigslot/sigslot.h"

#import "VideoMetalView.h"

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

    explicit Controller(bool is_outgoing, size_t init_timeout, size_t reconnect_timeout);
    ~Controller() override;
    void Start();
    //void SetNetworkType(message::NetworkType network_type);
    void SetDataSaving(bool data_saving);
    void SetMute(bool mute);
    void AttachVideoView(rtc::VideoSinkInterface<webrtc::VideoFrame> *sink);
    void SetProxy(rtc::ProxyType type, const rtc::SocketAddress& addr, const std::string& username, const std::string& password);
    void AddRemoteCandidates(const std::vector<std::string> &candidates);

    //static std::map<message::NetworkType, MediaEngineWebrtc::NetworkParams> network_params;
    static MediaEngineWebrtc::NetworkParams default_network_params;
    static MediaEngineWebrtc::NetworkParams datasaving_network_params;
    sigslot::signal1<State> SignalNewState;
    sigslot::signal1<const std::vector<std::string>&> SignalCandidatesGathered;

private:
    std::unique_ptr<rtc::Thread> thread;
    std::unique_ptr<Connector> connector;
    std::unique_ptr<MediaEngineWebrtc> media;
    State state;
    webrtc::RepeatingTaskHandle repeatable;
    int64_t last_recv_time;
    int64_t last_send_time;
    const bool isOutgoing;

    void PacketReceived(const rtc::CopyOnWriteBuffer &);
    void WriteableStateChanged(bool);
    void CandidatesGathered(const std::vector<std::string> &);
    void SetFail();
    void Play(const int16_t *data, size_t size);
    void Record(int16_t *data, size_t size);
    void SendRtp(rtc::CopyOnWriteBuffer packet);
    //void UpdateNetworkParams(const message::RtpStream& rtp);
};


#endif //DEMO_CONTROLLER_H
