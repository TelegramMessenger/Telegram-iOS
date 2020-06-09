/*
 *  Copyright 2015 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

// This file contains classes that implement RtpSenderInterface.
// An RtpSender associates a MediaStreamTrackInterface with an underlying
// transport (provided by AudioProviderInterface/VideoProviderInterface)

#ifndef TG_PC_RTP_SENDER_H_
#define TG_PC_RTP_SENDER_H_

#include <memory>
#include <string>
#include <vector>

#include "api/media_stream_interface.h"
#include "api/rtp_sender_interface.h"
#include "media/base/audio_source.h"
#include "media/base/media_channel.h"
#include "pc/dtmf_sender.h"
#include "rtc_base/critical_section.h"

#include "pc/rtp_sender.h"

namespace webrtc {

class StatsCollector;

bool TgUnimplementedRtpParameterHasValue(const RtpParameters& parameters);

// TgLocalAudioSinkAdapter receives data callback as a sink to the local
// AudioTrack, and passes the data to the sink of AudioSource.
class TgLocalAudioSinkAdapter : public AudioTrackSinkInterface,
                              public cricket::AudioSource {
 public:
  TgLocalAudioSinkAdapter();
  virtual ~TgLocalAudioSinkAdapter();

 private:
  // AudioSinkInterface implementation.
  void OnData(const void* audio_data,
              int bits_per_sample,
              int sample_rate,
              size_t number_of_channels,
              size_t number_of_frames) override;

  // cricket::AudioSource implementation.
  void SetSink(cricket::AudioSource::Sink* sink) override;

  cricket::AudioSource::Sink* sink_;
  // Critical section protecting |sink_|.
  rtc::CriticalSection lock_;
};

class TgAudioRtpSender : public DtmfProviderInterface, public RtpSenderBase {
 public:
  // Construct an RtpSender for audio with the given sender ID.
  // The sender is initialized with no track to send and no associated streams.
  // StatsCollector provided so that Add/RemoveLocalAudioTrack can be called
  // at the appropriate times.
  // If |set_streams_observer| is not null, it is invoked when SetStreams()
  // is called. |set_streams_observer| is not owned by this object. If not
  // null, it must be valid at least until this sender becomes stopped.
  static rtc::scoped_refptr<TgAudioRtpSender> Create(
      rtc::Thread* worker_thread,
      const std::string& id,
      SetStreamsObserver* set_streams_observer);
  virtual ~TgAudioRtpSender();

  // DtmfSenderProvider implementation.
  bool CanInsertDtmf() override;
  bool InsertDtmf(int code, int duration) override;
  sigslot::signal0<>* GetOnDestroyedSignal() override;

  // ObserverInterface implementation.
  void OnChanged() override;

  cricket::MediaType media_type() const override {
    return cricket::MEDIA_TYPE_AUDIO;
  }
  std::string track_kind() const override {
    return MediaStreamTrackInterface::kAudioKind;
  }

  rtc::scoped_refptr<DtmfSenderInterface> GetDtmfSender() const override;

 protected:
  TgAudioRtpSender(rtc::Thread* worker_thread,
                 const std::string& id,
                 SetStreamsObserver* set_streams_observer);

  void SetSend() override;
  void ClearSend() override;

  // Hooks to allow custom logic when tracks are attached and detached.
  void AttachTrack() override;
  void DetachTrack() override;
  void AddTrackToStats() override;
  void RemoveTrackFromStats() override;

 private:
  cricket::VoiceMediaChannel* voice_media_channel() {
    return static_cast<cricket::VoiceMediaChannel*>(media_channel_);
  }
  rtc::scoped_refptr<AudioTrackInterface> audio_track() const {
    return rtc::scoped_refptr<AudioTrackInterface>(
        static_cast<AudioTrackInterface*>(track_.get()));
  }
  sigslot::signal0<> SignalDestroyed;

  rtc::scoped_refptr<DtmfSenderInterface> dtmf_sender_proxy_;
  bool cached_track_enabled_ = false;

  // Used to pass the data callback from the |track_| to the other end of
  // cricket::AudioSource.
  std::unique_ptr<TgLocalAudioSinkAdapter> sink_adapter_;
};

class TgVideoRtpSender : public RtpSenderBase {
 public:
  // Construct an RtpSender for video with the given sender ID.
  // The sender is initialized with no track to send and no associated streams.
  // If |set_streams_observer| is not null, it is invoked when SetStreams()
  // is called. |set_streams_observer| is not owned by this object. If not
  // null, it must be valid at least until this sender becomes stopped.
  static rtc::scoped_refptr<TgVideoRtpSender> Create(
      rtc::Thread* worker_thread,
      const std::string& id,
      SetStreamsObserver* set_streams_observer);
  virtual ~TgVideoRtpSender();

  // ObserverInterface implementation
  void OnChanged() override;

  cricket::MediaType media_type() const override {
    return cricket::MEDIA_TYPE_VIDEO;
  }
  std::string track_kind() const override {
    return MediaStreamTrackInterface::kVideoKind;
  }

  rtc::scoped_refptr<DtmfSenderInterface> GetDtmfSender() const override;

 protected:
  TgVideoRtpSender(rtc::Thread* worker_thread,
                 const std::string& id,
                 SetStreamsObserver* set_streams_observer);

  void SetSend() override;
  void ClearSend() override;

  // Hook to allow custom logic when tracks are attached.
  void AttachTrack() override;

 private:
  cricket::VideoMediaChannel* video_media_channel() {
    return static_cast<cricket::VideoMediaChannel*>(media_channel_);
  }
  rtc::scoped_refptr<VideoTrackInterface> video_track() const {
    return rtc::scoped_refptr<VideoTrackInterface>(
        static_cast<VideoTrackInterface*>(track_.get()));
  }

  VideoTrackInterface::ContentHint cached_track_content_hint_ =
      VideoTrackInterface::ContentHint::kNone;
};

}  // namespace webrtc

#endif  // PC_RTP_SENDER_H_
