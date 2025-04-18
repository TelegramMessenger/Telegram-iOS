#import <TgVoipWebrtc/OngoingCallThreadLocalContext.h>

#import "MediaUtils.h"

#import "Instance.h"
#import "InstanceImpl.h"
#import "v2/InstanceV2Impl.h"
#import "v2/InstanceV2ReferenceImpl.h"
//#import "v2_4_0_0/InstanceV2_4_0_0Impl.h"
#include "StaticThreads.h"

#import "VideoCaptureInterface.h"
#import "platform/darwin/VideoCameraCapturer.h"

#ifndef WEBRTC_IOS
#import "platform/darwin/VideoMetalViewMac.h"
#import "platform/darwin/GLVideoViewMac.h"
#import "platform/darwin/VideoSampleBufferViewMac.h"
#define UIViewContentModeScaleAspectFill kCAGravityResizeAspectFill
#define UIViewContentModeScaleAspect kCAGravityResizeAspect

#else
#import "platform/darwin/VideoMetalView.h"
#import "platform/darwin/VideoSampleBufferView.h"
#import "platform/darwin/VideoCaptureView.h"
#import "platform/darwin/CustomExternalCapturer.h"

#include "platform/darwin/iOS/tgcalls_audio_device_module_ios.h"

#include "platform/darwin/iOS/RTCAudioSession.h"
#include "platform/darwin/iOS/RTCAudioSessionConfiguration.h"

#endif

#import "group/GroupInstanceImpl.h"
#import "group/GroupInstanceCustomImpl.h"

#import "VideoCaptureInterfaceImpl.h"

#include "sdk/objc/native/src/objc_frame_buffer.h"
#import "components/video_frame_buffer/RTCCVPixelBuffer.h"
#import "platform/darwin/TGRTCCVPixelBuffer.h"
#include "rtc_base/logging.h"

@implementation OngoingCallConnectionDescription

- (instancetype _Nonnull)initWithConnectionId:(int64_t)connectionId ip:(NSString * _Nonnull)ip ipv6:(NSString * _Nonnull)ipv6 port:(int32_t)port peerTag:(NSData * _Nonnull)peerTag {
    self = [super init];
    if (self != nil) {
        _connectionId = connectionId;
        _ip = ip;
        _ipv6 = ipv6;
        _port = port;
        _peerTag = peerTag;
    }
    return self;
}

@end

@implementation VoipProxyServer

- (instancetype _Nonnull)initWithHost:(NSString * _Nonnull)host port:(int32_t)port username:(NSString * _Nullable)username password:(NSString * _Nullable)password {
    self = [super init];
    if (self != nil) {
        _host = host;
        _port = port;
        _username = username;
        _password = password;
    }
    return self;
}

@end


@implementation CallAudioTone

- (instancetype _Nonnull)initWithSamples:(NSData * _Nonnull)samples sampleRate:(NSInteger)sampleRate loopCount:(NSInteger)loopCount {
    self = [super init];
    if (self != nil) {
        _samples = samples;
        _sampleRate = sampleRate;
        _loopCount = loopCount;
    }
    return self;
}

- (std::shared_ptr<tgcalls::CallAudioTone>)asTone {
    std::vector<int16_t> data;
    data.resize(_samples.length / 2);
    memcpy(data.data(), _samples.bytes, _samples.length);
    
    return std::make_shared<tgcalls::CallAudioTone>(std::move(data), (int)_sampleRate, (int)_loopCount);
}

@end

namespace tgcalls {

class WrappedChildAudioDeviceModuleControl {
public:
    WrappedChildAudioDeviceModuleControl() {
    }
    
    virtual ~WrappedChildAudioDeviceModuleControl() {
        _mutex.Lock();
        _mutex.Unlock();
    }
    
public:
    void setActive() {
        _mutex.Lock();
        
        
        
        _mutex.Unlock();
    }
    
private:
    webrtc::Mutex _mutex;
};

class SharedAudioDeviceModule {
public:
    virtual ~SharedAudioDeviceModule() = default;
    
public:
    virtual rtc::scoped_refptr<tgcalls::WrappedAudioDeviceModule> audioDeviceModule() = 0;
    virtual rtc::scoped_refptr<tgcalls::WrappedAudioDeviceModule> makeChildAudioDeviceModule() = 0;
    virtual void start() = 0;
};

}

class WrappedAudioDeviceModuleIOS : public tgcalls::DefaultWrappedAudioDeviceModule, public webrtc::AudioTransport {
public:
    WrappedAudioDeviceModuleIOS(webrtc::scoped_refptr<webrtc::AudioDeviceModule> impl) :
    tgcalls::DefaultWrappedAudioDeviceModule(impl) {
    }

    virtual ~WrappedAudioDeviceModuleIOS() {
        ActualStop();
    }

    virtual int32_t ActiveAudioLayer(AudioLayer *audioLayer) const override {
        return 0;
    }
    
    void UpdateAudioCallback(webrtc::AudioTransport *previousAudioCallback, webrtc::AudioTransport *audioCallback) {
        _mutex.Lock();
        
        if (audioCallback) {
            _audioTransports.push_back(audioCallback);
        } else if (previousAudioCallback) {
            for (size_t i = 0; i < _audioTransports.size(); i++) {
                if (_audioTransports[i] == previousAudioCallback) {
                    _audioTransports.erase(_audioTransports.begin() + i);
                    break;
                }
            }
        }
        
        _mutex.Unlock();
    }

    virtual int32_t RegisterAudioCallback(webrtc::AudioTransport *audioCallback) override {
        return 0;
    }

    virtual int32_t Init() override {
        return 0;
    }

    virtual int32_t Terminate() override {
        return 0;
    }

    virtual bool Initialized() const override {
        return true;
    }

    virtual int16_t PlayoutDevices() override {
        return 0;
    }

    virtual int16_t RecordingDevices() override {
        return 0;
    }

    virtual int32_t PlayoutDeviceName(uint16_t index, char name[webrtc::kAdmMaxDeviceNameSize], char guid[webrtc::kAdmMaxGuidSize]) override {
        return -1;
    }

    virtual int32_t RecordingDeviceName(uint16_t index, char name[webrtc::kAdmMaxDeviceNameSize], char guid[webrtc::kAdmMaxGuidSize]) override {
        return -1;
    }

    virtual int32_t SetPlayoutDevice(uint16_t index) override {
        return 0;
    }

    virtual int32_t SetPlayoutDevice(WindowsDeviceType device) override {
        return 0;
    }

    virtual int32_t SetRecordingDevice(uint16_t index) override {
        return 0;
    }

    virtual int32_t SetRecordingDevice(WindowsDeviceType device) override {
        return 0;
    }

    virtual int32_t PlayoutIsAvailable(bool *available) override {
        return 0;
    }

    virtual int32_t InitPlayout() override {
        return 0;
    }

    virtual bool PlayoutIsInitialized() const override {
        return true;
    }

    virtual int32_t RecordingIsAvailable(bool *available) override {
        if (available) {
            *available = true;
        }
        return 0;
    }

    virtual int32_t InitRecording() override {
        return 0;
    }

    virtual bool RecordingIsInitialized() const override {
        return true;
    }

    virtual int32_t StartPlayout() override {
        return 0;
    }

    virtual int32_t StopPlayout() override {
        return 0;
    }

    virtual bool Playing() const override {
        return true;
    }

    virtual int32_t StartRecording() override {
        return 0;
    }

    virtual int32_t StopRecording() override {
        return 0;
    }

    virtual bool Recording() const override {
        return true;
    }

    virtual int32_t InitSpeaker() override {
        return 0;
    }

    virtual bool SpeakerIsInitialized() const override {
        return true;
    }

    virtual int32_t InitMicrophone() override {
        return 0;
    }

    virtual bool MicrophoneIsInitialized() const override {
        return true;
    }

    virtual int32_t SpeakerVolumeIsAvailable(bool *available) override {
        if (available) {
            *available = false;
        }
        return 0;
    }

    virtual int32_t SetSpeakerVolume(uint32_t volume) override {
        return 0;
    }

    virtual int32_t SpeakerVolume(uint32_t* volume) const override {
        if (volume) {
            *volume = 0;
        }
        return 0;
    }

    virtual int32_t MaxSpeakerVolume(uint32_t *maxVolume) const override {
        if (maxVolume) {
            *maxVolume = 0;
        }
        return 0;
    }

    virtual int32_t MinSpeakerVolume(uint32_t *minVolume) const override {
        if (minVolume) {
            *minVolume = 0;
        }
        return 0;
    }

    virtual int32_t MicrophoneVolumeIsAvailable(bool *available) override {
        if (available) {
            *available = false;
        }
        return 0;
    }

    virtual int32_t SetMicrophoneVolume(uint32_t volume) override {
        return 0;
    }

    virtual int32_t MicrophoneVolume(uint32_t *volume) const override {
        if (volume) {
            *volume = 0;
        }
        return 0;
    }

    virtual int32_t MaxMicrophoneVolume(uint32_t *maxVolume) const override {
        if (maxVolume) {
            *maxVolume = 0;
        }
        return 0;
    }

    virtual int32_t MinMicrophoneVolume(uint32_t *minVolume) const override {
        if (minVolume) {
            *minVolume = 0;
        }
        return 0;
    }

    virtual int32_t SpeakerMuteIsAvailable(bool *available) override {
        if (available) {
            *available = false;
        }
        return 0;
    }

    virtual int32_t SetSpeakerMute(bool enable) override {
        return 0;
    }

    virtual int32_t SpeakerMute(bool *enabled) const override {
        if (enabled) {
            *enabled = false;
        }
        return 0;
    }

    virtual int32_t MicrophoneMuteIsAvailable(bool *available) override {
        if (available) {
            *available = false;
        }
        return 0;
    }

    virtual int32_t SetMicrophoneMute(bool enable) override {
        return 0;
    }

    virtual int32_t MicrophoneMute(bool *enabled) const override {
        if (enabled) {
            *enabled = false;
        }
        return 0;
    }

    virtual int32_t StereoPlayoutIsAvailable(bool *available) const override {
        if (available) {
            *available = false;
        }
        return 0;
    }

    virtual int32_t SetStereoPlayout(bool enable) override {
        return 0;
    }

    virtual int32_t StereoPlayout(bool *enabled) const override {
        if (enabled) {
            *enabled = false;
        }
        return 0;
    }

    virtual int32_t StereoRecordingIsAvailable(bool *available) const override {
        if (available) {
            *available = false;
        }
        return 0;
    }

    virtual int32_t SetStereoRecording(bool enable) override {
        return 0;
    }

    virtual int32_t StereoRecording(bool *enabled) const override {
        if (enabled) {
            *enabled = false;
        }
        return 0;
    }

    virtual int32_t PlayoutDelay(uint16_t* delayMS) const override {
        if (delayMS) {
            *delayMS = 0;
        }
        return 0;
    }

    virtual bool BuiltInAECIsAvailable() const override {
        return true;
    }

    virtual bool BuiltInAGCIsAvailable() const override {
        return true;
    }

    virtual bool BuiltInNSIsAvailable() const override {
        return true;
    }

    virtual int32_t EnableBuiltInAEC(bool enable) override {
        return 0;
    }

    virtual int32_t EnableBuiltInAGC(bool enable) override {
        return 0;
    }

    virtual int32_t EnableBuiltInNS(bool enable) override {
        return 0;
    }

    virtual int32_t GetPlayoutUnderrunCount() const override {
        return 0;
    }
    
    virtual int GetPlayoutAudioParameters(webrtc::AudioParameters *params) const override {
        return WrappedInstance()->GetPlayoutAudioParameters(params);
    }
    
    virtual int GetRecordAudioParameters(webrtc::AudioParameters *params) const override {
        return WrappedInstance()->GetRecordAudioParameters(params);
    }
    
public:
    virtual int32_t RecordedDataIsAvailable(
        const void* audioSamples,
        size_t nSamples,
        size_t nBytesPerSample,
        size_t nChannels,
        uint32_t samplesPerSec,
        uint32_t totalDelayMS,
        int32_t clockDrift,
        uint32_t currentMicLevel,
        bool keyPressed,
        uint32_t& newMicLevel
    ) override {
        _mutex.Lock();
        if (!_audioTransports.empty()) {
            for (size_t i = 0; i < _audioTransports.size(); i++) {
                _audioTransports[_audioTransports.size() - 1]->RecordedDataIsAvailable(
                    audioSamples,
                    nSamples,
                    nBytesPerSample,
                    nChannels,
                    samplesPerSec,
                    totalDelayMS,
                    clockDrift,
                    currentMicLevel,
                    keyPressed,
                    newMicLevel
                );
            }
        }
        _mutex.Unlock();
        return 0;
    }
    
    virtual int32_t RecordedDataIsAvailable(
        const void *audioSamples,
        size_t nSamples,
        size_t nBytesPerSample,
        size_t nChannels,
        uint32_t samplesPerSec,
        uint32_t totalDelayMS,
        int32_t clockDrift,
        uint32_t currentMicLevel,
        bool keyPressed,
        uint32_t& newMicLevel,
        absl::optional<int64_t> estimatedCaptureTimeNS
    ) override {
        _mutex.Lock();
        if (!_audioTransports.empty()) {
            for (size_t i = _audioTransports.size() - 1; i < _audioTransports.size(); i++) {
                _audioTransports[_audioTransports.size() - 1]->RecordedDataIsAvailable(
                    audioSamples,
                    nSamples,
                    nBytesPerSample,
                    nChannels,
                    samplesPerSec,
                    totalDelayMS,
                    clockDrift,
                    currentMicLevel,
                    keyPressed,
                    newMicLevel,
                    estimatedCaptureTimeNS
                );
            }
        }
        _mutex.Unlock();
        return 0;
    }

