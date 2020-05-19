#import "RtcConnection.h"

#import <UIKit/UIKit.h>

#include <memory>
#include "api/scoped_refptr.h"
#include "rtc_base/thread.h"
#include "api/peer_connection_interface.h"
#include "api/task_queue/default_task_queue_factory.h"
#include "media/engine/webrtc_media_engine.h"
#include "sdk/objc/native/api/audio_device_module.h"
#include "api/audio_codecs/builtin_audio_encoder_factory.h"
#include "api/audio_codecs/builtin_audio_decoder_factory.h"
#include "sdk/objc/components/video_codec/RTCVideoEncoderFactoryH264.h"
#include "sdk/objc/components/video_codec/RTCVideoDecoderFactoryH264.h"
#include "sdk/objc/native/api/video_encoder_factory.h"
#include "sdk/objc/native/api/video_decoder_factory.h"
#include "api/rtc_event_log/rtc_event_log_factory.h"
#include "sdk/media_constraints.h"
#include "api/peer_connection_interface.h"
#include "sdk/objc/native/src/objc_video_track_source.h"
#include "api/video_track_source_proxy.h"
#include "sdk/objc/api/RTCVideoRendererAdapter.h"
#include "sdk/objc/native/api/video_frame.h"

#include "VideoCameraCapturer.h"

#import "VideoMetalView.h"

class PeerConnectionObserverImpl : public webrtc::PeerConnectionObserver {
private:
    void (^_discoveredIceCandidate)(NSString *, int, NSString *);
    void (^_connectionStateChanged)(bool);
    
public:
    PeerConnectionObserverImpl(void (^discoveredIceCandidate)(NSString *, int, NSString *), void (^connectionStateChanged)(bool)) {
        _discoveredIceCandidate = [discoveredIceCandidate copy];
        _connectionStateChanged = [connectionStateChanged copy];
    }
    
    virtual ~PeerConnectionObserverImpl() {
        _discoveredIceCandidate = nil;
        _connectionStateChanged = nil;
    }
    
    virtual void OnSignalingChange(webrtc::PeerConnectionInterface::SignalingState new_state) {
        bool isConnected = false;
        if (new_state == webrtc::PeerConnectionInterface::SignalingState::kStable) {
            isConnected = true;
        }
        _connectionStateChanged(isConnected);
    }
    
    virtual void OnAddStream(rtc::scoped_refptr<webrtc::MediaStreamInterface> stream) {
    }
    
    virtual void OnRemoveStream(rtc::scoped_refptr<webrtc::MediaStreamInterface> stream) {
    }
    
    virtual void OnDataChannel(
                               rtc::scoped_refptr<webrtc::DataChannelInterface> data_channel) {
    }
    
    virtual void OnRenegotiationNeeded() {
    }
    
    virtual void OnIceConnectionChange(webrtc::PeerConnectionInterface::IceConnectionState new_state) {
    }
    
    virtual void OnStandardizedIceConnectionChange(webrtc::PeerConnectionInterface::IceConnectionState new_state) {
    }
    
    virtual void OnConnectionChange(webrtc::PeerConnectionInterface::PeerConnectionState new_state) {
    }
    
    virtual void OnIceGatheringChange(webrtc::PeerConnectionInterface::IceGatheringState new_state) {
    }
    
    virtual void OnIceCandidate(const webrtc::IceCandidateInterface* candidate) {
        std::string sdp;
        candidate->ToString(&sdp);
        NSString *sdpString = [NSString stringWithUTF8String:sdp.c_str()];
        NSString *sdpMidString = [NSString stringWithUTF8String:candidate->sdp_mid().c_str()];
        _discoveredIceCandidate(sdpString, candidate->sdp_mline_index(), sdpMidString);
    }
    
    virtual void OnIceCandidateError(const std::string& host_candidate, const std::string& url, int error_code, const std::string& error_text) {
    }
    
    virtual void OnIceCandidateError(const std::string& address,
                                     int port,
                                     const std::string& url,
                                     int error_code,
                                     const std::string& error_text) {
    }
    
    virtual void OnIceCandidatesRemoved(const std::vector<cricket::Candidate>& candidates) {
    }
    
    virtual void OnIceConnectionReceivingChange(bool receiving) {
    }
    
    virtual void OnIceSelectedCandidatePairChanged(const cricket::CandidatePairChangeEvent& event) {
    }
    
