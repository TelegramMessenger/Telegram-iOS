#include "Controller.h"

#include "modules/rtp_rtcp/source/rtp_utility.h"
#include "rtc_base/time_utils.h"
#include "rtc_base/message_handler.h"

#include <memory>

/*std::map<message::NetworkType, MediaEngineWebrtc::NetworkParams> Controller::network_params = {
        {message::NetworkType::nGprs, {6, 8, 6, 120, false, false, false}},
        {message::NetworkType::nEdge, {6, 16, 6, 120, false, false, false}},
        {message::NetworkType::n3gOrAbove, {6, 32, 16, 60, false, false, false}},
};
MediaEngineWebrtc::NetworkParams Controller::default_network_params = {6, 32, 16, 30, false, false, false};
MediaEngineWebrtc::NetworkParams Controller::datasaving_network_params = {6, 8, 6, 120, false, false, true};*/

Controller::Controller(bool is_outgoing, size_t init_timeout, size_t reconnect_timeout)
: thread(rtc::Thread::Create())
, connector(std::make_unique<Connector>(is_outgoing))
, state(State::Starting)
, last_recv_time(rtc::TimeMillis())
, last_send_time(rtc::TimeMillis())
, is_outgoing(is_outgoing)
, init_timeout(init_timeout * 1000)
, reconnect_timeout(reconnect_timeout * 1000)
, local_datasaving(false)
, final_datasaving(false)
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
    local_datasaving = data_saving;
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