    // Implementation has to setup safe values for all specified out parameters.
    virtual int32_t NeedMorePlayData(
        size_t nSamples,
        size_t nBytesPerSample,
        size_t nChannels,
        uint32_t samplesPerSec,
        void* audioSamples,
        size_t& nSamplesOut,
        int64_t* elapsed_time_ms,
        int64_t* ntp_time_ms
    ) override {
        _mutex.Lock();
        
        int32_t result = 0;
        if (!_audioTransports.empty()) {
            result = _audioTransports[_audioTransports.size() - 1]->NeedMorePlayData(
                nSamples,
                nBytesPerSample,
                nChannels,
                samplesPerSec,
                audioSamples,
                nSamplesOut,
                elapsed_time_ms,
                ntp_time_ms
            );
        } else {
            nSamplesOut = 0;
        }
        
        _mutex.Unlock();
        
        return result;
    }

    virtual void PullRenderData(
        int bits_per_sample,
        int sample_rate,
        size_t number_of_channels,
        size_t number_of_frames,
        void* audio_data,
        int64_t* elapsed_time_ms,
        int64_t* ntp_time_ms
    ) override {
        _mutex.Lock();
        
        if (!_audioTransports.empty()) {
            _audioTransports[_audioTransports.size() - 1]->PullRenderData(
                bits_per_sample,
                sample_rate,
                number_of_channels,
                number_of_frames,
                audio_data,
                elapsed_time_ms,
                ntp_time_ms
            );
        }
        
        _mutex.Unlock();
    }
    
public:
    virtual void Start() {
        if (!_isStarted) {
            _isStarted = true;
            WrappedInstance()->Init();
            
            WrappedInstance()->RegisterAudioCallback(this);
            
            if (!WrappedInstance()->Playing()) {
                WrappedInstance()->InitPlayout();
                WrappedInstance()->StartPlayout();
                WrappedInstance()->InitRecording();
                WrappedInstance()->StartRecording();
            }
        }
    }

    virtual void Stop() override {
    }
    
    virtual void ActualStop() {
        if (_isStarted) {
            _isStarted = false;
            WrappedInstance()->StopPlayout();
            WrappedInstance()->StopRecording();
            WrappedInstance()->Terminate();
        }
    }
    
private:
    bool _isStarted = false;
    std::vector<webrtc::AudioTransport *> _audioTransports;
    webrtc::Mutex _mutex;
};

class WrappedChildAudioDeviceModule : public tgcalls::DefaultWrappedAudioDeviceModule {
public:
    WrappedChildAudioDeviceModule(webrtc::scoped_refptr<WrappedAudioDeviceModuleIOS> impl) :
    tgcalls::DefaultWrappedAudioDeviceModule(impl) {
    }
    
    virtual ~WrappedChildAudioDeviceModule() {
    }
    
    virtual int32_t RegisterAudioCallback(webrtc::AudioTransport *audioCallback) override {
        auto previousAudioCallback = _audioCallback;
        _audioCallback = audioCallback;
        
        if (_isActive) {
            ((WrappedAudioDeviceModuleIOS *)WrappedInstance().get())->UpdateAudioCallback(previousAudioCallback, audioCallback);
        }
        
        return 0;
    }
    
public:
    void setIsActive() {
        if (_isActive) {
            return;
        }
        _isActive = true;
        
        if (_audioCallback) {
            ((WrappedAudioDeviceModuleIOS *)WrappedInstance().get())->UpdateAudioCallback(nullptr, _audioCallback);
        }
    }
    
private:
    webrtc::AudioTransport *_audioCallback = nullptr;
    bool _isActive = false;
};

class SharedAudioDeviceModuleImpl: public tgcalls::SharedAudioDeviceModule {
public:
    SharedAudioDeviceModuleImpl(bool disableAudioInput, bool enableSystemMute) {
        RTC_DCHECK(tgcalls::StaticThreads::getThreads()->getWorkerThread()->IsCurrent());
        auto sourceDeviceModule = rtc::make_ref_counted<webrtc::tgcalls_ios_adm::AudioDeviceModuleIOS>(false, disableAudioInput, enableSystemMute, disableAudioInput ? 2 : 1);
        _audioDeviceModule = rtc::make_ref_counted<WrappedAudioDeviceModuleIOS>(sourceDeviceModule);
    }
    
    virtual ~SharedAudioDeviceModuleImpl() override {
        if (tgcalls::StaticThreads::getThreads()->getWorkerThread()->IsCurrent()) {
            _audioDeviceModule->ActualStop();
            _audioDeviceModule = nullptr;
        } else {
            tgcalls::StaticThreads::getThreads()->getWorkerThread()->BlockingCall([&]() {
                _audioDeviceModule->ActualStop();
                _audioDeviceModule = nullptr;
            });
        }
    }
    
public:
    virtual rtc::scoped_refptr<tgcalls::WrappedAudioDeviceModule> audioDeviceModule() override {
        return _audioDeviceModule;
    }
    
    rtc::scoped_refptr<tgcalls::WrappedAudioDeviceModule> makeChildAudioDeviceModule() override {
        return rtc::make_ref_counted<WrappedChildAudioDeviceModule>(_audioDeviceModule);
    }
    
    virtual void start() override {
        RTC_DCHECK(tgcalls::StaticThreads::getThreads()->getWorkerThread()->IsCurrent());
        
        _audioDeviceModule->Start();
    }
    
private:
    rtc::scoped_refptr<WrappedAudioDeviceModuleIOS> _audioDeviceModule;
};

@implementation SharedCallAudioDevice {
    std::shared_ptr<tgcalls::ThreadLocalObject<tgcalls::SharedAudioDeviceModule>> _audioDeviceModule;
}

- (instancetype _Nonnull)initWithDisableRecording:(bool)disableRecording enableSystemMute:(bool)enableSystemMute {
    self = [super init];
    if (self != nil) {
        _audioDeviceModule.reset(new tgcalls::ThreadLocalObject<tgcalls::SharedAudioDeviceModule>(tgcalls::StaticThreads::getThreads()->getWorkerThread(), [disableRecording, enableSystemMute]() mutable {
            return std::static_pointer_cast<tgcalls::SharedAudioDeviceModule>(std::make_shared<SharedAudioDeviceModuleImpl>(disableRecording, enableSystemMute));
        }));
    }
    return self;
}

- (void)dealloc {
    _audioDeviceModule.reset();
}

- (void)setTone:(CallAudioTone * _Nullable)tone {
    _audioDeviceModule->perform([tone](tgcalls::SharedAudioDeviceModule *audioDeviceModule) {
        #ifdef WEBRTC_IOS
        WrappedAudioDeviceModuleIOS *deviceModule = (WrappedAudioDeviceModuleIOS *)audioDeviceModule->audioDeviceModule().get();
        webrtc::tgcalls_ios_adm::AudioDeviceModuleIOS *deviceModule_iOS = (webrtc::tgcalls_ios_adm::AudioDeviceModuleIOS *)deviceModule->WrappedInstance().get();
        deviceModule_iOS->setTone([tone asTone]);
        #endif
    });
}

- (std::shared_ptr<tgcalls::ThreadLocalObject<tgcalls::SharedAudioDeviceModule>>)getAudioDeviceModule {
    return _audioDeviceModule;
}

+ (void)setupAudioSession {
    RTCAudioSessionConfiguration *sharedConfiguration = [RTCAudioSessionConfiguration webRTCConfiguration];
    sharedConfiguration.mode = AVAudioSessionModeVoiceChat;
    sharedConfiguration.categoryOptions |= AVAudioSessionCategoryOptionMixWithOthers;
    sharedConfiguration.categoryOptions |= AVAudioSessionCategoryOptionAllowBluetoothA2DP;
    sharedConfiguration.outputNumberOfChannels = 1;
    [RTCAudioSessionConfiguration setWebRTCConfiguration:sharedConfiguration];
    
    [[RTCAudioSession sharedInstance] lockForConfiguration];
    [[RTCAudioSession sharedInstance] setConfiguration:sharedConfiguration active:false error:nil disableRecording:false];
    [[RTCAudioSession sharedInstance] unlockForConfiguration];
}

- (void)setManualAudioSessionIsActive:(bool)isAudioSessionActive {
    if (isAudioSessionActive) {
        [[RTCAudioSession sharedInstance] audioSessionDidActivate:[AVAudioSession sharedInstance]];
    } else {
        [[RTCAudioSession sharedInstance] audioSessionDidDeactivate:[AVAudioSession sharedInstance]];
    }
    [RTCAudioSession sharedInstance].isAudioEnabled = isAudioSessionActive;
    
    if (isAudioSessionActive) {
        _audioDeviceModule->perform([](tgcalls::SharedAudioDeviceModule *audioDeviceModule) {
            audioDeviceModule->start();
        });
    }
}

@end

@implementation OngoingCallConnectionDescriptionWebrtc

- (instancetype _Nonnull)initWithReflectorId:(uint8_t)reflectorId hasStun:(bool)hasStun hasTurn:(bool)hasTurn hasTcp:(bool)hasTcp ip:(NSString * _Nonnull)ip port:(int32_t)port username:(NSString * _Nonnull)username password:(NSString * _Nonnull)password {
    self = [super init];
    if (self != nil) {
        _reflectorId = reflectorId;
        _hasStun = hasStun;
        _hasTurn = hasTurn;
        _hasTcp = hasTcp;
        _ip = ip;
        _port = port;
        _username = username;
        _password = password;
    }
    return self;
}

@end

@interface IsProcessingCustomSampleBufferFlag : NSObject

@property (nonatomic) bool value;

@end

@implementation IsProcessingCustomSampleBufferFlag

- (instancetype)init {
    self = [super init];
    if (self != nil) {
    }
    return self;
}

@end

@interface OngoingCallThreadLocalContextVideoCapturer () {
    std::shared_ptr<tgcalls::VideoCaptureInterface> _interface;
    IsProcessingCustomSampleBufferFlag *_isProcessingCustomSampleBuffer;
}

@end

@protocol OngoingCallThreadLocalContextWebrtcVideoViewImpl <NSObject>

@property (nonatomic, readwrite) OngoingCallVideoOrientationWebrtc orientation;
@property (nonatomic, readonly) CGFloat aspect;

@end

@interface VideoMetalView (VideoViewImpl) <OngoingCallThreadLocalContextWebrtcVideoView, OngoingCallThreadLocalContextWebrtcVideoViewImpl>

@property (nonatomic, readwrite) OngoingCallVideoOrientationWebrtc orientation;
@property (nonatomic, readonly) CGFloat aspect;

@end

@implementation VideoMetalView (VideoViewImpl)

- (OngoingCallVideoOrientationWebrtc)orientation {
    return (OngoingCallVideoOrientationWebrtc)self.internalOrientation;
}

- (CGFloat)aspect {
    return self.internalAspect;
}

- (void)setOrientation:(OngoingCallVideoOrientationWebrtc)orientation {
    [self setInternalOrientation:(int)orientation];
}

- (void)setOnOrientationUpdated:(void (^ _Nullable)(OngoingCallVideoOrientationWebrtc, CGFloat))onOrientationUpdated {
    if (onOrientationUpdated) {
        [self internalSetOnOrientationUpdated:^(int value, CGFloat aspect) {
            onOrientationUpdated((OngoingCallVideoOrientationWebrtc)value, aspect);
        }];
    } else {
        [self internalSetOnOrientationUpdated:nil];
    }
}

- (void)setOnIsMirroredUpdated:(void (^ _Nullable)(bool))onIsMirroredUpdated {
    if (onIsMirroredUpdated) {
        [self internalSetOnIsMirroredUpdated:^(bool value) {
            onIsMirroredUpdated(value);
        }];
    } else {
        [self internalSetOnIsMirroredUpdated:nil];
    }
}

- (void)updateIsEnabled:(bool)isEnabled {
    [self setEnabled:isEnabled];
}

@end

@interface VideoSampleBufferView (VideoViewImpl) <OngoingCallThreadLocalContextWebrtcVideoView, OngoingCallThreadLocalContextWebrtcVideoViewImpl>

@property (nonatomic, readwrite) OngoingCallVideoOrientationWebrtc orientation;
@property (nonatomic, readonly) CGFloat aspect;

@end

@implementation VideoSampleBufferView (VideoViewImpl)

- (OngoingCallVideoOrientationWebrtc)orientation {
    return (OngoingCallVideoOrientationWebrtc)self.internalOrientation;
}

- (CGFloat)aspect {
    return self.internalAspect;
}

- (void)setOrientation:(OngoingCallVideoOrientationWebrtc)orientation {
    [self setInternalOrientation:(int)orientation];
}

- (void)setOnOrientationUpdated:(void (^ _Nullable)(OngoingCallVideoOrientationWebrtc, CGFloat))onOrientationUpdated {
    if (onOrientationUpdated) {
        [self internalSetOnOrientationUpdated:^(int value, CGFloat aspect) {
            onOrientationUpdated((OngoingCallVideoOrientationWebrtc)value, aspect);
        }];
    } else {
        [self internalSetOnOrientationUpdated:nil];
    }
}

- (void)setOnIsMirroredUpdated:(void (^ _Nullable)(bool))onIsMirroredUpdated {
    if (onIsMirroredUpdated) {
        [self internalSetOnIsMirroredUpdated:^(bool value) {
            onIsMirroredUpdated(value);
        }];
    } else {
        [self internalSetOnIsMirroredUpdated:nil];
    }
}

- (void)updateIsEnabled:(bool)isEnabled {
    [self setEnabled:isEnabled];
}

@end

@interface GroupCallDisposable () {
    dispatch_block_t _block;
}

@end

@implementation GroupCallDisposable

- (instancetype)initWithBlock:(dispatch_block_t _Nonnull)block {
    self = [super init];
    if (self != nil) {
        _block = [block copy];
    }
    return self;
}

- (void)dispose {
    if (_block) {
        _block();
    }
}

@end

