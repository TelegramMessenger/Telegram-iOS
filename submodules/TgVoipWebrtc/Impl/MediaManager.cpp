#include "MediaManager.h"

#include "absl/strings/match.h"
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
#include "api/video/video_bitrate_allocation.h"
#include "call/call.h"

#if TARGET_OS_IPHONE

#include "CodecsApple.h"

#else
#error "Unsupported platform"
#endif

#ifdef TGVOIP_NAMESPACE
namespace TGVOIP_NAMESPACE {
#endif

static const uint32_t ssrcAudioIncoming = 1;
static const uint32_t ssrcAudioOutgoing = 2;
static const uint32_t ssrcVideoIncoming = 3;
static const uint32_t ssrcVideoOutgoing = 4;

static void AddDefaultFeedbackParams(cricket::VideoCodec *codec) {
    // Don't add any feedback params for RED and ULPFEC.
    if (codec->name == cricket::kRedCodecName || codec->name == cricket::kUlpfecCodecName)
        return;
    codec->AddFeedbackParam(cricket::FeedbackParam(cricket::kRtcpFbParamRemb, cricket::kParamValueEmpty));
    codec->AddFeedbackParam(
                            cricket::FeedbackParam(cricket::kRtcpFbParamTransportCc, cricket::kParamValueEmpty));
    // Don't add any more feedback params for FLEXFEC.
    if (codec->name == cricket::kFlexfecCodecName)
        return;
    codec->AddFeedbackParam(cricket::FeedbackParam(cricket::kRtcpFbParamCcm, cricket::kRtcpFbCcmParamFir));
    codec->AddFeedbackParam(cricket::FeedbackParam(cricket::kRtcpFbParamNack, cricket::kParamValueEmpty));
    codec->AddFeedbackParam(cricket::FeedbackParam(cricket::kRtcpFbParamNack, cricket::kRtcpFbNackParamPli));
    if (codec->name == cricket::kVp8CodecName &&
        webrtc::field_trial::IsEnabled("WebRTC-RtcpLossNotification")) {
        codec->AddFeedbackParam(cricket::FeedbackParam(cricket::kRtcpFbParamLntf, cricket::kParamValueEmpty));
    }
}

static std::vector<cricket::VideoCodec> AssignPayloadTypesAndDefaultCodecs(std::vector<webrtc::SdpVideoFormat> input_formats, int32_t &outCodecId) {
    if (input_formats.empty())
        return std::vector<cricket::VideoCodec>();
    static const int kFirstDynamicPayloadType = 96;
    static const int kLastDynamicPayloadType = 127;
    int payload_type = kFirstDynamicPayloadType;
    
    input_formats.push_back(webrtc::SdpVideoFormat(cricket::kRedCodecName));
    input_formats.push_back(webrtc::SdpVideoFormat(cricket::kUlpfecCodecName));
    
    /*if (IsFlexfecAdvertisedFieldTrialEnabled()) {
     webrtc::SdpVideoFormat flexfec_format(kFlexfecCodecName);
     // This value is currently arbitrarily set to 10 seconds. (The unit
     // is microseconds.) This parameter MUST be present in the SDP, but
     // we never use the actual value anywhere in our code however.
     // TODO(brandtr): Consider honouring this value in the sender and receiver.
     flexfec_format.parameters = {{kFlexfecFmtpRepairWindow, "10000000"}};
     input_formats.push_back(flexfec_format);
     }*/
    
    bool found = false;
    bool useVP9 = true;
    
    std::vector<cricket::VideoCodec> output_codecs;
    for (const webrtc::SdpVideoFormat& format : input_formats) {
        cricket::VideoCodec codec(format);
        codec.id = payload_type;
        AddDefaultFeedbackParams(&codec);
        output_codecs.push_back(codec);
        
        if (useVP9 && codec.name == cricket::kVp9CodecName) {
            if (!found) {
                outCodecId = codec.id;
                found = true;
            }
        }
        if (!useVP9 && codec.name == cricket::kH264CodecName) {
            if (!found) {
                outCodecId = codec.id;
                found = true;
            }
        }
        
        // Increment payload type.
        ++payload_type;
        if (payload_type > kLastDynamicPayloadType) {
            RTC_LOG(LS_ERROR) << "Out of dynamic payload types, skipping the rest.";
            break;
        }
        
        // Add associated RTX codec for non-FEC codecs.
        if (!absl::EqualsIgnoreCase(codec.name, cricket::kUlpfecCodecName) &&
            !absl::EqualsIgnoreCase(codec.name, cricket::kFlexfecCodecName)) {
            output_codecs.push_back(
                                    cricket::VideoCodec::CreateRtxCodec(payload_type, codec.id));
            
            // Increment payload type.
            ++payload_type;
            if (payload_type > kLastDynamicPayloadType) {
                RTC_LOG(LS_ERROR) << "Out of dynamic payload types, skipping the rest.";
                break;
            }
        }
    }
    return output_codecs;
}

static absl::optional<cricket::VideoCodec> selectVideoCodec(std::vector<cricket::VideoCodec> &codecs) {
    bool useVP9 = false;
    
    for (auto &codec : codecs) {
        if (useVP9) {
            if (codec.name == cricket::kVp9CodecName) {
                return absl::optional<cricket::VideoCodec>(codec);
            }
        } else {
            if (codec.name == cricket::kH264CodecName) {
                return absl::optional<cricket::VideoCodec>(codec);
            }
        }
    }
    return absl::optional<cricket::VideoCodec>();
}

MediaManager::MediaManager(
    rtc::Thread *thread,
    bool isOutgoing,
    std::function<void (const rtc::CopyOnWriteBuffer &)> packetEmitted
) :
_packetEmitted(packetEmitted),
_thread(thread),
_eventLog(std::make_unique<webrtc::RtcEventLogNull>()),
_taskQueueFactory(webrtc::CreateDefaultTaskQueueFactory()),
_workerThread(rtc::Thread::Create()) {
    _ssrcAudio.incoming = isOutgoing ? ssrcAudioIncoming : ssrcAudioOutgoing;
    _ssrcAudio.outgoing = (!isOutgoing) ? ssrcAudioIncoming : ssrcAudioOutgoing;
    _ssrcVideo.incoming = isOutgoing ? ssrcVideoIncoming : ssrcVideoOutgoing;
    _ssrcVideo.outgoing = (!isOutgoing) ? ssrcVideoIncoming : ssrcVideoOutgoing;
    
    _audioNetworkInterface = std::unique_ptr<MediaManager::NetworkInterfaceImpl>(new MediaManager::NetworkInterfaceImpl(this, false));
    _videoNetworkInterface = std::unique_ptr<MediaManager::NetworkInterfaceImpl>(new MediaManager::NetworkInterfaceImpl(this, true));
    
    _workerThread->Start();
    
    webrtc::field_trial::InitFieldTrialsFromString(
        "WebRTC-Audio-SendSideBwe/Enabled/"
        "WebRTC-Audio-Allocation/min:6kbps,max:32kbps/"
        "WebRTC-Audio-OpusMinPacketLossRate/Enabled-1/"
    );
    
    _videoBitrateAllocatorFactory = webrtc::CreateBuiltinVideoBitrateAllocatorFactory();
    
    cricket::MediaEngineDependencies mediaDeps;
    mediaDeps.task_queue_factory = _taskQueueFactory.get();
    mediaDeps.audio_encoder_factory = webrtc::CreateAudioEncoderFactory<webrtc::AudioEncoderOpus>();
    mediaDeps.audio_decoder_factory = webrtc::CreateAudioDecoderFactory<webrtc::AudioDecoderOpus>();
    
    auto videoEncoderFactory = makeVideoEncoderFactory();
    int32_t outCodecId = 96;
    std::vector<cricket::VideoCodec> videoCodecs = AssignPayloadTypesAndDefaultCodecs(videoEncoderFactory->GetSupportedFormats(), outCodecId);
    
    mediaDeps.video_encoder_factory = makeVideoEncoderFactory();
    mediaDeps.video_decoder_factory = makeVideoDecoderFactory();
    
    mediaDeps.audio_processing = webrtc::AudioProcessingBuilder().Create();
    _mediaEngine = cricket::CreateMediaEngine(std::move(mediaDeps));
    _mediaEngine->Init();
    webrtc::Call::Config callConfig(_eventLog.get());
    callConfig.task_queue_factory = _taskQueueFactory.get();
    callConfig.trials = &_fieldTrials;
    callConfig.audio_state = _mediaEngine->voice().GetAudioState();
    _call.reset(webrtc::Call::Create(callConfig));
    _audioChannel.reset(_mediaEngine->voice().CreateMediaChannel(_call.get(), cricket::MediaConfig(), cricket::AudioOptions(), webrtc::CryptoOptions::NoGcm()));
    _videoChannel.reset(_mediaEngine->video().CreateMediaChannel(_call.get(), cricket::MediaConfig(), cricket::VideoOptions(), webrtc::CryptoOptions::NoGcm(), _videoBitrateAllocatorFactory.get()));
    
    _audioChannel->AddSendStream(cricket::StreamParams::CreateLegacy(_ssrcAudio.outgoing));
    
    const uint32_t opusClockrate = 48000;
    const uint16_t opusSdpPayload = 111;
    const char *opusSdpName = "opus";
    const uint8_t opusSdpChannels = 2;
    const uint32_t opusSdpBitrate = 0;
    
    const uint8_t opusMinBitrateKbps = 6;
    const uint8_t opusMaxBitrateKbps = 32;
    const uint8_t opusStartBitrateKbps = 6;
    const uint8_t opusPTimeMs = 120;
    const int opusExtensionSequence = 1;
    
    cricket::AudioCodec opusCodec(opusSdpPayload, opusSdpName, opusClockrate, opusSdpBitrate, opusSdpChannels);
    opusCodec.AddFeedbackParam(cricket::FeedbackParam(cricket::kRtcpFbParamTransportCc));
    opusCodec.SetParam(cricket::kCodecParamMinBitrate, opusMinBitrateKbps);
    opusCodec.SetParam(cricket::kCodecParamStartBitrate, opusStartBitrateKbps);
    opusCodec.SetParam(cricket::kCodecParamMaxBitrate, opusMaxBitrateKbps);
    opusCodec.SetParam(cricket::kCodecParamUseInbandFec, 1);
    opusCodec.SetParam(cricket::kCodecParamPTime, opusPTimeMs);

    cricket::AudioSendParameters audioSendPrameters;
    audioSendPrameters.codecs.push_back(opusCodec);
    audioSendPrameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, opusExtensionSequence);
    audioSendPrameters.options.echo_cancellation = false;
    //audioSendPrameters.options.experimental_ns = false;
    audioSendPrameters.options.noise_suppression = false;
    audioSendPrameters.options.auto_gain_control = false;
    audioSendPrameters.options.highpass_filter = false;
    audioSendPrameters.options.typing_detection = false;
    //audioSendPrameters.max_bandwidth_bps = 16000;
    audioSendPrameters.rtcp.reduced_size = true;
    audioSendPrameters.rtcp.remote_estimate = true;
    _audioChannel->SetSendParameters(audioSendPrameters);
    _audioChannel->SetInterface(_audioNetworkInterface.get(), webrtc::MediaTransportConfig());
    
