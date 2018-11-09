//
// Created by Grishka on 12.08.2018.
//

#include "VideoRendererAndroid.h"
#include "JNIUtilities.h"

using namespace tgvoip;
using namespace tgvoip::video;

jmethodID VideoRendererAndroid::resetMethod=NULL;
jmethodID VideoRendererAndroid::decodeAndDisplayMethod=NULL;

VideoRendererAndroid::VideoRendererAndroid(jobject jobj){
	this->jobj=jobj;
}

VideoRendererAndroid::~VideoRendererAndroid(){
	jni::DoWithJNI([this](JNIEnv* env){
		env->DeleteGlobalRef(jobj);
	});
}

void VideoRendererAndroid::Reset(uint32_t codec, unsigned int width, unsigned int height, std::vector<Buffer> &csd){
	jni::DoWithJNI([&](JNIEnv* env){
		jobjectArray jcsd=NULL;
		if(!csd.empty()){
			jcsd=env->NewObjectArray((jsize)csd.size(), env->FindClass("[B"), NULL);
			jsize i=0;
			for(Buffer& b:csd){
				env->SetObjectArrayElement(jcsd, i, jni::BufferToByteArray(env, b));
				i++;
			}
		}
		env->CallVoidMethod(jobj, resetMethod, (jint)codec, (jint)width, (jint)height, jcsd);
	});
}

void VideoRendererAndroid::DecodeAndDisplay(Buffer &frame, uint32_t pts){
	jni::DoWithJNI([&](JNIEnv* env){
		jobject jbuf=env->NewDirectByteBuffer(*frame, frame.Length());
		env->CallVoidMethod(jobj, decodeAndDisplayMethod, jbuf, (jint)frame.Length(), (jlong)pts);
	});
}