@implementation CallVideoFrameNativePixelBuffer

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    self = [super init];
    if (self != nil) {
        assert(pixelBuffer != nil);

        _pixelBuffer = CVPixelBufferRetain(pixelBuffer);
    }
    return self;
}

- (void)dealloc {
    CVPixelBufferRelease(_pixelBuffer);
}

@end

@implementation CallVideoFrameNV12Buffer

- (instancetype)initWithBuffer:(rtc::scoped_refptr<webrtc::NV12BufferInterface>)nv12Buffer {
    self = [super init];
    if (self != nil) {
        _width = nv12Buffer->width();
        _height = nv12Buffer->height();

        _strideY = nv12Buffer->StrideY();
        _strideUV = nv12Buffer->StrideUV();

        _y = [[NSData alloc] initWithBytesNoCopy:(void *)nv12Buffer->DataY() length:nv12Buffer->StrideY() * _height deallocator:^(__unused void * _Nonnull bytes, __unused NSUInteger length) {
            nv12Buffer.get();
        }];

        _uv = [[NSData alloc] initWithBytesNoCopy:(void *)nv12Buffer->DataUV() length:nv12Buffer->StrideUV() * _height deallocator:^(__unused void * _Nonnull bytes, __unused NSUInteger length) {
            nv12Buffer.get();
        }];
    }
    return self;
}

@end

@implementation CallVideoFrameI420Buffer

- (instancetype)initWithBuffer:(rtc::scoped_refptr<webrtc::I420BufferInterface>)i420Buffer {
    self = [super init];
    if (self != nil) {
        _width = i420Buffer->width();
        _height = i420Buffer->height();

        _strideY = i420Buffer->StrideY();
        _strideU = i420Buffer->StrideU();
        _strideV = i420Buffer->StrideV();

        _y = [[NSData alloc] initWithBytesNoCopy:(void *)i420Buffer->DataY() length:i420Buffer->StrideY() * _height deallocator:^(__unused void * _Nonnull bytes, __unused NSUInteger length) {
            i420Buffer.get();
        }];

        _u = [[NSData alloc] initWithBytesNoCopy:(void *)i420Buffer->DataU() length:i420Buffer->StrideU() * _height deallocator:^(__unused void * _Nonnull bytes, __unused NSUInteger length) {
            i420Buffer.get();
        }];

        _v = [[NSData alloc] initWithBytesNoCopy:(void *)i420Buffer->DataV() length:i420Buffer->StrideV() * _height deallocator:^(__unused void * _Nonnull bytes, __unused NSUInteger length) {
            i420Buffer.get();
        }];
    }
    return self;
}

@end

@interface CallVideoFrameData () {
}

@end

@implementation CallVideoFrameData

- (instancetype)initWithBuffer:(id<CallVideoFrameBuffer>)buffer frame:(webrtc::VideoFrame const &)frame mirrorHorizontally:(bool)mirrorHorizontally mirrorVertically:(bool)mirrorVertically hasDeviceRelativeVideoRotation:(bool)hasDeviceRelativeVideoRotation deviceRelativeVideoRotation:(OngoingCallVideoOrientationWebrtc)deviceRelativeVideoRotation {
    self = [super init];
    if (self != nil) {
        _buffer = buffer;

        _width = frame.width();
        _height = frame.height();

        switch (frame.rotation()) {
            case webrtc::kVideoRotation_0: {
                _orientation = OngoingCallVideoOrientation0;
                break;
            }
            case webrtc::kVideoRotation_90: {
                _orientation = OngoingCallVideoOrientation90;
                break;
            }
            case webrtc::kVideoRotation_180: {
                _orientation = OngoingCallVideoOrientation180;
                break;
            }
            case webrtc::kVideoRotation_270: {
                _orientation = OngoingCallVideoOrientation270;
                break;
            }
            default: {
                _orientation = OngoingCallVideoOrientation0;
                break;
            }
        }
        
        _hasDeviceRelativeOrientation = hasDeviceRelativeVideoRotation;
        _deviceRelativeOrientation = deviceRelativeVideoRotation;

        _mirrorHorizontally = mirrorHorizontally;
        _mirrorVertically = mirrorVertically;
    }
    return self;
}

@end

namespace {

class GroupCallVideoSinkAdapter : public rtc::VideoSinkInterface<webrtc::VideoFrame> {
public:
    GroupCallVideoSinkAdapter(void (^frameReceived)(webrtc::VideoFrame const &)) {
        _frameReceived = [frameReceived copy];
    }

    void OnFrame(const webrtc::VideoFrame& nativeVideoFrame) override {
        @autoreleasepool {
            if (_frameReceived) {
                _frameReceived(nativeVideoFrame);
            }
        }
    }

private:
    void (^_frameReceived)(webrtc::VideoFrame const &);
};

class DirectConnectionChannelImpl : public tgcalls::DirectConnectionChannel {
public:
    DirectConnectionChannelImpl(id<OngoingCallDirectConnection> _Nonnull impl) {
        _impl = impl;
    }
    
    virtual ~DirectConnectionChannelImpl() {
    }
    
    virtual std::vector<uint8_t> addOnIncomingPacket(std::function<void(std::shared_ptr<std::vector<uint8_t>>)> &&handler) override {
        __block auto localHandler = std::move(handler);
        
        NSData *token = [_impl addOnIncomingPacket:^(NSData * _Nonnull data) {
            std::shared_ptr<std::vector<uint8_t>> mappedData = std::make_shared<std::vector<uint8_t>>((uint8_t const *)data.bytes, (uint8_t const *)data.bytes + data.length);
            localHandler(mappedData);
        }];
        return std::vector<uint8_t>((uint8_t * const)token.bytes, (uint8_t * const)token.bytes + token.length);
    }
    
    virtual void removeOnIncomingPacket(std::vector<uint8_t> &token) override {
        [_impl removeOnIncomingPacket:[[NSData alloc] initWithBytes:token.data() length:token.size()]];
    }
    
    virtual void sendPacket(std::unique_ptr<std::vector<uint8_t>> &&packet) override {
        [_impl sendPacket:[[NSData alloc] initWithBytes:packet->data() length:packet->size()]];
    }
    
private:
    id<OngoingCallDirectConnection> _impl;
};

}

@interface GroupCallVideoSink : NSObject {
    std::shared_ptr<GroupCallVideoSinkAdapter> _adapter;
}

@end

@implementation GroupCallVideoSink

- (instancetype)initWithSink:(void (^_Nonnull)(CallVideoFrameData * _Nonnull))sink {
    self = [super init];
    if (self != nil) {
        void (^storedSink)(CallVideoFrameData * _Nonnull) = [sink copy];

        _adapter.reset(new GroupCallVideoSinkAdapter(^(webrtc::VideoFrame const &videoFrame) {
            id<CallVideoFrameBuffer> mappedBuffer = nil;

            bool mirrorHorizontally = false;
            bool mirrorVertically = false;
            
            bool hasDeviceRelativeVideoRotation = false;
            OngoingCallVideoOrientationWebrtc deviceRelativeVideoRotation = OngoingCallVideoOrientation0;

            if (videoFrame.video_frame_buffer()->type() == webrtc::VideoFrameBuffer::Type::kNative) {
                id<RTC_OBJC_TYPE(RTCVideoFrameBuffer)> nativeBuffer = static_cast<webrtc::ObjCFrameBuffer *>(videoFrame.video_frame_buffer().get())->wrapped_frame_buffer();
                if ([nativeBuffer isKindOfClass:[RTC_OBJC_TYPE(RTCCVPixelBuffer) class]]) {
                    RTCCVPixelBuffer *pixelBuffer = (RTCCVPixelBuffer *)nativeBuffer;
                    mappedBuffer = [[CallVideoFrameNativePixelBuffer alloc] initWithPixelBuffer:pixelBuffer.pixelBuffer];
                }
                if ([nativeBuffer isKindOfClass:[TGRTCCVPixelBuffer class]]) {
                    TGRTCCVPixelBuffer *tgNativeBuffer = (TGRTCCVPixelBuffer *)nativeBuffer;
                    if (tgNativeBuffer.shouldBeMirrored) {
                        switch (videoFrame.rotation()) {
                            case webrtc::kVideoRotation_0:
                            case webrtc::kVideoRotation_180:
                                mirrorHorizontally = true;
                                break;
                            case webrtc::kVideoRotation_90:
                            case webrtc::kVideoRotation_270:
                                mirrorVertically = true;
                                break;
                            default:
                                break;
                        }
                    }
                    if (tgNativeBuffer.deviceRelativeVideoRotation != -1) {
                        hasDeviceRelativeVideoRotation = true;
                        switch (tgNativeBuffer.deviceRelativeVideoRotation) {
                            case webrtc::kVideoRotation_0:
                                deviceRelativeVideoRotation = OngoingCallVideoOrientation0;
                                break;
                            case webrtc::kVideoRotation_90:
                                deviceRelativeVideoRotation = OngoingCallVideoOrientation90;
                                break;
                            case webrtc::kVideoRotation_180:
                                deviceRelativeVideoRotation = OngoingCallVideoOrientation180;
                                break;
                            case webrtc::kVideoRotation_270:
                                deviceRelativeVideoRotation = OngoingCallVideoOrientation270;
                                break;
                            default:
                                deviceRelativeVideoRotation = OngoingCallVideoOrientation0;
                                break;
                        }
                    }
                }
            } else if (videoFrame.video_frame_buffer()->type() == webrtc::VideoFrameBuffer::Type::kNV12) {
                rtc::scoped_refptr<webrtc::NV12BufferInterface> nv12Buffer(static_cast<webrtc::NV12BufferInterface *>(videoFrame.video_frame_buffer().get()));
                mappedBuffer = [[CallVideoFrameNV12Buffer alloc] initWithBuffer:nv12Buffer];
            } else if (videoFrame.video_frame_buffer()->type() == webrtc::VideoFrameBuffer::Type::kI420) {
                rtc::scoped_refptr<webrtc::I420BufferInterface> i420Buffer(static_cast<webrtc::I420BufferInterface *>(videoFrame.video_frame_buffer().get()));
                mappedBuffer = [[CallVideoFrameI420Buffer alloc] initWithBuffer:i420Buffer];
            }

            if (storedSink && mappedBuffer) {
                storedSink([[CallVideoFrameData alloc] initWithBuffer:mappedBuffer frame:videoFrame mirrorHorizontally:mirrorHorizontally mirrorVertically:mirrorVertically hasDeviceRelativeVideoRotation:hasDeviceRelativeVideoRotation deviceRelativeVideoRotation:deviceRelativeVideoRotation]);
            }
        }));
    }
    return self;
}

- (std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>)sink {
    return _adapter;
}

@end

@interface OngoingCallThreadLocalContextVideoCapturer () {
    bool _keepLandscape;
    std::shared_ptr<std::vector<uint8_t>> _croppingBuffer;

    int _nextSinkId;
    NSMutableDictionary<NSNumber *, GroupCallVideoSink *> *_sinks;
}

@end

@implementation OngoingCallThreadLocalContextVideoCapturer

- (instancetype _Nonnull)initWithInterface:(std::shared_ptr<tgcalls::VideoCaptureInterface>)interface {
    self = [super init];
    if (self != nil) {
        _interface = interface;
        _isProcessingCustomSampleBuffer = [[IsProcessingCustomSampleBufferFlag alloc] init];
        _croppingBuffer = std::make_shared<std::vector<uint8_t>>();
        _sinks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype _Nonnull)initWithDeviceId:(NSString * _Nonnull)deviceId keepLandscape:(bool)keepLandscape {
    self = [super init];
    if (self != nil) {
        _keepLandscape = keepLandscape;
        
        std::string resolvedId = deviceId.UTF8String;
        if (keepLandscape) {
            resolvedId += std::string(":landscape");
        }
        _interface = tgcalls::VideoCaptureInterface::Create(tgcalls::StaticThreads::getThreads(), resolvedId);
        _sinks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#if TARGET_OS_IOS

tgcalls::VideoCaptureInterfaceObject *GetVideoCaptureAssumingSameThread(tgcalls::VideoCaptureInterface *videoCapture) {
    return videoCapture
        ? static_cast<tgcalls::VideoCaptureInterfaceImpl*>(videoCapture)->object()->getSyncAssumingSameThread()
        : nullptr;
}

+ (instancetype _Nonnull)capturerWithExternalSampleBufferProvider {
    std::shared_ptr<tgcalls::VideoCaptureInterface> interface = tgcalls::VideoCaptureInterface::Create(tgcalls::StaticThreads::getThreads(), ":ios_custom", true);
    return [[OngoingCallThreadLocalContextVideoCapturer alloc] initWithInterface:interface];
}
#endif

- (void)dealloc {
}

#if TARGET_OS_IOS
- (void)submitSampleBuffer:(CMSampleBufferRef _Nonnull)sampleBuffer rotation:(OngoingCallVideoOrientationWebrtc)rotation completion:(void (^_Nonnull)())completion {
    if (!sampleBuffer) {
        if (completion) {
            completion();
        }
        return;
    }
    
    RTCVideoRotation videoRotation = RTCVideoRotation_0;
    switch (rotation) {
    case OngoingCallVideoOrientation0:
        videoRotation = RTCVideoRotation_0;
        break;
    case OngoingCallVideoOrientation90:
        videoRotation = RTCVideoRotation_90;
        break;
    case OngoingCallVideoOrientation180:
        videoRotation = RTCVideoRotation_180;
        break;
    case OngoingCallVideoOrientation270:
        videoRotation = RTCVideoRotation_270;
        break;
    }

    /*if (_isProcessingCustomSampleBuffer.value) {
        if (completion) {
            completion();
        }
        return;
    }*/
    _isProcessingCustomSampleBuffer.value = true;

    void (^capturedCompletion)() = [completion copy];
    
    tgcalls::StaticThreads::getThreads()->getMediaThread()->PostTask([interface = _interface, sampleBuffer = CFRetain(sampleBuffer), croppingBuffer = _croppingBuffer, videoRotation = videoRotation, isProcessingCustomSampleBuffer = _isProcessingCustomSampleBuffer, capturedCompletion]() {
        auto capture = GetVideoCaptureAssumingSameThread(interface.get());
        auto source = capture->source();
        if (source) {
            CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer((CMSampleBufferRef)sampleBuffer);
            
            [CustomExternalCapturer passPixelBuffer:pixelBuffer sampleBufferReference:(CMSampleBufferRef)sampleBuffer rotation:videoRotation toSource:source croppingBuffer:*croppingBuffer];
        }
        CFRelease(sampleBuffer);
        isProcessingCustomSampleBuffer.value = false;
        
        if (capturedCompletion) {
            capturedCompletion();
        }
    });
}

#endif

- (GroupCallDisposable * _Nonnull)addVideoOutput:(void (^_Nonnull)(CallVideoFrameData * _Nonnull))sink {
    int sinkId = _nextSinkId;
    _nextSinkId += 1;

    GroupCallVideoSink *storedSink = [[GroupCallVideoSink alloc] initWithSink:sink];
    _sinks[@(sinkId)] = storedSink;

    auto sinkReference = [storedSink sink];

    tgcalls::StaticThreads::getThreads()->getMediaThread()->PostTask([interface = _interface, sinkReference]() {
        interface->setOutput(sinkReference);
    });

    __weak OngoingCallThreadLocalContextVideoCapturer *weakSelf = self;
    return [[GroupCallDisposable alloc] initWithBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong OngoingCallThreadLocalContextVideoCapturer *strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            [strongSelf->_sinks removeObjectForKey:@(sinkId)];
        });
    }];
}