    cricket::AudioRecvParameters audioRecvParameters;
    audioRecvParameters.codecs.emplace_back(opusSdpPayload, opusSdpName, opusClockrate, opusSdpBitrate, opusSdpChannels);
    audioRecvParameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, opusExtensionSequence);
    audioRecvParameters.rtcp.reduced_size = true;
    audioRecvParameters.rtcp.remote_estimate = true;
    _audioChannel->AddRecvStream(cricket::StreamParams::CreateLegacy(_ssrcAudio.incoming));
    _audioChannel->SetRecvParameters(audioRecvParameters);
    _audioChannel->SetPlayout(true);
    
    _videoChannel->AddSendStream(cricket::StreamParams::CreateLegacy(_ssrcVideo.outgoing));
    
    auto videoCodec = selectVideoCodec(videoCodecs);
    if (videoCodec.has_value()) {
        _nativeVideoSource = makeVideoSource(_thread, _workerThread.get());
        
        auto codec = videoCodec.value();
        
        codec.SetParam(cricket::kCodecParamMinBitrate, 64);
        codec.SetParam(cricket::kCodecParamStartBitrate, 256);
        codec.SetParam(cricket::kCodecParamMaxBitrate, 2500);
        
        _videoCapturer = makeVideoCapturer(_nativeVideoSource);
        
        cricket::VideoSendParameters videoSendParameters;
        videoSendParameters.codecs.push_back(codec);
        const int videoExtensionSequence = 1;
        videoSendParameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, videoExtensionSequence);
        //send_parameters.max_bandwidth_bps = 800000;
        //send_parameters.rtcp.reduced_size = true;
        videoSendParameters.rtcp.remote_estimate = true;
        _videoChannel->SetSendParameters(videoSendParameters);
        
        _videoChannel->SetVideoSend(_ssrcVideo.outgoing, NULL, _nativeVideoSource.get());
        
        _videoChannel->SetInterface(_videoNetworkInterface.get(), webrtc::MediaTransportConfig());
        
        cricket::VideoRecvParameters videoRecvParameters;
        videoRecvParameters.codecs.emplace_back(codec);
        videoRecvParameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, videoExtensionSequence);
        //recv_parameters.rtcp.reduced_size = true;
        videoRecvParameters.rtcp.remote_estimate = true;
        _videoChannel->AddRecvStream(cricket::StreamParams::CreateLegacy(_ssrcVideo.incoming));
        _videoChannel->SetRecvParameters(videoRecvParameters);
    }
}

