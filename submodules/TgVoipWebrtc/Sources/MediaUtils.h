#import <TgVoipWebrtc/OngoingCallThreadLocalContext.h>


#import "Instance.h"
#import "InstanceImpl.h"
#import "v2/InstanceV2Impl.h"
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
#endif

#import "group/GroupInstanceImpl.h"
#import "group/GroupInstanceCustomImpl.h"

#import "VideoCaptureInterfaceImpl.h"

#include "sdk/objc/native/src/objc_frame_buffer.h"
#import "components/video_frame_buffer/RTCCVPixelBuffer.h"
#import "platform/darwin/TGRTCCVPixelBuffer.h"

@interface CallVideoFrameNativePixelBuffer (Initialization)

- (instancetype _Nonnull)initWithPixelBuffer:(CVPixelBufferRef _Nonnull)pixelBuffer;

@end

@interface CallVideoFrameI420Buffer (Initialization)

- (instancetype _Nonnull)initWithBuffer:(rtc::scoped_refptr<webrtc::I420BufferInterface>)i420Buffer;

@end

@interface CallVideoFrameNV12Buffer (Initialization)

- (instancetype _Nonnull)initWithBuffer:(rtc::scoped_refptr<webrtc::NV12BufferInterface>)nv12Buffer;

@end

@interface CallVideoFrameData (Initialization)

- (instancetype _Nonnull)initWithBuffer:(id<CallVideoFrameBuffer> _Nonnull)buffer frame:(webrtc::VideoFrame const &)frame mirrorHorizontally:(bool)mirrorHorizontally mirrorVertically:(bool)mirrorVertically;

@end