- (void)switchVideoInput:(NSString * _Nonnull)deviceId {
    std::string resolvedId = deviceId.UTF8String;
    if (_keepLandscape) {
        resolvedId += std::string(":landscape");
    }
    _interface->switchToDevice(resolvedId, false);
}

- (void)setIsVideoEnabled:(bool)isVideoEnabled {
    _interface->setState(isVideoEnabled ? tgcalls::VideoState::Active : tgcalls::VideoState::Paused);
}

- (std::shared_ptr<tgcalls::VideoCaptureInterface>)getInterface {
    return _interface;
}

-(void)setOnFatalError:(dispatch_block_t _Nullable)onError {
#if TARGET_OS_IOS
#else
    _interface->setOnFatalError(onError);
#endif
}

-(void)setOnPause:(void (^)(bool))onPause {
#if TARGET_OS_IOS
#else
    _interface->setOnPause(onPause);
#endif
}

- (void)setOnIsActiveUpdated:(void (^)(bool))onIsActiveUpdated {
    _interface->setOnIsActiveUpdated([onIsActiveUpdated](bool isActive) {
        if (onIsActiveUpdated) {
            onIsActiveUpdated(isActive);
        }
    });
}

- (void)makeOutgoingVideoView:(bool)requestClone completion:(void (^_Nonnull)(UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable, UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable))completion {
    __weak OngoingCallThreadLocalContextVideoCapturer *weakSelf = self;

    void (^makeDefault)() = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong OngoingCallThreadLocalContextVideoCapturer *strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            std::shared_ptr<tgcalls::VideoCaptureInterface> interface = strongSelf->_interface;

            VideoMetalView *remoteRenderer = [[VideoMetalView alloc] initWithFrame:CGRectZero];
            remoteRenderer.videoContentMode = UIViewContentModeScaleAspectFill;

            VideoMetalView *cloneRenderer = nil;
            if (requestClone) {
                cloneRenderer = [[VideoMetalView alloc] initWithFrame:CGRectZero];
#ifdef WEBRTC_IOS
                cloneRenderer.videoContentMode = UIViewContentModeScaleToFill;
                [remoteRenderer setClone:cloneRenderer];
#else
                cloneRenderer.videoContentMode = kCAGravityResizeAspectFill;
#endif
            }

            std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];

            interface->setOutput(sink);

            completion(remoteRenderer, cloneRenderer);
        });
    };

    makeDefault();
}

@end

@interface OngoingCallThreadLocalContextWebrtcTerminationResult : NSObject

@property (nonatomic, readonly) tgcalls::FinalState finalState;

@end

@implementation OngoingCallThreadLocalContextWebrtcTerminationResult

- (instancetype)initWithFinalState:(tgcalls::FinalState)finalState {
    self = [super init];
    if (self != nil) {
        _finalState = finalState;
    }
    return self;
}

@end

@interface OngoingCallThreadLocalContextWebrtc () {
    NSString *_version;
    id<OngoingCallThreadLocalContextQueueWebrtc> _queue;
    int32_t _contextId;
    
    bool _useManualAudioSessionControl;
    SharedCallAudioDevice *_audioDevice;
    
    int _nextSinkId;
    NSMutableDictionary<NSNumber *, GroupCallVideoSink *> *_sinks;
    
    rtc::scoped_refptr<webrtc::tgcalls_ios_adm::AudioDeviceModuleIOS> _currentAudioDeviceModule;
    rtc::Thread *_currentAudioDeviceModuleThread;
    
    OngoingCallNetworkTypeWebrtc _networkType;
    NSTimeInterval _callReceiveTimeout;
    NSTimeInterval _callRingTimeout;
    NSTimeInterval _callConnectTimeout;
    NSTimeInterval _callPacketTimeout;
    
    std::unique_ptr<tgcalls::Instance> _tgVoip;
    bool _didStop;
    
    OngoingCallStateWebrtc _pendingState;
    OngoingCallStateWebrtc _state;
    bool _didPushStateOnce;
    GroupCallDisposable *_pushStateDisposable;
    
    OngoingCallVideoStateWebrtc _videoState;
    bool _connectedOnce;
    OngoingCallRemoteBatteryLevelWebrtc _remoteBatteryLevel;
    OngoingCallRemoteVideoStateWebrtc _remoteVideoState;
    OngoingCallRemoteAudioStateWebrtc _remoteAudioState;
    OngoingCallVideoOrientationWebrtc _remoteVideoOrientation;
    __weak UIView<OngoingCallThreadLocalContextWebrtcVideoViewImpl> *_currentRemoteVideoRenderer;
    OngoingCallThreadLocalContextVideoCapturer *_videoCapturer;
    
    int32_t _signalBars;
    NSData *_lastDerivedState;
    
    void (^_sendSignalingData)(NSData *);
    
    float _remotePreferredAspectRatio;
}

- (void)controllerStateChanged:(tgcalls::State)state;
- (void)signalBarsChanged:(int32_t)signalBars;

@end

@implementation VoipProxyServerWebrtc

- (instancetype _Nonnull)initWithHost:(NSString * _Nonnull)host port:(int32_t)port username:(NSString * _Nullable)username password:(NSString * _Nullable)password {
    self = [super init];
    if (self != nil) {
        _host = host;
        _port = port;
        _username = username;
        _password = password;
    }
    return self;
}

@end

static tgcalls::NetworkType callControllerNetworkTypeForType(OngoingCallNetworkTypeWebrtc type) {
    switch (type) {
        case OngoingCallNetworkTypeWifi:
            return tgcalls::NetworkType::WiFi;
        case OngoingCallNetworkTypeCellularGprs:
            return tgcalls::NetworkType::Gprs;
        case OngoingCallNetworkTypeCellular3g:
            return tgcalls::NetworkType::ThirdGeneration;
        case OngoingCallNetworkTypeCellularLte:
            return tgcalls::NetworkType::Lte;
        default:
            return tgcalls::NetworkType::ThirdGeneration;
    }
}

static tgcalls::DataSaving callControllerDataSavingForType(OngoingCallDataSavingWebrtc type) {
    switch (type) {
        case OngoingCallDataSavingNever:
            return tgcalls::DataSaving::Never;
        case OngoingCallDataSavingCellular:
            return tgcalls::DataSaving::Mobile;
        case OngoingCallDataSavingAlways:
            return tgcalls::DataSaving::Always;
        default:
            return tgcalls::DataSaving::Never;
    }
}

@implementation OngoingCallThreadLocalContextWebrtc

static void (*InternalVoipLoggingFunction)(NSString *) = NULL;

+ (void)logMessage:(NSString * _Nonnull)string {
    RTC_LOG(LS_INFO) << std::string(string.UTF8String);
}

+ (void)setupLoggingFunction:(void (*)(NSString *))loggingFunction {
    InternalVoipLoggingFunction = loggingFunction;
    tgcalls::SetLoggingFunction([](std::string const &string) {
        if (InternalVoipLoggingFunction) {
            InternalVoipLoggingFunction([[NSString alloc] initWithUTF8String:string.c_str()]);
        }
    });
}

+ (void)applyServerConfig:(NSString *)string {
}

+ (void)setupAudioSession {
    RTCAudioSessionConfiguration *sharedConfiguration = [RTCAudioSessionConfiguration webRTCConfiguration];
    sharedConfiguration.mode = AVAudioSessionModeVoiceChat;
    sharedConfiguration.categoryOptions |= AVAudioSessionCategoryOptionMixWithOthers;
    sharedConfiguration.categoryOptions |= AVAudioSessionCategoryOptionAllowBluetoothA2DP;
    sharedConfiguration.outputNumberOfChannels = 1;
    [RTCAudioSessionConfiguration setWebRTCConfiguration:sharedConfiguration];
    
    [[RTCAudioSession sharedInstance] lockForConfiguration];
    [[RTCAudioSession sharedInstance] setConfiguration:sharedConfiguration active:false error:nil disableRecording:false];
    [[RTCAudioSession sharedInstance] unlockForConfiguration];
}

+ (int32_t)maxLayer {
    return 92;
}

+ (void)ensureRegisteredImplementations {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tgcalls::Register<tgcalls::InstanceImpl>();
        //tgcalls::Register<tgcalls::InstanceV2_4_0_0Impl>();
        tgcalls::Register<tgcalls::InstanceV2Impl>();
        tgcalls::Register<tgcalls::InstanceV2ReferenceImpl>();
    });
}

+ (NSArray<NSString *> * _Nonnull)versionsWithIncludeReference:(bool)includeReference {
    [self ensureRegisteredImplementations];
    
    NSMutableArray<NSString *> *list = [[NSMutableArray alloc] init];
    
    for (const auto &version : tgcalls::Meta::Versions()) {
        [list addObject:[NSString stringWithUTF8String:version.c_str()]];
    }
    
    [list sortUsingComparator:^NSComparisonResult(NSString * _Nonnull lhs, NSString * _Nonnull rhs) {
        return [lhs compare:rhs];
    }];
    
    return list;
}

+ (tgcalls::ProtocolVersion)protocolVersionFromLibraryVersion:(NSString *)version {
    if ([version isEqualToString:@"2.7.7"]) {
        return tgcalls::ProtocolVersion::V0;
    } else if ([version isEqualToString:@"5.0.0"]) {
        return tgcalls::ProtocolVersion::V1;
    } else {
        return tgcalls::ProtocolVersion::V0;
    }
}