MediaManager::~MediaManager() {
    assert(_thread->IsCurrent());
    
    _call->SignalChannelNetworkState(webrtc::MediaType::AUDIO, webrtc::kNetworkDown);
    _call->SignalChannelNetworkState(webrtc::MediaType::VIDEO, webrtc::kNetworkDown);
    
    _audioChannel->OnReadyToSend(false);
    _audioChannel->SetSend(false);
    _audioChannel->SetAudioSend(_ssrcAudio.outgoing, false, nullptr, &_audioSource);
    
    _audioChannel->SetPlayout(false);
    
    _audioChannel->RemoveRecvStream(_ssrcAudio.incoming);
    _audioChannel->RemoveSendStream(_ssrcAudio.outgoing);
}

void MediaManager::setIsConnected(bool isConnected) {
    if (isConnected) {
        _call->SignalChannelNetworkState(webrtc::MediaType::AUDIO, webrtc::kNetworkUp);
        _call->SignalChannelNetworkState(webrtc::MediaType::VIDEO, webrtc::kNetworkUp);
    } else {
        _call->SignalChannelNetworkState(webrtc::MediaType::AUDIO, webrtc::kNetworkDown);
        _call->SignalChannelNetworkState(webrtc::MediaType::VIDEO, webrtc::kNetworkDown);
    }
    if (_audioChannel) {
        _audioChannel->OnReadyToSend(isConnected);
        _audioChannel->SetSend(isConnected);
        _audioChannel->SetAudioSend(_ssrcAudio.outgoing, isConnected, nullptr, &_audioSource);
    }
    if (_videoChannel) {
        _videoChannel->OnReadyToSend(isConnected);
        _videoChannel->SetSend(isConnected);
    }
}

