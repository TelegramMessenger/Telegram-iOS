#import "VideoMetalView.h"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#import "base/RTCLogging.h"
#import "base/RTCVideoFrame.h"
#import "base/RTCVideoFrameBuffer.h"
#import "components/video_frame_buffer/RTCCVPixelBuffer.h"
#include "sdk/objc/native/api/video_frame.h"

#import "api/video/video_sink_interface.h"
#import "api/media_stream_interface.h"

#import "RTCMTLI420Renderer.h"
#import "RTCMTLNV12Renderer.h"
#import "RTCMTLRGBRenderer.h"

#define MTKViewClass NSClassFromString(@"MTKView")
#define RTCMTLNV12RendererClass NSClassFromString(@"RTCMTLNV12Renderer")
#define RTCMTLI420RendererClass NSClassFromString(@"RTCMTLI420Renderer")
#define RTCMTLRGBRendererClass NSClassFromString(@"RTCMTLRGBRenderer")

class VideoRendererAdapterImpl : public rtc::VideoSinkInterface<webrtc::VideoFrame> {
 public:
    VideoRendererAdapterImpl(VideoMetalView *adapter) {
        adapter_ = adapter;
        size_ = CGSizeZero;
    }
    
    void OnFrame(const webrtc::VideoFrame& nativeVideoFrame) override {
        RTCVideoFrame* videoFrame = NativeToObjCVideoFrame(nativeVideoFrame);
        
        CGSize current_size = (videoFrame.rotation % 180 == 0) ? CGSizeMake(videoFrame.width, videoFrame.height) : CGSizeMake(videoFrame.height, videoFrame.width);
        
        if (!CGSizeEqualToSize(size_, current_size)) {
            size_ = current_size;
            [adapter_ setSize:size_];
        }
        [adapter_ renderFrame:videoFrame];
    }
    
private:
    __weak VideoMetalView *adapter_;
    CGSize size_;
};

@interface VideoMetalView () <MTKViewDelegate> {
    RTCMTLI420Renderer *_rendererI420;
    RTCMTLNV12Renderer *_rendererNV12;
    RTCMTLRGBRenderer *_rendererRGB;
    MTKView *_metalView;
    RTCVideoFrame *_videoFrame;
    CGSize _videoFrameSize;
    int64_t _lastFrameTimeNs;
    
    std::unique_ptr<VideoRendererAdapterImpl> _sink;
}

@end

@implementation VideoMetalView

- (instancetype)initWithFrame:(CGRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self configure];
        
        _sink.reset(new VideoRendererAdapterImpl(self));
    }
    return self;
}

- (BOOL)isEnabled {
    return !_metalView.paused;
}

- (void)setEnabled:(BOOL)enabled {
    _metalView.paused = !enabled;
}

- (UIViewContentMode)videoContentMode {
    return _metalView.contentMode;
}

- (void)setVideoContentMode:(UIViewContentMode)mode {
    _metalView.contentMode = mode;
}

#pragma mark - Private

+ (BOOL)isMetalAvailable {
    return MTLCreateSystemDefaultDevice() != nil;
}

+ (MTKView *)createMetalView:(CGRect)frame {
    return [[MTKViewClass alloc] initWithFrame:frame];
}

+ (RTCMTLNV12Renderer *)createNV12Renderer {
    return [[RTCMTLNV12RendererClass alloc] init];
}

+ (RTCMTLI420Renderer *)createI420Renderer {
    return [[RTCMTLI420RendererClass alloc] init];
}

+ (RTCMTLRGBRenderer *)createRGBRenderer {
    return [[RTCMTLRGBRenderer alloc] init];
}

- (void)configure {
    NSAssert([VideoMetalView isMetalAvailable], @"Metal not availiable on this device");
    
    _metalView = [VideoMetalView createMetalView:self.bounds];
    _metalView.delegate = self;
    _metalView.contentMode = UIViewContentModeScaleAspectFill;
    [self addSubview:_metalView];
    _videoFrameSize = CGSizeZero;
}

- (void)setMultipleTouchEnabled:(BOOL)multipleTouchEnabled {
    [super setMultipleTouchEnabled:multipleTouchEnabled];
    _metalView.multipleTouchEnabled = multipleTouchEnabled;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    _metalView.frame = bounds;
    if (!CGSizeEqualToSize(_videoFrameSize, CGSizeZero)) {
        _metalView.drawableSize = [self drawableSize];
    } else {
        _metalView.drawableSize = bounds.size;
    }
}

