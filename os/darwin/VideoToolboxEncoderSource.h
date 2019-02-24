//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_VIDEOTOOLBOXENCODERSOURCE
#define LIBTGVOIP_VIDEOTOOLBOXENCODERSOURCE

#include "../../video/VideoSource.h"
#include <CoreMedia/CoreMedia.h>
#include <VideoToolbox/VideoToolbox.h>

namespace tgvoip{
	namespace video{
		class VideoToolboxEncoderSource : public VideoSource{
		public:
			VideoToolboxEncoderSource();
			virtual ~VideoToolboxEncoderSource();
			virtual void Start() override;
			virtual void Stop() override;
			virtual void Reset(uint32_t codec, int maxResolution) override;
			virtual void RequestKeyFrame() override;
			void EncodeFrame(CMSampleBufferRef frame);
		};
	}
}

#endif /* LIBTGVOIP_VIDEOTOOLBOXENCODERSOURCE */
