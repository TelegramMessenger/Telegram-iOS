#include "MediaEngineWebrtc.h"

#include "api/audio_codecs/audio_decoder_factory_template.h"
#include "api/audio_codecs/audio_encoder_factory_template.h"
#include "api/audio_codecs/opus/audio_decoder_opus.h"
#include "api/audio_codecs/opus/audio_encoder_opus.h"
#include "api/rtp_parameters.h"
#include "api/task_queue/default_task_queue_factory.h"
#include "media/base/codec.h"
#include "media/base/media_constants.h"
#include "media/engine/webrtc_media_engine.h"
#include "modules/audio_device/include/audio_device_default.h"
#include "rtc_base/task_utils/repeating_task.h"
#include "system_wrappers/include/field_trial.h"
#include "api/video/builtin_video_bitrate_allocator_factory.h"

#if WEBRTC_ENABLE_PROTOBUF
#include "modules/audio_coding/audio_network_adaptor/config.pb.h"
#endif

namespace {
const size_t frame_samples = 480;
const uint8_t channels = 1;
const uint8_t sample_bytes = 2;
const uint32_t clockrate = 48000;
const uint16_t sdp_payload = 111;
const char* sdp_name = "opus";
const uint8_t sdp_channels = 2;
const uint32_t sdp_bitrate = 0;
const uint32_t caller_ssrc = 1;
const uint32_t called_ssrc = 2;
const uint32_t caller_ssrc_video = 1;
const uint32_t called_ssrc_video = 2;
const int extension_sequence = 1;
}

MediaEngineWebrtc::MediaEngineWebrtc(bool outgoing, bool send, bool recv)
: ssrc_send(outgoing ? caller_ssrc : called_ssrc)
, ssrc_recv(outgoing ? called_ssrc : caller_ssrc)
, ssrc_send_video(outgoing ? caller_ssrc_video : called_ssrc_video)
, ssrc_recv_video(outgoing ? called_ssrc_video : caller_ssrc_video)
, event_log(std::make_unique<webrtc::RtcEventLogNull>())
, task_queue_factory(webrtc::CreateDefaultTaskQueueFactory())
, data_sender(*this) {
    webrtc::field_trial::InitFieldTrialsFromString(
            "WebRTC-Audio-SendSideBwe/Enabled/"
            "WebRTC-Audio-Allocation/min:6kbps,max:32kbps/"
            "WebRTC-Audio-OpusMinPacketLossRate/Enabled-1/"
    );
    video_bitrate_allocator_factory = webrtc::CreateBuiltinVideoBitrateAllocatorFactory();
    cricket::MediaEngineDependencies media_deps;
    media_deps.task_queue_factory = task_queue_factory.get();
    media_deps.audio_encoder_factory = webrtc::CreateAudioEncoderFactory<webrtc::AudioEncoderOpus>();
    media_deps.audio_decoder_factory = webrtc::CreateAudioDecoderFactory<webrtc::AudioDecoderOpus>();
    media_deps.audio_processing = webrtc::AudioProcessingBuilder().Create();
    media_engine = cricket::CreateMediaEngine(std::move(media_deps));
    media_engine->Init();
    webrtc::Call::Config call_config(event_log.get());
    call_config.task_queue_factory = task_queue_factory.get();
    call_config.trials = &field_trials;
    call_config.audio_state = media_engine->voice().GetAudioState();
    call.reset(webrtc::Call::Create(call_config));
    voice_channel.reset(media_engine->voice().CreateMediaChannel(
            call.get(), cricket::MediaConfig(), cricket::AudioOptions(), webrtc::CryptoOptions::NoGcm()));
    video_channel.reset(media_engine->video().CreateMediaChannel(call.get(), cricket::MediaConfig(), cricket::VideoOptions(), webrtc::CryptoOptions::NoGcm(), video_bitrate_allocator_factory.get()));
    if (send) {
        voice_channel->AddSendStream(cricket::StreamParams::CreateLegacy(ssrc_send));
        SetNetworkParams({6, 32, 6, 120, false, false, false});
        SetMute(false);
        voice_channel->SetInterface(&data_sender, webrtc::MediaTransportConfig());
        voice_channel->OnReadyToSend(true);
        voice_channel->SetSend(true);
    }
    if (false && send) {
        video_channel->AddSendStream(cricket::StreamParams::CreateLegacy(ssrc_send_video));
        video_channel->SetInterface(&data_sender, webrtc::MediaTransportConfig());
        video_channel->OnReadyToSend(true);
        video_channel->SetSend(true);
    }
    if (recv) {
        cricket::AudioRecvParameters recv_parameters;
        recv_parameters.codecs.emplace_back(sdp_payload, sdp_name, clockrate, sdp_bitrate, sdp_channels);
        recv_parameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, extension_sequence);
        recv_parameters.rtcp.reduced_size = true;
        recv_parameters.rtcp.remote_estimate = true;
        voice_channel->AddRecvStream(cricket::StreamParams::CreateLegacy(ssrc_recv));
        voice_channel->SetRecvParameters(recv_parameters);
        voice_channel->SetPlayout(true);
    }
    if (false && recv) {
        cricket::VideoRecvParameters recv_parameters;
        //recv_parameters.codecs.emplace_back(sdp_payload, sdp_name, clockrate, sdp_bitrate, sdp_channels);
        recv_parameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, extension_sequence);
        recv_parameters.rtcp.reduced_size = true;
        recv_parameters.rtcp.remote_estimate = true;
        video_channel->AddRecvStream(cricket::StreamParams::CreateLegacy(ssrc_recv_video));
        video_channel->SetRecvParameters(recv_parameters);
        //video_channel->SetPlayout(true);
    }
}

