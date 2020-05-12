#ifndef VIDEOMETALVIEW_H
#define VIDEOMETALVIEW_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "api/media_stream_interface.h"

@class RTCVideoFrame;

@interface VideoMetalView : UIView

@property(nonatomic) UIViewContentMode videoContentMode;
@property(nonatomic, getter=isEnabled) BOOL enabled;
@property(nonatomic, nullable) NSValue* rotationOverride;

- (void)setSize:(CGSize)size;
- (void)renderFrame:(nullable RTCVideoFrame *)frame;

- (void)addToTrack:(rtc::scoped_refptr<webrtc::VideoTrackInterface>)track;

@end

#endif