void MediaManager::receivePacket(const rtc::CopyOnWriteBuffer &packet) {
    if (packet.size() < 1) {
        return;
    }
    
    uint8_t header = ((uint8_t *)packet.data())[0];
    rtc::CopyOnWriteBuffer unwrappedPacket = packet.Slice(1, packet.size() - 1);
    
    if (header == 0xba) {
        if (_audioChannel) {
            _audioChannel->OnPacketReceived(unwrappedPacket, -1);
        }
    } else if (header == 0xbf) {
        if (_videoChannel) {
            _videoChannel->OnPacketReceived(unwrappedPacket, -1);
        }
    }
}

void MediaManager::notifyPacketSent(const rtc::SentPacket &sentPacket) {
    _call->OnSentPacket(sentPacket);
}

void MediaManager::setIncomingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
    _currentIncomingVideoSink = sink;
    _videoChannel->SetSink(_ssrcVideo.incoming, sink.get());
}

void MediaManager::setOutgoingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
    _currentOutgoingVideoSink = sink;
    _nativeVideoSource->AddOrUpdateSink(sink.get(), rtc::VideoSinkWants());
}

MediaManager::NetworkInterfaceImpl::NetworkInterfaceImpl(MediaManager *mediaManager, bool isVideo) :
_mediaManager(mediaManager),
_isVideo(isVideo) {
}

bool MediaManager::NetworkInterfaceImpl::SendPacket(rtc::CopyOnWriteBuffer *packet, const rtc::PacketOptions& options) {
    rtc::CopyOnWriteBuffer wrappedPacket;
    uint8_t header = _isVideo ? 0xbf : 0xba;
    wrappedPacket.AppendData(&header, 1);
    wrappedPacket.AppendData(*packet);
    
    _mediaManager->_packetEmitted(wrappedPacket);
    rtc::SentPacket sentPacket(options.packet_id, rtc::TimeMillis(), options.info_signaled_after_sent);
    _mediaManager->notifyPacketSent(sentPacket);
    return true;
}

bool MediaManager::NetworkInterfaceImpl::SendRtcp(rtc::CopyOnWriteBuffer *packet, const rtc::PacketOptions& options) {
    rtc::CopyOnWriteBuffer wrappedPacket;
    uint8_t header = _isVideo ? 0xbf : 0xba;
    wrappedPacket.AppendData(&header, 1);
    wrappedPacket.AppendData(*packet);
    
    _mediaManager->_packetEmitted(wrappedPacket);
    rtc::SentPacket sentPacket(options.packet_id, rtc::TimeMillis(), options.info_signaled_after_sent);
    _mediaManager->notifyPacketSent(sentPacket);
    return true;
}

int MediaManager::NetworkInterfaceImpl::SetOption(cricket::MediaChannel::NetworkInterface::SocketType, rtc::Socket::Option, int) {
    return -1;
}

#ifdef TGVOIP_NAMESPACE
}
#endif
