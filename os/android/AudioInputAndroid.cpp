//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "AudioInputAndroid.h"
#include <stdio.h>
#include "../../logging.h"

extern JavaVM* sharedJVM;

jmethodID CAudioInputAndroid::initMethod=NULL;
jmethodID CAudioInputAndroid::releaseMethod=NULL;
jmethodID CAudioInputAndroid::startMethod=NULL;
jmethodID CAudioInputAndroid::stopMethod=NULL;
jclass CAudioInputAndroid::jniClass=NULL;

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
	init_mutex(mutex);
}

CAudioInputAndroid::~CAudioInputAndroid(){
	{
		CMutexGuard guard(mutex);
		JNIEnv *env=NULL;
		bool didAttach=false;
		sharedJVM->GetEnv((void **) &env, JNI_VERSION_1_6);
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
	free_mutex(mutex);
}

void CAudioInputAndroid::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	CMutexGuard guard(mutex);
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
	CMutexGuard guard(mutex);
	JNIEnv* env=NULL;
	bool didAttach=false;
	sharedJVM->GetEnv((void**) &env, JNI_VERSION_1_6);
	if(!env){
		sharedJVM->AttachCurrentThread(&env, NULL);
		didAttach=true;
	}

	failed=!env->CallBooleanMethod(javaObject, startMethod);

	if(didAttach){
		sharedJVM->DetachCurrentThread();
	}
	running=true;
}

void CAudioInputAndroid::Stop(){
	CMutexGuard guard(mutex);
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