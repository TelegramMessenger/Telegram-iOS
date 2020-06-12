#include "MediaEngineWebrtc.h"

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

#include "sdk/objc/components/video_codec/RTCVideoEncoderFactoryH264.h"
#include "sdk/objc/components/video_codec/RTCVideoDecoderFactoryH264.h"
#include "sdk/objc/components/video_codec/RTCDefaultVideoEncoderFactory.h"
#include "sdk/objc/components/video_codec/RTCDefaultVideoDecoderFactory.h"
#include "sdk/objc/native/api/video_encoder_factory.h"
#include "sdk/objc/native/api/video_decoder_factory.h"

#include "sdk/objc/native/src/objc_video_track_source.h"
#include "api/video_track_source_proxy.h"
#include "sdk/objc/api/RTCVideoRendererAdapter.h"
#include "sdk/objc/native/api/video_frame.h"
#include "api/media_types.h"

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
const uint32_t caller_ssrc_video = 3;
const uint32_t called_ssrc_video = 4;
const int extension_sequence = 1;
const int extension_sequence_video = 1;
}

static void AddDefaultFeedbackParams(cricket::VideoCodec* codec) {
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

MediaEngineWebrtc::MediaEngineWebrtc(bool outgoing)
: ssrc_send(outgoing ? caller_ssrc : called_ssrc)
, ssrc_recv(outgoing ? called_ssrc : caller_ssrc)
, ssrc_send_video(outgoing ? caller_ssrc_video : called_ssrc_video)
, ssrc_recv_video(outgoing ? called_ssrc_video : caller_ssrc_video)
, event_log(std::make_unique<webrtc::RtcEventLogNull>())
, task_queue_factory(webrtc::CreateDefaultTaskQueueFactory())
, audio_sender(*this, false)
, video_sender(*this, true)
, signaling_thread(rtc::Thread::Create())
, worker_thread(rtc::Thread::Create()) {
    signaling_thread->Start();
    worker_thread->Start();
    
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
    
    //auto video_encoder_factory = webrtc::ObjCToNativeVideoEncoderFactory([[RTCVideoEncoderFactoryH264 alloc] init]);
    auto video_encoder_factory = webrtc::ObjCToNativeVideoEncoderFactory([[RTCDefaultVideoEncoderFactory alloc] init]);
    int32_t outCodecId = 96;
    std::vector<cricket::VideoCodec> videoCodecs = AssignPayloadTypesAndDefaultCodecs(video_encoder_factory->GetSupportedFormats(), outCodecId);
    
    media_deps.video_encoder_factory = webrtc::ObjCToNativeVideoEncoderFactory([[RTCDefaultVideoEncoderFactory alloc] init]);
    media_deps.video_decoder_factory = webrtc::ObjCToNativeVideoDecoderFactory([[RTCDefaultVideoDecoderFactory alloc] init]);
    
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
    
    if (true) {
        voice_channel->AddSendStream(cricket::StreamParams::CreateLegacy(ssrc_send));
        SetNetworkParams({6, 32, 6, 120, false, false, false});
        SetMute(false);
        voice_channel->SetInterface(&audio_sender, webrtc::MediaTransportConfig());
    }
    
    if (true) {
        video_channel->AddSendStream(cricket::StreamParams::CreateLegacy(ssrc_send_video));
        
        for (auto codec : videoCodecs) {
            if (codec.id == outCodecId) {
                rtc::scoped_refptr<webrtc::ObjCVideoTrackSource> objCVideoTrackSource(new rtc::RefCountedObject<webrtc::ObjCVideoTrackSource>());
                _nativeVideoSource = webrtc::VideoTrackSourceProxy::Create(signaling_thread.get(), worker_thread.get(), objCVideoTrackSource);
                
                codec.SetParam(cricket::kCodecParamMinBitrate, 64);
                codec.SetParam(cricket::kCodecParamStartBitrate, 256);
                codec.SetParam(cricket::kCodecParamMaxBitrate, 2500);
     
                dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_IPHONE_SIMULATOR
#else
                    _videoCapturer = [[VideoCameraCapturer alloc] initWithSource:_nativeVideoSource];
                    
                    AVCaptureDevice *frontCamera = nil;
                    for (AVCaptureDevice *device in [VideoCameraCapturer captureDevices]) {
                        if (device.position == AVCaptureDevicePositionFront) {
                            frontCamera = device;
                            break;
                        }
                    }
                    
                    if (frontCamera == nil) {
                        assert(false);
                        return;
                    }
                    
                    NSArray<AVCaptureDeviceFormat *> *sortedFormats = [[VideoCameraCapturer supportedFormatsForDevice:frontCamera] sortedArrayUsingComparator:^NSComparisonResult(AVCaptureDeviceFormat* lhs, AVCaptureDeviceFormat *rhs) {
                        int32_t width1 = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription).width;
                        int32_t width2 = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription).width;
                        return width1 < width2 ? NSOrderedAscending : NSOrderedDescending;
                    }];
                    
                    AVCaptureDeviceFormat *bestFormat = nil;
                    for (AVCaptureDeviceFormat *format in sortedFormats) {
                        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
                        if (dimensions.width >= 1000 || dimensions.height >= 1000) {
                            bestFormat = format;
                            break;
                        }
                    }
                    
                    if (bestFormat == nil) {
                        assert(false);
                        return;
                    }
                    
                    AVFrameRateRange *frameRateRange = [[bestFormat.videoSupportedFrameRateRanges sortedArrayUsingComparator:^NSComparisonResult(AVFrameRateRange *lhs, AVFrameRateRange *rhs) {
                        if (lhs.maxFrameRate < rhs.maxFrameRate) {
                            return NSOrderedAscending;
                        } else {
                            return NSOrderedDescending;
                        }
                    }] lastObject];
                    
                    if (frameRateRange == nil) {
                        assert(false);
                        return;
                    }
                    
                    [_videoCapturer startCaptureWithDevice:frontCamera format:bestFormat fps:27];
#endif
                });
                
                cricket::VideoSendParameters send_parameters;
                send_parameters.codecs.push_back(codec);
                send_parameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, extension_sequence_video);
                //send_parameters.options.echo_cancellation = params.echo_cancellation;
                //send_parameters.options.noise_suppression = params.noise_suppression;
                //send_parameters.options.auto_gain_control = params.auto_gain_control;
                //send_parameters.options.highpass_filter = false;
                //send_parameters.options.typing_detection = false;
                //send_parameters.max_bandwidth_bps = 800000;
                //send_parameters.rtcp.reduced_size = true;
                send_parameters.rtcp.remote_estimate = true;
                video_channel->SetSendParameters(send_parameters);
                
                video_channel->SetVideoSend(ssrc_send_video, NULL, _nativeVideoSource.get());
                
                video_channel->SetInterface(&video_sender, webrtc::MediaTransportConfig());
                
                break;
            }
        }
    }
    if (true) {
        cricket::AudioRecvParameters recv_parameters;
        recv_parameters.codecs.emplace_back(sdp_payload, sdp_name, clockrate, sdp_bitrate, sdp_channels);
        recv_parameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, extension_sequence);
        recv_parameters.rtcp.reduced_size = true;
        recv_parameters.rtcp.remote_estimate = true;
        voice_channel->AddRecvStream(cricket::StreamParams::CreateLegacy(ssrc_recv));
        voice_channel->SetRecvParameters(recv_parameters);
        voice_channel->SetPlayout(true);
    }
    if (true) {
        for (auto codec : videoCodecs) {
            if (codec.id == outCodecId) {
                codec.SetParam(cricket::kCodecParamMinBitrate, 32);
                codec.SetParam(cricket::kCodecParamStartBitrate, 300);
                codec.SetParam(cricket::kCodecParamMaxBitrate, 1000);
                
                cricket::VideoRecvParameters recv_parameters;
                recv_parameters.codecs.emplace_back(codec);
                recv_parameters.extensions.emplace_back(webrtc::RtpExtension::kTransportSequenceNumberUri, extension_sequence_video);
                //recv_parameters.rtcp.reduced_size = true;
                recv_parameters.rtcp.remote_estimate = true;
                video_channel->AddRecvStream(cricket::StreamParams::CreateLegacy(ssrc_recv_video));
                video_channel->SetRecvParameters(recv_parameters);
                
                break;
            }
        }
    }
}

