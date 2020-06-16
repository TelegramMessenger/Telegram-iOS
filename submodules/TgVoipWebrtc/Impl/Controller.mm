#include "Controller.h"

#include "modules/rtp_rtcp/source/rtp_utility.h"

#include <memory>

Controller::Controller(bool is_outgoing, size_t init_timeout, size_t reconnect_timeout)
: thread(rtc::Thread::Create())
, connector(std::make_unique<Connector>(is_outgoing))
, state(State::Starting)
, last_recv_time(rtc::TimeMillis())
, last_send_time(rtc::TimeMillis())
, isOutgoing(is_outgoing)
{
    connector->SignalReadyToSendStateChanged.connect(this, &Controller::WriteableStateChanged);
    connector->SignalPacketReceived.connect(this, &Controller::PacketReceived);
    connector->SignalCandidatesGathered.connect(this, &Controller::CandidatesGathered);
    thread->Start();
    
    thread->Invoke<void>(RTC_FROM_HERE, [this, is_outgoing]() {
        media.reset(new MediaEngineWebrtc(is_outgoing));
        media->Send.connect(this, &Controller::SendRtp);
    });
}

Controller::~Controller() {
    thread->Invoke<void>(RTC_FROM_HERE, [this]() {
        media = nullptr;
        connector = nullptr;
    });
}

void Controller::Start() {
    last_recv_time = rtc::TimeMillis();
    connector->Start();
}

void Controller::PacketReceived(const rtc::CopyOnWriteBuffer &data) {
    thread->PostTask(RTC_FROM_HERE, [this, data]() {
        if (media) {
            media->Receive(data);
        }
    });
}

void Controller::WriteableStateChanged(bool isWriteable) {
    if (isWriteable) {
        SignalNewState(State::Established);
    } else {
        SignalNewState(State::Reconnecting);
    }
    thread->PostTask(RTC_FROM_HERE, [this, isWriteable]() {
        if (media) {
            media->SetCanSendPackets(isWriteable);
        }
    });
}

void Controller::SendRtp(rtc::CopyOnWriteBuffer packet) {
    connector->SendPacket(packet);
}

/*void Controller::UpdateNetworkParams(const message::RtpStream& rtp) {
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
}*/

void Controller::AttachVideoView(rtc::VideoSinkInterface<webrtc::VideoFrame> *sink) {
    thread->PostTask(RTC_FROM_HERE, [this, sink]() {
        media->AttachVideoView(sink);
    });
}

/*void Controller::SetNetworkType(message::NetworkType network_type) {
    local_network_type = network_type;
}*/

void Controller::SetDataSaving(bool data_saving) {
}

void Controller::SetMute(bool mute) {
    thread->Invoke<void>(RTC_FROM_HERE, [this, mute]() {
        if (media)
            media->SetMute(mute);
    });
}

void Controller::SetProxy(rtc::ProxyType type, const rtc::SocketAddress& addr, const std::string& username, const std::string& password) {
}

void Controller::CandidatesGathered(const std::vector<std::string> &candidates) {
    SignalCandidatesGathered(candidates);
}

void Controller::AddRemoteCandidates(const std::vector<std::string> &candidates) {
    connector->AddRemoteCandidates(candidates);
}
