//
// Created by Grishka on 12.08.2018.
//

#ifndef LIBTGVOIP_VIDEOSOURCEANDROID_H
#define LIBTGVOIP_VIDEOSOURCEANDROID_H

#include "../../video/VideoSource.h"
#include "../../Buffers.h"
#include <jni.h>
#include <vector>

namespace tgvoip{
	namespace video{
		class VideoSourceAndroid : public VideoSource{
		public:
			VideoSourceAndroid(jobject jobj);
			virtual ~VideoSourceAndroid();
			virtual void Start();
			virtual void Stop();
			void SendFrame(Buffer frame, uint32_t flags);
			void SetStreamParameters(std::vector<Buffer> csd, unsigned int width, unsigned int height);
		private:
			jobject javaObject;
		};
	}
}


#endif //LIBTGVOIP_VIDEOSOURCEANDROID_H
