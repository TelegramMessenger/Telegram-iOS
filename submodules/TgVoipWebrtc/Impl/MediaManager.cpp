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

#include "api/video_codecs/builtin_video_encoder_factory.h"

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
static const uint32_t ssrcAudioFecIncoming = 5;
static const uint32_t ssrcAudioFecOutgoing = 6;
static const uint32_t ssrcVideoIncoming = 3;
static const uint32_t ssrcVideoOutgoing = 4;
static const uint32_t ssrcVideoFecIncoming = 7;
static const uint32_t ssrcVideoFecOutgoing = 8;

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

static std::vector<cricket::VideoCodec> AssignPayloadTypesAndDefaultCodecs(std::vector<webrtc::SdpVideoFormat> input_formats) {
    if (input_formats.empty())
        return std::vector<cricket::VideoCodec>();
    static const int kFirstDynamicPayloadType = 96;
    static const int kLastDynamicPayloadType = 127;
    int payload_type = kFirstDynamicPayloadType;
    
    input_formats.push_back(webrtc::SdpVideoFormat(cricket::kRedCodecName));
    input_formats.push_back(webrtc::SdpVideoFormat(cricket::kUlpfecCodecName));
    
    if (true) {
        webrtc::SdpVideoFormat flexfec_format(cricket::kFlexfecCodecName);
        // This value is currently arbitrarily set to 10 seconds. (The unit
        // is microseconds.) This parameter MUST be present in the SDP, but
        // we never use the actual value anywhere in our code however.
        // TODO(brandtr): Consider honouring this value in the sender and receiver.
        flexfec_format.parameters = {{cricket::kFlexfecFmtpRepairWindow, "10000000"}};
        input_formats.push_back(flexfec_format);
    }
    
    std::vector<cricket::VideoCodec> output_codecs;
    for (const webrtc::SdpVideoFormat& format : input_formats) {
        cricket::VideoCodec codec(format);
        codec.id = payload_type;
        AddDefaultFeedbackParams(&codec);
        output_codecs.push_back(codec);
        
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

static int sendCodecPriority(const cricket::VideoCodec &codec) {
    int priotity = 0;
    if (codec.name == cricket::kAv1CodecName) {
        return priotity;
    }
    priotity++;
    if (codec.name == cricket::kH265CodecName) {
        if (supportsH265Encoding()) {
            return priotity;
        }
    }
    priotity++;
    if (codec.name == cricket::kH264CodecName) {
        return priotity;
    }
    priotity++;
    if (codec.name == cricket::kVp9CodecName) {
        return priotity;
    }
    priotity++;
    if (codec.name == cricket::kVp8CodecName) {
        return priotity;
    }
    priotity++;
    return -1;
}

static absl::optional<cricket::VideoCodec> selectVideoCodec(std::vector<cricket::VideoCodec> &codecs) {
    std::vector<cricket::VideoCodec> sortedCodecs;
    for (auto &codec : codecs) {
        if (sendCodecPriority(codec) != -1) {
            sortedCodecs.push_back(codec);
        }
    }
    
    std::sort(sortedCodecs.begin(), sortedCodecs.end(), [](const cricket::VideoCodec &lhs, const cricket::VideoCodec &rhs) {
        return sendCodecPriority(lhs) < sendCodecPriority(rhs);
    });
    
    if (sortedCodecs.size() != 0) {
        return sortedCodecs[0];
    } else {
        return absl::nullopt;
    }
}

static rtc::Thread *makeWorkerThread() {
    static std::unique_ptr<rtc::Thread> value = rtc::Thread::Create();
    value->SetName("WebRTC-Worker", nullptr);
    value->Start();
    return value.get();
}


static rtc::Thread *MediaManager::getWorkerThread() {
    static rtc::Thread *value = makeWorkerThread();
    return value;
}

MediaManager::MediaManager(
    rtc::Thread *thread,
    bool isOutgoing,
    bool startWithVideo,
    std::function<void (const rtc::CopyOnWriteBuffer &)> packetEmitted,
    std::function<void (bool)> localVideoCaptureActiveUpdated
) :
_packetEmitted(packetEmitted),
_localVideoCaptureActiveUpdated(localVideoCaptureActiveUpdated),
_thread(thread),
_eventLog(std::make_unique<webrtc::RtcEventLogNull>()),
_taskQueueFactory(webrtc::CreateDefaultTaskQueueFactory()) {
    _ssrcAudio.incoming = isOutgoing ? ssrcAudioIncoming : ssrcAudioOutgoing;
    _ssrcAudio.outgoing = (!isOutgoing) ? ssrcAudioIncoming : ssrcAudioOutgoing;
    _ssrcAudio.fecIncoming = isOutgoing ? ssrcAudioFecIncoming : ssrcAudioFecOutgoing;
    _ssrcAudio.fecOutgoing = (!isOutgoing) ? ssrcAudioFecIncoming : ssrcAudioFecOutgoing;
    _ssrcVideo.incoming = isOutgoing ? ssrcVideoIncoming : ssrcVideoOutgoing;
    _ssrcVideo.outgoing = (!isOutgoing) ? ssrcVideoIncoming : ssrcVideoOutgoing;
    _ssrcVideo.fecIncoming = isOutgoing ? ssrcVideoFecIncoming : ssrcVideoFecOutgoing;
    _ssrcVideo.fecOutgoing = (!isOutgoing) ? ssrcVideoFecIncoming : ssrcVideoFecOutgoing;
    
    _enableFlexfec = true;
    
    _isConnected = false;
    _muteOutgoingAudio = false;
    
    auto videoEncoderFactory = makeVideoEncoderFactory();
    _videoCodecs = AssignPayloadTypesAndDefaultCodecs(videoEncoderFactory->GetSupportedFormats());
    
    _isSendingVideo = false;
    _useFrontCamera = true;
    
    _audioNetworkInterface = std::unique_ptr<MediaManager::NetworkInterfaceImpl>(new MediaManager::NetworkInterfaceImpl(this, false));
    _videoNetworkInterface = std::unique_ptr<MediaManager::NetworkInterfaceImpl>(new MediaManager::NetworkInterfaceImpl(this, true));
    
    webrtc::field_trial::InitFieldTrialsFromString(
        "WebRTC-Audio-SendSideBwe/Enabled/"
        "WebRTC-Audio-Allocation/min:6kbps,max:32kbps/"
        "WebRTC-Audio-OpusMinPacketLossRate/Enabled-1/"
        "WebRTC-FlexFEC-03/Enabled/"
        "WebRTC-FlexFEC-03-Advertised/Enabled/"
    );
    
    configurePlatformAudio();
    
    _videoBitrateAllocatorFactory = webrtc::CreateBuiltinVideoBitrateAllocatorFactory();
    
    cricket::MediaEngineDependencies mediaDeps;
    mediaDeps.task_queue_factory = _taskQueueFactory.get();
    mediaDeps.audio_encoder_factory = webrtc::CreateAudioEncoderFactory<webrtc::AudioEncoderOpus>();
    mediaDeps.audio_decoder_factory = webrtc::CreateAudioDecoderFactory<webrtc::AudioDecoderOpus>();
    
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
    const uint8_t opusStartBitrateKbps = 8;
    const uint8_t opusPTimeMs = 120;
    
    cricket::AudioCodec opusCodec(opusSdpPayload, opusSdpName, opusClockrate, opusSdpBitrate, opusSdpChannels);
    opusCodec.AddFeedbackParam(cricket::FeedbackParam(cricket::kRtcpFbParamTransportCc));
    opusCodec.SetParam(cricket::kCodecParamMinBitrate, opusMinBitrateKbps);
    opusCodec.SetParam(cricket::kCodecParamStartBitrate, opusStartBitrateKbps);
    opusCodec.SetParam(cricket::kCodecParamMaxBitrate, opusMaxBitrateKbps);
    opusCodec.SetParam(cricket::kCodecParamUseInbandFec, 1);
    opusCodec.SetParam(cricket::kCodecParamPTime, opusPTimeMs);

    cricket::AudioSendParameters audioSendPrameters;
    audioSendPrameters.codecs.push_back(opusCodec);
    audioSendPrameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, 1);
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
    audioRecvParameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, 1);
    audioRecvParameters.rtcp.reduced_size = true;
    audioRecvParameters.rtcp.remote_estimate = true;
    
    _audioChannel->SetRecvParameters(audioRecvParameters);
    _audioChannel->AddRecvStream(cricket::StreamParams::CreateLegacy(_ssrcAudio.incoming));
    _audioChannel->SetPlayout(true);
    
    _videoChannel->SetInterface(_videoNetworkInterface.get(), webrtc::MediaTransportConfig());
    
    _nativeVideoSource = makeVideoSource(_thread, getWorkerThread());
    
    if (startWithVideo) {
        setSendVideo(true);
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
    
    _audioChannel->SetInterface(nullptr, webrtc::MediaTransportConfig());
    
    setSendVideo(false);
}

void MediaManager::setIsConnected(bool isConnected) {
    if (_isConnected == isConnected) {
        return;
    }
    _isConnected = isConnected;
    
    if (_isConnected) {
        _call->SignalChannelNetworkState(webrtc::MediaType::AUDIO, webrtc::kNetworkUp);
        _call->SignalChannelNetworkState(webrtc::MediaType::VIDEO, webrtc::kNetworkUp);
    } else {
        _call->SignalChannelNetworkState(webrtc::MediaType::AUDIO, webrtc::kNetworkDown);
        _call->SignalChannelNetworkState(webrtc::MediaType::VIDEO, webrtc::kNetworkDown);
    }
    if (_audioChannel) {
        _audioChannel->OnReadyToSend(_isConnected);
        _audioChannel->SetSend(_isConnected);
        _audioChannel->SetAudioSend(_ssrcAudio.outgoing, _isConnected && !_muteOutgoingAudio, nullptr, &_audioSource);
    }
    if (_isSendingVideo && _videoChannel) {
        _videoChannel->OnReadyToSend(_isConnected);
        _videoChannel->SetSend(_isConnected);
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

void MediaManager::setSendVideo(bool sendVideo) {
    if (_isSendingVideo == sendVideo) {
        return;
    }
    _isSendingVideo = sendVideo;
    
    if (_isSendingVideo) {
        auto videoCodec = selectVideoCodec(_videoCodecs);
        if (videoCodec.has_value()) {
            auto codec = videoCodec.value();
            
            codec.SetParam(cricket::kCodecParamMinBitrate, 64);
            codec.SetParam(cricket::kCodecParamStartBitrate, 512);
            codec.SetParam(cricket::kCodecParamMaxBitrate, 2500);
            
            _videoCapturer = makeVideoCapturer(_nativeVideoSource, _useFrontCamera, [localVideoCaptureActiveUpdated = _localVideoCaptureActiveUpdated](bool isActive) {
                localVideoCaptureActiveUpdated(isActive);
            });
            
            cricket::VideoSendParameters videoSendParameters;
            videoSendParameters.codecs.push_back(codec);
            
            if (_enableFlexfec) {
                for (auto &c : _videoCodecs) {
                    if (c.name == cricket::kFlexfecCodecName) {
                        videoSendParameters.codecs.push_back(c);
                        break;
                    }
                }
            }
            
            videoSendParameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, 1);
            //send_parameters.max_bandwidth_bps = 800000;
            //send_parameters.rtcp.reduced_size = true;
            //videoSendParameters.rtcp.remote_estimate = true;
            _videoChannel->SetSendParameters(videoSendParameters);
            
            if (_enableFlexfec) {
                cricket::StreamParams videoSendStreamParams;
                cricket::SsrcGroup videoSendSsrcGroup(cricket::kFecFrSsrcGroupSemantics, {_ssrcVideo.outgoing, _ssrcVideo.fecOutgoing});
                videoSendStreamParams.ssrcs = {_ssrcVideo.outgoing};
                videoSendStreamParams.ssrc_groups.push_back(videoSendSsrcGroup);
                videoSendStreamParams.cname = "cname";
                _videoChannel->AddSendStream(videoSendStreamParams);
                
                _videoChannel->SetVideoSend(_ssrcVideo.outgoing, NULL, _nativeVideoSource.get());
                _videoChannel->SetVideoSend(_ssrcVideo.fecOutgoing, NULL, nullptr);
            } else {
                _videoChannel->AddSendStream(cricket::StreamParams::CreateLegacy(_ssrcVideo.outgoing));
                _videoChannel->SetVideoSend(_ssrcVideo.outgoing, NULL, _nativeVideoSource.get());
            }
            
            cricket::VideoRecvParameters videoRecvParameters;
            
            for (auto &c : _videoCodecs) {
                if (c.name == cricket::kFlexfecCodecName) {
                    videoRecvParameters.codecs.push_back(c);
                } else if (c.name == cricket::kH264CodecName) {
                    videoRecvParameters.codecs.push_back(c);
                } else if (c.name == cricket::kH265CodecName) {
                    videoRecvParameters.codecs.push_back(c);
                } else if (c.name == cricket::kVp8CodecName) {
                    videoRecvParameters.codecs.push_back(c);
                } else if (c.name == cricket::kVp9CodecName) {
                    videoRecvParameters.codecs.push_back(c);
                } else if (c.name == cricket::kAv1CodecName) {
                    videoRecvParameters.codecs.push_back(c);
                }
            }
            
            videoRecvParameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, 1);
            //recv_parameters.rtcp.reduced_size = true;
            videoRecvParameters.rtcp.remote_estimate = true;
            
            cricket::StreamParams videoRecvStreamParams;
            cricket::SsrcGroup videoRecvSsrcGroup(cricket::kFecFrSsrcGroupSemantics, {_ssrcVideo.incoming, _ssrcVideo.fecIncoming});
            videoRecvStreamParams.ssrcs = {_ssrcVideo.incoming};
            videoRecvStreamParams.ssrc_groups.push_back(videoRecvSsrcGroup);
            videoRecvStreamParams.cname = "cname";
            
            _videoChannel->AddRecvStream(videoRecvStreamParams);
            _videoChannel->SetRecvParameters(videoRecvParameters);
            
            if (_isSendingVideo && _videoChannel) {
                _videoChannel->OnReadyToSend(_isConnected);
                _videoChannel->SetSend(_isConnected);
            }
        }
    } else {
        _videoChannel->SetVideoSend(_ssrcVideo.outgoing, NULL, nullptr);
        _videoChannel->SetVideoSend(_ssrcVideo.fecOutgoing, NULL, nullptr);
        
        _videoCapturer.reset();
        
        _videoChannel->RemoveRecvStream(_ssrcVideo.incoming);
        _videoChannel->RemoveRecvStream(_ssrcVideo.fecIncoming);
        _videoChannel->RemoveSendStream(_ssrcVideo.outgoing);
        if (_enableFlexfec) {
            _videoChannel->RemoveSendStream(_ssrcVideo.fecOutgoing);
        }
    }
}

void MediaManager::setMuteOutgoingAudio(bool mute) {
    _muteOutgoingAudio = mute;
    
    _audioChannel->SetAudioSend(_ssrcAudio.outgoing, _isConnected && !_muteOutgoingAudio, nullptr, &_audioSource);
}

void MediaManager::switchVideoCamera() {
    if (_isSendingVideo) {
        _useFrontCamera = !_useFrontCamera;
        _videoCapturer = makeVideoCapturer(_nativeVideoSource, _useFrontCamera, [localVideoCaptureActiveUpdated = _localVideoCaptureActiveUpdated](bool isActive) {
            localVideoCaptureActiveUpdated(isActive);
        });
    }
}

void MediaManager::setIncomingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
    _currentIncomingVideoSink = sink;
    _videoChannel->SetSink(_ssrcVideo.incoming, _currentIncomingVideoSink.get());
}

void MediaManager::setOutgoingVideoOutput(std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {
    _currentOutgoingVideoSink = sink;
    _nativeVideoSource->AddOrUpdateSink(_currentOutgoingVideoSink.get(), rtc::VideoSinkWants());
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
