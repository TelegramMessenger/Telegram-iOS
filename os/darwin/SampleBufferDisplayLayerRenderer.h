//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef TGVOIP_SAMPLEBUFFERDISPLAYLAYERRENDERER
#define TGVOIP_SAMPLEBUFFERDISPLAYLAYERRENDERER

#include "../../video/VideoRenderer.h"

namespace tgvoip{
	namespace video{
		class SampleBufferDisplayLayerRenderer : public VideoRenderer{
		public:
			SampleBufferDisplayLayerRenderer();
			virtual ~SampleBufferDisplayLayerRenderer();
			virtual void Reset(uint32_t codec, unsigned int width, unsigned int height, std::vector<Buffer>& csd) override;
			virtual void DecodeAndDisplay(Buffer frame, uint32_t pts) override;
			virtual void SetStreamEnabled(bool enabled) override;
			static int GetMaximumResolution();
		private:
			
		};
	}
}

#endif /* TGVOIP_SAMPLEBUFFERDISPLAYLAYERRENDERER */