- (instancetype _Nonnull)initWithVersion:(NSString * _Nonnull)version
                        customParameters:(NSString * _Nullable)customParameters
                                   queue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue
                                   proxy:(VoipProxyServerWebrtc * _Nullable)proxy
                             networkType:(OngoingCallNetworkTypeWebrtc)networkType dataSaving:(OngoingCallDataSavingWebrtc)dataSaving
                            derivedState:(NSData * _Nonnull)derivedState
                                     key:(NSData * _Nonnull)key
                              isOutgoing:(bool)isOutgoing
                             connections:(NSArray<OngoingCallConnectionDescriptionWebrtc *> * _Nonnull)connections maxLayer:(int32_t)maxLayer
                                allowP2P:(BOOL)allowP2P
                                allowTCP:(BOOL)allowTCP
                       enableStunMarking:(BOOL)enableStunMarking
                                 logPath:(NSString * _Nonnull)logPath
                            statsLogPath:(NSString * _Nonnull)statsLogPath
                       sendSignalingData:(void (^ _Nonnull)(NSData * _Nonnull))sendSignalingData videoCapturer:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer
                     preferredVideoCodec:(NSString * _Nullable)preferredVideoCodec
                      audioInputDeviceId:(NSString * _Nonnull)audioInputDeviceId
                             audioDevice:(SharedCallAudioDevice * _Nullable)audioDevice
                        directConnection:(id<OngoingCallDirectConnection> _Nullable)directConnection {
    self = [super init];
    if (self != nil) {
        _version = version;
        _queue = queue;
        assert([queue isCurrent]);
        
        assert([[OngoingCallThreadLocalContextWebrtc versionsWithIncludeReference:true] containsObject:version]);
        
        _audioDevice = audioDevice;
        
        _sinks = [[NSMutableDictionary alloc] init];
        
        _useManualAudioSessionControl = true;
        [RTCAudioSession sharedInstance].useManualAudio = true;
        
#ifdef WEBRTC_IOS
        RTCAudioSessionConfiguration *sharedConfiguration = [RTCAudioSessionConfiguration webRTCConfiguration];
        sharedConfiguration.mode = AVAudioSessionModeVoiceChat;
        sharedConfiguration.categoryOptions |= AVAudioSessionCategoryOptionMixWithOthers;
        sharedConfiguration.categoryOptions |= AVAudioSessionCategoryOptionAllowBluetoothA2DP;
        sharedConfiguration.outputNumberOfChannels = 1;
        [RTCAudioSessionConfiguration setWebRTCConfiguration:sharedConfiguration];
        
        /*[RTCAudioSession sharedInstance].useManualAudio = true;
         [[RTCAudioSession sharedInstance] audioSessionDidActivate:[AVAudioSession sharedInstance]];
         [RTCAudioSession sharedInstance].isAudioEnabled = true;*/
#endif
        
        _callReceiveTimeout = 20.0;
        _callRingTimeout = 90.0;
        _callConnectTimeout = 30.0;
        _callPacketTimeout = 10.0;
        _remotePreferredAspectRatio = 0;
        _networkType = networkType;
        _sendSignalingData = [sendSignalingData copy];
        _videoCapturer = videoCapturer;
        if (videoCapturer != nil) {
            _videoState = OngoingCallVideoStateActive;
        } else {
            _videoState = OngoingCallVideoStateInactive;
        }
        _remoteVideoState = OngoingCallRemoteVideoStateInactive;
        _remoteAudioState = OngoingCallRemoteAudioStateActive;
        
        _remoteVideoOrientation = OngoingCallVideoOrientation0;
        
        std::vector<uint8_t> derivedStateValue;
        derivedStateValue.resize(derivedState.length);
        [derivedState getBytes:derivedStateValue.data() length:derivedState.length];
        
        std::unique_ptr<tgcalls::Proxy> proxyValue = nullptr;
        if (proxy != nil) {
            tgcalls::Proxy *proxyObject = new tgcalls::Proxy();
            proxyObject->host = proxy.host.UTF8String;
            proxyObject->port = (uint16_t)proxy.port;
            proxyObject->login = proxy.username.UTF8String ?: "";
            proxyObject->password = proxy.password.UTF8String ?: "";
            proxyValue = std::unique_ptr<tgcalls::Proxy>(proxyObject);
        }
        
        std::vector<tgcalls::RtcServer> parsedRtcServers;
        for (OngoingCallConnectionDescriptionWebrtc *connection in connections) {
            if (connection.hasStun) {
                parsedRtcServers.push_back((tgcalls::RtcServer){
                    .id = 0,
                    .host = connection.ip.UTF8String,
                    .port = (uint16_t)connection.port,
                    .login = "",
                    .password = "",
                    .isTurn = false,
                    .isTcp = false
                });
            }
            if (connection.hasTurn || connection.hasTcp) {
                parsedRtcServers.push_back((tgcalls::RtcServer){
                    .id = connection.reflectorId,
                    .host = connection.ip.UTF8String,
                    .port = (uint16_t)connection.port,
                    .login = connection.username.UTF8String,
                    .password = connection.password.UTF8String,
                    .isTurn = true,
                    .isTcp = connection.hasTcp
                });
            }
        }
        
        std::vector<std::string> preferredVideoCodecs;
        if (preferredVideoCodec != nil) {
            preferredVideoCodecs.push_back([preferredVideoCodec UTF8String]);
        }
        
        std::vector<tgcalls::Endpoint> endpoints;
        
        std::string customParametersString = "{}";
        if (customParameters && customParameters.length != 0) {
            customParametersString = std::string(customParameters.UTF8String);
        }
        
        tgcalls::Config config = {
            .initializationTimeout = _callConnectTimeout,
            .receiveTimeout = _callPacketTimeout,
            .dataSaving = callControllerDataSavingForType(dataSaving),
            .enableP2P = (bool)allowP2P,
            .allowTCP = (bool)allowTCP,
            .enableStunMarking = (bool)enableStunMarking,
            .enableAEC = false,
            .enableNS = true,
            .enableAGC = true,
            .enableCallUpgrade = false,
            .logPath = { std::string(logPath.length == 0 ? "" : logPath.UTF8String) },
            .statsLogPath = { std::string(statsLogPath.length == 0 ? "" : statsLogPath.UTF8String) },
            .maxApiLayer = [OngoingCallThreadLocalContextWebrtc maxLayer],
            .enableHighBitrateVideo = true,
            .preferredVideoCodecs = preferredVideoCodecs,
            .protocolVersion = [OngoingCallThreadLocalContextWebrtc protocolVersionFromLibraryVersion:version],
            .customParameters = customParametersString
        };
        
        auto encryptionKeyValue = std::make_shared<std::array<uint8_t, 256>>();
        memcpy(encryptionKeyValue->data(), key.bytes, key.length);
        
        tgcalls::EncryptionKey encryptionKey(encryptionKeyValue, isOutgoing);
        
        [OngoingCallThreadLocalContextWebrtc ensureRegisteredImplementations];
        
        std::shared_ptr<tgcalls::ThreadLocalObject<tgcalls::SharedAudioDeviceModule>> audioDeviceModule;
        if (_audioDevice) {
            audioDeviceModule = [_audioDevice getAudioDeviceModule];
        }
        
        std::shared_ptr<tgcalls::DirectConnectionChannel> directConnectionChannel;
        if (directConnection) {
            directConnectionChannel = std::static_pointer_cast<tgcalls::DirectConnectionChannel>(std::make_shared<DirectConnectionChannelImpl>(directConnection));
        }
        
        __weak OngoingCallThreadLocalContextWebrtc *weakSelf = self;
        _tgVoip = tgcalls::Meta::Create([version UTF8String], (tgcalls::Descriptor){
            .version = [version UTF8String],
            .config = config,
            .persistentState = (tgcalls::PersistentState){ derivedStateValue },
            .endpoints = endpoints,
            .proxy = std::move(proxyValue),
            .rtcServers = parsedRtcServers,
            .initialNetworkType = callControllerNetworkTypeForType(networkType),
            .encryptionKey = encryptionKey,
            .mediaDevicesConfig = tgcalls::MediaDevicesConfig {
                .audioInputId = [audioInputDeviceId UTF8String],
                .audioOutputId = [@"" UTF8String]
            },
            .videoCapture = [_videoCapturer getInterface],
            .stateUpdated = [weakSelf, queue](tgcalls::State state) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        [strongSelf controllerStateChanged:state];
                    }
                }];
            },
            .signalBarsUpdated = [weakSelf, queue](int value) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        strongSelf->_signalBars = value;
                        if (strongSelf->_signalBarsChanged) {
                            strongSelf->_signalBarsChanged(value);
                        }
                    }
                }];
            },
            .audioLevelUpdated = [weakSelf, queue](float level) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        if (strongSelf->_audioLevelUpdated) {
                            strongSelf->_audioLevelUpdated(level);
                        }
                    }
                }];
            },
            .remoteMediaStateUpdated = [weakSelf, queue](tgcalls::AudioState audioState, tgcalls::VideoState videoState) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        OngoingCallRemoteAudioStateWebrtc remoteAudioState;
                        OngoingCallRemoteVideoStateWebrtc remoteVideoState;
                        switch (audioState) {
                            case tgcalls::AudioState::Muted:
                                remoteAudioState = OngoingCallRemoteAudioStateMuted;
                                break;
                            case tgcalls::AudioState::Active:
                                remoteAudioState = OngoingCallRemoteAudioStateActive;
                                break;
                            default:
                                remoteAudioState = OngoingCallRemoteAudioStateMuted;
                                break;
                        }
                        switch (videoState) {
                            case tgcalls::VideoState::Inactive:
                                remoteVideoState = OngoingCallRemoteVideoStateInactive;
                                break;
                            case tgcalls::VideoState::Paused:
                                remoteVideoState = OngoingCallRemoteVideoStatePaused;
                                break;
                            case tgcalls::VideoState::Active:
                                remoteVideoState = OngoingCallRemoteVideoStateActive;
                                break;
                            default:
                                remoteVideoState = OngoingCallRemoteVideoStateInactive;
                                break;
                        }
                        if (strongSelf->_remoteVideoState != remoteVideoState || strongSelf->_remoteAudioState != remoteAudioState) {
                            strongSelf->_remoteVideoState = remoteVideoState;
                            strongSelf->_remoteAudioState = remoteAudioState;
                            if (strongSelf->_stateChanged) {
                                strongSelf->_stateChanged(strongSelf->_state, strongSelf->_videoState, strongSelf->_remoteVideoState, strongSelf->_remoteAudioState, strongSelf->_remoteBatteryLevel, strongSelf->_remotePreferredAspectRatio);
                            }
                        }
                    }
                }];
            },
            .remoteBatteryLevelIsLowUpdated = [weakSelf, queue](bool isLow) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        OngoingCallRemoteBatteryLevelWebrtc remoteBatteryLevel;
                        if (isLow) {
                            remoteBatteryLevel = OngoingCallRemoteBatteryLevelLow;
                        } else {
                            remoteBatteryLevel = OngoingCallRemoteBatteryLevelNormal;
                        }
                        if (strongSelf->_remoteBatteryLevel != remoteBatteryLevel) {
                            strongSelf->_remoteBatteryLevel = remoteBatteryLevel;
                            if (strongSelf->_stateChanged) {
                                strongSelf->_stateChanged(strongSelf->_state, strongSelf->_videoState, strongSelf->_remoteVideoState, strongSelf->_remoteAudioState, strongSelf->_remoteBatteryLevel, strongSelf->_remotePreferredAspectRatio);
                            }
                        }
                    }
                }];
            },
            .remotePrefferedAspectRatioUpdated = [weakSelf, queue](float value) {
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        strongSelf->_remotePreferredAspectRatio = value;
                        if (strongSelf->_stateChanged) {
                            strongSelf->_stateChanged(strongSelf->_state, strongSelf->_videoState, strongSelf->_remoteVideoState, strongSelf->_remoteAudioState, strongSelf->_remoteBatteryLevel, strongSelf->_remotePreferredAspectRatio);
                        }
                    }
                }];
            },
            .signalingDataEmitted = [weakSelf, queue](const std::vector<uint8_t> &data) {
                NSData *mappedData = [[NSData alloc] initWithBytes:data.data() length:data.size()];
                [queue dispatch:^{
                    __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                    if (strongSelf) {
                        [strongSelf signalingDataEmitted:mappedData];
                    }
                }];
            },
            .createAudioDeviceModule = [weakSelf, queue, audioDeviceModule](webrtc::TaskQueueFactory *taskQueueFactory) -> rtc::scoped_refptr<webrtc::AudioDeviceModule> {
                if (audioDeviceModule) {
                    return audioDeviceModule->getSyncAssumingSameThread()->audioDeviceModule();
                } else {
                    rtc::Thread *audioDeviceModuleThread = rtc::Thread::Current();
                    auto resultModule = rtc::make_ref_counted<webrtc::tgcalls_ios_adm::AudioDeviceModuleIOS>(false, false, false, 1);
                    [queue dispatch:^{
                        __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                        if (strongSelf) {
                            strongSelf->_currentAudioDeviceModuleThread = audioDeviceModuleThread;
                            strongSelf->_currentAudioDeviceModule = resultModule;
                        }
                    }];
                    return resultModule;
                }
            },
            .createWrappedAudioDeviceModule = [audioDeviceModule](webrtc::TaskQueueFactory *taskQueueFactory) -> rtc::scoped_refptr<tgcalls::WrappedAudioDeviceModule> {
                if (audioDeviceModule) {
                    auto result = audioDeviceModule->getSyncAssumingSameThread()->makeChildAudioDeviceModule();
                    ((WrappedChildAudioDeviceModule *)result.get())->setIsActive();
                    return result;
                } else {
                    return nullptr;
                }
            },
            .directConnectionChannel = directConnectionChannel
        });
        _state = OngoingCallStateInitializing;
        _pendingState = OngoingCallStateInitializing;
        _signalBars = 4;
    }
    return self;
}

- (void)dealloc {
    if (InternalVoipLoggingFunction) {
        InternalVoipLoggingFunction(@"OngoingCallThreadLocalContext: dealloc");
    }
    
    if (_currentAudioDeviceModuleThread) {
        auto currentAudioDeviceModule = _currentAudioDeviceModule;
        _currentAudioDeviceModule = nullptr;
        _currentAudioDeviceModuleThread->PostTask([currentAudioDeviceModule]() {
        });
        _currentAudioDeviceModuleThread = nullptr;
    }
    
    [_pushStateDisposable dispose];
    
    if (_tgVoip != NULL) {
        [self stop:nil];
    }
}

- (bool)needRate {
    return false;
}

- (void)beginTermination {
}

- (void)setManualAudioSessionIsActive:(bool)isAudioSessionActive {
    if (_useManualAudioSessionControl) {
        if (isAudioSessionActive) {
            [[RTCAudioSession sharedInstance] audioSessionDidActivate:[AVAudioSession sharedInstance]];
        } else {
            [[RTCAudioSession sharedInstance] audioSessionDidDeactivate:[AVAudioSession sharedInstance]];
        }
        [RTCAudioSession sharedInstance].isAudioEnabled = isAudioSessionActive;
    }
}

+ (void)stopWithTerminationResult:(OngoingCallThreadLocalContextWebrtcTerminationResult *)terminationResult completion:(void (^)(NSString *, int64_t, int64_t, int64_t, int64_t))completion {
    if (completion) {
        if (terminationResult) {
            NSString *debugLog = [NSString stringWithUTF8String:terminationResult.finalState.debugLog.c_str()];
            
            if (completion) {
                completion(debugLog, terminationResult.finalState.trafficStats.bytesSentWifi, terminationResult.finalState.trafficStats.bytesReceivedWifi, terminationResult.finalState.trafficStats.bytesSentMobile, terminationResult.finalState.trafficStats.bytesReceivedMobile);
            }
        } else {
            if (completion) {
                completion(@"", 0, 0, 0, 0);
            }
        }
    }
}

- (void)stop:(void (^)(NSString *, int64_t, int64_t, int64_t, int64_t))completion {
    if (!_tgVoip) {
        return;
    }
    if (completion == nil) {
        if (!_didStop) {
            _tgVoip->stop([](tgcalls::FinalState finalState) {
            });
        }
        _tgVoip.reset();
        return;
    }
    
    __weak OngoingCallThreadLocalContextWebrtc *weakSelf = self;
    id<OngoingCallThreadLocalContextQueueWebrtc> queue = _queue;
    _didStop = true;
    _tgVoip->stop([weakSelf, queue, completion = [completion copy]](tgcalls::FinalState finalState) {
        [queue dispatch:^{
            __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
            if (strongSelf) {
                strongSelf->_tgVoip.reset();
            }
            
            OngoingCallThreadLocalContextWebrtcTerminationResult *terminationResult = [[OngoingCallThreadLocalContextWebrtcTerminationResult alloc] initWithFinalState:finalState];
            
            [OngoingCallThreadLocalContextWebrtc stopWithTerminationResult:terminationResult completion:completion];
        }];
    });
}

