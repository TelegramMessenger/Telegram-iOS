#include "Controller.h"

#include "Layer92.h"

#include "modules/rtp_rtcp/source/rtp_utility.h"
#include "rtc_base/time_utils.cc"
#include "rtc_base/message_handler.h"

#include <memory>

std::map<message::NetworkType, MediaEngineWebrtc::NetworkParams> Controller::network_params = {
        {message::NetworkType::nGprs, {6, 8, 6, 120, false, false, false}},
        {message::NetworkType::nEdge, {6, 16, 6, 120, false, false, false}},
        {message::NetworkType::n3gOrAbove, {6, 32, 16, 60, false, false, false}},
};
MediaEngineWebrtc::NetworkParams Controller::default_network_params = {6, 32, 16, 30, false, false, false};
MediaEngineWebrtc::NetworkParams Controller::datasaving_network_params = {6, 8, 6, 120, false, false, true};

Controller::Controller(bool is_outgoing, const EncryptionKey& encryption_key, size_t init_timeout, size_t reconnect_timeout)
: thread(rtc::Thread::Create())
, connector(std::make_unique<Connector>(std::make_unique<Layer92>(encryption_key, is_outgoing)))
, state(State::Starting)
, is_outgoing(is_outgoing)
, last_recv_time(rtc::TimeMillis())
, last_send_time(rtc::TimeMillis())
, init_timeout(init_timeout * 1000)
, reconnect_timeout(reconnect_timeout * 1000)
, local_datasaving(false)
, final_datasaving(false)
, local_network_type(message::NetworkType::nUnknown)
, final_network_type(message::NetworkType::nUnknown)
{
    connector->SignalMessage.connect(this, &Controller::NewMessage);
    thread->Start();
}

Controller::~Controller() {
    thread->Invoke<void>(RTC_FROM_HERE, [this]() {
        media = nullptr;
#ifdef TGVOIP_PREPROCESSED_OUTPUT
        preproc = nullptr;
#endif
        connector = nullptr;
    });
}

void Controller::AddEndpoint(const rtc::SocketAddress& address, const Relay::PeerTag &peer_tag,
        Controller::EndpointType type) {
    if (type == EndpointType::UDP)
        connector->AddEndpointRelayUdp(address, peer_tag);
    else if (type == EndpointType::TCP)
        connector->AddEndpointRelayTcpObfuscated(address, peer_tag);
    else if (type == EndpointType::P2P)
        connector->SetEndpointP2p(address);
}

void Controller::Start() {
    last_recv_time = rtc::TimeMillis();
    connector->Start();
}

void Controller::NewMessage(const message::Base& msg) {
    if (msg.ID == message::tReady && state == State::Starting) {
        state = State::WaitInit;
        SignalNewState(state);
        StartRepeating([this]() {
            message::Init msg;
            msg.minVer = ProtocolBase::minimal_version;
            msg.ver = ProtocolBase::actual_version;
            connector->SendMessage(msg);
            if (rtc::TimeMillis() - last_recv_time > init_timeout)
                SetFail();
            return webrtc::TimeDelta::seconds(1);
        });
    } else if ((msg.ID == message::tInit || msg.ID == message::tInitAck) && state == State::WaitInit) {
        state = State::WaitInitAck;
        SignalNewState(state);
        StartRepeating([this]() {
            message::InitAck msg;
            // TODO: version matching
            msg.minVer = ProtocolBase::minimal_version;
            msg.ver = ProtocolBase::actual_version;
            connector->SendMessage(msg);
            if (rtc::TimeMillis() - last_recv_time > init_timeout)
                SetFail();
            return webrtc::TimeDelta::seconds(1);
        });
    } else if ((msg.ID == message::tInitAck || msg.ID == message::tRtpStream) && state == State::WaitInitAck) {
        state = State::Established;
        SignalNewState(state);
        thread->PostTask(RTC_FROM_HERE, [this]() {
#ifdef TGVOIP_PREPROCESSED_OUTPUT
            preproc = std::make_unique<MediaEngineWebrtc>(not is_outgoing, false, true);
            preproc->Play.connect(this, &Controller::Preprocessed);
#endif
            media = std::make_unique<MediaEngineWebrtc>(is_outgoing);
            media->Record.connect(this, &Controller::Record);
            media->Play.connect(this, &Controller::Play);
            media->Send.connect(this, &Controller::SendRtp);
        });
        StartRepeating([this]() {
            if (state == State::Established && rtc::TimeMillis() - last_recv_time > 1000) {
                connector->ResetActiveEndpoint();
                state = State::Reconnecting;
                SignalNewState(state);
            } else if (state == State::Reconnecting && rtc::TimeMillis() - last_recv_time > reconnect_timeout)
                SetFail();
            return webrtc::TimeDelta::seconds(1);
        });
    } if ((msg.ID == message::tRtpStream) && (state == State::Established || state == State::Reconnecting)) {
        const auto msg_rtp = *dynamic_cast<const message::RtpStream *>(&msg);
        thread->PostTask(RTC_FROM_HERE, [this, msg_rtp]() {
            if (media) {
                media->Receive(msg_rtp.data);
                UpdateNetworkParams(msg_rtp);
            }
        });
        if (!webrtc::RtpUtility::RtpHeaderParser(msg_rtp.data.data(), msg_rtp.data.size()).RTCP()) {
            last_recv_time = rtc::TimeMillis();
            if (state == State::Reconnecting) {
                state = State::Established;
                SignalNewState(state);
            }
        }
    } else if (msg.ID == message::tBufferOverflow ||
               msg.ID == message::tPacketIncorrect ||
               msg.ID == message::tWrongProtocol) {
        SetFail();
    }
}