MediaEngineWebrtc::~MediaEngineWebrtc() {
    [_videoCapturer stopCapture];
    video_channel->SetSink(ssrc_recv_video, nullptr);
    video_channel->RemoveSendStream(ssrc_send_video);
    video_channel->RemoveRecvStream(ssrc_recv_video);
    
    voice_channel->SetPlayout(false);
    voice_channel->RemoveSendStream(ssrc_send);
    voice_channel->RemoveRecvStream(ssrc_recv);
};

void MediaEngineWebrtc::Receive(rtc::CopyOnWriteBuffer packet) {
    if (packet.size() < 1) {
        return;
    }
    
    uint8_t header = ((uint8_t *)packet.data())[0];
    rtc::CopyOnWriteBuffer unwrappedPacket = packet.Slice(1, packet.size() - 1);
    
    if (header == 0xba) {
        if (voice_channel) {
            voice_channel->OnPacketReceived(unwrappedPacket, -1);
        }
    } else if (header == 0xbf) {
        if (video_channel) {
            video_channel->OnPacketReceived(unwrappedPacket, -1);
        }
    } else {
        printf("----- Unknown packet header");
    }
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

}

void MediaEngineWebrtc::SetCanSendPackets(bool canSendPackets) {
    if (canSendPackets) {
        call->SignalChannelNetworkState(webrtc::MediaType::AUDIO, webrtc::kNetworkUp);
        call->SignalChannelNetworkState(webrtc::MediaType::VIDEO, webrtc::kNetworkUp);
    } else {
        call->SignalChannelNetworkState(webrtc::MediaType::AUDIO, webrtc::kNetworkDown);
        call->SignalChannelNetworkState(webrtc::MediaType::VIDEO, webrtc::kNetworkDown);
    }
    if (voice_channel) {
        voice_channel->OnReadyToSend(canSendPackets);
        voice_channel->SetSend(canSendPackets);
        voice_channel->SetAudioSend(ssrc_send, true, nullptr, &audio_source);
    }
    if (video_channel) {
        video_channel->OnReadyToSend(canSendPackets);
        video_channel->SetSend(canSendPackets);
    }
}