- (NSString *)debugInfo {
    if (_tgVoip != nullptr) {
        NSString *version = [self version];
        return [NSString stringWithFormat:@"WebRTC, Version: %@", version];
        //auto rawDebugString = _tgVoip->getDebugInfo();
        //return [NSString stringWithUTF8String:rawDebugString.c_str()];
    } else {
        return nil;
    }
}

- (NSString *)version {
    return _version;
}

- (NSData * _Nonnull)getDerivedState {
    if (_tgVoip) {
        auto persistentState = _tgVoip->getPersistentState();
        return [[NSData alloc] initWithBytes:persistentState.value.data() length:persistentState.value.size()];
    } else if (_lastDerivedState != nil) {
        return _lastDerivedState;
    } else {
        return [NSData data];
    }
}

- (void)pushPendingState {
    _didPushStateOnce = true;
    
    if (_state != _pendingState) {
        _state = _pendingState;
        
        if (_stateChanged) {
            _stateChanged(_state, _videoState, _remoteVideoState, _remoteAudioState, _remoteBatteryLevel, _remotePreferredAspectRatio);
        }
    }
}

- (void)controllerStateChanged:(tgcalls::State)state {
    OngoingCallStateWebrtc callState = OngoingCallStateInitializing;
    switch (state) {
        case tgcalls::State::Established:
            callState = OngoingCallStateConnected;
            break;
        case tgcalls::State::Failed:
            callState = OngoingCallStateFailed;
            break;
        case tgcalls::State::Reconnecting:
            callState = OngoingCallStateReconnecting;
            break;
        default:
            break;
    }
    
    if (_pendingState != callState) {
        _pendingState = callState;
        
        [_pushStateDisposable dispose];
        _pushStateDisposable = nil;
        
        bool maybeDelayPush = false;
        if (!_didPushStateOnce) {
            maybeDelayPush = false;
        } else if (callState == OngoingCallStateReconnecting) {
            maybeDelayPush = true;
        } else {
            maybeDelayPush = false;
        }
        
        if (!maybeDelayPush) {
            [self pushPendingState];
        } else {
            __weak OngoingCallThreadLocalContextWebrtc *weakSelf = self;
            _pushStateDisposable = [_queue scheduleBlock:^{
                __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                [strongSelf pushPendingState];
            } after:1.0];
        }
    }
}

- (void)signalBarsChanged:(int32_t)signalBars {
    if (signalBars != _signalBars) {
        _signalBars = signalBars;
        
        if (_signalBarsChanged) {
            _signalBarsChanged(signalBars);
        }
    }
}

- (void)signalingDataEmitted:(NSData *)data {
    if (_sendSignalingData) {
        _sendSignalingData(data);
    }
}


- (void)addSignalingData:(NSData *)data {
    if (_tgVoip) {
        std::vector<uint8_t> mappedData;
        mappedData.resize(data.length);
        [data getBytes:mappedData.data() length:data.length];
        _tgVoip->receiveSignalingData(mappedData);
    }
}

- (void)setIsMuted:(bool)isMuted {
    if (_tgVoip) {
        _tgVoip->setMuteMicrophone(isMuted);
    }
}

- (void)setIsLowBatteryLevel:(bool)isLowBatteryLevel {
    if (_tgVoip) {
        _tgVoip->setIsLowBatteryLevel(isLowBatteryLevel);
    }
}

- (void)setNetworkType:(OngoingCallNetworkTypeWebrtc)networkType {
    if (_networkType != networkType) {
        _networkType = networkType;
        if (_tgVoip) {
            _tgVoip->setNetworkType(callControllerNetworkTypeForType(networkType));
        }
    }
}

- (GroupCallDisposable * _Nonnull)addVideoOutputWithIsIncoming:(bool)isIncoming sink:(void (^_Nonnull)(CallVideoFrameData * _Nonnull))sink {
    int sinkId = _nextSinkId;
    _nextSinkId += 1;
    
    GroupCallVideoSink *storedSink = [[GroupCallVideoSink alloc] initWithSink:sink];
    _sinks[@(sinkId)] = storedSink;

    if (_tgVoip) {
        if (isIncoming) {
            _tgVoip->setIncomingVideoOutput([storedSink sink]);
        }
    }

    __weak OngoingCallThreadLocalContextWebrtc *weakSelf = self;
    id<OngoingCallThreadLocalContextQueueWebrtc> queue = _queue;
    return [[GroupCallDisposable alloc] initWithBlock:^{
        [queue dispatch:^{
            __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            [strongSelf->_sinks removeObjectForKey:@(sinkId)];
        }];
    }];
}

- (void)makeIncomingVideoView:(void (^_Nonnull)(UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable))completion {
    if (_tgVoip) {
        __weak OngoingCallThreadLocalContextWebrtc *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            VideoMetalView *remoteRenderer = [[VideoMetalView alloc] initWithFrame:CGRectZero];
#if TARGET_OS_IPHONE
            remoteRenderer.videoContentMode = UIViewContentModeScaleToFill;
#else
            remoteRenderer.videoContentMode = UIViewContentModeScaleAspect;
#endif
            
            std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
            __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
            if (strongSelf) {
                [remoteRenderer setOrientation:strongSelf->_remoteVideoOrientation];
                strongSelf->_currentRemoteVideoRenderer = remoteRenderer;
                strongSelf->_tgVoip->setIncomingVideoOutput(sink);
            }
            
            completion(remoteRenderer);
        });
    }
}

- (void)requestVideo:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer {
    if (_tgVoip && _videoCapturer == nil) {
        _videoCapturer = videoCapturer;
        _tgVoip->setVideoCapture([_videoCapturer getInterface]);
        
        _videoState = OngoingCallVideoStateActive;
        if (_stateChanged) {
            _stateChanged(_state, _videoState, _remoteVideoState, _remoteAudioState, _remoteBatteryLevel, _remotePreferredAspectRatio);
        }
    }
}

- (void)setRequestedVideoAspect:(float)aspect {
    if (_tgVoip) {
        _tgVoip->setRequestedVideoAspect(aspect);
    }
}

- (void)disableVideo {
    if (_tgVoip) {
        _videoCapturer = nil;
        _tgVoip->setVideoCapture(nullptr);
        
        _videoState = OngoingCallVideoStateInactive;
        if (_stateChanged) {
            _stateChanged(_state, _videoState, _remoteVideoState, _remoteAudioState, _remoteBatteryLevel, _remotePreferredAspectRatio);
        }
    }
}

- (void)remotePrefferedAspectRatioUpdated:(float)remotePrefferedAspectRatio {
    
}

- (void)switchAudioOutput:(NSString * _Nonnull)deviceId {
    _tgVoip->setAudioOutputDevice(deviceId.UTF8String);
}
- (void)switchAudioInput:(NSString * _Nonnull)deviceId {
    _tgVoip->setAudioInputDevice(deviceId.UTF8String);
}

- (void)addExternalAudioData:(NSData * _Nonnull)data {
    if (_tgVoip) {
        std::vector<uint8_t> samples;
        samples.resize(data.length);
        [data getBytes:samples.data() length:data.length];
        _tgVoip->addExternalAudioSamples(std::move(samples));
    }
}

@end

namespace {

class BroadcastPartTaskImpl : public tgcalls::BroadcastPartTask {
public:
    BroadcastPartTaskImpl(id<OngoingGroupCallBroadcastPartTask> task) {
        _task = task;
    }
    
    virtual ~BroadcastPartTaskImpl() {
    }
    
    virtual void cancel() override {
        [_task cancel];
    }
    
private:
    id<OngoingGroupCallBroadcastPartTask> _task;
};

class RequestMediaChannelDescriptionTaskImpl : public tgcalls::RequestMediaChannelDescriptionTask {
public:
    RequestMediaChannelDescriptionTaskImpl(id<OngoingGroupCallMediaChannelDescriptionTask> task) {
        _task = task;
    }

    virtual ~RequestMediaChannelDescriptionTaskImpl() {
    }

    virtual void cancel() override {
        [_task cancel];
    }

private:
    id<OngoingGroupCallMediaChannelDescriptionTask> _task;
};

}

@interface GroupCallThreadLocalContext () {
    id<OngoingCallThreadLocalContextQueueWebrtc> _queue;

    std::unique_ptr<tgcalls::GroupInstanceInterface> _instance;
    OngoingCallThreadLocalContextVideoCapturer *_videoCapturer;

    void (^_networkStateUpdated)(GroupCallNetworkState);

    int _nextSinkId;
    NSMutableDictionary<NSNumber *, GroupCallVideoSink *> *_sinks;
    
    rtc::scoped_refptr<webrtc::tgcalls_ios_adm::AudioDeviceModuleIOS> _currentAudioDeviceModule;
    rtc::Thread *_currentAudioDeviceModuleThread;
    
    SharedCallAudioDevice * _audioDevice;
    
    void (^_onMutedSpeechActivityDetected)(bool);
    
    int32_t _signalBars;
}

@end

@implementation GroupCallThreadLocalContext

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue
    networkStateUpdated:(void (^ _Nonnull)(GroupCallNetworkState))networkStateUpdated
    audioLevelsUpdated:(void (^ _Nonnull)(NSArray<NSNumber *> * _Nonnull))audioLevelsUpdated
    activityUpdated:(void (^ _Nonnull)(NSArray<NSNumber *> * _Nonnull))activityUpdated
    inputDeviceId:(NSString * _Nonnull)inputDeviceId
    outputDeviceId:(NSString * _Nonnull)outputDeviceId
    videoCapturer:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer
    requestMediaChannelDescriptions:(id<OngoingGroupCallMediaChannelDescriptionTask> _Nonnull (^ _Nonnull)(NSArray<NSNumber *> * _Nonnull, void (^ _Nonnull)(NSArray<OngoingGroupCallMediaChannelDescription *> * _Nonnull)))requestMediaChannelDescriptions
    requestCurrentTime:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(void (^ _Nonnull)(int64_t)))requestCurrentTime
    requestAudioBroadcastPart:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(int64_t, int64_t, void (^ _Nonnull)(OngoingGroupCallBroadcastPart * _Nullable)))requestAudioBroadcastPart
    requestVideoBroadcastPart:(id<OngoingGroupCallBroadcastPartTask> _Nonnull (^ _Nonnull)(int64_t, int64_t, int32_t, OngoingGroupCallRequestedVideoQuality, void (^ _Nonnull)(OngoingGroupCallBroadcastPart * _Nullable)))requestVideoBroadcastPart
    outgoingAudioBitrateKbit:(int32_t)outgoingAudioBitrateKbit
    videoContentType:(OngoingGroupCallVideoContentType)videoContentType
    enableNoiseSuppression:(bool)enableNoiseSuppression
    disableAudioInput:(bool)disableAudioInput
    enableSystemMute:(bool)enableSystemMute
    preferX264:(bool)preferX264
    logPath:(NSString * _Nonnull)logPath
