//
// Created by Grishka on 12.08.2018.
//

#include "VideoRendererAndroid.h"
#include "JNIUtilities.h"
#include "../../PrivateDefines.h"
#include "../../logging.h"

using namespace tgvoip;
using namespace tgvoip::video;

jmethodID VideoRendererAndroid::resetMethod=NULL;
jmethodID VideoRendererAndroid::decodeAndDisplayMethod=NULL;
jmethodID VideoRendererAndroid::setStreamEnabledMethod=NULL;
std::vector<uint32_t> VideoRendererAndroid::availableDecoders;
int VideoRendererAndroid::maxResolution;

extern JavaVM* sharedJVM;

VideoRendererAndroid::VideoRendererAndroid(jobject jobj) : queue(50){
	this->jobj=jobj;
}

VideoRendererAndroid::~VideoRendererAndroid(){
	running=false;
	Buffer empty(0);
	queue.Put(std::move(empty));
	thread->Join();
	delete thread;
	/*decoderThread.Post([this]{
		decoderEnv->DeleteGlobalRef(jobj);
	});*/
}

void VideoRendererAndroid::Reset(uint32_t codec, unsigned int width, unsigned int height, std::vector<Buffer> &_csd){
	assert(!thread);
	for(Buffer& b:_csd){
		csd.push_back(Buffer::CopyOf(b));
	}
	this->codec=codec;
	this->width=width;
	this->height=height;
	thread=new Thread(std::bind(&VideoRendererAndroid::RunThread, this));
	thread->Start();
}

void VideoRendererAndroid::DecodeAndDisplay(Buffer frame, uint32_t pts){
	/*decoderThread.Post(std::bind([this](Buffer frame){
	}, std::move(frame)));*/
	LOGV("2 before decode %u", (unsigned int)frame.Length());
	queue.Put(std::move(frame));
}

void VideoRendererAndroid::RunThread(){
	JNIEnv* env;
	sharedJVM->AttachCurrentThread(&env, NULL);

	jobjectArray jcsd=NULL;
	if(!csd.empty()){
		jcsd=env->NewObjectArray((jsize)csd.size(), env->FindClass("[B"), NULL);
		jsize i=0;
		for(Buffer& b:csd){
			env->SetObjectArrayElement(jcsd, i, jni::BufferToByteArray(env, b));
			i++;
		}
	}
	std::string codecStr="";
	switch(codec){
		case CODEC_AVC:
			codecStr="video/avc";
			break;
		case CODEC_HEVC:
			codecStr="video/hevc";
			break;
		case CODEC_VP8:
			codecStr="video/x-vnd.on2.vp8";
			break;
		case CODEC_VP9:
			codecStr="video/x-vnd.on2.vp9";
			break;
	}
	env->CallVoidMethod(jobj, resetMethod, env->NewStringUTF(codecStr.c_str()), (jint)width, (jint)height, jcsd);
	bool enabled=true;
	env->CallVoidMethod(jobj, setStreamEnabledMethod, enabled);

	constexpr size_t bufferSize=200*1024;
	unsigned char* buf=reinterpret_cast<unsigned char*>(malloc(bufferSize));
	jobject jbuf=env->NewDirectByteBuffer(buf, bufferSize);

	while(running){
		LOGV("before get from queue");
		Buffer frame=std::move(queue.GetBlocking());
		LOGV("1 before decode %u", (unsigned int)frame.Length());
		if(!running)
			break;
		if(frame.Length()>bufferSize){
			LOGE("Frame data is too long (%u, max %u)", (int)frame.Length(), (int)bufferSize);
		}else{
			memcpy(buf, *frame, frame.Length());
			env->CallVoidMethod(jobj, decodeAndDisplayMethod, jbuf, (jint) frame.Length(), 0);
		}
	}
	free(buf);
	sharedJVM->DetachCurrentThread();
	LOGI("==== decoder thread exiting ====");
}

void VideoRendererAndroid::SetStreamEnabled(bool enabled){
	LOGI("Video stream state: %d", enabled);
	/*decoderThread.Post([=](){
		decoderEnv->CallVoidMethod(jobj, setStreamEnabledMethod, enabled);
	});*/
}
