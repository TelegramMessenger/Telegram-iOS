//
// Created by Grishka on 12.08.2018.
//

#ifndef LIBTGVOIP_VIDEORENDERERANDROID_H
#define LIBTGVOIP_VIDEORENDERERANDROID_H

#include "../../video/VideoRenderer.h"
#include "../../MessageThread.h"

#include <jni.h>
#include "../../BlockingQueue.h"

namespace tgvoip{
	namespace video{
		class VideoRendererAndroid : public VideoRenderer{
		public:
			VideoRendererAndroid(jobject jobj);
			virtual ~VideoRendererAndroid();
			virtual void Reset(uint32_t codec, unsigned int width, unsigned int height, std::vector<Buffer>& csd) override;
			virtual void DecodeAndDisplay(Buffer frame, uint32_t pts) override;
			virtual void SetStreamEnabled(bool enabled) override;

			static jmethodID resetMethod;
			static jmethodID decodeAndDisplayMethod;
			static jmethodID setStreamEnabledMethod;
			static std::vector<uint32_t> availableDecoders;
			static int maxResolution;
		private:
			void RunThread();
			Thread* thread=NULL;
			bool running=true;
			BlockingQueue<Buffer> queue;
			std::vector<Buffer> csd;
			int width;
			int height;
			uint32_t codec;
			jobject jobj;
		};
	}
}

#endif //LIBTGVOIP_VIDEORENDERERANDROID_H