statsLogPath:(NSString * _Nonnull)statsLogPath
onMutedSpeechActivityDetected:(void (^ _Nullable)(bool))onMutedSpeechActivityDetected
audioDevice:(SharedCallAudioDevice * _Nullable)audioDevice
encryptionKey:(NSData * _Nullable)encryptionKey
isConference:(bool)isConference {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        
        tgcalls::PlatformInterface::SharedInstance()->preferX264 = preferX264;

        _sinks = [[NSMutableDictionary alloc] init];
        
        _networkStateUpdated = [networkStateUpdated copy];
        _videoCapturer = videoCapturer;
        
        _onMutedSpeechActivityDetected = [onMutedSpeechActivityDetected copy];
        
        _audioDevice = audioDevice;
        std::shared_ptr<tgcalls::ThreadLocalObject<tgcalls::SharedAudioDeviceModule>> audioDeviceModule;
        if (_audioDevice) {
            audioDeviceModule = [_audioDevice getAudioDeviceModule];
        }
        
        tgcalls::VideoContentType _videoContentType;
        switch (videoContentType) {
            case OngoingGroupCallVideoContentTypeGeneric: {
                _videoContentType = tgcalls::VideoContentType::Generic;
                break;
            }
            case OngoingGroupCallVideoContentTypeScreencast: {
                _videoContentType = tgcalls::VideoContentType::Screencast;
                break;
            }
            case OngoingGroupCallVideoContentTypeNone: {
                _videoContentType = tgcalls::VideoContentType::None;
                break;
            }
            default: {
                _videoContentType = tgcalls::VideoContentType::None;
                break;
            }
        }
        
#ifdef WEBRTC_IOS
        RTCAudioSessionConfiguration *sharedConfiguration = [RTCAudioSessionConfiguration webRTCConfiguration];
        sharedConfiguration.mode = AVAudioSessionModeVoiceChat;
        sharedConfiguration.categoryOptions |= AVAudioSessionCategoryOptionMixWithOthers;
        sharedConfiguration.categoryOptions |= AVAudioSessionCategoryOptionAllowBluetoothA2DP;
        if (disableAudioInput) {
            sharedConfiguration.outputNumberOfChannels = 2;
        } else {
            sharedConfiguration.outputNumberOfChannels = 1;
        }
        [RTCAudioSessionConfiguration setWebRTCConfiguration:sharedConfiguration];
        
        /*[RTCAudioSession sharedInstance].useManualAudio = true;
         [[RTCAudioSession sharedInstance] audioSessionDidActivate:[AVAudioSession sharedInstance]];
         [RTCAudioSession sharedInstance].isAudioEnabled = true;*/
#endif
        
        std::vector<tgcalls::VideoCodecName> videoCodecPreferences;

        int minOutgoingVideoBitrateKbit = 500;
        bool disableOutgoingAudioProcessing = false;

        tgcalls::GroupConfig config;
        config.need_log = true;
        config.logPath.data = std::string(logPath.length == 0 ? "" : logPath.UTF8String);
        
        std::string statsLogPathValue(statsLogPath.length == 0 ? "" : statsLogPath.UTF8String);
        
        std::optional<tgcalls::EncryptionKey> mappedEncryptionKey;
        if (encryptionKey) {
            auto encryptionKeyValue = std::make_shared<std::array<uint8_t, 256>>();
            memcpy(encryptionKeyValue->data(), encryptionKey.bytes, encryptionKey.length);
            
            #if DEBUG
            NSLog(@"Encryption key: %@", [encryptionKey base64EncodedStringWithOptions:0]);
            #endif
            
            mappedEncryptionKey = tgcalls::EncryptionKey(encryptionKeyValue, true);
        }

        __weak GroupCallThreadLocalContext *weakSelf = self;
        _instance.reset(new tgcalls::GroupInstanceCustomImpl((tgcalls::GroupInstanceDescriptor){
            .threads = tgcalls::StaticThreads::getThreads(),
            .config = config,
            .statsLogPath = statsLogPathValue,
            .networkStateUpdated = [weakSelf, queue, networkStateUpdated](tgcalls::GroupNetworkState networkState) {
                [queue dispatch:^{
                    __strong GroupCallThreadLocalContext *strongSelf = weakSelf;
                    if (strongSelf == nil) {
                        return;
                    }
                    GroupCallNetworkState mappedState;
                    mappedState.isConnected = networkState.isConnected;
                    mappedState.isTransitioningFromBroadcastToRtc = networkState.isTransitioningFromBroadcastToRtc;
                    networkStateUpdated(mappedState);
                }];
            },
            .signalBarsUpdated = [weakSelf, queue](int value) {
                [queue dispatch:^{
                    __strong GroupCallThreadLocalContext *strongSelf = weakSelf;
                    if (strongSelf) {
                        strongSelf->_signalBars = value;
                        if (strongSelf->_signalBarsChanged) {
                            strongSelf->_signalBarsChanged(value);
                        }
                    }
                }];
            },
            .audioLevelsUpdated = [audioLevelsUpdated](tgcalls::GroupLevelsUpdate const &levels) {
                NSMutableArray *result = [[NSMutableArray alloc] init];
                for (auto &it : levels.updates) {
                    [result addObject:@(it.ssrc)];
                    auto level = it.value.level;
                    if (it.value.isMuted) {
                        level = 0.0;
                    }
                    [result addObject:@(level)];
                    [result addObject:@(it.value.voice)];
                }
                audioLevelsUpdated(result);
            },
            .ssrcActivityUpdated = [activityUpdated](tgcalls::GroupActivitiesUpdate const &update) {
                NSMutableArray *result = [[NSMutableArray alloc] init];
                for (auto &it : update.updates) {
                    [result addObject:@(it.ssrc)];
                }
                activityUpdated(result);
            },
            .initialInputDeviceId = inputDeviceId.UTF8String,
            .initialOutputDeviceId = outputDeviceId.UTF8String,
            .videoCapture = [_videoCapturer getInterface],
            .requestCurrentTime = [requestCurrentTime](std::function<void(int64_t)> completion) {
                id<OngoingGroupCallBroadcastPartTask> task = requestCurrentTime(^(int64_t result) {
                    completion(result);
                });
                return std::make_shared<BroadcastPartTaskImpl>(task);
            },
            .requestAudioBroadcastPart = [requestAudioBroadcastPart](int64_t timestampMilliseconds, int64_t durationMilliseconds, std::function<void(tgcalls::BroadcastPart &&)> completion) -> std::shared_ptr<tgcalls::BroadcastPartTask> {
                id<OngoingGroupCallBroadcastPartTask> task = requestAudioBroadcastPart(timestampMilliseconds, durationMilliseconds, ^(OngoingGroupCallBroadcastPart * _Nullable part) {
                    tgcalls::BroadcastPart parsedPart;
                    parsedPart.timestampMilliseconds = part.timestampMilliseconds;
                    
                    parsedPart.responseTimestamp = part.responseTimestamp;
                    
                    tgcalls::BroadcastPart::Status mappedStatus;
                    switch (part.status) {
                        case OngoingGroupCallBroadcastPartStatusSuccess: {
                            mappedStatus = tgcalls::BroadcastPart::Status::Success;
                            break;
                        }
                        case OngoingGroupCallBroadcastPartStatusNotReady: {
                            mappedStatus = tgcalls::BroadcastPart::Status::NotReady;
                            break;
                        }
                        case OngoingGroupCallBroadcastPartStatusResyncNeeded: {
                            mappedStatus = tgcalls::BroadcastPart::Status::ResyncNeeded;
                            break;
                        }
                        default: {
                            mappedStatus = tgcalls::BroadcastPart::Status::NotReady;
                            break;
                        }
                    }
                    parsedPart.status = mappedStatus;
                    
                    parsedPart.data.resize(part.oggData.length);
                    [part.oggData getBytes:parsedPart.data.data() length:part.oggData.length];
                    
                    completion(std::move(parsedPart));
                });
                return std::make_shared<BroadcastPartTaskImpl>(task);
            },
            .requestVideoBroadcastPart = [requestVideoBroadcastPart](int64_t timestampMilliseconds, int64_t durationMilliseconds, int32_t channelId, tgcalls::VideoChannelDescription::Quality quality, std::function<void(tgcalls::BroadcastPart &&)> completion) -> std::shared_ptr<tgcalls::BroadcastPartTask> {
                OngoingGroupCallRequestedVideoQuality mappedQuality;
                switch (quality) {
                    case tgcalls::VideoChannelDescription::Quality::Thumbnail: {
                        mappedQuality = OngoingGroupCallRequestedVideoQualityThumbnail;
                        break;
                    }
                    case tgcalls::VideoChannelDescription::Quality::Medium: {
                        mappedQuality = OngoingGroupCallRequestedVideoQualityMedium;
                        break;
                    }
                    case tgcalls::VideoChannelDescription::Quality::Full: {
                        mappedQuality = OngoingGroupCallRequestedVideoQualityFull;
                        break;
                    }
                    default: {
                        mappedQuality = OngoingGroupCallRequestedVideoQualityThumbnail;
                        break;
                    }
                }
                id<OngoingGroupCallBroadcastPartTask> task = requestVideoBroadcastPart(timestampMilliseconds, durationMilliseconds, channelId, mappedQuality, ^(OngoingGroupCallBroadcastPart * _Nullable part) {
                    tgcalls::BroadcastPart parsedPart;
                    parsedPart.timestampMilliseconds = part.timestampMilliseconds;

                    parsedPart.responseTimestamp = part.responseTimestamp;

                    tgcalls::BroadcastPart::Status mappedStatus;
                    switch (part.status) {
                        case OngoingGroupCallBroadcastPartStatusSuccess: {
                            mappedStatus = tgcalls::BroadcastPart::Status::Success;
                            break;
                        }
                        case OngoingGroupCallBroadcastPartStatusNotReady: {
                            mappedStatus = tgcalls::BroadcastPart::Status::NotReady;
                            break;
                        }
                        case OngoingGroupCallBroadcastPartStatusResyncNeeded: {
                            mappedStatus = tgcalls::BroadcastPart::Status::ResyncNeeded;
                            break;
                        }
                        default: {
                            mappedStatus = tgcalls::BroadcastPart::Status::NotReady;
                            break;
                        }
                    }
                    parsedPart.status = mappedStatus;

                    parsedPart.data.resize(part.oggData.length);
                    [part.oggData getBytes:parsedPart.data.data() length:part.oggData.length];

                    completion(std::move(parsedPart));
                });
                return std::make_shared<BroadcastPartTaskImpl>(task);
            },
            .outgoingAudioBitrateKbit = outgoingAudioBitrateKbit,
            .disableOutgoingAudioProcessing = disableOutgoingAudioProcessing,
            .disableAudioInput = disableAudioInput,
            .ios_enableSystemMute = enableSystemMute,
            .videoContentType = _videoContentType,
            .videoCodecPreferences = videoCodecPreferences,
            .initialEnableNoiseSuppression = enableNoiseSuppression,
            .requestMediaChannelDescriptions = [requestMediaChannelDescriptions](std::vector<uint32_t> const &ssrcs, std::function<void(std::vector<tgcalls::MediaChannelDescription> &&)> completion) -> std::shared_ptr<tgcalls::RequestMediaChannelDescriptionTask> {
                NSMutableArray<NSNumber *> *mappedSsrcs = [[NSMutableArray alloc] init];
                for (auto ssrc : ssrcs) {
                    [mappedSsrcs addObject:[NSNumber numberWithUnsignedInt:ssrc]];
                }
                id<OngoingGroupCallMediaChannelDescriptionTask> task = requestMediaChannelDescriptions(mappedSsrcs, ^(NSArray<OngoingGroupCallMediaChannelDescription *> *channels) {
                    std::vector<tgcalls::MediaChannelDescription> mappedChannels;
                    for (OngoingGroupCallMediaChannelDescription *channel in channels) {
                        tgcalls::MediaChannelDescription mappedChannel;
                        switch (channel.type) {
                            case OngoingGroupCallMediaChannelTypeAudio: {
                                mappedChannel.type = tgcalls::MediaChannelDescription::Type::Audio;
                                break;
                            }
                            case OngoingGroupCallMediaChannelTypeVideo: {
                                mappedChannel.type = tgcalls::MediaChannelDescription::Type::Video;
                                break;
                            }
                            default: {
                                continue;
                            }
                        }
                        mappedChannel.audioSsrc = channel.audioSsrc;
                        mappedChannel.videoInformation = channel.videoDescription.UTF8String ?: "";
                        mappedChannels.push_back(std::move(mappedChannel));
                    }

                    completion(std::move(mappedChannels));
                });

                return std::make_shared<RequestMediaChannelDescriptionTaskImpl>(task);
            },
            .minOutgoingVideoBitrateKbit = minOutgoingVideoBitrateKbit,
            .createAudioDeviceModule = [weakSelf, queue, disableAudioInput, enableSystemMute, audioDeviceModule, onMutedSpeechActivityDetected = _onMutedSpeechActivityDetected](webrtc::TaskQueueFactory *taskQueueFactory) -> rtc::scoped_refptr<webrtc::AudioDeviceModule> {
                if (audioDeviceModule) {
                    return audioDeviceModule->getSyncAssumingSameThread()->audioDeviceModule();
                } else {
                    rtc::Thread *audioDeviceModuleThread = rtc::Thread::Current();
                    auto resultModule = rtc::make_ref_counted<webrtc::tgcalls_ios_adm::AudioDeviceModuleIOS>(false, disableAudioInput, enableSystemMute, disableAudioInput ? 2 : 1);
                    if (resultModule) {
                        resultModule->mutedSpeechDetectionChanged = ^(bool value) {
                            if (onMutedSpeechActivityDetected) {
                                onMutedSpeechActivityDetected(value);
                            }
                        };
                    }
                    [queue dispatch:^{
                        __strong GroupCallThreadLocalContext *strongSelf = weakSelf;
                        if (strongSelf) {
                            strongSelf->_currentAudioDeviceModuleThread = audioDeviceModuleThread;
                            strongSelf->_currentAudioDeviceModule = resultModule;
                        }
                    }];
                    return resultModule;
                }
            },
            .createWrappedAudioDeviceModule = [audioDeviceModule](webrtc::TaskQueueFactory *taskQueueFactory) -> rtc::scoped_refptr<tgcalls::WrappedAudioDeviceModule> {
                if (audioDeviceModule) {
                    auto result = audioDeviceModule->getSyncAssumingSameThread()->makeChildAudioDeviceModule();
                    ((WrappedChildAudioDeviceModule *)result.get())->setIsActive();
                    return result;
                } else {
                    return nullptr;
                }
            },
            .onMutedSpeechActivityDetected = [weakSelf, queue](bool value) {
                [queue dispatch:^{
                    __strong GroupCallThreadLocalContext *strongSelf = weakSelf;
                    if (strongSelf && strongSelf->_onMutedSpeechActivityDetected) {
                        strongSelf->_onMutedSpeechActivityDetected(value);
                    }
                }];
            },
            .encryptionKey = mappedEncryptionKey,
            .isConference = isConference
        }));
    }
    return self;
}

- (void)dealloc {
    if (_currentAudioDeviceModuleThread) {
        auto currentAudioDeviceModule = _currentAudioDeviceModule;
        _currentAudioDeviceModule = nullptr;
        _currentAudioDeviceModuleThread->PostTask([currentAudioDeviceModule]() {
        });
        _currentAudioDeviceModuleThread = nullptr;
    }
}

- (void)stop:(void (^ _Nullable)())completion {
    if (_currentAudioDeviceModuleThread) {
        auto currentAudioDeviceModule = _currentAudioDeviceModule;
        _currentAudioDeviceModule = nullptr;
        _currentAudioDeviceModuleThread->PostTask([currentAudioDeviceModule]() {
        });
        _currentAudioDeviceModuleThread = nullptr;
    }
    
    if (_instance) {
        void (^capturedCompletion)() = [completion copy];
        _instance->stop([capturedCompletion] {
            if (capturedCompletion) {
                capturedCompletion();
            }
        });
        _instance.reset();
    } else {
        if (completion) {
            completion();
        }
    }
}

- (void)setTone:(CallAudioTone * _Nullable)tone {
    if (_currentAudioDeviceModuleThread) {
        auto currentAudioDeviceModule = _currentAudioDeviceModule;
        if (currentAudioDeviceModule) {
            _currentAudioDeviceModuleThread->PostTask([currentAudioDeviceModule, tone]() {
                currentAudioDeviceModule->setTone([tone asTone]);
            });
        }
    }
}

