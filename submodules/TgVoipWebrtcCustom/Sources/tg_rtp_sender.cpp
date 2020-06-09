/*
 *  Copyright 2015 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#include "tg_rtp_sender.h"

#include <atomic>
#include <utility>
#include <vector>

#include "api/audio_options.h"
#include "api/media_stream_interface.h"
#include "media/base/media_engine.h"
#include "pc/peer_connection.h"
#include "pc/stats_collector.h"
#include "rtc_base/checks.h"
#include "rtc_base/helpers.h"
#include "rtc_base/location.h"
#include "rtc_base/logging.h"
#include "rtc_base/trace_event.h"

namespace webrtc {

namespace {

// This function is only expected to be called on the signaling thread.
// On the other hand, some test or even production setups may use
// several signaling threads.
int GenerateUniqueId() {
  static std::atomic<int> g_unique_id{0};

  return ++g_unique_id;
}

// Returns true if a "per-sender" encoding parameter contains a value that isn't
// its default. Currently max_bitrate_bps and bitrate_priority both are
// implemented "per-sender," meaning that these encoding parameters
// are used for the RtpSender as a whole, not for a specific encoding layer.
// This is done by setting these encoding parameters at index 0 of
// RtpParameters.encodings. This function can be used to check if these
// parameters are set at any index other than 0 of RtpParameters.encodings,
// because they are currently unimplemented to be used for a specific encoding
// layer.
bool PerSenderRtpEncodingParameterHasValue(
    const RtpEncodingParameters& encoding_params) {
  if (encoding_params.bitrate_priority != kDefaultBitratePriority ||
      encoding_params.network_priority != kDefaultBitratePriority) {
    return true;
  }
  return false;
}

void RemoveEncodingLayers(const std::vector<std::string>& rids,
                          std::vector<RtpEncodingParameters>* encodings) {
  RTC_DCHECK(encodings);
  encodings->erase(
      std::remove_if(encodings->begin(), encodings->end(),
                     [&rids](const RtpEncodingParameters& encoding) {
                       return absl::c_linear_search(rids, encoding.rid);
                     }),
      encodings->end());
}

RtpParameters RestoreEncodingLayers(
    const RtpParameters& parameters,
    const std::vector<std::string>& removed_rids,
    const std::vector<RtpEncodingParameters>& all_layers) {
  RTC_DCHECK_EQ(parameters.encodings.size() + removed_rids.size(),
                all_layers.size());
  RtpParameters result(parameters);
  result.encodings.clear();
  size_t index = 0;
  for (const RtpEncodingParameters& encoding : all_layers) {
    if (absl::c_linear_search(removed_rids, encoding.rid)) {
      result.encodings.push_back(encoding);
      continue;
    }
    result.encodings.push_back(parameters.encodings[index++]);
  }
  return result;
}

}  // namespace

// Returns true if any RtpParameters member that isn't implemented contains a
// value.
bool TgUnimplementedRtpParameterHasValue(const RtpParameters& parameters) {
  if (!parameters.mid.empty()) {
    return true;
  }
  for (size_t i = 0; i < parameters.encodings.size(); ++i) {
    // Encoding parameters that are per-sender should only contain value at
    // index 0.
    if (i != 0 &&
        PerSenderRtpEncodingParameterHasValue(parameters.encodings[i])) {
      return true;
    }
  }
  return false;
}

TgLocalAudioSinkAdapter::TgLocalAudioSinkAdapter() : sink_(nullptr) {}

TgLocalAudioSinkAdapter::~TgLocalAudioSinkAdapter() {
  rtc::CritScope lock(&lock_);
  if (sink_)
    sink_->OnClose();
}

void TgLocalAudioSinkAdapter::OnData(const void* audio_data,
                                   int bits_per_sample,
                                   int sample_rate,
                                   size_t number_of_channels,
                                   size_t number_of_frames) {
  rtc::CritScope lock(&lock_);
  if (sink_) {
    sink_->OnData(audio_data, bits_per_sample, sample_rate, number_of_channels,
                  number_of_frames);
  }
}

void TgLocalAudioSinkAdapter::SetSink(cricket::AudioSource::Sink* sink) {
  rtc::CritScope lock(&lock_);
  RTC_DCHECK(!sink || !sink_);
  sink_ = sink;
}

rtc::scoped_refptr<TgAudioRtpSender> TgAudioRtpSender::Create(
    rtc::Thread* worker_thread,
    const std::string& id,
    SetStreamsObserver* set_streams_observer) {
  return rtc::scoped_refptr<TgAudioRtpSender>(
      new rtc::RefCountedObject<TgAudioRtpSender>(worker_thread, id,
                                                set_streams_observer));
}

TgAudioRtpSender::TgAudioRtpSender(rtc::Thread* worker_thread,
                               const std::string& id,
                               SetStreamsObserver* set_streams_observer)
    : RtpSenderBase(worker_thread, id, set_streams_observer),
      dtmf_sender_proxy_(DtmfSenderProxy::Create(
          rtc::Thread::Current(),
          DtmfSender::Create(rtc::Thread::Current(), this))),
      sink_adapter_(new TgLocalAudioSinkAdapter()) {}

TgAudioRtpSender::~TgAudioRtpSender() {
  // For DtmfSender.
  SignalDestroyed();
  Stop();
}

bool TgAudioRtpSender::CanInsertDtmf() {
  if (!media_channel_) {
    RTC_LOG(LS_ERROR) << "CanInsertDtmf: No audio channel exists.";
    return false;
  }
  // Check that this RTP sender is active (description has been applied that
  // matches an SSRC to its ID).
  if (!ssrc_) {
    RTC_LOG(LS_ERROR) << "CanInsertDtmf: Sender does not have SSRC.";
    return false;
  }
  return worker_thread_->Invoke<bool>(
      RTC_FROM_HERE, [&] { return voice_media_channel()->CanInsertDtmf(); });
}

bool TgAudioRtpSender::InsertDtmf(int code, int duration) {
  if (!media_channel_) {
    RTC_LOG(LS_ERROR) << "InsertDtmf: No audio channel exists.";
    return false;
  }
  if (!ssrc_) {
    RTC_LOG(LS_ERROR) << "InsertDtmf: Sender does not have SSRC.";
    return false;
  }
  bool success = worker_thread_->Invoke<bool>(RTC_FROM_HERE, [&] {
    return voice_media_channel()->InsertDtmf(ssrc_, code, duration);
  });
  if (!success) {
    RTC_LOG(LS_ERROR) << "Failed to insert DTMF to channel.";
  }
  return success;
}

sigslot::signal0<>* TgAudioRtpSender::GetOnDestroyedSignal() {
  return &SignalDestroyed;
}

void TgAudioRtpSender::OnChanged() {
  TRACE_EVENT0("webrtc", "TgAudioRtpSender::OnChanged");
  RTC_DCHECK(!stopped_);
  if (cached_track_enabled_ != track_->enabled()) {
    cached_track_enabled_ = track_->enabled();
    if (can_send_track()) {
      SetSend();
    }
  }
}

void TgAudioRtpSender::DetachTrack() {
  RTC_DCHECK(track_);
  audio_track()->RemoveSink(sink_adapter_.get());
}

void TgAudioRtpSender::AttachTrack() {
  RTC_DCHECK(track_);
  cached_track_enabled_ = track_->enabled();
  audio_track()->AddSink(sink_adapter_.get());
}

void TgAudioRtpSender::AddTrackToStats() {
}

void TgAudioRtpSender::RemoveTrackFromStats() {
}

rtc::scoped_refptr<DtmfSenderInterface> TgAudioRtpSender::GetDtmfSender() const {
  return dtmf_sender_proxy_;
}

void TgAudioRtpSender::SetSend() {
  RTC_DCHECK(!stopped_);
  RTC_DCHECK(can_send_track());
  if (!media_channel_) {
    RTC_LOG(LS_ERROR) << "SetAudioSend: No audio channel exists.";
    return;
  }
  cricket::AudioOptions options;
#if !defined(WEBRTC_CHROMIUM_BUILD) && !defined(WEBRTC_WEBKIT_BUILD)
  // TODO(tommi): Remove this hack when we move CreateAudioSource out of
  // PeerConnection.  This is a bit of a strange way to apply local audio
  // options since it is also applied to all streams/channels, local or remote.
  if (track_->enabled() && audio_track()->GetSource() &&
      !audio_track()->GetSource()->remote()) {
    options = audio_track()->GetSource()->options();
  }
#endif

  // |track_->enabled()| hops to the signaling thread, so call it before we hop
  // to the worker thread or else it will deadlock.
  bool track_enabled = track_->enabled();
  bool success = worker_thread_->Invoke<bool>(RTC_FROM_HERE, [&] {
    return voice_media_channel()->SetAudioSend(ssrc_, track_enabled, &options,
                                               sink_adapter_.get());
  });
  if (!success) {
    RTC_LOG(LS_ERROR) << "SetAudioSend: ssrc is incorrect: " << ssrc_;
  }
}

void TgAudioRtpSender::ClearSend() {
  RTC_DCHECK(ssrc_ != 0);
  RTC_DCHECK(!stopped_);
  if (!media_channel_) {
    RTC_LOG(LS_WARNING) << "ClearAudioSend: No audio channel exists.";
    return;
  }
  cricket::AudioOptions options;
  bool success = worker_thread_->Invoke<bool>(RTC_FROM_HERE, [&] {
    return voice_media_channel()->SetAudioSend(ssrc_, false, &options, nullptr);
  });
  if (!success) {
    RTC_LOG(LS_WARNING) << "ClearAudioSend: ssrc is incorrect: " << ssrc_;
  }
}

rtc::scoped_refptr<TgVideoRtpSender> TgVideoRtpSender::Create(
    rtc::Thread* worker_thread,
    const std::string& id,
    SetStreamsObserver* set_streams_observer) {
  return rtc::scoped_refptr<TgVideoRtpSender>(
      new rtc::RefCountedObject<TgVideoRtpSender>(worker_thread, id,
                                                set_streams_observer));
}

TgVideoRtpSender::TgVideoRtpSender(rtc::Thread* worker_thread,
                               const std::string& id,
                               SetStreamsObserver* set_streams_observer)
    : RtpSenderBase(worker_thread, id, set_streams_observer) {}

TgVideoRtpSender::~TgVideoRtpSender() {
  Stop();
}

void TgVideoRtpSender::OnChanged() {
  TRACE_EVENT0("webrtc", "TgVideoRtpSender::OnChanged");
  RTC_DCHECK(!stopped_);
  if (cached_track_content_hint_ != video_track()->content_hint()) {
    cached_track_content_hint_ = video_track()->content_hint();
    if (can_send_track()) {
      SetSend();
    }
  }
}

void TgVideoRtpSender::AttachTrack() {
  RTC_DCHECK(track_);
  cached_track_content_hint_ = video_track()->content_hint();
}

rtc::scoped_refptr<DtmfSenderInterface> TgVideoRtpSender::GetDtmfSender() const {
  RTC_LOG(LS_ERROR) << "Tried to get DTMF sender from video sender.";
  return nullptr;
}

void TgVideoRtpSender::SetSend() {
  RTC_DCHECK(!stopped_);
  RTC_DCHECK(can_send_track());
  if (!media_channel_) {
    RTC_LOG(LS_ERROR) << "SetVideoSend: No video channel exists.";
    return;
  }
  cricket::VideoOptions options;
  VideoTrackSourceInterface* source = video_track()->GetSource();
  if (source) {
    options.is_screencast = source->is_screencast();
    options.video_noise_reduction = source->needs_denoising();
  }
  switch (cached_track_content_hint_) {
    case VideoTrackInterface::ContentHint::kNone:
      break;
    case VideoTrackInterface::ContentHint::kFluid:
      options.is_screencast = false;
      break;
    case VideoTrackInterface::ContentHint::kDetailed:
    case VideoTrackInterface::ContentHint::kText:
      options.is_screencast = true;
      break;
  }
  bool success = worker_thread_->Invoke<bool>(RTC_FROM_HERE, [&] {
    return video_media_channel()->SetVideoSend(ssrc_, &options, video_track());
  });
  RTC_DCHECK(success);
}

void TgVideoRtpSender::ClearSend() {
  RTC_DCHECK(ssrc_ != 0);
  RTC_DCHECK(!stopped_);
  if (!media_channel_) {
    RTC_LOG(LS_WARNING) << "SetVideoSend: No video channel exists.";
    return;
  }
  // Allow SetVideoSend to fail since |enable| is false and |source| is null.
  // This the normal case when the underlying media channel has already been
  // deleted.
  worker_thread_->Invoke<bool>(RTC_FROM_HERE, [&] {
    return video_media_channel()->SetVideoSend(ssrc_, nullptr, nullptr);
  });
}

}  // namespace webrtc
