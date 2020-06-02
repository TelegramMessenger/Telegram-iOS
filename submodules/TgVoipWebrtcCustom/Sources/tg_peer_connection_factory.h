
/*
 *  Copyright 2011 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#ifndef TG_PC_PEER_CONNECTION_FACTORY_H_
#define TG_PC_PEER_CONNECTION_FACTORY_H_

#include <memory>
#include <string>

#include "api/media_stream_interface.h"
#include "api/peer_connection_interface.h"
#include "api/scoped_refptr.h"
#include "api/transport/media/media_transport_interface.h"
#include "media/sctp/sctp_transport_internal.h"
#include "pc/channel_manager.h"
#include "rtc_base/rtc_certificate_generator.h"
#include "rtc_base/thread.h"
#include "pc/peer_connection_factory.h"

namespace rtc {
class BasicNetworkManager;
class BasicPacketSocketFactory;
}  // namespace rtc

namespace webrtc {

class RtcEventLog;
class TgPeerConnection;
class TgPeerConnectionInterface;

class RTC_EXPORT TgPeerConnectionFactoryInterface
    : public rtc::RefCountInterface {
 public:
  // Set the options to be used for subsequently created PeerConnections.
    virtual void SetOptions(const PeerConnectionFactoryInterface::Options& options) = 0;

  // The preferred way to create a new peer connection. Simply provide the
  // configuration and a PeerConnectionDependencies structure.
  // TODO(benwright): Make pure virtual once downstream mock PC factory classes
  // are updated.
  virtual rtc::scoped_refptr<TgPeerConnectionInterface> CreatePeerConnection(
      const PeerConnectionInterface::RTCConfiguration& configuration,
      PeerConnectionDependencies dependencies);

  // Deprecated; |allocator| and |cert_generator| may be null, in which case
  // default implementations will be used.
  //
  // |observer| must not be null.
  //
  // Note that this method does not take ownership of |observer|; it's the
  // responsibility of the caller to delete it. It can be safely deleted after
  // Close has been called on the returned PeerConnection, which ensures no
  // more observer callbacks will be invoked.
  virtual rtc::scoped_refptr<TgPeerConnectionInterface> CreatePeerConnection(
      const PeerConnectionInterface::RTCConfiguration& configuration,
      std::unique_ptr<cricket::PortAllocator> allocator,
      std::unique_ptr<rtc::RTCCertificateGeneratorInterface> cert_generator,
      PeerConnectionObserver* observer);

  // Returns the capabilities of an RTP sender of type |kind|.
  // If for some reason you pass in MEDIA_TYPE_DATA, returns an empty structure.
  // TODO(orphis): Make pure virtual when all subclasses implement it.
  virtual RtpCapabilities GetRtpSenderCapabilities(
      cricket::MediaType kind) const;

  // Returns the capabilities of an RTP receiver of type |kind|.
  // If for some reason you pass in MEDIA_TYPE_DATA, returns an empty structure.
  // TODO(orphis): Make pure virtual when all subclasses implement it.
  virtual RtpCapabilities GetRtpReceiverCapabilities(
      cricket::MediaType kind) const;

  virtual rtc::scoped_refptr<MediaStreamInterface> CreateLocalMediaStream(
      const std::string& stream_id) = 0;

  // Creates an AudioSourceInterface.
  // |options| decides audio processing settings.
  virtual rtc::scoped_refptr<AudioSourceInterface> CreateAudioSource(
      const cricket::AudioOptions& options) = 0;

  // Creates a new local VideoTrack. The same |source| can be used in several
  // tracks.
  virtual rtc::scoped_refptr<VideoTrackInterface> CreateVideoTrack(
      const std::string& label,
      VideoTrackSourceInterface* source) = 0;

  // Creates an new AudioTrack. At the moment |source| can be null.
  virtual rtc::scoped_refptr<AudioTrackInterface> CreateAudioTrack(
      const std::string& label,
      AudioSourceInterface* source) = 0;

  // Starts AEC dump using existing file. Takes ownership of |file| and passes
  // it on to VoiceEngine (via other objects) immediately, which will take
  // the ownerhip. If the operation fails, the file will be closed.
  // A maximum file size in bytes can be specified. When the file size limit is
  // reached, logging is stopped automatically. If max_size_bytes is set to a
  // value <= 0, no limit will be used, and logging will continue until the
  // StopAecDump function is called.
  // TODO(webrtc:6463): Delete default implementation when downstream mocks
  // classes are updated.
  virtual bool StartAecDump(FILE* file, int64_t max_size_bytes) {
    return false;
  }

  // Stops logging the AEC dump.
  virtual void StopAecDump() = 0;

 protected:
  // Dtor and ctor protected as objects shouldn't be created or deleted via
  // this interface.
  TgPeerConnectionFactoryInterface() {}
  ~TgPeerConnectionFactoryInterface() override = default;
};

class TgPeerConnectionFactory: public TgPeerConnectionFactoryInterface {
 public:
  void SetOptions(const PeerConnectionFactoryInterface::Options& options);

  rtc::scoped_refptr<TgPeerConnectionInterface> CreatePeerConnection(
      const PeerConnectionInterface::RTCConfiguration& configuration,
      std::unique_ptr<cricket::PortAllocator> allocator,
      std::unique_ptr<rtc::RTCCertificateGeneratorInterface> cert_generator,
      PeerConnectionObserver* observer);

  rtc::scoped_refptr<TgPeerConnectionInterface> CreatePeerConnection(
      const PeerConnectionInterface::RTCConfiguration& configuration,
      PeerConnectionDependencies dependencies);

  bool Initialize();

  RtpCapabilities GetRtpSenderCapabilities(
      cricket::MediaType kind) const;

  RtpCapabilities GetRtpReceiverCapabilities(
      cricket::MediaType kind) const;

  rtc::scoped_refptr<MediaStreamInterface> CreateLocalMediaStream(
      const std::string& stream_id);

  rtc::scoped_refptr<AudioSourceInterface> CreateAudioSource(
      const cricket::AudioOptions& options);

  rtc::scoped_refptr<VideoTrackInterface> CreateVideoTrack(
      const std::string& id,
      VideoTrackSourceInterface* video_source);

  rtc::scoped_refptr<AudioTrackInterface> CreateAudioTrack(
      const std::string& id,
      AudioSourceInterface* audio_source);

  bool StartAecDump(FILE* file, int64_t max_size_bytes);
  void StopAecDump();

  virtual std::unique_ptr<cricket::SctpTransportInternalFactory>
  CreateSctpTransportInternalFactory();

  virtual cricket::ChannelManager* channel_manager();

  rtc::Thread* signaling_thread() {
    // This method can be called on a different thread when the factory is
    // created in CreatePeerConnectionFactory().
    return signaling_thread_;
  }
  rtc::Thread* worker_thread() { return worker_thread_; }
  rtc::Thread* network_thread() { return network_thread_; }

  const PeerConnectionFactoryInterface::Options& options() const { return options_; }

  MediaTransportFactory* media_transport_factory() {
    return media_transport_factory_.get();
  }

 protected:
  // This structure allows simple management of all new dependencies being added
  // to the PeerConnectionFactory.
  explicit TgPeerConnectionFactory(
      PeerConnectionFactoryDependencies dependencies);

  // Hook to let testing framework insert actions between
  // "new RTCPeerConnection" and "pc.Initialize"
  virtual void ActionsBeforeInitializeForTesting(PeerConnectionInterface*) {}

  virtual ~TgPeerConnectionFactory();

 private:
  bool IsTrialEnabled(absl::string_view key) const;

  std::unique_ptr<RtcEventLog> CreateRtcEventLog_w();
  std::unique_ptr<Call> CreateCall_w(RtcEventLog* event_log);

  bool wraps_current_thread_;
  rtc::Thread* network_thread_;
  rtc::Thread* worker_thread_;
  rtc::Thread* signaling_thread_;
  std::unique_ptr<rtc::Thread> owned_network_thread_;
  std::unique_ptr<rtc::Thread> owned_worker_thread_;
  const std::unique_ptr<TaskQueueFactory> task_queue_factory_;
  PeerConnectionFactoryInterface::Options options_;
  std::unique_ptr<cricket::ChannelManager> channel_manager_;
  std::unique_ptr<rtc::BasicNetworkManager> default_network_manager_;
  std::unique_ptr<rtc::BasicPacketSocketFactory> default_socket_factory_;
  std::unique_ptr<cricket::MediaEngineInterface> media_engine_;
  std::unique_ptr<webrtc::CallFactoryInterface> call_factory_;
  std::unique_ptr<RtcEventLogFactoryInterface> event_log_factory_;
  std::unique_ptr<FecControllerFactoryInterface> fec_controller_factory_;
  std::unique_ptr<NetworkStatePredictorFactoryInterface>
      network_state_predictor_factory_;
  std::unique_ptr<NetworkControllerFactoryInterface>
      injected_network_controller_factory_;
  std::unique_ptr<MediaTransportFactory> media_transport_factory_;
  std::unique_ptr<NetEqFactory> neteq_factory_;
  const std::unique_ptr<WebRtcKeyValueConfig> trials_;
};

BEGIN_SIGNALING_PROXY_MAP(TgPeerConnectionFactory)
PROXY_SIGNALING_THREAD_DESTRUCTOR()
PROXY_METHOD1(void, SetOptions, const PeerConnectionFactory::Options&)
PROXY_METHOD4(rtc::scoped_refptr<TgPeerConnectionInterface>,
              CreatePeerConnection,
              const PeerConnectionInterface::RTCConfiguration&,
              std::unique_ptr<cricket::PortAllocator>,
              std::unique_ptr<rtc::RTCCertificateGeneratorInterface>,
              PeerConnectionObserver*)
PROXY_METHOD2(rtc::scoped_refptr<TgPeerConnectionInterface>,
              CreatePeerConnection,
              const PeerConnectionInterface::RTCConfiguration&,
              PeerConnectionDependencies)
PROXY_CONSTMETHOD1(webrtc::RtpCapabilities,
                   GetRtpSenderCapabilities,
                   cricket::MediaType)
PROXY_CONSTMETHOD1(webrtc::RtpCapabilities,
                   GetRtpReceiverCapabilities,
                   cricket::MediaType)
PROXY_METHOD1(rtc::scoped_refptr<MediaStreamInterface>,
              CreateLocalMediaStream,
              const std::string&)
PROXY_METHOD1(rtc::scoped_refptr<AudioSourceInterface>,
              CreateAudioSource,
              const cricket::AudioOptions&)
PROXY_METHOD2(rtc::scoped_refptr<VideoTrackInterface>,
              CreateVideoTrack,
              const std::string&,
              VideoTrackSourceInterface*)
PROXY_METHOD2(rtc::scoped_refptr<AudioTrackInterface>,
              CreateAudioTrack,
              const std::string&,
              AudioSourceInterface*)
PROXY_METHOD2(bool, StartAecDump, FILE*, int64_t)
PROXY_METHOD0(void, StopAecDump)
END_PROXY_MAP()

}  // namespace webrtc

#endif  // PC_PEER_CONNECTION_FACTORY_H_