- (void)setManualAudioSessionIsActive:(bool)isAudioSessionActive {
    if (isAudioSessionActive) {
        [[RTCAudioSession sharedInstance] audioSessionDidActivate:[AVAudioSession sharedInstance]];
    } else {
        [[RTCAudioSession sharedInstance] audioSessionDidDeactivate:[AVAudioSession sharedInstance]];
    }
    [RTCAudioSession sharedInstance].isAudioEnabled = isAudioSessionActive;
}

- (void)setConnectionMode:(OngoingCallConnectionMode)connectionMode keepBroadcastConnectedIfWasEnabled:(bool)keepBroadcastConnectedIfWasEnabled isUnifiedBroadcast:(bool)isUnifiedBroadcast {
    if (_instance) {
        tgcalls::GroupConnectionMode mappedConnectionMode;
        switch (connectionMode) {
            case OngoingCallConnectionModeNone: {
                mappedConnectionMode = tgcalls::GroupConnectionMode::GroupConnectionModeNone;
                break;
            }
            case OngoingCallConnectionModeRtc: {
                mappedConnectionMode = tgcalls::GroupConnectionMode::GroupConnectionModeRtc;
                break;
            }
            case OngoingCallConnectionModeBroadcast: {
                mappedConnectionMode = tgcalls::GroupConnectionMode::GroupConnectionModeBroadcast;
                break;
            }
            default: {
                mappedConnectionMode = tgcalls::GroupConnectionMode::GroupConnectionModeNone;
                break;
            }
        }
        _instance->setConnectionMode(mappedConnectionMode, keepBroadcastConnectedIfWasEnabled, isUnifiedBroadcast);
    }
}

- (void)emitJoinPayload:(void (^ _Nonnull)(NSString * _Nonnull, uint32_t))completion {
    if (_instance) {
        _instance->emitJoinPayload([completion](tgcalls::GroupJoinPayload const &payload) {
            completion([NSString stringWithUTF8String:payload.json.c_str()], payload.audioSsrc);
        });
    }
}

- (void)setJoinResponsePayload:(NSString * _Nonnull)payload {
    if (_instance) {
        _instance->setJoinResponsePayload(payload.UTF8String);
    }
}

- (void)removeSsrcs:(NSArray<NSNumber *> * _Nonnull)ssrcs {
    if (_instance) {
        std::vector<uint32_t> values;
        for (NSNumber *ssrc in ssrcs) {
            values.push_back([ssrc unsignedIntValue]);
        }
        _instance->removeSsrcs(values);
    }
}

- (void)removeIncomingVideoSource:(uint32_t)ssrc {
    if (_instance) {
        _instance->removeIncomingVideoSource(ssrc);
    }
}

- (void)setIsMuted:(bool)isMuted {
    if (_instance) {
        _instance->setIsMuted(isMuted);
    }
}

- (void)setIsNoiseSuppressionEnabled:(bool)isNoiseSuppressionEnabled {
    if (_instance) {
        _instance->setIsNoiseSuppressionEnabled(isNoiseSuppressionEnabled);
    }
}

- (void)requestVideo:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer completion:(void (^ _Nonnull)(NSString * _Nonnull, uint32_t))completion {
    if (_instance) {
        _instance->setVideoCapture([videoCapturer getInterface]);
    }
}

- (void)disableVideo:(void (^ _Nonnull)(NSString * _Nonnull, uint32_t))completion {
    if (_instance) {
        _instance->setVideoCapture(nullptr);
    }
}

- (void)setVolumeForSsrc:(uint32_t)ssrc volume:(double)volume {
    if (_instance) {
        _instance->setVolume(ssrc, volume);
    }
}

- (void)setRequestedVideoChannels:(NSArray<OngoingGroupCallRequestedVideoChannel *> * _Nonnull)requestedVideoChannels {
    if (_instance) {
        std::vector<tgcalls::VideoChannelDescription> mappedChannels;
        for (OngoingGroupCallRequestedVideoChannel *channel : requestedVideoChannels) {
            tgcalls::VideoChannelDescription description;
            description.audioSsrc = channel.audioSsrc;
            description.endpointId = channel.endpointId.UTF8String ?: "";
            for (OngoingGroupCallSsrcGroup *group in channel.ssrcGroups) {
                tgcalls::MediaSsrcGroup parsedGroup;
                parsedGroup.semantics = group.semantics.UTF8String ?: "";
                for (NSNumber *ssrc in group.ssrcs) {
                    parsedGroup.ssrcs.push_back([ssrc unsignedIntValue]);
                }
                description.ssrcGroups.push_back(std::move(parsedGroup));
            }
            switch (channel.minQuality) {
                case OngoingGroupCallRequestedVideoQualityThumbnail: {
                    description.minQuality = tgcalls::VideoChannelDescription::Quality::Thumbnail;
                    break;
                }
                case OngoingGroupCallRequestedVideoQualityMedium: {
                    description.minQuality = tgcalls::VideoChannelDescription::Quality::Medium;
                    break;
                }
                case OngoingGroupCallRequestedVideoQualityFull: {
                    description.minQuality = tgcalls::VideoChannelDescription::Quality::Full;
                    break;
                }
                default: {
                    break;
                }
            }
            switch (channel.maxQuality) {
                case OngoingGroupCallRequestedVideoQualityThumbnail: {
                    description.maxQuality = tgcalls::VideoChannelDescription::Quality::Thumbnail;
                    break;
                }
                case OngoingGroupCallRequestedVideoQualityMedium: {
                    description.maxQuality = tgcalls::VideoChannelDescription::Quality::Medium;
                    break;
                }
                case OngoingGroupCallRequestedVideoQualityFull: {
                    description.maxQuality = tgcalls::VideoChannelDescription::Quality::Full;
                    break;
                }
                default: {
                    break;
                }
            }
            mappedChannels.push_back(std::move(description));
        }
        _instance->setRequestedVideoChannels(std::move(mappedChannels));
    }
}

- (void)switchAudioOutput:(NSString * _Nonnull)deviceId {
    if (_instance) {
        _instance->setAudioOutputDevice(deviceId.UTF8String);
    }
}
- (void)switchAudioInput:(NSString * _Nonnull)deviceId {
    if (_instance) {
        _instance->setAudioInputDevice(deviceId.UTF8String);
    }
}

- (void)makeIncomingVideoViewWithEndpointId:(NSString * _Nonnull)endpointId requestClone:(bool)requestClone completion:(void (^_Nonnull)(UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable, UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable))completion {
    if (_instance) {
        __weak GroupCallThreadLocalContext *weakSelf = self;
        id<OngoingCallThreadLocalContextQueueWebrtc> queue = _queue;
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL useSampleBuffer = NO;
#ifdef WEBRTC_IOS
            useSampleBuffer = YES;
#endif
            if (useSampleBuffer) {
                VideoSampleBufferView *remoteRenderer = [[VideoSampleBufferView alloc] initWithFrame:CGRectZero];
                remoteRenderer.videoContentMode = UIViewContentModeScaleAspectFill;

                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];

                VideoSampleBufferView *cloneRenderer = nil;
                if (requestClone) {
                    cloneRenderer = [[VideoSampleBufferView alloc] initWithFrame:CGRectZero];
                    cloneRenderer.videoContentMode = UIViewContentModeScaleAspectFill;
#ifdef WEBRTC_IOS
                    [remoteRenderer setCloneTarget:cloneRenderer];
#endif
                }

                [queue dispatch:^{
                    __strong GroupCallThreadLocalContext *strongSelf = weakSelf;
                    if (strongSelf && strongSelf->_instance) {
                        strongSelf->_instance->addIncomingVideoOutput(endpointId.UTF8String, sink);
                    }
                }];

                completion(remoteRenderer, cloneRenderer);
            } else {
                VideoMetalView *remoteRenderer = [[VideoMetalView alloc] initWithFrame:CGRectZero];
#ifdef WEBRTC_IOS
                remoteRenderer.videoContentMode = UIViewContentModeScaleToFill;
#else
                remoteRenderer.videoContentMode = kCAGravityResizeAspectFill;
#endif
                
                VideoMetalView *cloneRenderer = nil;
                if (requestClone) {
                    cloneRenderer = [[VideoMetalView alloc] initWithFrame:CGRectZero];
#ifdef WEBRTC_IOS
                    cloneRenderer.videoContentMode = UIViewContentModeScaleToFill;
#else
                    cloneRenderer.videoContentMode = kCAGravityResizeAspectFill;
#endif
                }
                
                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> cloneSink = [cloneRenderer getSink];
                
                [queue dispatch:^{
                    __strong GroupCallThreadLocalContext *strongSelf = weakSelf;
                    if (strongSelf && strongSelf->_instance) {
                        strongSelf->_instance->addIncomingVideoOutput(endpointId.UTF8String, sink);
                        if (cloneSink) {
                            strongSelf->_instance->addIncomingVideoOutput(endpointId.UTF8String, cloneSink);
                        }
                    }
                }];
                
                completion(remoteRenderer, cloneRenderer);
            }
        });
    }
}

- (GroupCallDisposable * _Nonnull)addVideoOutputWithEndpointId:(NSString * _Nonnull)endpointId sink:(void (^_Nonnull)(CallVideoFrameData * _Nonnull))sink {
    int sinkId = _nextSinkId;
    _nextSinkId += 1;

    GroupCallVideoSink *storedSink = [[GroupCallVideoSink alloc] initWithSink:sink];
    _sinks[@(sinkId)] = storedSink;

    if (_instance) {
        _instance->addIncomingVideoOutput(endpointId.UTF8String, [storedSink sink]);
    }

    __weak GroupCallThreadLocalContext *weakSelf = self;
    id<OngoingCallThreadLocalContextQueueWebrtc> queue = _queue;
    return [[GroupCallDisposable alloc] initWithBlock:^{
        [queue dispatch:^{
            __strong GroupCallThreadLocalContext *strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            [strongSelf->_sinks removeObjectForKey:@(sinkId)];
        }];
    }];
}

- (void)addExternalAudioData:(NSData * _Nonnull)data {
    if (_instance) {
        std::vector<uint8_t> samples;
        samples.resize(data.length);
        [data getBytes:samples.data() length:data.length];
        _instance->addExternalAudioSamples(std::move(samples));
    }
}

- (void)getStats:(void (^ _Nonnull)(OngoingGroupCallStats * _Nonnull))completion {
    if (_instance) {
        _instance->getStats([completion](tgcalls::GroupInstanceStats stats) {
            NSMutableDictionary<NSString *,OngoingGroupCallIncomingVideoStats *> *incomingVideoStats = [[NSMutableDictionary alloc] init];

            for (const auto &it : stats.incomingVideoStats) {
                incomingVideoStats[[NSString stringWithUTF8String:it.first.c_str()]] = [[OngoingGroupCallIncomingVideoStats alloc] initWithReceivingQuality:it.second.receivingQuality availableQuality:it.second.availableQuality];
            }

            completion([[OngoingGroupCallStats alloc] initWithIncomingVideoStats:incomingVideoStats]);
        });
    }
}

- (void)activateIncomingAudio {
}

@end

@implementation OngoingGroupCallMediaChannelDescription

- (instancetype _Nonnull)initWithType:(OngoingGroupCallMediaChannelType)type
    audioSsrc:(uint32_t)audioSsrc
    videoDescription:(NSString * _Nullable)videoDescription {
    self = [super init];
    if (self != nil) {
        _type = type;
        _audioSsrc = audioSsrc;
        _videoDescription = videoDescription;
    }
    return self;
}

@end

@implementation OngoingGroupCallBroadcastPart

- (instancetype _Nonnull)initWithTimestampMilliseconds:(int64_t)timestampMilliseconds responseTimestamp:(double)responseTimestamp status:(OngoingGroupCallBroadcastPartStatus)status oggData:(NSData * _Nonnull)oggData {
    self = [super init];
    if (self != nil) {
        _timestampMilliseconds = timestampMilliseconds;
        _responseTimestamp = responseTimestamp;
        _status = status;
        _oggData = oggData;
    }
    return self;
}

@end

@implementation OngoingGroupCallSsrcGroup

- (instancetype)initWithSemantics:(NSString * _Nonnull)semantics ssrcs:(NSArray<NSNumber *> * _Nonnull)ssrcs {
    self = [super init];
    if (self != nil) {
        _semantics = semantics;
        _ssrcs = ssrcs;
    }
    return self;
}

@end

@implementation OngoingGroupCallRequestedVideoChannel

- (instancetype)initWithAudioSsrc:(uint32_t)audioSsrc endpointId:(NSString * _Nonnull)endpointId ssrcGroups:(NSArray<OngoingGroupCallSsrcGroup *> * _Nonnull)ssrcGroups minQuality:(OngoingGroupCallRequestedVideoQuality)minQuality maxQuality:(OngoingGroupCallRequestedVideoQuality)maxQuality {
    self = [super init];
    if (self != nil) {
        _audioSsrc = audioSsrc;
        _endpointId = endpointId;
        _ssrcGroups = ssrcGroups;
        _minQuality = minQuality;
        _maxQuality = maxQuality;
    }
    return self;
}

@end

@implementation OngoingGroupCallIncomingVideoStats

- (instancetype _Nonnull)initWithReceivingQuality:(int)receivingQuality availableQuality:(int)availableQuality {
    self = [super init];
    if (self != nil) {
        _receivingQuality = receivingQuality;
        _availableQuality = availableQuality;
    }
    return self;
}

@end

@implementation OngoingGroupCallStats

- (instancetype _Nonnull)initWithIncomingVideoStats:(NSDictionary<NSString *, OngoingGroupCallIncomingVideoStats *> * _Nonnull)incomingVideoStats {
    self = [super init];
    if (self != nil) {
        _incomingVideoStats = incomingVideoStats;
    }
    return self;
}

@end
