//
// Created by Grishka on 10.08.2018.
//

#include "VideoSource.h"

#ifdef __ANDROID__
#include "../os/android/VideoSourceAndroid.h"
#endif

using namespace tgvoip;
using namespace tgvoip::video;

std::shared_ptr<VideoSource> VideoSource::Create(){
#ifdef __ANDROID__
	//return std::make_shared<VideoSourceAndroid>();
	return nullptr;
#endif
	return nullptr;
}


void VideoSource::SetCallback(std::function<void(const Buffer &, int32_t)> callback){
	this->callback=callback;
}

bool VideoSource::Failed(){
	return failed;
}

std::string VideoSource::GetErrorDescription(){
	return error;
}
