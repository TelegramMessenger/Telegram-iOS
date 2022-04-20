#import <TgVoipWebrtc/OngoingCallThreadLocalContext.h>

#import "MediaUtils.h"

#import "Instance.h"
#import "InstanceImpl.h"
#import "v2/InstanceV2Impl.h"
#import "v2/InstanceV2ReferenceImpl.h"
#import "v2_4_0_0/InstanceV2_4_0_0Impl.h"
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
#import "platform/darwin/GLVideoView.h"
#import "platform/darwin/VideoSampleBufferView.h"
#import "platform/darwin/VideoCaptureView.h"
#import "platform/darwin/CustomExternalCapturer.h"

#include "platform/darwin/iOS/tgcalls_audio_device_module_ios.h"

#endif

#import "group/GroupInstanceImpl.h"
#import "group/GroupInstanceCustomImpl.h"

#import "VideoCaptureInterfaceImpl.h"

#include "sdk/objc/native/src/objc_frame_buffer.h"
#import "components/video_frame_buffer/RTCCVPixelBuffer.h"
#import "platform/darwin/TGRTCCVPixelBuffer.h"

@implementation OngoingCallConnectionDescriptionWebrtc

- (instancetype _Nonnull)initWithConnectionId:(int64_t)connectionId hasStun:(bool)hasStun hasTurn:(bool)hasTurn ip:(NSString * _Nonnull)ip port:(int32_t)port username:(NSString * _Nonnull)username password:(NSString * _Nonnull)password {
    self = [super init];
    if (self != nil) {
        _connectionId = connectionId;
        _hasStun = hasStun;
        _hasTurn = hasTurn;
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

@interface GLVideoView (VideoViewImpl) <OngoingCallThreadLocalContextWebrtcVideoView, OngoingCallThreadLocalContextWebrtcVideoViewImpl>

@property (nonatomic, readwrite) OngoingCallVideoOrientationWebrtc orientation;
@property (nonatomic, readonly) CGFloat aspect;

@end

@implementation GLVideoView (VideoViewImpl)

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

- (void)updateIsEnabled:(bool)__unused isEnabled {
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

- (instancetype)initWithBuffer:(id<CallVideoFrameBuffer>)buffer frame:(webrtc::VideoFrame const &)frame mirrorHorizontally:(bool)mirrorHorizontally mirrorVertically:(bool)mirrorVertically {
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

            if (videoFrame.video_frame_buffer()->type() == webrtc::VideoFrameBuffer::Type::kNative) {
                id<RTC_OBJC_TYPE(RTCVideoFrameBuffer)> nativeBuffer = static_cast<webrtc::ObjCFrameBuffer *>(videoFrame.video_frame_buffer().get())->wrapped_frame_buffer();
                if ([nativeBuffer isKindOfClass:[RTC_OBJC_TYPE(RTCCVPixelBuffer) class]]) {
                    RTCCVPixelBuffer *pixelBuffer = (RTCCVPixelBuffer *)nativeBuffer;
                    mappedBuffer = [[CallVideoFrameNativePixelBuffer alloc] initWithPixelBuffer:pixelBuffer.pixelBuffer];
                }
                if ([nativeBuffer isKindOfClass:[TGRTCCVPixelBuffer class]]) {
                    if (((TGRTCCVPixelBuffer *)nativeBuffer).shouldBeMirrored) {
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
                }
            } else if (videoFrame.video_frame_buffer()->type() == webrtc::VideoFrameBuffer::Type::kNV12) {
                rtc::scoped_refptr<webrtc::NV12BufferInterface> nv12Buffer = (webrtc::NV12BufferInterface *)videoFrame.video_frame_buffer().get();
                mappedBuffer = [[CallVideoFrameNV12Buffer alloc] initWithBuffer:nv12Buffer];
            } else if (videoFrame.video_frame_buffer()->type() == webrtc::VideoFrameBuffer::Type::kI420) {
                rtc::scoped_refptr<webrtc::I420BufferInterface> i420Buffer = (webrtc::I420BufferInterface *)videoFrame.video_frame_buffer().get();
                mappedBuffer = [[CallVideoFrameI420Buffer alloc] initWithBuffer:i420Buffer];
            }

            if (storedSink && mappedBuffer) {
                storedSink([[CallVideoFrameData alloc] initWithBuffer:mappedBuffer frame:videoFrame mirrorHorizontally:mirrorHorizontally mirrorVertically:mirrorVertically]);
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
- (void)submitPixelBuffer:(CVPixelBufferRef _Nonnull)pixelBuffer rotation:(OngoingCallVideoOrientationWebrtc)rotation {
    if (!pixelBuffer) {
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

    if (_isProcessingCustomSampleBuffer.value) {
        return;
    }
    _isProcessingCustomSampleBuffer.value = true;

    tgcalls::StaticThreads::getThreads()->getMediaThread()->PostTask(RTC_FROM_HERE, [interface = _interface, pixelBuffer = CFRetain(pixelBuffer), croppingBuffer = _croppingBuffer, videoRotation = videoRotation, isProcessingCustomSampleBuffer = _isProcessingCustomSampleBuffer]() {
        auto capture = GetVideoCaptureAssumingSameThread(interface.get());
        auto source = capture->source();
        if (source) {
            [CustomExternalCapturer passPixelBuffer:(CVPixelBufferRef)pixelBuffer rotation:videoRotation toSource:source croppingBuffer:*croppingBuffer];
        }
        CFRelease(pixelBuffer);
        isProcessingCustomSampleBuffer.value = false;
    });
}

#endif

- (GroupCallDisposable * _Nonnull)addVideoOutput:(void (^_Nonnull)(CallVideoFrameData * _Nonnull))sink {
    int sinkId = _nextSinkId;
    _nextSinkId += 1;

    GroupCallVideoSink *storedSink = [[GroupCallVideoSink alloc] initWithSink:sink];
    _sinks[@(sinkId)] = storedSink;

    auto sinkReference = [storedSink sink];

    tgcalls::StaticThreads::getThreads()->getMediaThread()->PostTask(RTC_FROM_HERE, [interface = _interface, sinkReference]() {
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

            if (false && requestClone) {
                VideoSampleBufferView *remoteRenderer = [[VideoSampleBufferView alloc] initWithFrame:CGRectZero];
                remoteRenderer.videoContentMode = UIViewContentModeScaleAspectFill;

                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
                interface->setOutput(sink);

                VideoSampleBufferView *cloneRenderer = nil;
                if (requestClone) {
                    cloneRenderer = [[VideoSampleBufferView alloc] initWithFrame:CGRectZero];
                    cloneRenderer.videoContentMode = UIViewContentModeScaleAspectFill;
#ifdef WEBRTC_IOS
                    [remoteRenderer setCloneTarget:cloneRenderer];
#endif
                }

                completion(remoteRenderer, cloneRenderer);
            } else if ([VideoMetalView isSupported]) {
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
            } else {
                GLVideoView *remoteRenderer = [[GLVideoView alloc] initWithFrame:CGRectZero];
    #ifndef WEBRTC_IOS
                remoteRenderer.videoContentMode = UIViewContentModeScaleAspectFill;
    #endif

                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
                interface->setOutput(sink);

                completion(remoteRenderer, nil);
            }
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
    
    OngoingCallNetworkTypeWebrtc _networkType;
    NSTimeInterval _callReceiveTimeout;
    NSTimeInterval _callRingTimeout;
    NSTimeInterval _callConnectTimeout;
    NSTimeInterval _callPacketTimeout;
    
    std::unique_ptr<tgcalls::Instance> _tgVoip;
    bool _didStop;
    
    OngoingCallStateWebrtc _state;
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

+ (void)setupLoggingFunction:(void (*)(NSString *))loggingFunction {
    InternalVoipLoggingFunction = loggingFunction;
    tgcalls::SetLoggingFunction([](std::string const &string) {
        if (InternalVoipLoggingFunction) {
            InternalVoipLoggingFunction([[NSString alloc] initWithUTF8String:string.c_str()]);
        }
    });
}

+ (void)applyServerConfig:(NSString *)string {
    if (string.length != 0) {
        //TgVoip::setGlobalServerConfig(std::string(string.UTF8String));
    }
}

+ (int32_t)maxLayer {
    return 92;
}

+ (void)ensureRegisteredImplementations {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tgcalls::Register<tgcalls::InstanceImpl>();
        tgcalls::Register<tgcalls::InstanceV2_4_0_0Impl>();
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
    } else if ([version isEqualToString:@"3.0.0"]) {
        return tgcalls::ProtocolVersion::V1;
    } else {
        return tgcalls::ProtocolVersion::V0;
    }
}

- (instancetype _Nonnull)initWithVersion:(NSString * _Nonnull)version queue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue proxy:(VoipProxyServerWebrtc * _Nullable)proxy networkType:(OngoingCallNetworkTypeWebrtc)networkType dataSaving:(OngoingCallDataSavingWebrtc)dataSaving derivedState:(NSData * _Nonnull)derivedState key:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing connections:(NSArray<OngoingCallConnectionDescriptionWebrtc *> * _Nonnull)connections maxLayer:(int32_t)maxLayer allowP2P:(BOOL)allowP2P allowTCP:(BOOL)allowTCP enableStunMarking:(BOOL)enableStunMarking logPath:(NSString * _Nonnull)logPath statsLogPath:(NSString * _Nonnull)statsLogPath sendSignalingData:(void (^)(NSData * _Nonnull))sendSignalingData videoCapturer:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer preferredVideoCodec:(NSString * _Nullable)preferredVideoCodec audioInputDeviceId: (NSString * _Nonnull)audioInputDeviceId {
    self = [super init];
    if (self != nil) {
        _version = version;
        _queue = queue;
        assert([queue isCurrent]);
        
        assert([[OngoingCallThreadLocalContextWebrtc versionsWithIncludeReference:true] containsObject:version]);
        
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
                    .host = connection.ip.UTF8String,
                    .port = (uint16_t)connection.port,
                    .login = "",
                    .password = "",
                    .isTurn = false
                });
            }
            if (connection.hasTurn) {
                parsedRtcServers.push_back((tgcalls::RtcServer){
                    .host = connection.ip.UTF8String,
                    .port = (uint16_t)connection.port,
                    .login = connection.username.UTF8String,
                    .password = connection.password.UTF8String,
                    .isTurn = true
                });
            }
        }
        
        std::vector<std::string> preferredVideoCodecs;
        if (preferredVideoCodec != nil) {
            preferredVideoCodecs.push_back([preferredVideoCodec UTF8String]);
        }
        
        std::vector<tgcalls::Endpoint> endpoints;
        
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
            .logPath = std::string(logPath.length == 0 ? "" : logPath.UTF8String),
            .statsLogPath = std::string(statsLogPath.length == 0 ? "" : statsLogPath.UTF8String),
            .maxApiLayer = [OngoingCallThreadLocalContextWebrtc maxLayer],
            .enableHighBitrateVideo = true,
            .preferredVideoCodecs = preferredVideoCodecs,
            .protocolVersion = [OngoingCallThreadLocalContextWebrtc protocolVersionFromLibraryVersion:version]
        };
        
        auto encryptionKeyValue = std::make_shared<std::array<uint8_t, 256>>();
        memcpy(encryptionKeyValue->data(), key.bytes, key.length);
        
        tgcalls::EncryptionKey encryptionKey(encryptionKeyValue, isOutgoing);
        
        [OngoingCallThreadLocalContextWebrtc ensureRegisteredImplementations];
        
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
            .createAudioDeviceModule = [](webrtc::TaskQueueFactory *taskQueueFactory) -> rtc::scoped_refptr<webrtc::AudioDeviceModule> {
                return rtc::make_ref_counted<webrtc::tgcalls_ios_adm::AudioDeviceModuleIOS>(false, false, 1);
            }
        });
        _state = OngoingCallStateInitializing;
        _signalBars = 4;
    }
    return self;
}

- (void)dealloc {
    if (InternalVoipLoggingFunction) {
        InternalVoipLoggingFunction(@"OngoingCallThreadLocalContext: dealloc");
    }
    
    if (_tgVoip != NULL) {
        [self stop:nil];
    }
}

- (bool)needRate {
    return false;
}

- (void)beginTermination {
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
    
    if (_state != callState) {
        _state = callState;
        
        if (_stateChanged) {
            _stateChanged(_state, _videoState, _remoteVideoState, _remoteAudioState, _remoteBatteryLevel, _remotePreferredAspectRatio);
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

- (void)makeIncomingVideoView:(void (^_Nonnull)(UIView<OngoingCallThreadLocalContextWebrtcVideoView> * _Nullable))completion {
    if (_tgVoip) {
        __weak OngoingCallThreadLocalContextWebrtc *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([VideoMetalView isSupported]) {
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
            } else {
                GLVideoView *remoteRenderer = [[GLVideoView alloc] initWithFrame:CGRectZero];
                
                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
                __strong OngoingCallThreadLocalContextWebrtc *strongSelf = weakSelf;
                if (strongSelf) {
                    [remoteRenderer setOrientation:strongSelf->_remoteVideoOrientation];
                    strongSelf->_currentRemoteVideoRenderer = remoteRenderer;
                    strongSelf->_tgVoip->setIncomingVideoOutput(sink);
                }
                
                completion(remoteRenderer);
            }
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
}

@end

@implementation GroupCallThreadLocalContext

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue
    networkStateUpdated:(void (^ _Nonnull)(GroupCallNetworkState))networkStateUpdated
    audioLevelsUpdated:(void (^ _Nonnull)(NSArray<NSNumber *> * _Nonnull))audioLevelsUpdated
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
    preferX264:(bool)preferX264 {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        
        tgcalls::PlatformInterface::SharedInstance()->preferX264 = preferX264;

        _sinks = [[NSMutableDictionary alloc] init];
        
        _networkStateUpdated = [networkStateUpdated copy];
        _videoCapturer = videoCapturer;
        
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
        
        std::vector<tgcalls::VideoCodecName> videoCodecPreferences;

        int minOutgoingVideoBitrateKbit = 500;
        bool disableOutgoingAudioProcessing = false;

        tgcalls::GroupConfig config;
        config.need_log = false;
#if DEBUG
        config.need_log = true;
#endif

        __weak GroupCallThreadLocalContext *weakSelf = self;
        _instance.reset(new tgcalls::GroupInstanceCustomImpl((tgcalls::GroupInstanceDescriptor){
            .threads = tgcalls::StaticThreads::getThreads(),
            .config = config,
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
            .audioLevelsUpdated = [audioLevelsUpdated](tgcalls::GroupLevelsUpdate const &levels) {
                NSMutableArray *result = [[NSMutableArray alloc] init];
                for (auto &it : levels.updates) {
                    [result addObject:@(it.ssrc)];
                    [result addObject:@(it.value.level)];
                    [result addObject:@(it.value.voice)];
                }
                audioLevelsUpdated(result);
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
            .minOutgoingVideoBitrateKbit = minOutgoingVideoBitrateKbit
        }));
    }
    return self;
}

- (void)stop {
    if (_instance) {
        _instance->stop();
        _instance.reset();
    }
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
            } else if ([VideoMetalView isSupported]) {
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
            } else {
                GLVideoView *remoteRenderer = [[GLVideoView alloc] initWithFrame:CGRectZero];
             //   [remoteRenderer setVideoContentMode:kCAGravityResizeAspectFill];
                std::shared_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink = [remoteRenderer getSink];
                
                [queue dispatch:^{
                    __strong GroupCallThreadLocalContext *strongSelf = weakSelf;
                    if (strongSelf && strongSelf->_instance) {
                        strongSelf->_instance->addIncomingVideoOutput(endpointId.UTF8String, sink);
                    }
                }];
                
                completion(remoteRenderer, nil);
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