#pragma mark - MTKViewDelegate methods

- (void)drawInMTKView:(nonnull MTKView *)view {
    NSAssert(view == _metalView, @"Receiving draw callbacks from foreign instance.");
    RTCVideoFrame *videoFrame = _videoFrame;
    // Skip rendering if we've already rendered this frame.
    if (!videoFrame || videoFrame.timeStampNs == _lastFrameTimeNs) {
        return;
    }
    
    if (CGRectIsEmpty(view.bounds)) {
        return;
    }
    
    RTCMTLRenderer *renderer;
    if ([videoFrame.buffer isKindOfClass:[RTCCVPixelBuffer class]]) {
        RTCCVPixelBuffer *buffer = (RTCCVPixelBuffer*)videoFrame.buffer;
        const OSType pixelFormat = CVPixelBufferGetPixelFormatType(buffer.pixelBuffer);
        if (pixelFormat == kCVPixelFormatType_32BGRA || pixelFormat == kCVPixelFormatType_32ARGB) {
            if (!_rendererRGB) {
                _rendererRGB = [VideoMetalView createRGBRenderer];
                if (![_rendererRGB addRenderingDestination:_metalView]) {
                    _rendererRGB = nil;
                    RTCLogError(@"Failed to create RGB renderer");
                    return;
                }
            }
            renderer = _rendererRGB;
        } else {
            if (!_rendererNV12) {
                _rendererNV12 = [VideoMetalView createNV12Renderer];
                if (![_rendererNV12 addRenderingDestination:_metalView]) {
                    _rendererNV12 = nil;
                    RTCLogError(@"Failed to create NV12 renderer");
                    return;
                }
            }
            renderer = _rendererNV12;
        }
    } else {
        if (!_rendererI420) {
            _rendererI420 = [VideoMetalView createI420Renderer];
            if (![_rendererI420 addRenderingDestination:_metalView]) {
                _rendererI420 = nil;
                RTCLogError(@"Failed to create I420 renderer");
                return;
            }
        }
        renderer = _rendererI420;
    }
    
    renderer.rotationOverride = _rotationOverride;
    
    [renderer drawFrame:videoFrame];
    _lastFrameTimeNs = videoFrame.timeStampNs;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}

#pragma mark -

- (void)setRotationOverride:(NSValue *)rotationOverride {
    _rotationOverride = rotationOverride;
    
    _metalView.drawableSize = [self drawableSize];
    [self setNeedsLayout];
}

- (RTCVideoRotation)frameRotation {
    if (_rotationOverride) {
        RTCVideoRotation rotation;
        if (@available(iOS 11, *)) {
            [_rotationOverride getValue:&rotation size:sizeof(rotation)];
        } else {
            [_rotationOverride getValue:&rotation];
        }
        return rotation;
    }
    
    return _videoFrame.rotation;
}

- (CGSize)drawableSize {
    // Flip width/height if the rotations are not the same.
    CGSize videoFrameSize = _videoFrameSize;
    RTCVideoRotation frameRotation = [self frameRotation];
    
    BOOL useLandscape =
    (frameRotation == RTCVideoRotation_0) || (frameRotation == RTCVideoRotation_180);
    BOOL sizeIsLandscape = (_videoFrame.rotation == RTCVideoRotation_0) ||
    (_videoFrame.rotation == RTCVideoRotation_180);
    
    if (useLandscape == sizeIsLandscape) {
        return videoFrameSize;
    } else {
        return CGSizeMake(videoFrameSize.height, videoFrameSize.width);
    }
}

#pragma mark - RTCVideoRenderer

- (void)setSize:(CGSize)size {
    __weak VideoMetalView *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong VideoMetalView *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        strongSelf->_videoFrameSize = size;
        CGSize drawableSize = [strongSelf drawableSize];
        
        strongSelf->_metalView.drawableSize = drawableSize;
        [strongSelf setNeedsLayout];
        //[strongSelf.delegate videoView:self didChangeVideoSize:size];
    });
}

- (void)renderFrame:(nullable RTCVideoFrame *)frame {
    if (!self.isEnabled) {
        return;
    }
    
    if (frame == nil) {
        RTCLogInfo(@"Incoming frame is nil. Exiting render callback.");
        return;
    }
    _videoFrame = frame;
}

- (void)addToTrack:(rtc::scoped_refptr<webrtc::VideoTrackInterface>)track {
    track->AddOrUpdateSink(_sink.get(), rtc::VideoSinkWants());
}

@end