template<class Closure>
void Controller::StartRepeating(Closure&& closure) {
    StopRepeating();
    repeatable = webrtc::RepeatingTaskHandle::Start(thread.get(), std::forward<Closure>(closure));
}

void Controller::StopRepeating() {
    thread->Invoke<void>(RTC_FROM_HERE, [this]() {
        repeatable.Stop();
    });
}

void Controller::SetFail() {
    thread->PostTask(RTC_FROM_HERE, [this]() {
        media = nullptr;
#ifdef TGVOIP_PREPROCESSED_OUTPUT
        preproc = nullptr;
#endif
    });
    if (state != State::Failed) {
        state = State::Failed;
        SignalNewState(state);
    }
    StopRepeating();
}

void Controller::Play(const int16_t *data, size_t size) {
    SignalPlay(data, size);
}

void Controller::Record(int16_t *data, size_t size) {
    SignalRecord(data, size);
    last_send_time = rtc::TimeMillis();
}

#ifdef TGVOIP_PREPROCESSED_OUTPUT
void Controller::Preprocessed(const int16_t *data, size_t size) {
    if (rtc::TimeMillis() - last_send_time < 100)
        SignalPreprocessed(data, size);
}
#endif

void Controller::SendRtp(rtc::CopyOnWriteBuffer packet) {
#ifdef TGVOIP_PREPROCESSED_OUTPUT
    thread->PostTask(RTC_FROM_HERE, [this, packet]() {
        if (preproc)
            preproc->Receive(packet);
    });
#endif
    message::RtpStream msg;
    msg.data = packet;
    msg.network_type = local_network_type;
    msg.data_saving = local_datasaving;
    connector->SendMessage(msg);
}

void Controller::UpdateNetworkParams(const message::RtpStream& rtp) {
    bool new_datasaving = local_datasaving || rtp.data_saving;
    if (!new_datasaving) {
        final_datasaving = false;
        message::NetworkType new_network_type = std::min(local_network_type, rtp.network_type);
        if (new_network_type != final_network_type) {
            final_network_type = new_network_type;
            auto it = network_params.find(rtp.network_type);
            if (it == network_params.end())
                media->SetNetworkParams(default_network_params);
            else
                media->SetNetworkParams(it->second);
        }
    } else if (new_datasaving != final_datasaving) {
        final_datasaving = true;
        media->SetNetworkParams(datasaving_network_params);
    }
}

void Controller::SetNetworkType(message::NetworkType network_type) {
    local_network_type = network_type;
}

void Controller::SetDataSaving(bool data_saving) {
    local_datasaving = data_saving;
}

void Controller::SetMute(bool mute) {
    thread->Invoke<void>(RTC_FROM_HERE, [this, mute]() {
        if (media)
            media->SetMute(mute);
    });
}

void Controller::SetProxy(rtc::ProxyType type, const rtc::SocketAddress& addr, const std::string& username,
                          const std::string& password) {
    connector->SetProxy(type, addr, username, password);
}
