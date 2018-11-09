//
// Created by Grishka on 10.08.2018.
//

#ifndef LIBTGVOIP_VIDEORENDERER_H
#define LIBTGVOIP_VIDEORENDERER_H

#include <vector>
#include "../Buffers.h"

namespace tgvoip{
	namespace video{
		class VideoRenderer{
		public:
			virtual ~VideoRenderer(){};
			virtual void Reset(uint32_t codec, unsigned int width, unsigned int height, std::vector<Buffer>& csd)=0;
			virtual void DecodeAndDisplay(Buffer& frame, uint32_t pts)=0;
		};
	}
}

#endif //LIBTGVOIP_VIDEORENDERER_H