void MediaEngineWebrtc::AttachVideoView(rtc::VideoSinkInterface<webrtc::VideoFrame> *sink) {
    video_channel->SetSink(ssrc_recv_video, sink);
}

bool MediaEngineWebrtc::Sender::SendPacket(rtc::CopyOnWriteBuffer *packet, const rtc::PacketOptions& options) {
    rtc::CopyOnWriteBuffer wrappedPacket;
    uint8_t header = isVideo ? 0xbf : 0xba;
    wrappedPacket.AppendData(&header, 1);
    wrappedPacket.AppendData(*packet);
    
    engine.Send(wrappedPacket);
    rtc::SentPacket sent_packet(options.packet_id, rtc::TimeMillis(), options.info_signaled_after_sent);
    engine.OnSentPacket(sent_packet);
    return true;
}

bool MediaEngineWebrtc::Sender::SendRtcp(rtc::CopyOnWriteBuffer *packet, const rtc::PacketOptions& options) {
    rtc::CopyOnWriteBuffer wrappedPacket;
    uint8_t header = isVideo ? 0xbf : 0xba;
    wrappedPacket.AppendData(&header, 1);
    wrappedPacket.AppendData(*packet);
    
    engine.Send(wrappedPacket);
    rtc::SentPacket sent_packet(options.packet_id, rtc::TimeMillis(), options.info_signaled_after_sent);
    engine.OnSentPacket(sent_packet);
    return true;
}

int MediaEngineWebrtc::Sender::SetOption(cricket::MediaChannel::NetworkInterface::SocketType, rtc::Socket::Option, int) {
    return -1;  // in general, the result is not important yet
}

MediaEngineWebrtc::Sender::Sender(MediaEngineWebrtc &engine, bool isVideo) :
engine(engine),
isVideo(isVideo) {
    
}
