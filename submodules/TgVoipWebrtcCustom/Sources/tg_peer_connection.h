/*
 *  Copyright 2012 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#ifndef TG_PC_PEER_CONNECTION_H_
#define TG_PC_PEER_CONNECTION_H_

#include <map>
#include <memory>
#include <set>
#include <string>
#include <utility>
#include <vector>

#include "api/peer_connection_interface.h"
#include "api/transport/data_channel_transport_interface.h"
#include "api/turn_customizer.h"
#include "pc/data_channel_controller.h"
#include "pc/ice_server_parsing.h"
#include "pc/peer_connection_factory.h"
#include "pc/peer_connection_internal.h"
#include "pc/rtc_stats_collector.h"
#include "pc/rtp_sender.h"
#include "pc/rtp_transceiver.h"
#include "pc/sctp_transport.h"
#include "pc/stats_collector.h"
#include "pc/stream_collection.h"
#include "tg_webrtc_session_description_factory.h"
#include "rtc_base/experiments/field_trial_parser.h"
#include "rtc_base/operations_chain.h"
#include "rtc_base/race_checker.h"
#include "rtc_base/unique_id_generator.h"
#include "rtc_base/weak_ptr.h"

#include "tg_jsep_transport_controller.h"
#include "tg_peer_connection_factory.h"
#include "tg_webrtc_session_description_factory.h"
#include "tg_rtp_sender.h"

namespace webrtc {

class MediaStreamObserver;
class VideoRtpReceiver;
class RtcEventLog;

// TgPeerConnection is the implementation of the TgPeerConnection object as defined
// by the PeerConnectionInterface API surface.
// The class currently is solely responsible for the following:
// - Managing the session state machine (signaling state).
// - Creating and initializing lower-level objects, like PortAllocator and
//   BaseChannels.
// - Owning and managing the life cycle of the RtpSender/RtpReceiver and track
//   objects.
// - Tracking the current and pending local/remote session descriptions.
// The class currently is jointly responsible for the following:
// - Parsing and interpreting SDP.
// - Generating offers and answers based on the current state.
// - The ICE state machine.
// - Generating stats.

class RTC_EXPORT TgPeerConnectionInterface : public rtc::RefCountInterface {
 public:
  // Accessor methods to active local streams.
  // This method is not supported with kUnifiedPlan semantics. Please use
  // GetSenders() instead.
  virtual rtc::scoped_refptr<StreamCollectionInterface> local_streams() = 0;

  // Accessor methods to remote streams.
  // This method is not supported with kUnifiedPlan semantics. Please use
  // GetReceivers() instead.
  virtual rtc::scoped_refptr<StreamCollectionInterface> remote_streams() = 0;

  // Add a new MediaStream to be sent on this PeerConnection.
  // Note that a SessionDescription negotiation is needed before the
  // remote peer can receive the stream.
  //
  // This has been removed from the standard in favor of a track-based API. So,
  // this is equivalent to simply calling AddTrack for each track within the
  // stream, with the one difference that if "stream->AddTrack(...)" is called
  // later, the PeerConnection will automatically pick up the new track. Though
  // this functionality will be deprecated in the future.
  //
  // This method is not supported with kUnifiedPlan semantics. Please use
  // AddTrack instead.
  virtual bool AddStream(MediaStreamInterface* stream) = 0;

  // Remove a MediaStream from this PeerConnection.
  // Note that a SessionDescription negotiation is needed before the
  // remote peer is notified.
  //
  // This method is not supported with kUnifiedPlan semantics. Please use
  // RemoveTrack instead.
  virtual void RemoveStream(MediaStreamInterface* stream) = 0;

  // Add a new MediaStreamTrack to be sent on this PeerConnection, and return
  // the newly created RtpSender. The RtpSender will be associated with the
  // streams specified in the |stream_ids| list.
  //
  // Errors:
  // - INVALID_PARAMETER: |track| is null, has a kind other than audio or video,
  //       or a sender already exists for the track.
  // - INVALID_STATE: The PeerConnection is closed.
  virtual RTCErrorOr<rtc::scoped_refptr<RtpSenderInterface>> AddTrack(
      rtc::scoped_refptr<MediaStreamTrackInterface> track,
      const std::vector<std::string>& stream_ids) = 0;

  // Remove an RtpSender from this PeerConnection.
  // Returns true on success.
  // TODO(steveanton): Replace with signature that returns RTCError.
  virtual bool RemoveTrack(RtpSenderInterface* sender) = 0;

  // Plan B semantics: Removes the RtpSender from this PeerConnection.
  // Unified Plan semantics: Stop sending on the RtpSender and mark the
  // corresponding RtpTransceiver direction as no longer sending.
  //
  // Errors:
  // - INVALID_PARAMETER: |sender| is null or (Plan B only) the sender is not
  //       associated with this PeerConnection.
  // - INVALID_STATE: PeerConnection is closed.
  // TODO(bugs.webrtc.org/9534): Rename to RemoveTrack once the other signature
  // is removed.
  virtual RTCError RemoveTrackNew(
      rtc::scoped_refptr<RtpSenderInterface> sender);

  // AddTransceiver creates a new RtpTransceiver and adds it to the set of
  // transceivers. Adding a transceiver will cause future calls to CreateOffer
  // to add a media description for the corresponding transceiver.
  //
  // The initial value of |mid| in the returned transceiver is null. Setting a
  // new session description may change it to a non-null value.
  //
  // https://w3c.github.io/webrtc-pc/#dom-rtcpeerconnection-addtransceiver
  //
  // Optionally, an RtpTransceiverInit structure can be specified to configure
  // the transceiver from construction. If not specified, the transceiver will
  // default to having a direction of kSendRecv and not be part of any streams.
  //
  // These methods are only available when Unified Plan is enabled (see
  // RTCConfiguration).
  //
  // Common errors:
  // - INTERNAL_ERROR: The configuration does not have Unified Plan enabled.

  // Adds a transceiver with a sender set to transmit the given track. The kind
  // of the transceiver (and sender/receiver) will be derived from the kind of
  // the track.
  // Errors:
  // - INVALID_PARAMETER: |track| is null.
  virtual RTCErrorOr<rtc::scoped_refptr<RtpTransceiverInterface>>
  AddTransceiver(rtc::scoped_refptr<MediaStreamTrackInterface> track) = 0;
  virtual RTCErrorOr<rtc::scoped_refptr<RtpTransceiverInterface>>
  AddTransceiver(rtc::scoped_refptr<MediaStreamTrackInterface> track,
                 const RtpTransceiverInit& init) = 0;

  // Adds a transceiver with the given kind. Can either be MEDIA_TYPE_AUDIO or
  // MEDIA_TYPE_VIDEO.
  // Errors:
  // - INVALID_PARAMETER: |media_type| is not MEDIA_TYPE_AUDIO or
  //                      MEDIA_TYPE_VIDEO.
  virtual RTCErrorOr<rtc::scoped_refptr<RtpTransceiverInterface>>
  AddTransceiver(cricket::MediaType media_type) = 0;
  virtual RTCErrorOr<rtc::scoped_refptr<RtpTransceiverInterface>>
  AddTransceiver(cricket::MediaType media_type,
                 const RtpTransceiverInit& init) = 0;

  // Creates a sender without a track. Can be used for "early media"/"warmup"
  // use cases, where the application may want to negotiate video attributes
  // before a track is available to send.
  //
  // The standard way to do this would be through "addTransceiver", but we
  // don't support that API yet.
  //
  // |kind| must be "audio" or "video".
  //
  // |stream_id| is used to populate the msid attribute; if empty, one will
  // be generated automatically.
  //
  // This method is not supported with kUnifiedPlan semantics. Please use
  // AddTransceiver instead.
  virtual rtc::scoped_refptr<RtpSenderInterface> CreateSender(
      const std::string& kind,
      const std::string& stream_id) = 0;

  // If Plan B semantics are specified, gets all RtpSenders, created either
  // through AddStream, AddTrack, or CreateSender. All senders of a specific
  // media type share the same media description.
  //
  // If Unified Plan semantics are specified, gets the RtpSender for each
  // RtpTransceiver.
  virtual std::vector<rtc::scoped_refptr<RtpSenderInterface>> GetSenders()
      const = 0;

  // If Plan B semantics are specified, gets all RtpReceivers created when a
  // remote description is applied. All receivers of a specific media type share
  // the same media description. It is also possible to have a media description
  // with no associated RtpReceivers, if the directional attribute does not
  // indicate that the remote peer is sending any media.
  //
  // If Unified Plan semantics are specified, gets the RtpReceiver for each
  // RtpTransceiver.
  virtual std::vector<rtc::scoped_refptr<RtpReceiverInterface>> GetReceivers()
      const = 0;

  // Get all RtpTransceivers, created either through AddTransceiver, AddTrack or
  // by a remote description applied with SetRemoteDescription.
  //
  // Note: This method is only available when Unified Plan is enabled (see
  // RTCConfiguration).
  virtual std::vector<rtc::scoped_refptr<RtpTransceiverInterface>>
  GetTransceivers() const = 0;

  
  // Clear cached stats in the RTCStatsCollector.
  // Exposed for testing while waiting for automatic cache clear to work.
  // https://bugs.webrtc.org/8693
  virtual void ClearStatsCache() {}

  // Create a data channel with the provided config, or default config if none
  // is provided. Note that an offer/answer negotiation is still necessary
  // before the data channel can be used.
  //
  // Also, calling CreateDataChannel is the only way to get a data "m=" section
  // in SDP, so it should be done before CreateOffer is called, if the
  // application plans to use data channels.
  virtual rtc::scoped_refptr<DataChannelInterface> CreateDataChannel(
      const std::string& label,
      const DataChannelInit* config) = 0;

  // Returns the more recently applied description; "pending" if it exists, and
  // otherwise "current". See below.
  virtual const SessionDescriptionInterface* local_description() const = 0;
  virtual const SessionDescriptionInterface* remote_description() const = 0;

  // A "current" description the one currently negotiated from a complete
  // offer/answer exchange.
  virtual const SessionDescriptionInterface* current_local_description()
      const = 0;
  virtual const SessionDescriptionInterface* current_remote_description()
      const = 0;

  // A "pending" description is one that's part of an incomplete offer/answer
  // exchange (thus, either an offer or a pranswer). Once the offer/answer
  // exchange is finished, the "pending" description will become "current".
  virtual const SessionDescriptionInterface* pending_local_description()
      const = 0;
  virtual const SessionDescriptionInterface* pending_remote_description()
      const = 0;

  // Tells the PeerConnection that ICE should be restarted. This triggers a need
  // for negotiation and subsequent CreateOffer() calls will act as if
  // RTCOfferAnswerOptions::ice_restart is true.
  // https://w3c.github.io/webrtc-pc/#dom-rtcpeerconnection-restartice
  // TODO(hbos): Remove default implementation when downstream projects
  // implement this.
  virtual void RestartIce() = 0;

  // Create a new offer.
  // The CreateSessionDescriptionObserver callback will be called when done.
  virtual void CreateOffer(CreateSessionDescriptionObserver* observer,
                           const PeerConnectionInterface::RTCOfferAnswerOptions& options) = 0;

  // Create an answer to an offer.
  // The CreateSessionDescriptionObserver callback will be called when done.
  virtual void CreateAnswer(CreateSessionDescriptionObserver* observer,
                            const PeerConnectionInterface::RTCOfferAnswerOptions& options) = 0;

  // Sets the local session description.
  // The PeerConnection takes the ownership of |desc| even if it fails.
  // The |observer| callback will be called when done.
  // TODO(deadbeef): Change |desc| to be a unique_ptr, to make it clear
  // that this method always takes ownership of it.
  virtual void SetLocalDescription(SetSessionDescriptionObserver* observer,
                                   SessionDescriptionInterface* desc) = 0;
  // Implicitly creates an offer or answer (depending on the current signaling
  // state) and performs SetLocalDescription() with the newly generated session
  // description.
  // TODO(hbos): Make pure virtual when implemented by downstream projects.
  virtual void SetLocalDescription(SetSessionDescriptionObserver* observer) {}
  // Sets the remote session description.
  // The PeerConnection takes the ownership of |desc| even if it fails.
  // The |observer| callback will be called when done.
  // TODO(hbos): Remove when Chrome implements the new signature.
  virtual void SetRemoteDescription(SetSessionDescriptionObserver* observer,
                                    SessionDescriptionInterface* desc) {}
  virtual void SetRemoteDescription(
      std::unique_ptr<SessionDescriptionInterface> desc,
      rtc::scoped_refptr<SetRemoteDescriptionObserverInterface> observer) = 0;

  virtual PeerConnectionInterface::RTCConfiguration GetConfiguration() = 0;

  // Sets the PeerConnection's global configuration to |config|.
  //
  // The members of |config| that may be changed are |type|, |servers|,
  // |ice_candidate_pool_size| and |prune_turn_ports| (though the candidate
  // pool size can't be changed after the first call to SetLocalDescription).
  // Note that this means the BUNDLE and RTCP-multiplexing policies cannot be
  // changed with this method.
  //
  // Any changes to STUN/TURN servers or ICE candidate policy will affect the
  // next gathering phase, and cause the next call to createOffer to generate
  // new ICE credentials, as described in JSEP. This also occurs when
  // |prune_turn_ports| changes, for the same reasoning.
  //
  // If an error occurs, returns false and populates |error| if non-null:
  // - INVALID_MODIFICATION if |config| contains a modified parameter other
  //   than one of the parameters listed above.
  // - INVALID_RANGE if |ice_candidate_pool_size| is out of range.
  // - SYNTAX_ERROR if parsing an ICE server URL failed.
  // - INVALID_PARAMETER if a TURN server is missing |username| or |password|.
  // - INTERNAL_ERROR if an unexpected error occurred.
  //
  // TODO(nisse): Make this pure virtual once all Chrome subclasses of
  // PeerConnectionInterface implement it.
  virtual RTCError SetConfiguration(
      const PeerConnectionInterface::RTCConfiguration& config);

  // Provides a remote candidate to the ICE Agent.
  // A copy of the |candidate| will be created and added to the remote
  // description. So the caller of this method still has the ownership of the
  // |candidate|.
  // TODO(hbos): The spec mandates chaining this operation onto the operations
  // chain; deprecate and remove this version in favor of the callback-based
  // signature.
  virtual bool AddIceCandidate(const IceCandidateInterface* candidate) = 0;
  // TODO(hbos): Remove default implementation once implemented by downstream
  // projects.
  virtual void AddIceCandidate(std::unique_ptr<IceCandidateInterface> candidate,
                               std::function<void(RTCError)> callback) {}

  // Removes a group of remote candidates from the ICE agent. Needed mainly for
  // continual gathering, to avoid an ever-growing list of candidates as
  // networks come and go.
  virtual bool RemoveIceCandidates(
      const std::vector<cricket::Candidate>& candidates) = 0;

  // SetBitrate limits the bandwidth allocated for all RTP streams sent by
  // this PeerConnection. Other limitations might affect these limits and
  // are respected (for example "b=AS" in SDP).
  //
  // Setting |current_bitrate_bps| will reset the current bitrate estimate
  // to the provided value.
  virtual RTCError SetBitrate(const BitrateSettings& bitrate);

  // TODO(nisse): Deprecated - use version above. These two default
  // implementations require subclasses to implement one or the other
  // of the methods.
  virtual RTCError SetBitrate(const PeerConnectionInterface::BitrateParameters& bitrate_parameters);

  // Enable/disable playout of received audio streams. Enabled by default. Note
  // that even if playout is enabled, streams will only be played out if the
  // appropriate SDP is also applied. Setting |playout| to false will stop
  // playout of the underlying audio device but starts a task which will poll
  // for audio data every 10ms to ensure that audio processing happens and the
  // audio statistics are updated.
  // TODO(henrika): deprecate and remove this.
  virtual void SetAudioPlayout(bool playout) {}

  // Enable/disable recording of transmitted audio streams. Enabled by default.
  // Note that even if recording is enabled, streams will only be recorded if
  // the appropriate SDP is also applied.
  // TODO(henrika): deprecate and remove this.
  virtual void SetAudioRecording(bool recording) {}

  // Looks up the DtlsTransport associated with a MID value.
  // In the Javascript API, DtlsTransport is a property of a sender, but
  // because the PeerConnection owns the DtlsTransport in this implementation,
  // it is better to look them up on the PeerConnection.
  virtual rtc::scoped_refptr<DtlsTransportInterface> LookupDtlsTransportByMid(
      const std::string& mid) = 0;

  // Returns the SCTP transport, if any.
  virtual rtc::scoped_refptr<SctpTransportInterface> GetSctpTransport()
      const = 0;

  // Returns the current SignalingState.
  virtual PeerConnectionInterface::SignalingState signaling_state() = 0;

  // Returns an aggregate state of all ICE *and* DTLS transports.
  // This is left in place to avoid breaking native clients who expect our old,
  // nonstandard behavior.
  // TODO(jonasolsson): deprecate and remove this.
  virtual PeerConnectionInterface::IceConnectionState ice_connection_state() = 0;

  // Returns an aggregated state of all ICE transports.
  virtual PeerConnectionInterface::IceConnectionState standardized_ice_connection_state() = 0;

  // Returns an aggregated state of all ICE and DTLS transports.
  virtual PeerConnectionInterface::PeerConnectionState peer_connection_state() = 0;

  virtual PeerConnectionInterface::IceGatheringState ice_gathering_state() = 0;

  // Start RtcEventLog using an existing output-sink. Takes ownership of
  // |output| and passes it on to Call, which will take the ownership. If the
  // operation fails the output will be closed and deallocated. The event log
  // will send serialized events to the output object every |output_period_ms|.
  // Applications using the event log should generally make their own trade-off
  // regarding the output period. A long period is generally more efficient,
  // with potential drawbacks being more bursty thread usage, and more events
  // lost in case the application crashes. If the |output_period_ms| argument is
  // omitted, webrtc selects a default deemed to be workable in most cases.
  virtual bool StartRtcEventLog(std::unique_ptr<RtcEventLogOutput> output,
                                int64_t output_period_ms) = 0;
  virtual bool StartRtcEventLog(std::unique_ptr<RtcEventLogOutput> output) = 0;

  // Stops logging the RtcEventLog.
  virtual void StopRtcEventLog() = 0;

  // Terminates all media, closes the transports, and in general releases any
  // resources used by the PeerConnection. This is an irreversible operation.
  //
  // Note that after this method completes, the PeerConnection will no longer
  // use the PeerConnectionObserver interface passed in on construction, and
  // thus the observer object can be safely destroyed.
  virtual void Close() = 0;

 protected:
  // Dtor protected as objects shouldn't be deleted via this interface.
  ~TgPeerConnectionInterface() override = default;
};

class TgPeerConnection : public TgPeerConnectionInterface,
public TgJsepTransportController::Observer,
public RtpSenderBase::SetStreamsObserver,
public rtc::MessageHandler,
public sigslot::has_slots<> {
 public:
  // A bit in the usage pattern is registered when its defining event occurs at
  // least once.
  enum class UsageEvent : int {
    TURN_SERVER_ADDED = 0x01,
    STUN_SERVER_ADDED = 0x02,
    DATA_ADDED = 0x04,
    AUDIO_ADDED = 0x08,
    VIDEO_ADDED = 0x10,
    // |SetLocalDescription| returns successfully.
    SET_LOCAL_DESCRIPTION_SUCCEEDED = 0x20,
    // |SetRemoteDescription| returns successfully.
    SET_REMOTE_DESCRIPTION_SUCCEEDED = 0x40,
    // A local candidate (with type host, server-reflexive, or relay) is
    // collected.
    CANDIDATE_COLLECTED = 0x80,
    // A remote candidate is successfully added via |AddIceCandidate|.
    ADD_ICE_CANDIDATE_SUCCEEDED = 0x100,
    ICE_STATE_CONNECTED = 0x200,
    CLOSE_CALLED = 0x400,
    // A local candidate with private IP is collected.
    PRIVATE_CANDIDATE_COLLECTED = 0x800,
    // A remote candidate with private IP is added, either via AddiceCandidate
    // or from the remote description.
    REMOTE_PRIVATE_CANDIDATE_ADDED = 0x1000,
    // A local mDNS candidate is collected.
    MDNS_CANDIDATE_COLLECTED = 0x2000,
    // A remote mDNS candidate is added, either via AddIceCandidate or from the
    // remote description.
    REMOTE_MDNS_CANDIDATE_ADDED = 0x4000,
    // A local candidate with IPv6 address is collected.
    IPV6_CANDIDATE_COLLECTED = 0x8000,
    // A remote candidate with IPv6 address is added, either via AddIceCandidate
    // or from the remote description.
    REMOTE_IPV6_CANDIDATE_ADDED = 0x10000,
    // A remote candidate (with type host, server-reflexive, or relay) is
    // successfully added, either via AddIceCandidate or from the remote
    // description.
    REMOTE_CANDIDATE_ADDED = 0x20000,
    // An explicit host-host candidate pair is selected, i.e. both the local and
    // the remote candidates have the host type. This does not include candidate
    // pairs formed with equivalent prflx remote candidates, e.g. a host-prflx
    // pair where the prflx candidate has the same base as a host candidate of
    // the remote peer.
    DIRECT_CONNECTION_SELECTED = 0x40000,
    MAX_VALUE = 0x80000,
  };

  explicit TgPeerConnection(TgPeerConnectionFactory* factory,
                          std::unique_ptr<RtcEventLog> event_log,
                          std::unique_ptr<Call> call);

  bool Initialize(
      const PeerConnectionInterface::RTCConfiguration& configuration,
      PeerConnectionDependencies dependencies);

  rtc::scoped_refptr<StreamCollectionInterface> local_streams();
  rtc::scoped_refptr<StreamCollectionInterface> remote_streams();
  bool AddStream(MediaStreamInterface* local_stream);
  void RemoveStream(MediaStreamInterface* local_stream);

  RTCErrorOr<rtc::scoped_refptr<RtpSenderInterface>> AddTrack(
      rtc::scoped_refptr<MediaStreamTrackInterface> track,
      const std::vector<std::string>& stream_ids);
  bool RemoveTrack(RtpSenderInterface* sender);
  RTCError RemoveTrackNew(
      rtc::scoped_refptr<RtpSenderInterface> sender);

  RTCErrorOr<rtc::scoped_refptr<RtpTransceiverInterface>> AddTransceiver(
      rtc::scoped_refptr<MediaStreamTrackInterface> track);
  RTCErrorOr<rtc::scoped_refptr<RtpTransceiverInterface>> AddTransceiver(
      rtc::scoped_refptr<MediaStreamTrackInterface> track,
      const RtpTransceiverInit& init);
  RTCErrorOr<rtc::scoped_refptr<RtpTransceiverInterface>> AddTransceiver(
      cricket::MediaType media_type);
  RTCErrorOr<rtc::scoped_refptr<RtpTransceiverInterface>> AddTransceiver(
      cricket::MediaType media_type,
      const RtpTransceiverInit& init);

  // Gets the DTLS SSL certificate associated with the audio transport on the
  // remote side. This will become populated once the DTLS connection with the
  // peer has been completed, as indicated by the ICE connection state
  // transitioning to kIceConnectionCompleted.
  // Note that this will be removed once we implement RTCDtlsTransport which
  // has standardized method for getting this information.
  // See https://www.w3.org/TR/webrtc/#rtcdtlstransport-interface
  std::unique_ptr<rtc::SSLCertificate> GetRemoteAudioSSLCertificate();

  // Version of the above method that returns the full certificate chain.
  std::unique_ptr<rtc::SSLCertChain> GetRemoteAudioSSLCertChain();

  rtc::scoped_refptr<RtpSenderInterface> CreateSender(
      const std::string& kind,
      const std::string& stream_id);

  std::vector<rtc::scoped_refptr<RtpSenderInterface>> GetSenders()
      const;
  std::vector<rtc::scoped_refptr<RtpReceiverInterface>> GetReceivers()
      const;
  std::vector<rtc::scoped_refptr<RtpTransceiverInterface>> GetTransceivers()
      const;

  rtc::scoped_refptr<DataChannelInterface> CreateDataChannel(
      const std::string& label,
      const DataChannelInit* config);
  // WARNING: LEGACY. See peerconnectioninterface.h
  bool GetStats(StatsObserver* observer,
                webrtc::MediaStreamTrackInterface* track,
                PeerConnectionInterface::StatsOutputLevel level);
  // Spec-complaint GetStats(). See peerconnectioninterface.h
  void GetStats(RTCStatsCollectorCallback* callback);
  void GetStats(
      rtc::scoped_refptr<RtpSenderInterface> selector,
      rtc::scoped_refptr<RTCStatsCollectorCallback> callback);
  void GetStats(
      rtc::scoped_refptr<RtpReceiverInterface> selector,
      rtc::scoped_refptr<RTCStatsCollectorCallback> callback);
  void ClearStatsCache();

  PeerConnectionInterface::SignalingState signaling_state();

  PeerConnectionInterface::IceConnectionState ice_connection_state();
  PeerConnectionInterface::IceConnectionState standardized_ice_connection_state();
  PeerConnectionInterface::PeerConnectionState peer_connection_state();
  PeerConnectionInterface::IceGatheringState ice_gathering_state();

  const SessionDescriptionInterface* local_description() const;
  const SessionDescriptionInterface* remote_description() const;
  const SessionDescriptionInterface* current_local_description() const;
  const SessionDescriptionInterface* current_remote_description()
      const;
  const SessionDescriptionInterface* pending_local_description() const;
  const SessionDescriptionInterface* pending_remote_description()
      const;

  void RestartIce();

  // JSEP01
  void CreateOffer(CreateSessionDescriptionObserver* observer,
                   const PeerConnectionInterface::RTCOfferAnswerOptions& options);
  void CreateAnswer(CreateSessionDescriptionObserver* observer,
                    const PeerConnectionInterface::RTCOfferAnswerOptions& options);
  void SetLocalDescription(SetSessionDescriptionObserver* observer,
                           SessionDescriptionInterface* desc);
  void SetLocalDescription(SetSessionDescriptionObserver* observer);
  void SetRemoteDescription(SetSessionDescriptionObserver* observer,
                            SessionDescriptionInterface* desc);
  void SetRemoteDescription(
      std::unique_ptr<SessionDescriptionInterface> desc,
      rtc::scoped_refptr<SetRemoteDescriptionObserverInterface> observer);
  PeerConnectionInterface::RTCConfiguration GetConfiguration();
  RTCError SetConfiguration(
      const PeerConnectionInterface::RTCConfiguration& configuration);
  bool AddIceCandidate(const IceCandidateInterface* candidate);
  void AddIceCandidate(std::unique_ptr<IceCandidateInterface> candidate,
                       std::function<void(RTCError)> callback);
  bool RemoveIceCandidates(
      const std::vector<cricket::Candidate>& candidates);

  RTCError SetBitrate(const BitrateSettings& bitrate);

  void SetAudioPlayout(bool playout);
  void SetAudioRecording(bool recording);

  rtc::scoped_refptr<DtlsTransportInterface> LookupDtlsTransportByMid(
      const std::string& mid);
  rtc::scoped_refptr<DtlsTransport> LookupDtlsTransportByMidInternal(
      const std::string& mid);

  rtc::scoped_refptr<SctpTransportInterface> GetSctpTransport() const;

  bool StartRtcEventLog(std::unique_ptr<RtcEventLogOutput> output,
                        int64_t output_period_ms);
  bool StartRtcEventLog(std::unique_ptr<RtcEventLogOutput> output);
  void StopRtcEventLog();

  void Close();

  // PeerConnectionInternal implementation.
  rtc::Thread* network_thread() const {
    return factory_->network_thread();
  }
  rtc::Thread* worker_thread() const { return factory_->worker_thread(); }
  rtc::Thread* signaling_thread() const {
    return factory_->signaling_thread();
  }

  std::string session_id() const {
    RTC_DCHECK_RUN_ON(signaling_thread());
    return session_id_;
  }

  bool initial_offerer() const {
    RTC_DCHECK_RUN_ON(signaling_thread());
    return transport_controller_ && transport_controller_->initial_offerer();
  }

  std::vector<
      rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>>
  GetTransceiversInternal() const {
    RTC_DCHECK_RUN_ON(signaling_thread());
    return transceivers_;
  }

  sigslot::signal1<DataChannel*>& SignalDataChannelCreated() {
      RTC_DCHECK_RUN_ON(signaling_thread());
      return SignalDataChannelCreated_;
  }

  cricket::RtpDataChannel* rtp_data_channel() const {
    return nullptr;
  }

  std::vector<rtc::scoped_refptr<DataChannel>> sctp_data_channels()
      const {
    RTC_DCHECK_RUN_ON(signaling_thread());
    return std::vector<rtc::scoped_refptr<DataChannel>>();
  }

  absl::optional<std::string> sctp_content_name() const {
    RTC_DCHECK_RUN_ON(signaling_thread());
    return sctp_mid_;
  }

  absl::optional<std::string> sctp_transport_name() const;

  cricket::CandidateStatsList GetPooledCandidateStats() const;
  std::map<std::string, std::string> GetTransportNamesByMid() const;
  std::map<std::string, cricket::TransportStats> GetTransportStatsByNames(
      const std::set<std::string>& transport_names);
  Call::Stats GetCallStats();

  bool GetLocalCertificate(
      const std::string& transport_name,
      rtc::scoped_refptr<rtc::RTCCertificate>* certificate);
  std::unique_ptr<rtc::SSLCertChain> GetRemoteSSLCertChain(
      const std::string& transport_name);
  bool IceRestartPending(const std::string& content_name) const;
  bool NeedsIceRestart(const std::string& content_name) const;
  bool GetSslRole(const std::string& content_name, rtc::SSLRole* role);

  // Functions needed by DataChannelController
  void NoteDataAddedEvent() { NoteUsageEvent(UsageEvent::DATA_ADDED); }
  // Returns the observer. Will crash on CHECK if the observer is removed.
  PeerConnectionObserver* Observer() const;
  bool IsClosed() const {
    RTC_DCHECK_RUN_ON(signaling_thread());
    return signaling_state_ == PeerConnectionInterface::kClosed;
  }
  // Get current SSL role used by SCTP's underlying transport.
  bool GetSctpSslRole(rtc::SSLRole* role);
  // Handler for the "channel closed" signal
  void OnSctpDataChannelClosed(DataChannel* channel);

  // Functions made public for testing.
  void ReturnHistogramVeryQuicklyForTesting() {
    RTC_DCHECK_RUN_ON(signaling_thread());
    return_histogram_very_quickly_ = true;
  }
  void RequestUsagePatternReportForTesting();

 protected:
  ~TgPeerConnection() override;

 private:
  class ImplicitCreateSessionDescriptionObserver;
  friend class ImplicitCreateSessionDescriptionObserver;
  class SetRemoteDescriptionObserverAdapter;
  friend class SetRemoteDescriptionObserverAdapter;
                           
  sigslot::signal1<DataChannel*> SignalDataChannelCreated_ RTC_GUARDED_BY(signaling_thread());

  // Represents the [[LocalIceCredentialsToReplace]] internal slot in the spec.
  // It makes the next CreateOffer() produce new ICE credentials even if
  // RTCOfferAnswerOptions::ice_restart is false.
  // https://w3c.github.io/webrtc-pc/#dfn-localufragstoreplace
  // TODO(hbos): When TgJsepTransportController/TgJsepTransport supports rollback,
  // move this type of logic to TgJsepTransportController/TgJsepTransport.
  class LocalIceCredentialsToReplace;

  struct RtpSenderInfo {
    RtpSenderInfo() : first_ssrc(0) {}
    RtpSenderInfo(const std::string& stream_id,
                  const std::string sender_id,
                  uint32_t ssrc)
        : stream_id(stream_id), sender_id(sender_id), first_ssrc(ssrc) {}
    bool operator==(const RtpSenderInfo& other) {
      return this->stream_id == other.stream_id &&
             this->sender_id == other.sender_id &&
             this->first_ssrc == other.first_ssrc;
    }
    std::string stream_id;
    std::string sender_id;
    // An RtpSender can have many SSRCs. The first one is used as a sort of ID
    // for communicating with the lower layers.
    uint32_t first_ssrc;
  };

  // Field-trial based configuration for datagram transport.
  struct DatagramTransportConfig {
    explicit DatagramTransportConfig(const std::string& field_trial)
        : enabled("enabled", true), default_value("default_value", false) {
      ParseFieldTrial({&enabled, &default_value}, field_trial);
    }

    // Whether datagram transport support is enabled at all.  Defaults to true,
    // allowing datagram transport to be used if (a) the application provides a
    // factory for it and (b) the configuration specifies its use.  This flag
    // provides a kill-switch to force-disable datagram transport across all
    // applications, without code changes.
    FieldTrialFlag enabled;

    // Whether the datagram transport is enabled or disabled by default.
    // Defaults to false, meaning that applications must configure use of
    // datagram transport through RTCConfiguration.  If set to true,
    // applications will use the datagram transport by default (but may still
    // explicitly configure themselves not to use it through RTCConfiguration).
    FieldTrialFlag default_value;
  };

  // Field-trial based configuration for datagram transport data channels.
  struct DatagramTransportDataChannelConfig {
    explicit DatagramTransportDataChannelConfig(const std::string& field_trial)
        : enabled("enabled", true),
          default_value("default_value", false),
          receive_only("receive_only", false) {
      ParseFieldTrial({&enabled, &default_value, &receive_only}, field_trial);
    }

    // Whether datagram transport data channel support is enabled at all.
    // Defaults to true, allowing datagram transport to be used if (a) the
    // application provides a factory for it and (b) the configuration specifies
    // its use.  This flag provides a kill-switch to force-disable datagram
    // transport across all applications, without code changes.
    FieldTrialFlag enabled;

    // Whether the datagram transport data channels are enabled or disabled by
    // default. Defaults to false, meaning that applications must configure use
    // of datagram transport through RTCConfiguration.  If set to true,
    // applications will use the datagram transport by default (but may still
    // explicitly configure themselves not to use it through RTCConfiguration).
    FieldTrialFlag default_value;

    // Whether the datagram transport is enabled in receive-only mode.  If true,
    // and if the datagram transport is enabled, it will only be used when
    // receiving incoming calls, not when placing outgoing calls.
    FieldTrialFlag receive_only;
  };

  // Captures partial state to be used for rollback. Applicable only in
  // Unified Plan.
  class TransceiverStableState {
   public:
    TransceiverStableState() {}
    void set_newly_created();
    void SetMSectionIfUnset(absl::optional<std::string> mid,
                            absl::optional<size_t> mline_index);
    void SetRemoteStreamIdsIfUnset(const std::vector<std::string>& ids);
    absl::optional<std::string> mid() const { return mid_; }
    absl::optional<size_t> mline_index() const { return mline_index_; }
    absl::optional<std::vector<std::string>> remote_stream_ids() const {
      return remote_stream_ids_;
    }
    bool has_m_section() const { return has_m_section_; }
    bool newly_created() const { return newly_created_; }

   private:
    absl::optional<std::string> mid_;
    absl::optional<size_t> mline_index_;
    absl::optional<std::vector<std::string>> remote_stream_ids_;
    // Indicates that mid value from stable state has been captured and
    // that rollback has to restore the transceiver. Also protects against
    // subsequent overwrites.
    bool has_m_section_ = false;
    // Indicates that the transceiver was created as part of applying a
    // description to track potential need for removing transceiver during
    // rollback.
    bool newly_created_ = false;
  };

  // Implements MessageHandler.
  void OnMessage(rtc::Message* msg) override;

  // Plan B helpers for getting the voice/video media channels for the single
  // audio/video transceiver, if it exists.
  cricket::VoiceMediaChannel* voice_media_channel() const
      RTC_RUN_ON(signaling_thread());
  cricket::VideoMediaChannel* video_media_channel() const
      RTC_RUN_ON(signaling_thread());

  std::vector<rtc::scoped_refptr<RtpSenderProxyWithInternal<RtpSenderInternal>>>
  GetSendersInternal() const RTC_RUN_ON(signaling_thread());
  std::vector<
      rtc::scoped_refptr<RtpReceiverProxyWithInternal<RtpReceiverInternal>>>
  GetReceiversInternal() const RTC_RUN_ON(signaling_thread());

  rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
  GetAudioTransceiver() const RTC_RUN_ON(signaling_thread());
  rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
  GetVideoTransceiver() const RTC_RUN_ON(signaling_thread());

  rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
  GetFirstAudioTransceiver() const RTC_RUN_ON(signaling_thread());

  // Implementation of the offer/answer exchange operations. These are chained
  // onto the |operations_chain_| when the public CreateOffer(), CreateAnswer(),
  // SetLocalDescription() and SetRemoteDescription() methods are invoked.
  void DoCreateOffer(
      const PeerConnectionInterface::RTCOfferAnswerOptions& options,
      rtc::scoped_refptr<CreateSessionDescriptionObserver> observer);
  void DoCreateAnswer(
      const PeerConnectionInterface::RTCOfferAnswerOptions& options,
      rtc::scoped_refptr<CreateSessionDescriptionObserver> observer);
  void DoSetLocalDescription(
      std::unique_ptr<SessionDescriptionInterface> desc,
      rtc::scoped_refptr<SetSessionDescriptionObserver> observer);
  void DoSetRemoteDescription(
      std::unique_ptr<SessionDescriptionInterface> desc,
      rtc::scoped_refptr<SetRemoteDescriptionObserverInterface> observer);

  void CreateAudioReceiver(MediaStreamInterface* stream,
                           const RtpSenderInfo& remote_sender_info)
      RTC_RUN_ON(signaling_thread());

  void CreateVideoReceiver(MediaStreamInterface* stream,
                           const RtpSenderInfo& remote_sender_info)
      RTC_RUN_ON(signaling_thread());
  rtc::scoped_refptr<RtpReceiverInterface> RemoveAndStopReceiver(
      const RtpSenderInfo& remote_sender_info) RTC_RUN_ON(signaling_thread());

  // May be called either by AddStream/RemoveStream, or when a track is
  // added/removed from a stream previously added via AddStream.
  void AddAudioTrack(AudioTrackInterface* track, MediaStreamInterface* stream)
      RTC_RUN_ON(signaling_thread());
  void RemoveAudioTrack(AudioTrackInterface* track,
                        MediaStreamInterface* stream)
      RTC_RUN_ON(signaling_thread());
  void AddVideoTrack(VideoTrackInterface* track, MediaStreamInterface* stream)
      RTC_RUN_ON(signaling_thread());
  void RemoveVideoTrack(VideoTrackInterface* track,
                        MediaStreamInterface* stream)
      RTC_RUN_ON(signaling_thread());

  // AddTrack implementation when Unified Plan is specified.
  RTCErrorOr<rtc::scoped_refptr<RtpSenderInterface>> AddTrackUnifiedPlan(
      rtc::scoped_refptr<MediaStreamTrackInterface> track,
      const std::vector<std::string>& stream_ids)
      RTC_RUN_ON(signaling_thread());
  // AddTrack implementation when Plan B is specified.
  RTCErrorOr<rtc::scoped_refptr<RtpSenderInterface>> AddTrackPlanB(
      rtc::scoped_refptr<MediaStreamTrackInterface> track,
      const std::vector<std::string>& stream_ids)
      RTC_RUN_ON(signaling_thread());

  // Returns the first RtpTransceiver suitable for a newly added track, if such
  // transceiver is available.
  rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
  FindFirstTransceiverForAddedTrack(
      rtc::scoped_refptr<MediaStreamTrackInterface> track)
      RTC_RUN_ON(signaling_thread());

  rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
  FindTransceiverBySender(rtc::scoped_refptr<RtpSenderInterface> sender)
      RTC_RUN_ON(signaling_thread());

  // Internal implementation for AddTransceiver family of methods. If
  // |fire_callback| is set, fires OnRenegotiationNeeded callback if successful.
  RTCErrorOr<rtc::scoped_refptr<RtpTransceiverInterface>> AddTransceiver(
      cricket::MediaType media_type,
      rtc::scoped_refptr<MediaStreamTrackInterface> track,
      const RtpTransceiverInit& init,
      bool fire_callback = true) RTC_RUN_ON(signaling_thread());

  rtc::scoped_refptr<RtpSenderProxyWithInternal<RtpSenderInternal>>
  CreateSender(cricket::MediaType media_type,
               const std::string& id,
               rtc::scoped_refptr<MediaStreamTrackInterface> track,
               const std::vector<std::string>& stream_ids,
               const std::vector<RtpEncodingParameters>& send_encodings);

  rtc::scoped_refptr<RtpReceiverProxyWithInternal<RtpReceiverInternal>>
  CreateReceiver(cricket::MediaType media_type, const std::string& receiver_id);

  // Create a new RtpTransceiver of the given type and add it to the list of
  // transceivers.
  rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
  CreateAndAddTransceiver(
      rtc::scoped_refptr<RtpSenderProxyWithInternal<RtpSenderInternal>> sender,
      rtc::scoped_refptr<RtpReceiverProxyWithInternal<RtpReceiverInternal>>
          receiver) RTC_RUN_ON(signaling_thread());

  void SetIceConnectionState(PeerConnectionInterface::IceConnectionState new_state)
      RTC_RUN_ON(signaling_thread());
  void SetStandardizedIceConnectionState(
      PeerConnectionInterface::IceConnectionState new_state)
      RTC_RUN_ON(signaling_thread());
  void SetConnectionState(
      PeerConnectionInterface::PeerConnectionState new_state)
      RTC_RUN_ON(signaling_thread());

  // Called any time the IceGatheringState changes.
  void OnIceGatheringChange(PeerConnectionInterface::IceGatheringState new_state)
      RTC_RUN_ON(signaling_thread());
  // New ICE candidate has been gathered.
  void OnIceCandidate(std::unique_ptr<IceCandidateInterface> candidate)
      RTC_RUN_ON(signaling_thread());
  // Gathering of an ICE candidate failed.
  void OnIceCandidateError(const std::string& address,
                           int port,
                           const std::string& url,
                           int error_code,
                           const std::string& error_text)
      RTC_RUN_ON(signaling_thread());
  // Some local ICE candidates have been removed.
  void OnIceCandidatesRemoved(const std::vector<cricket::Candidate>& candidates)
      RTC_RUN_ON(signaling_thread());

  void OnSelectedCandidatePairChanged(
      const cricket::CandidatePairChangeEvent& event)
      RTC_RUN_ON(signaling_thread());

  // Update the state, signaling if necessary.
  void ChangeSignalingState(PeerConnectionInterface::SignalingState signaling_state)
      RTC_RUN_ON(signaling_thread());

  // Signals from MediaStreamObserver.
  void OnAudioTrackAdded(AudioTrackInterface* track,
                         MediaStreamInterface* stream)
      RTC_RUN_ON(signaling_thread());
  void OnAudioTrackRemoved(AudioTrackInterface* track,
                           MediaStreamInterface* stream)
      RTC_RUN_ON(signaling_thread());
  void OnVideoTrackAdded(VideoTrackInterface* track,
                         MediaStreamInterface* stream)
      RTC_RUN_ON(signaling_thread());
  void OnVideoTrackRemoved(VideoTrackInterface* track,
                           MediaStreamInterface* stream)
      RTC_RUN_ON(signaling_thread());

  void PostSetSessionDescriptionSuccess(
      SetSessionDescriptionObserver* observer);
  void PostSetSessionDescriptionFailure(SetSessionDescriptionObserver* observer,
                                        RTCError&& error);
  void PostCreateSessionDescriptionFailure(
      CreateSessionDescriptionObserver* observer,
      RTCError error);

  // Synchronous implementations of SetLocalDescription/SetRemoteDescription
  // that return an RTCError instead of invoking a callback.
  RTCError ApplyLocalDescription(
      std::unique_ptr<SessionDescriptionInterface> desc);
  RTCError ApplyRemoteDescription(
      std::unique_ptr<SessionDescriptionInterface> desc);

  // Updates the local RtpTransceivers according to the JSEP rules. Called as
  // part of setting the local/remote description.
  RTCError UpdateTransceiversAndDataChannels(
      cricket::ContentSource source,
      const SessionDescriptionInterface& new_session,
      const SessionDescriptionInterface* old_local_description,
      const SessionDescriptionInterface* old_remote_description)
      RTC_RUN_ON(signaling_thread());

  // Either creates or destroys the transceiver's BaseChannel according to the
  // given media section.
  RTCError UpdateTransceiverChannel(
      rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
          transceiver,
      const cricket::ContentInfo& content,
      const cricket::ContentGroup* bundle_group) RTC_RUN_ON(signaling_thread());

  // Either creates or destroys the local data channel according to the given
  // media section.
  RTCError UpdateDataChannel(cricket::ContentSource source,
                             const cricket::ContentInfo& content,
                             const cricket::ContentGroup* bundle_group)
      RTC_RUN_ON(signaling_thread());

  // Associate the given transceiver according to the JSEP rules.
  RTCErrorOr<
      rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>>
  AssociateTransceiver(cricket::ContentSource source,
                       SdpType type,
                       size_t mline_index,
                       const cricket::ContentInfo& content,
                       const cricket::ContentInfo* old_local_content,
                       const cricket::ContentInfo* old_remote_content)
      RTC_RUN_ON(signaling_thread());

  // Returns the RtpTransceiver, if found, that is associated to the given MID.
  rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
  GetAssociatedTransceiver(const std::string& mid) const
      RTC_RUN_ON(signaling_thread());

  // Returns the RtpTransceiver, if found, that was assigned to the given mline
  // index in CreateOffer.
  rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
  GetTransceiverByMLineIndex(size_t mline_index) const
      RTC_RUN_ON(signaling_thread());

  // Returns an RtpTransciever, if available, that can be used to receive the
  // given media type according to JSEP rules.
  rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
  FindAvailableTransceiverToReceive(cricket::MediaType media_type) const
      RTC_RUN_ON(signaling_thread());

  // Returns the media section in the given session description that is
  // associated with the RtpTransceiver. Returns null if none found or this
  // RtpTransceiver is not associated. Logic varies depending on the
  // SdpSemantics specified in the configuration.
  const cricket::ContentInfo* FindMediaSectionForTransceiver(
      rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
          transceiver,
      const SessionDescriptionInterface* sdesc) const
      RTC_RUN_ON(signaling_thread());

  // Runs the algorithm **set the associated remote streams** specified in
  // https://w3c.github.io/webrtc-pc/#set-associated-remote-streams.
  void SetAssociatedRemoteStreams(
      rtc::scoped_refptr<RtpReceiverInternal> receiver,
      const std::vector<std::string>& stream_ids,
      std::vector<rtc::scoped_refptr<MediaStreamInterface>>* added_streams,
      std::vector<rtc::scoped_refptr<MediaStreamInterface>>* removed_streams)
      RTC_RUN_ON(signaling_thread());

  // Runs the algorithm **process the removal of a remote track** specified in
  // the WebRTC specification.
  // This method will update the following lists:
  // |remove_list| is the list of transceivers for which the receiving track is
  //     being removed.
  // |removed_streams| is the list of streams which no longer have a receiving
  //     track so should be removed.
  // https://w3c.github.io/webrtc-pc/#process-remote-track-removal
  void ProcessRemovalOfRemoteTrack(
      rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
          transceiver,
      std::vector<rtc::scoped_refptr<RtpTransceiverInterface>>* remove_list,
      std::vector<rtc::scoped_refptr<MediaStreamInterface>>* removed_streams)
      RTC_RUN_ON(signaling_thread());

  void RemoveRemoteStreamsIfEmpty(
      const std::vector<rtc::scoped_refptr<MediaStreamInterface>>&
          remote_streams,
      std::vector<rtc::scoped_refptr<MediaStreamInterface>>* removed_streams)
      RTC_RUN_ON(signaling_thread());

  void OnNegotiationNeeded();

  // Returns a MediaSessionOptions struct with options decided by |options|,
  // the local MediaStreams and DataChannels.
  void GetOptionsForOffer(const PeerConnectionInterface::RTCOfferAnswerOptions&
                              offer_answer_options,
                          cricket::MediaSessionOptions* session_options)
      RTC_RUN_ON(signaling_thread());
  void GetOptionsForPlanBOffer(
      const PeerConnectionInterface::RTCOfferAnswerOptions&
          offer_answer_options,
      cricket::MediaSessionOptions* session_options)
      RTC_RUN_ON(signaling_thread());
  void GetOptionsForUnifiedPlanOffer(
      const PeerConnectionInterface::RTCOfferAnswerOptions&
          offer_answer_options,
      cricket::MediaSessionOptions* session_options)
      RTC_RUN_ON(signaling_thread());

  RTCError HandleLegacyOfferOptions(const PeerConnectionInterface::RTCOfferAnswerOptions& options)
      RTC_RUN_ON(signaling_thread());
  void RemoveRecvDirectionFromReceivingTransceiversOfType(
      cricket::MediaType media_type) RTC_RUN_ON(signaling_thread());
  void AddUpToOneReceivingTransceiverOfType(cricket::MediaType media_type);
  std::vector<
      rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>>
  GetReceivingTransceiversOfType(cricket::MediaType media_type)
      RTC_RUN_ON(signaling_thread());

  // Returns a MediaSessionOptions struct with options decided by
  // |constraints|, the local MediaStreams and DataChannels.
  void GetOptionsForAnswer(const PeerConnectionInterface::RTCOfferAnswerOptions& offer_answer_options,
                           cricket::MediaSessionOptions* session_options)
      RTC_RUN_ON(signaling_thread());
  void GetOptionsForPlanBAnswer(
      const PeerConnectionInterface::RTCOfferAnswerOptions&
          offer_answer_options,
      cricket::MediaSessionOptions* session_options)
      RTC_RUN_ON(signaling_thread());
  void GetOptionsForUnifiedPlanAnswer(
      const PeerConnectionInterface::RTCOfferAnswerOptions&
          offer_answer_options,
      cricket::MediaSessionOptions* session_options)
      RTC_RUN_ON(signaling_thread());

  // Generates MediaDescriptionOptions for the |session_opts| based on existing
  // local description or remote description.
  void GenerateMediaDescriptionOptions(
      const SessionDescriptionInterface* session_desc,
      RtpTransceiverDirection audio_direction,
      RtpTransceiverDirection video_direction,
      absl::optional<size_t>* audio_index,
      absl::optional<size_t>* video_index,
      absl::optional<size_t>* data_index,
      cricket::MediaSessionOptions* session_options)
      RTC_RUN_ON(signaling_thread());

  // Remove all local and remote senders of type |media_type|.
  // Called when a media type is rejected (m-line set to port 0).
  void RemoveSenders(cricket::MediaType media_type)
      RTC_RUN_ON(signaling_thread());

  // Makes sure a MediaStreamTrack is created for each StreamParam in |streams|,
  // and existing MediaStreamTracks are removed if there is no corresponding
  // StreamParam. If |default_track_needed| is true, a default MediaStreamTrack
  // is created if it doesn't exist; if false, it's removed if it exists.
  // |media_type| is the type of the |streams| and can be either audio or video.
  // If a new MediaStream is created it is added to |new_streams|.
  void UpdateRemoteSendersList(
      const std::vector<cricket::StreamParams>& streams,
      bool default_track_needed,
      cricket::MediaType media_type,
      StreamCollection* new_streams) RTC_RUN_ON(signaling_thread());

  // Triggered when a remote sender has been seen for the first time in a remote
  // session description. It creates a remote MediaStreamTrackInterface
  // implementation and triggers CreateAudioReceiver or CreateVideoReceiver.
  void OnRemoteSenderAdded(const RtpSenderInfo& sender_info,
                           cricket::MediaType media_type)
      RTC_RUN_ON(signaling_thread());

  // Triggered when a remote sender has been removed from a remote session
  // description. It removes the remote sender with id |sender_id| from a remote
  // MediaStream and triggers DestroyAudioReceiver or DestroyVideoReceiver.
  void OnRemoteSenderRemoved(const RtpSenderInfo& sender_info,
                             cricket::MediaType media_type)
      RTC_RUN_ON(signaling_thread());

  // Finds remote MediaStreams without any tracks and removes them from
  // |remote_streams_| and notifies the observer that the MediaStreams no longer
  // exist.
  void UpdateEndedRemoteMediaStreams() RTC_RUN_ON(signaling_thread());

  // Loops through the vector of |streams| and finds added and removed
  // StreamParams since last time this method was called.
  // For each new or removed StreamParam, OnLocalSenderSeen or
  // OnLocalSenderRemoved is invoked.
  void UpdateLocalSenders(const std::vector<cricket::StreamParams>& streams,
                          cricket::MediaType media_type)
      RTC_RUN_ON(signaling_thread());

  // Triggered when a local sender has been seen for the first time in a local
  // session description.
  // This method triggers CreateAudioSender or CreateVideoSender if the rtp
  // streams in the local SessionDescription can be mapped to a MediaStreamTrack
  // in a MediaStream in |local_streams_|
  void OnLocalSenderAdded(const RtpSenderInfo& sender_info,
                          cricket::MediaType media_type)
      RTC_RUN_ON(signaling_thread());

  // Triggered when a local sender has been removed from a local session
  // description.
  // This method triggers DestroyAudioSender or DestroyVideoSender if a stream
  // has been removed from the local SessionDescription and the stream can be
  // mapped to a MediaStreamTrack in a MediaStream in |local_streams_|.
  void OnLocalSenderRemoved(const RtpSenderInfo& sender_info,
                            cricket::MediaType media_type)
      RTC_RUN_ON(signaling_thread());

  // Returns true if the TgPeerConnection is configured to use Unified Plan
  // semantics for creating offers/answers and setting local/remote
  // descriptions. If this is true the RtpTransceiver API will also be available
  // to the user. If this is false, Plan B semantics are assumed.
  // TODO(bugs.webrtc.org/8530): Flip the default to be Unified Plan once
  // sufficient time has passed.
  bool IsUnifiedPlan() const RTC_RUN_ON(signaling_thread()) {
    return configuration_.sdp_semantics == SdpSemantics::kUnifiedPlan;
  }

  // The offer/answer machinery assumes the media section MID is present and
  // unique. To support legacy end points that do not supply a=mid lines, this
  // method will modify the session description to add MIDs generated according
  // to the SDP semantics.
  void FillInMissingRemoteMids(cricket::SessionDescription* remote_description)
      RTC_RUN_ON(signaling_thread());

  // Is there an RtpSender of the given type?
  bool HasRtpSender(cricket::MediaType type) const
      RTC_RUN_ON(signaling_thread());

  // Return the RtpSender with the given track attached.
  rtc::scoped_refptr<RtpSenderProxyWithInternal<RtpSenderInternal>>
  FindSenderForTrack(MediaStreamTrackInterface* track) const
      RTC_RUN_ON(signaling_thread());

  // Return the RtpSender with the given id, or null if none exists.
  rtc::scoped_refptr<RtpSenderProxyWithInternal<RtpSenderInternal>>
  FindSenderById(const std::string& sender_id) const
      RTC_RUN_ON(signaling_thread());

  // Return the RtpReceiver with the given id, or null if none exists.
  rtc::scoped_refptr<RtpReceiverProxyWithInternal<RtpReceiverInternal>>
  FindReceiverById(const std::string& receiver_id) const
      RTC_RUN_ON(signaling_thread());

  std::vector<RtpSenderInfo>* GetRemoteSenderInfos(
      cricket::MediaType media_type);
  std::vector<RtpSenderInfo>* GetLocalSenderInfos(
      cricket::MediaType media_type);
  const RtpSenderInfo* FindSenderInfo(const std::vector<RtpSenderInfo>& infos,
                                      const std::string& stream_id,
                                      const std::string sender_id) const;

  // Returns the specified SCTP DataChannel in sctp_data_channels_,
  // or nullptr if not found.
  DataChannel* FindDataChannelBySid(int sid) const
      RTC_RUN_ON(signaling_thread());

  // Called when first configuring the port allocator.
  struct InitializePortAllocatorResult {
    bool enable_ipv6;
  };
  InitializePortAllocatorResult InitializePortAllocator_n(
      const cricket::ServerAddresses& stun_servers,
      const std::vector<cricket::RelayServerConfig>& turn_servers,
      const PeerConnectionInterface::RTCConfiguration& configuration);
  // Called when SetConfiguration is called to apply the supported subset
  // of the configuration on the network thread.
  bool ReconfigurePortAllocator_n(
      const cricket::ServerAddresses& stun_servers,
      const std::vector<cricket::RelayServerConfig>& turn_servers,
      PeerConnectionInterface::IceTransportsType type,
      int candidate_pool_size,
      PortPrunePolicy turn_port_prune_policy,
      webrtc::TurnCustomizer* turn_customizer,
      absl::optional<int> stun_candidate_keepalive_interval,
      bool have_local_description);

  // Starts output of an RTC event log to the given output object.
  // This function should only be called from the worker thread.
  bool StartRtcEventLog_w(std::unique_ptr<RtcEventLogOutput> output,
                          int64_t output_period_ms);

  // Stops recording an RTC event log.
  // This function should only be called from the worker thread.
  void StopRtcEventLog_w();

  // Ensures the configuration doesn't have any parameters with invalid values,
  // or values that conflict with other parameters.
  //
  // Returns RTCError::OK() if there are no issues.
  RTCError ValidateConfiguration(const PeerConnectionInterface::RTCConfiguration& config) const;

  cricket::ChannelManager* channel_manager() const;

  enum class SessionError {
    kNone,       // No error.
    kContent,    // Error in BaseChannel SetLocalContent/SetRemoteContent.
    kTransport,  // Error from the underlying transport.
  };

  // Returns the last error in the session. See the enum above for details.
  SessionError session_error() const RTC_RUN_ON(signaling_thread()) {
    return session_error_;
  }
  const std::string& session_error_desc() const { return session_error_desc_; }

  cricket::ChannelInterface* GetChannel(const std::string& content_name);

  cricket::IceConfig ParseIceConfig(
      const PeerConnectionInterface::RTCConfiguration& config) const;

  // Called when an RTCCertificate is generated or retrieved by
  // WebRTCSessionDescriptionFactory. Should happen before setLocalDescription.
  void OnCertificateReady(
      const rtc::scoped_refptr<rtc::RTCCertificate>& certificate);
  void OnDtlsSrtpSetupFailure(cricket::BaseChannel*, bool rtcp);

  // Non-const versions of local_description()/remote_description(), for use
  // internally.
  SessionDescriptionInterface* mutable_local_description()
      RTC_RUN_ON(signaling_thread()) {
    return pending_local_description_ ? pending_local_description_.get()
                                      : current_local_description_.get();
  }
  SessionDescriptionInterface* mutable_remote_description()
      RTC_RUN_ON(signaling_thread()) {
    return pending_remote_description_ ? pending_remote_description_.get()
                                       : current_remote_description_.get();
  }

  // Updates the error state, signaling if necessary.
  void SetSessionError(SessionError error, const std::string& error_desc);

  RTCError UpdateSessionState(SdpType type,
                              cricket::ContentSource source,
                              const cricket::SessionDescription* description);
  // Push the media parts of the local or remote session description
  // down to all of the channels.
  RTCError PushdownMediaDescription(SdpType type, cricket::ContentSource source)
      RTC_RUN_ON(signaling_thread());

  RTCError PushdownTransportDescription(cricket::ContentSource source,
                                        SdpType type);

  // Returns true and the TransportInfo of the given |content_name|
  // from |description|. Returns false if it's not available.
  static bool GetTransportDescription(
      const cricket::SessionDescription* description,
      const std::string& content_name,
      cricket::TransportDescription* info);

  // Enables media channels to allow sending of media.
  // This enables media to flow on all configured audio/video channels and the
  // RtpDataChannel.
  void EnableSending() RTC_RUN_ON(signaling_thread());

  // Destroys all BaseChannels and destroys the SCTP data channel, if present.
  void DestroyAllChannels() RTC_RUN_ON(signaling_thread());

  // Returns the media index for a local ice candidate given the content name.
  // Returns false if the local session description does not have a media
  // content called  |content_name|.
  bool GetLocalCandidateMediaIndex(const std::string& content_name,
                                   int* sdp_mline_index)
      RTC_RUN_ON(signaling_thread());
  // Uses all remote candidates in |remote_desc| in this session.
  bool UseCandidatesInSessionDescription(
      const SessionDescriptionInterface* remote_desc)
      RTC_RUN_ON(signaling_thread());
  // Uses |candidate| in this session.
  bool UseCandidate(const IceCandidateInterface* candidate)
      RTC_RUN_ON(signaling_thread());
  RTCErrorOr<const cricket::ContentInfo*> FindContentInfo(
      const SessionDescriptionInterface* description,
      const IceCandidateInterface* candidate) RTC_RUN_ON(signaling_thread());
  // Deletes the corresponding channel of contents that don't exist in |desc|.
  // |desc| can be null. This means that all channels are deleted.
  void RemoveUnusedChannels(const cricket::SessionDescription* desc)
      RTC_RUN_ON(signaling_thread());

  // Allocates media channels based on the |desc|. If |desc| doesn't have
  // the BUNDLE option, this method will disable BUNDLE in PortAllocator.
  // This method will also delete any existing media channels before creating.
  RTCError CreateChannels(const cricket::SessionDescription& desc)
      RTC_RUN_ON(signaling_thread());

  // If the BUNDLE policy is max-bundle, then we know for sure that all
  // transports will be bundled from the start. This method returns the BUNDLE
  // group if that's the case, or null if BUNDLE will be negotiated later. An
  // error is returned if max-bundle is specified but the session description
  // does not have a BUNDLE group.
  RTCErrorOr<const cricket::ContentGroup*> GetEarlyBundleGroup(
      const cricket::SessionDescription& desc) const
      RTC_RUN_ON(signaling_thread());

  // Helper methods to create media channels.
  cricket::VoiceChannel* CreateVoiceChannel(const std::string& mid)
      RTC_RUN_ON(signaling_thread());
  cricket::VideoChannel* CreateVideoChannel(const std::string& mid)
      RTC_RUN_ON(signaling_thread());
  bool CreateDataChannel(const std::string& mid) RTC_RUN_ON(signaling_thread());

  bool SetupDataChannelTransport_n(const std::string& mid)
      RTC_RUN_ON(network_thread());
  void TeardownDataChannelTransport_n() RTC_RUN_ON(network_thread());

  bool ValidateBundleSettings(const cricket::SessionDescription* desc);
  bool HasRtcpMuxEnabled(const cricket::ContentInfo* content);
  // Below methods are helper methods which verifies SDP.
  RTCError ValidateSessionDescription(const SessionDescriptionInterface* sdesc,
                                      cricket::ContentSource source)
      RTC_RUN_ON(signaling_thread());

  // Check if a call to SetLocalDescription is acceptable with a session
  // description of the given type.
  bool ExpectSetLocalDescription(SdpType type);
  // Check if a call to SetRemoteDescription is acceptable with a session
  // description of the given type.
  bool ExpectSetRemoteDescription(SdpType type);
  // Verifies a=setup attribute as per RFC 5763.
  bool ValidateDtlsSetupAttribute(const cricket::SessionDescription* desc,
                                  SdpType type);

  // Returns true if we are ready to push down the remote candidate.
  // |remote_desc| is the new remote description, or NULL if the current remote
  // description should be used. Output |valid| is true if the candidate media
  // index is valid.
  bool ReadyToUseRemoteCandidate(const IceCandidateInterface* candidate,
                                 const SessionDescriptionInterface* remote_desc,
                                 bool* valid) RTC_RUN_ON(signaling_thread());

  // Returns true if SRTP (either using DTLS-SRTP or SDES) is required by
  // this session.
  bool SrtpRequired() const RTC_RUN_ON(signaling_thread());

  // TgJsepTransportController signal handlers.
  void OnTransportControllerConnectionState(cricket::IceConnectionState state)
      RTC_RUN_ON(signaling_thread());
  void OnTransportControllerGatheringState(cricket::IceGatheringState state)
      RTC_RUN_ON(signaling_thread());
  void OnTransportControllerCandidatesGathered(
      const std::string& transport_name,
      const std::vector<cricket::Candidate>& candidates)
      RTC_RUN_ON(signaling_thread());
  void OnTransportControllerCandidateError(
      const cricket::IceCandidateErrorEvent& event)
      RTC_RUN_ON(signaling_thread());
  void OnTransportControllerCandidatesRemoved(
      const std::vector<cricket::Candidate>& candidates)
      RTC_RUN_ON(signaling_thread());
  void OnTransportControllerCandidateChanged(
      const cricket::CandidatePairChangeEvent& event)
      RTC_RUN_ON(signaling_thread());
  void OnTransportControllerDtlsHandshakeError(rtc::SSLHandshakeError error);

  const char* SessionErrorToString(SessionError error) const;
  std::string GetSessionErrorMsg() RTC_RUN_ON(signaling_thread());

  // Report the UMA metric SdpFormatReceived for the given remote offer.
  void ReportSdpFormatReceived(const SessionDescriptionInterface& remote_offer);

  // Report inferred negotiated SDP semantics from a local/remote answer to the
  // UMA observer.
  void ReportNegotiatedSdpSemantics(const SessionDescriptionInterface& answer);

  // Invoked when TransportController connection completion is signaled.
  // Reports stats for all transports in use.
  void ReportTransportStats() RTC_RUN_ON(signaling_thread());

  // Gather the usage of IPv4/IPv6 as best connection.
  void ReportBestConnectionState(const cricket::TransportStats& stats);

  void ReportNegotiatedCiphers(const cricket::TransportStats& stats,
                               const std::set<cricket::MediaType>& media_types)
      RTC_RUN_ON(signaling_thread());
  void ReportIceCandidateCollected(const cricket::Candidate& candidate)
      RTC_RUN_ON(signaling_thread());
  void ReportRemoteIceCandidateAdded(const cricket::Candidate& candidate)
      RTC_RUN_ON(signaling_thread());

  void NoteUsageEvent(UsageEvent event);
  void ReportUsagePattern() const RTC_RUN_ON(signaling_thread());

  void OnSentPacket_w(const rtc::SentPacket& sent_packet);

  const std::string GetTransportName(const std::string& content_name)
      RTC_RUN_ON(signaling_thread());

  // Functions for dealing with transports.
  // Note that cricket code uses the term "channel" for what other code
  // refers to as "transport".

  // Destroys and clears the BaseChannel associated with the given transceiver,
  // if such channel is set.
  void DestroyTransceiverChannel(
      rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>
          transceiver);

  // Destroys the given ChannelInterface.
  // The channel cannot be accessed after this method is called.
  void DestroyChannelInterface(cricket::ChannelInterface* channel);

  // TgJsepTransportController::Observer override.
  //
  // Called by |transport_controller_| when processing transport information
  // from a session description, and the mapping from m= sections to transports
  // changed (as a result of BUNDLE negotiation, or m= sections being
  // rejected).
  bool OnTransportChanged(
      const std::string& mid,
      RtpTransportInternal* rtp_transport,
      rtc::scoped_refptr<DtlsTransport> dtls_transport,
      DataChannelTransportInterface* data_channel_transport) override;

  // RtpSenderBase::SetStreamsObserver override.
  void OnSetStreams() override;

  // Returns the CryptoOptions for this TgPeerConnection. This will always
  // return the RTCConfiguration.crypto_options if set and will only default
  // back to the PeerConnectionFactory settings if nothing was set.
  CryptoOptions GetCryptoOptions() RTC_RUN_ON(signaling_thread());

  // Returns rtp transport, result can not be nullptr.
  RtpTransportInternal* GetRtpTransport(const std::string& mid)
      RTC_RUN_ON(signaling_thread()) {
    auto rtp_transport = transport_controller_->GetRtpTransport(mid);
    RTC_DCHECK(rtp_transport);
    return rtp_transport;
  }

  void UpdateNegotiationNeeded();
  bool CheckIfNegotiationIsNeeded();

  // | sdp_type | is the type of the SDP that caused the rollback.
  RTCError Rollback(SdpType sdp_type);

  // Storing the factory as a scoped reference pointer ensures that the memory
  // in the PeerConnectionFactoryImpl remains available as long as the
  // TgPeerConnection is running. It is passed to TgPeerConnection as a raw pointer.
  // However, since the reference counting is done in the
  // PeerConnectionFactoryInterface all instances created using the raw pointer
  // will refer to the same reference count.
  const rtc::scoped_refptr<TgPeerConnectionFactory> factory_;
  PeerConnectionObserver* observer_ RTC_GUARDED_BY(signaling_thread()) =
      nullptr;

  // The EventLog needs to outlive |call_| (and any other object that uses it).
  std::unique_ptr<RtcEventLog> event_log_ RTC_GUARDED_BY(worker_thread());

  // Points to the same thing as `event_log_`. Since it's const, we may read the
  // pointer (but not touch the object) from any thread.
  RtcEventLog* const event_log_ptr_ RTC_PT_GUARDED_BY(worker_thread());

  // The operations chain is used by the offer/answer exchange methods to ensure
  // they are executed in the right order. For example, if
  // SetRemoteDescription() is invoked while CreateOffer() is still pending, the
  // SRD operation will not start until CreateOffer() has completed. See
  // https://w3c.github.io/webrtc-pc/#dfn-operations-chain.
  rtc::scoped_refptr<rtc::OperationsChain> operations_chain_
      RTC_GUARDED_BY(signaling_thread());

  PeerConnectionInterface::SignalingState signaling_state_ RTC_GUARDED_BY(signaling_thread()) = PeerConnectionInterface::kStable;
  PeerConnectionInterface::IceConnectionState ice_connection_state_ RTC_GUARDED_BY(signaling_thread()) =
      PeerConnectionInterface::kIceConnectionNew;
  PeerConnectionInterface::IceConnectionState standardized_ice_connection_state_
      RTC_GUARDED_BY(signaling_thread()) = PeerConnectionInterface::kIceConnectionNew;
  PeerConnectionInterface::PeerConnectionState connection_state_
      RTC_GUARDED_BY(signaling_thread()) = PeerConnectionInterface::PeerConnectionState::kNew;

  PeerConnectionInterface::IceGatheringState ice_gathering_state_ RTC_GUARDED_BY(signaling_thread()) =
      PeerConnectionInterface::kIceGatheringNew;
  PeerConnectionInterface::RTCConfiguration configuration_
      RTC_GUARDED_BY(signaling_thread());

  // Field-trial based configuration for datagram transport.
  const DatagramTransportConfig datagram_transport_config_;

  // Field-trial based configuration for datagram transport data channels.
  const DatagramTransportDataChannelConfig
      datagram_transport_data_channel_config_;

  // Final, resolved value for whether datagram transport is in use.
  bool use_datagram_transport_ RTC_GUARDED_BY(signaling_thread()) = false;

  // Equivalent of |use_datagram_transport_|, but for its use with data
  // channels.
  bool use_datagram_transport_for_data_channels_
      RTC_GUARDED_BY(signaling_thread()) = false;

  // Resolved value of whether to use data channels only for incoming calls.
  bool use_datagram_transport_for_data_channels_receive_only_
      RTC_GUARDED_BY(signaling_thread()) = false;

  // TODO(zstein): |async_resolver_factory_| can currently be nullptr if it
  // is not injected. It should be required once chromium supplies it.
  std::unique_ptr<AsyncResolverFactory> async_resolver_factory_
      RTC_GUARDED_BY(signaling_thread());
  std::unique_ptr<cricket::PortAllocator>
      port_allocator_;  // TODO(bugs.webrtc.org/9987): Accessed on both
                        // signaling and network thread.
  std::unique_ptr<webrtc::IceTransportFactory>
      ice_transport_factory_;  // TODO(bugs.webrtc.org/9987): Accessed on the
                               // signaling thread but the underlying raw
                               // pointer is given to
                               // |jsep_transport_controller_| and used on the
                               // network thread.
  std::unique_ptr<rtc::SSLCertificateVerifier>
      tls_cert_verifier_;  // TODO(bugs.webrtc.org/9987): Accessed on both
                           // signaling and network thread.

  // One TgPeerConnection has only one RTCP CNAME.
  // https://tools.ietf.org/html/draft-ietf-rtcweb-rtp-usage-26#section-4.9
  const std::string rtcp_cname_;

  // Streams added via AddStream.
  const rtc::scoped_refptr<StreamCollection> local_streams_
      RTC_GUARDED_BY(signaling_thread());
  // Streams created as a result of SetRemoteDescription.
  const rtc::scoped_refptr<StreamCollection> remote_streams_
      RTC_GUARDED_BY(signaling_thread());

  std::vector<std::unique_ptr<MediaStreamObserver>> stream_observers_
      RTC_GUARDED_BY(signaling_thread());

  // These lists store sender info seen in local/remote descriptions.
  std::vector<RtpSenderInfo> remote_audio_sender_infos_
      RTC_GUARDED_BY(signaling_thread());
  std::vector<RtpSenderInfo> remote_video_sender_infos_
      RTC_GUARDED_BY(signaling_thread());
  std::vector<RtpSenderInfo> local_audio_sender_infos_
      RTC_GUARDED_BY(signaling_thread());
  std::vector<RtpSenderInfo> local_video_sender_infos_
      RTC_GUARDED_BY(signaling_thread());

  bool remote_peer_supports_msid_ RTC_GUARDED_BY(signaling_thread()) = false;

  // The unique_ptr belongs to the worker thread, but the Call object manages
  // its own thread safety.
  std::unique_ptr<Call> call_ RTC_GUARDED_BY(worker_thread());

  rtc::AsyncInvoker rtcp_invoker_ RTC_GUARDED_BY(network_thread());

  // Points to the same thing as `call_`. Since it's const, we may read the
  // pointer from any thread.
  Call* const call_ptr_;

  // Holds changes made to transceivers during applying descriptors for
  // potential rollback. Gets cleared once signaling state goes to stable.
  std::map<rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>,
           TransceiverStableState>
      transceiver_stable_states_by_transceivers_;
  // Holds remote stream ids for transceivers from stable state.
  std::map<rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>,
           std::vector<std::string>>
      remote_stream_ids_by_transceivers_;
  std::vector<
      rtc::scoped_refptr<RtpTransceiverProxyWithInternal<RtpTransceiver>>>
      transceivers_;  // TODO(bugs.webrtc.org/9987): Accessed on both signaling
                      // and network thread.

  // In Unified Plan, if we encounter remote SDP that does not contain an a=msid
  // line we create and use a stream with a random ID for our receivers. This is
  // to support legacy endpoints that do not support the a=msid attribute (as
  // opposed to streamless tracks with "a=msid:-").
  rtc::scoped_refptr<MediaStreamInterface> missing_msid_default_stream_
      RTC_GUARDED_BY(signaling_thread());
  // MIDs will be generated using this generator which will keep track of
  // all the MIDs that have been seen over the life of the TgPeerConnection.
  rtc::UniqueStringGenerator mid_generator_ RTC_GUARDED_BY(signaling_thread());

  SessionError session_error_ RTC_GUARDED_BY(signaling_thread()) =
      SessionError::kNone;
  std::string session_error_desc_ RTC_GUARDED_BY(signaling_thread());

  std::string session_id_ RTC_GUARDED_BY(signaling_thread());

  std::unique_ptr<TgJsepTransportController>
      transport_controller_;  // TODO(bugs.webrtc.org/9987): Accessed on both
                              // signaling and network thread.
  std::unique_ptr<cricket::SctpTransportInternalFactory>
      sctp_factory_;  // TODO(bugs.webrtc.org/9987): Accessed on both
                      // signaling and network thread.

  // |sctp_mid_| is the content name (MID) in SDP.
  // Note: this is used as the data channel MID by both SCTP and data channel
  // transports.  It is set when either transport is initialized and unset when
  // both transports are deleted.
  absl::optional<std::string>
      sctp_mid_;  // TODO(bugs.webrtc.org/9987): Accessed on both signaling
                  // and network thread.

  // Whether this peer is the caller. Set when the local description is applied.
  absl::optional<bool> is_caller_ RTC_GUARDED_BY(signaling_thread());



  std::unique_ptr<SessionDescriptionInterface> current_local_description_
      RTC_GUARDED_BY(signaling_thread());
  std::unique_ptr<SessionDescriptionInterface> pending_local_description_
      RTC_GUARDED_BY(signaling_thread());
  std::unique_ptr<SessionDescriptionInterface> current_remote_description_
      RTC_GUARDED_BY(signaling_thread());
  std::unique_ptr<SessionDescriptionInterface> pending_remote_description_
      RTC_GUARDED_BY(signaling_thread());
  bool dtls_enabled_ RTC_GUARDED_BY(signaling_thread()) = false;

  // List of content names for which the remote side triggered an ICE restart.
  std::set<std::string> pending_ice_restarts_
      RTC_GUARDED_BY(signaling_thread());

  std::unique_ptr<TgWebRtcSessionDescriptionFactory> webrtc_session_desc_factory_
      RTC_GUARDED_BY(signaling_thread());

  // Member variables for caching global options.
  cricket::AudioOptions audio_options_ RTC_GUARDED_BY(signaling_thread());
  cricket::VideoOptions video_options_ RTC_GUARDED_BY(signaling_thread());

  int usage_event_accumulator_ RTC_GUARDED_BY(signaling_thread()) = 0;
  bool return_histogram_very_quickly_ RTC_GUARDED_BY(signaling_thread()) =
      false;

  // This object should be used to generate any SSRC that is not explicitly
  // specified by the user (or by the remote party).
  // The generator is not used directly, instead it is passed on to the
  // channel manager and the session description factory.
  rtc::UniqueRandomIdGenerator ssrc_generator_
      RTC_GUARDED_BY(signaling_thread());

  // A video bitrate allocator factory.
  // This can injected using the PeerConnectionDependencies,
  // or else the CreateBuiltinVideoBitrateAllocatorFactory() will be called.
  // Note that one can still choose to override this in a MediaEngine
  // if one wants too.
  std::unique_ptr<webrtc::VideoBitrateAllocatorFactory>
      video_bitrate_allocator_factory_;

  std::unique_ptr<LocalIceCredentialsToReplace>
      local_ice_credentials_to_replace_ RTC_GUARDED_BY(signaling_thread());
  bool is_negotiation_needed_ RTC_GUARDED_BY(signaling_thread()) = false;

  rtc::WeakPtrFactory<TgPeerConnection> weak_ptr_factory_
      RTC_GUARDED_BY(signaling_thread());
};

}  // namespace webrtc

#endif  // PC_PEER_CONNECTION_H_