    virtual void OnAddTrack(rtc::scoped_refptr<webrtc::RtpReceiverInterface> receiver, const std::vector<rtc::scoped_refptr<webrtc::MediaStreamInterface>>& streams) {
    }
    
    virtual void OnTrack(rtc::scoped_refptr<webrtc::RtpTransceiverInterface> transceiver) {
    }
    
    virtual void OnRemoveTrack(rtc::scoped_refptr<webrtc::RtpReceiverInterface> receiver) {
    }
    
    virtual void OnInterestingUsage(int usage_pattern) {
    }
};

class CreateSessionDescriptionObserverImpl : public webrtc::CreateSessionDescriptionObserver {
private:
    void (^_completion)(NSString *, NSString *);
    
public:
    CreateSessionDescriptionObserverImpl(void (^completion)(NSString *, NSString *)) {
        _completion = [completion copy];
    }
    
    ~CreateSessionDescriptionObserverImpl() override {
        _completion = nil;
    }
    
    virtual void OnSuccess(webrtc::SessionDescriptionInterface* desc) override {
        if (desc) {
            NSString *typeString = [NSString stringWithUTF8String:desc->type().c_str()];
            std::string sdp;
            desc->ToString(&sdp);
            NSString *serializedString = [NSString stringWithUTF8String:sdp.c_str()];
            if (_completion && typeString && serializedString) {
                _completion(serializedString, typeString);
            }
        }
        _completion = nil;
    }
    
    virtual void OnFailure(webrtc::RTCError error) override {
        _completion = nil;
    }
};

class SetSessionDescriptionObserverImpl : public webrtc::SetSessionDescriptionObserver {
private:
    void (^_completion)();
    
public:
    SetSessionDescriptionObserverImpl(void (^completion)()) {
        _completion = [completion copy];
    }
    
    ~SetSessionDescriptionObserverImpl() override {
        _completion = nil;
    }

    virtual void OnSuccess() override {
        if (_completion) {
            _completion();
        }
        _completion = nil;
    }
    
    virtual void OnFailure(webrtc::RTCError error) override {
        _completion = nil;
    }
};

@interface RtcConnection () {
    void (^_discoveredIceCandidate)(NSString *, int, NSString *);
    void (^_connectionStateChanged)(bool);
    
    std::unique_ptr<rtc::Thread> _networkThread;
    std::unique_ptr<rtc::Thread> _workerThread;
    std::unique_ptr<rtc::Thread> _signalingThread;
    rtc::scoped_refptr<webrtc::PeerConnectionFactoryInterface> _nativeFactory;
    
    std::unique_ptr<PeerConnectionObserverImpl> _observer;
    rtc::scoped_refptr<webrtc::PeerConnectionInterface> _peerConnection;
    std::unique_ptr<webrtc::MediaConstraints> _nativeConstraints;
    bool _hasStartedRtcEventLog;
    
    rtc::scoped_refptr<webrtc::AudioTrackInterface> _localAudioTrack;
    
    rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> _nativeVideoSource;
    rtc::scoped_refptr<webrtc::VideoTrackInterface> _localVideoTrack;
    VideoCameraCapturer *_videoCapturer;
    
    rtc::scoped_refptr<webrtc::VideoTrackInterface> _remoteVideoTrack;
}

@end

@implementation RtcConnection

