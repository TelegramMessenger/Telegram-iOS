//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "AudioInputAndroid.h"
#include <stdio.h>
#include "../../logging.h"

extern JavaVM* sharedJVM;

jmethodID CAudioInputAndroid::initMethod;
jmethodID CAudioInputAndroid::releaseMethod;
jmethodID CAudioInputAndroid::startMethod;
jmethodID CAudioInputAndroid::stopMethod;
jclass CAudioInputAndroid::jniClass;

CAudioInputAndroid::CAudioInputAndroid(){
	JNIEnv* env=NULL;
	bool didAttach=false;
	sharedJVM->GetEnv((void**) &env, JNI_VERSION_1_6);
	if(!env){
		sharedJVM->AttachCurrentThread(&env, NULL);
		didAttach=true;
	}

	jmethodID ctor=env->GetMethodID(jniClass, "<init>", "(J)V");
	jobject obj=env->NewObject(jniClass, ctor, (jlong)(intptr_t)this);
	javaObject=env->NewGlobalRef(obj);

	if(didAttach){
		sharedJVM->DetachCurrentThread();
	}
	running=false;
}

CAudioInputAndroid::~CAudioInputAndroid(){
	JNIEnv* env=NULL;
	bool didAttach=false;
	sharedJVM->GetEnv((void**) &env, JNI_VERSION_1_6);
	if(!env){
		sharedJVM->AttachCurrentThread(&env, NULL);
		didAttach=true;
	}

	env->CallVoidMethod(javaObject, releaseMethod);
	env->DeleteGlobalRef(javaObject);
	javaObject=NULL;

	if(didAttach){
		sharedJVM->DetachCurrentThread();
	}
}

void CAudioInputAndroid::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	JNIEnv* env=NULL;
	bool didAttach=false;
	sharedJVM->GetEnv((void**) &env, JNI_VERSION_1_6);
	if(!env){
		sharedJVM->AttachCurrentThread(&env, NULL);
		didAttach=true;
	}

	env->CallVoidMethod(javaObject, initMethod, sampleRate, bitsPerSample, channels, 960*2);

	if(didAttach){
		sharedJVM->DetachCurrentThread();
	}
}

void CAudioInputAndroid::Start(){
	JNIEnv* env=NULL;
	bool didAttach=false;
	sharedJVM->GetEnv((void**) &env, JNI_VERSION_1_6);
	if(!env){
		sharedJVM->AttachCurrentThread(&env, NULL);
		didAttach=true;
	}

	env->CallVoidMethod(javaObject, startMethod);

	if(didAttach){
		sharedJVM->DetachCurrentThread();
	}
	running=true;
}

void CAudioInputAndroid::Stop(){
	running=false;
	JNIEnv* env=NULL;
	bool didAttach=false;
	sharedJVM->GetEnv((void**) &env, JNI_VERSION_1_6);
	if(!env){
		sharedJVM->AttachCurrentThread(&env, NULL);
		didAttach=true;
	}

	env->CallVoidMethod(javaObject, stopMethod);

	if(didAttach){
		sharedJVM->DetachCurrentThread();
	}
}

void CAudioInputAndroid::HandleCallback(JNIEnv* env, jobject buffer){
	if(!running)
		return;
	unsigned char* buf=(unsigned char*) env->GetDirectBufferAddress(buffer);
	size_t len=(size_t) env->GetDirectBufferCapacity(buffer);
	InvokeCallback(buf, len);
}