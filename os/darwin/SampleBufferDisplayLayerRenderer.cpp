//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "SampleBufferDisplayLayerRenderer.h"
#include "../../PrivateDefines.h"

using namespace tgvoip;
using namespace tgvoip::video;

SampleBufferDisplayLayerRenderer::SampleBufferDisplayLayerRenderer(){

}

SampleBufferDisplayLayerRenderer::~SampleBufferDisplayLayerRenderer(){

}

void SampleBufferDisplayLayerRenderer::Reset(uint32_t codec, unsigned int width, unsigned int height, std::vector<Buffer>& csd){

}

void SampleBufferDisplayLayerRenderer::DecodeAndDisplay(Buffer frame, uint32_t pts){

}

void SampleBufferDisplayLayerRenderer::SetStreamEnabled(bool enabled){

}

int SampleBufferDisplayLayerRenderer::GetMaximumResolution(){
	return INIT_VIDEO_RES_1080;
}