- (instancetype)initWithDiscoveredIceCandidate:(void (^)(NSString *, int, NSString *))discoveredIceCandidate connectionStateChanged:(void (^)(bool))connectionStateChanged {
    self = [super init];
    if (self != nil) {
        _discoveredIceCandidate = [discoveredIceCandidate copy];
        _connectionStateChanged = [connectionStateChanged copy];
        
        _networkThread = rtc::Thread::CreateWithSocketServer();
        _networkThread->SetName("network_thread", _networkThread.get());
        BOOL result = _networkThread->Start();
        assert(result);

        _workerThread = rtc::Thread::Create();
        _workerThread->SetName("worker_thread", _workerThread.get());
        result = _workerThread->Start();
        assert(result);

        _signalingThread = rtc::Thread::Create();
        _signalingThread->SetName("signaling_thread", _signalingThread.get());
        result = _signalingThread->Start();
        assert(result);
        
        webrtc::PeerConnectionFactoryDependencies dependencies;
        dependencies.network_thread = _networkThread.get();
        dependencies.worker_thread = _workerThread.get();
        dependencies.signaling_thread = _signalingThread.get();
        dependencies.task_queue_factory = webrtc::CreateDefaultTaskQueueFactory();
        cricket::MediaEngineDependencies media_deps;
        media_deps.adm = webrtc::CreateAudioDeviceModule();
        media_deps.task_queue_factory = dependencies.task_queue_factory.get();
        media_deps.audio_encoder_factory = webrtc::CreateBuiltinAudioEncoderFactory();
        media_deps.audio_decoder_factory = webrtc::CreateBuiltinAudioDecoderFactory();
        media_deps.video_encoder_factory = webrtc::ObjCToNativeVideoEncoderFactory([[RTCVideoEncoderFactoryH264 alloc] init]);
        media_deps.video_decoder_factory = webrtc::ObjCToNativeVideoDecoderFactory([[RTCVideoDecoderFactoryH264 alloc] init]);
        media_deps.audio_processing = webrtc::AudioProcessingBuilder().Create();
        dependencies.media_engine = cricket::CreateMediaEngine(std::move(media_deps));
        dependencies.call_factory = webrtc::CreateCallFactory();
        dependencies.event_log_factory =
            std::make_unique<webrtc::RtcEventLogFactory>(dependencies.task_queue_factory.get());
        dependencies.network_controller_factory = nil;
        dependencies.media_transport_factory = nil;
        _nativeFactory = webrtc::CreateModularPeerConnectionFactory(std::move(dependencies));
        
        webrtc::PeerConnectionInterface::RTCConfiguration config;
        config.sdp_semantics = webrtc::SdpSemantics::kUnifiedPlan;
        config.continual_gathering_policy = webrtc::PeerConnectionInterface::ContinualGatheringPolicy::GATHER_CONTINUALLY;
        webrtc::PeerConnectionInterface::IceServer iceServer;
        iceServer.uri = "stun:stun.l.google.com:19302";
        
        /*iceServer.uri = "stun:rrrtest.uksouth.cloudapp.azure.com:3478";
        iceServer.username = "user";
        iceServer.password = "root";*/
        
        config.servers.push_back(iceServer);
        
        /*webrtc::PeerConnectionInterface::IceServer turnServer;
        turnServer.uri = "turn:rrrtest.uksouth.cloudapp.azure.com:3478";
        turnServer.username = "user";
        turnServer.password = "root";
        
        config.servers.push_back(turnServer);*/
        
        //config.type = webrtc::PeerConnectionInterface::kRelay;
        
        _observer.reset(new PeerConnectionObserverImpl(_discoveredIceCandidate, _connectionStateChanged));
        _peerConnection = _nativeFactory->CreatePeerConnection(config, nullptr, nullptr, _observer.get());
        assert(_peerConnection != nullptr);
        
        std::vector<std::string> streamIds;
        streamIds.push_back("stream");
        
        cricket::AudioOptions options;
        rtc::scoped_refptr<webrtc::AudioSourceInterface> audioSource = _nativeFactory->CreateAudioSource(options);
        _localAudioTrack = _nativeFactory->CreateAudioTrack("audio0", audioSource);
        _peerConnection->AddTrack(_localAudioTrack, streamIds);
        
        rtc::scoped_refptr<webrtc::ObjCVideoTrackSource> objCVideoTrackSource(new rtc::RefCountedObject<webrtc::ObjCVideoTrackSource>());
        _nativeVideoSource = webrtc::VideoTrackSourceProxy::Create(_signalingThread.get(), _workerThread.get(), objCVideoTrackSource);
        
        _localVideoTrack = _nativeFactory->CreateVideoTrack("video0", _nativeVideoSource);
        _peerConnection->AddTrack(_localVideoTrack, streamIds);
        
        [self startLocalVideo];
    }
    return self;
}

- (void)close {
    if (_videoCapturer != nil) {
        [_videoCapturer stopCapture];
    }
    
    _peerConnection->Close();
}

- (void)startLocalVideo {
#if TARGET_OS_SIMULATOR
    return;
#endif
    _videoCapturer = [[VideoCameraCapturer alloc] initWithSource:_nativeVideoSource];
    
    AVCaptureDevice *frontCamera = nil;
    for (AVCaptureDevice *device in [VideoCameraCapturer captureDevices]) {
        if (device.position == AVCaptureDevicePositionFront) {
            frontCamera = device;
            break;
        }
    }
    
    if (frontCamera == nil) {
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
        if (dimensions.width >= 600 || dimensions.height >= 600) {
            bestFormat = format;
            break;
        }
    }
    
    if (bestFormat == nil) {
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
        return;
    }
    
    [_videoCapturer startCaptureWithDevice:frontCamera format:bestFormat fps:27];
}

