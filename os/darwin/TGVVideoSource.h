//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

namespace tgvoip{
namespace video{
class VideoSource;
}
}

typedef NS_ENUM(int, TGVVideoResolution){
	TGVVideoResolution1080,
	TGVVideoResolution720,
	TGVVideoResolution480,
	TGVVideoResolution360
};

@interface TGVVideoSource : NSObject

- (void)sendVideoFrame: (CMSampleBufferRef)buffer;
- (TGVVideoResolution)maximumSupportedVideoResolution;
- (void)setVideoRotation: (int)rotation;
- (void)pauseStream;
- (void)resumeStream;
- (tgvoip::video::VideoSource*)nativeVideoSource;

@end
