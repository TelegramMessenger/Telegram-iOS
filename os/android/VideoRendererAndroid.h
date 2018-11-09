//
// Created by Grishka on 12.08.2018.
//

#ifndef LIBTGVOIP_VIDEORENDERERANDROID_H
#define LIBTGVOIP_VIDEORENDERERANDROID_H

#include "../../video/VideoRenderer.h"

#include <jni.h>

namespace tgvoip{
	namespace video{
		class VideoRendererAndroid : public VideoRenderer{
		public:
			VideoRendererAndroid(jobject jobj);
			virtual ~VideoRendererAndroid();
			virtual void Reset(uint32_t codec, unsigned int width, unsigned int height, std::vector<Buffer>& csd) override;
			virtual void DecodeAndDisplay(Buffer& frame, uint32_t pts) override;

			static jmethodID resetMethod;
			static jmethodID decodeAndDisplayMethod;
		private:
			jobject jobj;
		};
	}
}

#endif //LIBTGVOIP_VIDEORENDERERANDROID_H
