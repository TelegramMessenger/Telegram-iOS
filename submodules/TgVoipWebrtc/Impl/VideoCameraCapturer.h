#ifndef VIDEOCAMERACAPTURER_H
#define VIDEOCAMERACAPTURER_H

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#include <memory>
#include "api/scoped_refptr.h"
#include "api/media_stream_interface.h"

@interface VideoCameraCapturer : NSObject

+ (NSArray<AVCaptureDevice *> *)captureDevices;
+ (NSArray<AVCaptureDeviceFormat *> *)supportedFormatsForDevice:(AVCaptureDevice *)device;

- (instancetype)initWithSource:(rtc::scoped_refptr<webrtc::VideoTrackSourceInterface>)source isActiveUpdated:(void (^)(bool))isActiveUpdated;

- (void)startCaptureWithDevice:(AVCaptureDevice *)device format:(AVCaptureDeviceFormat *)format fps:(NSInteger)fps;
- (void)stopCapture;

@end

#endif