MediaEngineWebrtc::~MediaEngineWebrtc() = default;

void MediaEngineWebrtc::Receive(rtc::CopyOnWriteBuffer packet) {
    if (voice_channel)
        voice_channel->OnPacketReceived(packet, -1);
}

void MediaEngineWebrtc::OnSentPacket(const rtc::SentPacket& sent_packet) {
    call->OnSentPacket(sent_packet);
}

void MediaEngineWebrtc::SetNetworkParams(const MediaEngineWebrtc::NetworkParams& params) {
    cricket::AudioCodec opus_codec(sdp_payload, sdp_name, clockrate, sdp_bitrate, sdp_channels);
    opus_codec.AddFeedbackParam(cricket::FeedbackParam(cricket::kRtcpFbParamTransportCc));
    opus_codec.SetParam(cricket::kCodecParamMinBitrate, params.min_bitrate_kbps);
    opus_codec.SetParam(cricket::kCodecParamStartBitrate, params.start_bitrate_kbps);
    opus_codec.SetParam(cricket::kCodecParamMaxBitrate, params.max_bitrate_kbps);
    opus_codec.SetParam(cricket::kCodecParamUseInbandFec, 1);
    opus_codec.SetParam(cricket::kCodecParamPTime, params.ptime_ms);

    cricket::AudioSendParameters send_parameters;
    send_parameters.codecs.push_back(opus_codec);
    send_parameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, extension_sequence);
    send_parameters.options.echo_cancellation = params.echo_cancellation;
//    send_parameters.options.experimental_ns = false;
    send_parameters.options.noise_suppression = params.noise_suppression;
    send_parameters.options.auto_gain_control = params.auto_gain_control;
    send_parameters.options.highpass_filter = false;
    send_parameters.options.typing_detection = false;
//        send_parameters.max_bandwidth_bps = 16000;
    send_parameters.rtcp.reduced_size = true;
    send_parameters.rtcp.remote_estimate = true;
    voice_channel->SetSendParameters(send_parameters);
}

void MediaEngineWebrtc::SetMute(bool mute) {
    voice_channel->SetAudioSend(ssrc_send, !mute, nullptr, &audio_source);
}

bool MediaEngineWebrtc::Sender::SendPacket(rtc::CopyOnWriteBuffer *packet, const rtc::PacketOptions& options) {
    engine.Send(*packet);
    rtc::SentPacket sent_packet(options.packet_id, rtc::TimeMillis(), options.info_signaled_after_sent);
    engine.OnSentPacket(sent_packet);
    return true;
}

bool MediaEngineWebrtc::Sender::SendRtcp(rtc::CopyOnWriteBuffer *packet, const rtc::PacketOptions& options) {
    engine.Send(*packet);
    rtc::SentPacket sent_packet(options.packet_id, rtc::TimeMillis(), options.info_signaled_after_sent);
    engine.OnSentPacket(sent_packet);
    return true;
}

int MediaEngineWebrtc::Sender::SetOption(cricket::MediaChannel::NetworkInterface::SocketType, rtc::Socket::Option, int) {
    return -1;  // in general, the result is not important yet
}

MediaEngineWebrtc::Sender::Sender(MediaEngineWebrtc& engine) : engine(engine) {}
