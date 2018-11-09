//
// Created by Grishka on 10.08.2018.
//

#ifndef LIBTGVOIP_VIDEOSOURCE_H
#define LIBTGVOIP_VIDEOSOURCE_H

#include <vector>
#include <functional>
#include <memory>
#include <string>
#include "../Buffers.h"

namespace tgvoip{
	namespace video {
		class VideoSource{
		public:
			virtual ~VideoSource(){};
			static std::shared_ptr<VideoSource> Create();
			void SetCallback(std::function<void(const Buffer& buffer, int32_t flags)> callback);
			virtual void Start()=0;
			virtual void Stop()=0;
			bool Failed();
			std::string GetErrorDescription();
			std::vector<Buffer>& GetCodecSpecificData(){
				return csd;
			}
			unsigned int GetFrameWidth(){
				return width;
			}
			unsigned int GetFrameHeight(){
				return height;
			}

		protected:
			std::function<void(const Buffer &, int32_t)> callback;
			bool failed;
			std::string error;
			unsigned int width=0;
			unsigned int height=0;
			std::vector<Buffer> csd;
		};
	}
}

#endif //LIBTGVOIP_VIDEOSOURCE_H
