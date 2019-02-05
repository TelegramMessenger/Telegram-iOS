//
// Created by Grishka on 10.08.2018.
//

#include "VideoRenderer.h"

#ifdef __ANDROID__
#include "../os/android/VideoRendererAndroid.h"
#endif

std::vector<uint32_t> tgvoip::video::VideoRenderer::GetAvailableDecoders(){
#ifdef __ANDROID__
	return VideoRendererAndroid::availableDecoders;
#endif
	return std::vector<uint32_t>();
}

int tgvoip::video::VideoRenderer::GetMaximumResolution(){
#ifdef __ANDROID__
	return VideoRendererAndroid::maxResolution;
#endif
	return 0;
}