- (void)setIsMuted:(bool)isMuted {
    _localAudioTrack->set_enabled(!isMuted);
}

- (void)getOffer:(void (^)(NSString *, NSString *))completion {
    webrtc::PeerConnectionInterface::RTCOfferAnswerOptions options;
    options.offer_to_receive_audio = 1;
    options.offer_to_receive_video = 1;
    
    rtc::scoped_refptr<CreateSessionDescriptionObserverImpl> observer(new rtc::RefCountedObject<CreateSessionDescriptionObserverImpl>(completion));
    _peerConnection->CreateOffer(observer, options);
}

- (void)getAnswer:(void (^)(NSString *, NSString *))completion {
    webrtc::PeerConnectionInterface::RTCOfferAnswerOptions options;
    options.offer_to_receive_audio = 1;
    options.offer_to_receive_video = 1;
    
    rtc::scoped_refptr<CreateSessionDescriptionObserverImpl> observer(new rtc::RefCountedObject<CreateSessionDescriptionObserverImpl>(completion));
    _peerConnection->CreateAnswer(observer, options);
}

- (void)setLocalDescription:(NSString *)serializedDescription type:(NSString *)type completion:(void (^)())completion {
    webrtc::SdpParseError error;
    webrtc::SessionDescriptionInterface *sessionDescription = webrtc::CreateSessionDescription(type.UTF8String, serializedDescription.UTF8String, &error);
    if (sessionDescription != nullptr) {
        rtc::scoped_refptr<SetSessionDescriptionObserverImpl> observer(new rtc::RefCountedObject<SetSessionDescriptionObserverImpl>(completion));
        _peerConnection->SetLocalDescription(observer, sessionDescription);
    }
}

- (void)setRemoteDescription:(NSString *)serializedDescription type:(NSString *)type completion:(void (^)())completion {
    webrtc::SdpParseError error;
    webrtc::SessionDescriptionInterface *sessionDescription = webrtc::CreateSessionDescription(type.UTF8String, serializedDescription.UTF8String, &error);
    if (sessionDescription != nullptr) {
        rtc::scoped_refptr<SetSessionDescriptionObserverImpl> observer(new rtc::RefCountedObject<SetSessionDescriptionObserverImpl>(completion));
        _peerConnection->SetRemoteDescription(observer, sessionDescription);
    }
}

- (void)addIceCandidateWithSdp:(NSString *)sdp sdpMLineIndex:(int)sdpMLineIndex sdpMid:(NSString *)sdpMid {
    webrtc::SdpParseError error;
    webrtc::IceCandidateInterface *iceCandidate = webrtc::CreateIceCandidate(sdpMid == nil ? "" : sdpMid.UTF8String, sdpMLineIndex, sdp.UTF8String, &error);
    if (iceCandidate != nullptr) {
        std::unique_ptr<webrtc::IceCandidateInterface> nativeCandidate = std::unique_ptr<webrtc::IceCandidateInterface>(iceCandidate);
        _peerConnection->AddIceCandidate(std::move(nativeCandidate), [](auto error) {
        });
    }
}

- (void)getRemoteCameraView:(void (^_Nonnull)(UIView * _Nullable))completion {
    if (_remoteVideoTrack == nullptr) {
        for (auto &it : _peerConnection->GetTransceivers()) {
            if (it->media_type() == cricket::MediaType::MEDIA_TYPE_VIDEO) {
                _remoteVideoTrack = static_cast<webrtc::VideoTrackInterface *>(it->receiver()->track().get());
                break;
            }
        }
    }
    
    rtc::scoped_refptr<webrtc::VideoTrackInterface> remoteVideoTrack = _remoteVideoTrack;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (remoteVideoTrack != nullptr) {
            VideoMetalView *remoteRenderer = [[VideoMetalView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 240.0f)];
            remoteRenderer.videoContentMode = UIViewContentModeScaleAspectFill;
            [remoteRenderer addToTrack:remoteVideoTrack];
            
            completion(remoteRenderer);
        }
    });
}

@end
