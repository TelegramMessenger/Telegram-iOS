//
// Created by Grishka on 12.08.2018.
//

#include "VideoSourceAndroid.h"
#include "JNIUtilities.h"
#include "../../logging.h"

using namespace tgvoip;
using namespace tgvoip::video;

extern JavaVM* sharedJVM;

VideoSourceAndroid::VideoSourceAndroid(jobject jobj) : javaObject(jobj){

}

VideoSourceAndroid::~VideoSourceAndroid(){
	jni::DoWithJNI([this](JNIEnv* env){
		env->DeleteGlobalRef(javaObject);
	});
}

void VideoSourceAndroid::Start(){

}

void VideoSourceAndroid::Stop(){

}

void VideoSourceAndroid::SendFrame(Buffer frame, uint32_t flags){
	callback(frame, flags);
}

void VideoSourceAndroid::SetStreamParameters(std::vector<Buffer> csd, unsigned int width, unsigned int height){
	LOGD("Video stream parameters: %d x %d", width, height);
	this->width=width;
	this->height=height;
	this->csd=std::move(csd);
}
