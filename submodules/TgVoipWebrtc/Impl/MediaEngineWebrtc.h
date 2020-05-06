#ifndef DEMO_MEDIAENGINEWEBRTC_H
#define DEMO_MEDIAENGINEWEBRTC_H


#include "MediaEngineBase.h"

#include "api/transport/field_trial_based_config.h"
#include "call/call.h"
#include "media/base/media_engine.h"
#include "pc/rtp_sender.h"
#include "rtc_base/task_queue.h"

#include <memory>

class MediaEngineWebrtc : public MediaEngineBase {
public:
    struct NetworkParams {
        uint8_t min_bitrate_kbps;
        uint8_t max_bitrate_kbps;
        uint8_t start_bitrate_kbps;
        uint8_t ptime_ms;
        bool echo_cancellation;
        bool auto_gain_control;
        bool noise_suppression;
    };

    explicit MediaEngineWebrtc(bool outgoing, bool send = true, bool recv = true);
    ~MediaEngineWebrtc() override;
    void Receive(rtc::CopyOnWriteBuffer) override;
    void OnSentPacket(const rtc::SentPacket& sent_packet);
    void SetNetworkParams(const NetworkParams& params);
    void SetMute(bool mute);

private:
    class Sender final : public cricket::MediaChannel::NetworkInterface {
    public:
        explicit Sender(MediaEngineWebrtc&);
        bool SendPacket(rtc::CopyOnWriteBuffer *packet, const rtc::PacketOptions& options) override;
        bool SendRtcp(rtc::CopyOnWriteBuffer *packet, const rtc::PacketOptions& options) override;
        int SetOption(SocketType type, rtc::Socket::Option opt, int option) override;
    private:
        MediaEngineWebrtc& engine;
    };

    class AudioProcessor {
    public:
        AudioProcessor(webrtc::AudioTransport *transport, webrtc::TaskQueueFactory *task_queue_factory,
                MediaEngineBase& engine, bool send, bool recv);
        ~AudioProcessor();
    private:
        bool send;
        bool recv;
        webrtc::AudioTransport *transport;
        size_t delay_us;
        int16_t *buf_send;
        int16_t *buf_recv;
        MediaEngineBase& engine;
        std::unique_ptr<rtc::TaskQueue> task_queue_send;
        std::unique_ptr<rtc::TaskQueue> task_queue_recv;
    };

    const uint32_t ssrc_send;
    const uint32_t ssrc_recv;
    std::unique_ptr<webrtc::Call> call;
    std::unique_ptr<cricket::MediaEngineInterface> media_engine;
    std::unique_ptr<webrtc::RtcEventLogNull> event_log;
    std::unique_ptr<webrtc::TaskQueueFactory> task_queue_factory;
    webrtc::FieldTrialBasedConfig field_trials;
    webrtc::LocalAudioSinkAdapter audio_source;
    Sender data_sender;
    std::unique_ptr<cricket::VoiceMediaChannel> voice_channel;
#ifdef TGVOIP_USE_CALLBACK_AUDIO_IO
    std::unique_ptr<AudioProcessor> audio_processor;
#endif
};


#endif //DEMO_MEDIAENGINEWEBRTC_H
