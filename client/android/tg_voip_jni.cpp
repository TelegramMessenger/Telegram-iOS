//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include <jni.h>
#include <string.h>
#include <wchar.h>
#include <map>
#include <string>
#include <libtgvoip/VoIPServerConfig.h>
#include "../../VoIPController.h"
#include "../../os/android/AudioOutputOpenSLES.h"
#include "../../os/android/AudioInputOpenSLES.h"
#include "../../os/android/AudioInputAndroid.h"
#include "../../os/android/AudioOutputAndroid.h"

JavaVM* sharedJVM;
jfieldID audioRecordInstanceFld=NULL;
jfieldID audioTrackInstanceFld=NULL;
jmethodID setStateMethod=NULL;

struct impl_data_android_t{
	jobject javaObject;
};

void updateConnectionState(CVoIPController* cntrlr, int state){
	impl_data_android_t* impl=(impl_data_android_t*) cntrlr->implData;
	if(!impl->javaObject)
		return;
	JNIEnv* env=NULL;
	bool didAttach=false;
	sharedJVM->GetEnv((void**) &env, JNI_VERSION_1_6);
	if(!env){
		sharedJVM->AttachCurrentThread(&env, NULL);
		didAttach=true;
	}

	if(setStateMethod)
		env->CallVoidMethod(impl->javaObject, setStateMethod, state);

	if(didAttach){
		sharedJVM->DetachCurrentThread();
	}
}

extern "C" JNIEXPORT jlong Java_org_telegram_messenger_voip_VoIPController_nativeInit(JNIEnv* env, jobject thiz, jint systemVersion){
	CAudioOutputAndroid::systemVersion=systemVersion;

	env->GetJavaVM(&sharedJVM);
	if(!CAudioInputAndroid::jniClass){
		jclass cls=env->FindClass("org/telegram/messenger/voip/AudioRecordJNI");
		CAudioInputAndroid::jniClass=(jclass) env->NewGlobalRef(cls);
		CAudioInputAndroid::initMethod=env->GetMethodID(cls, "init", "(IIII)V");
		CAudioInputAndroid::releaseMethod=env->GetMethodID(cls, "release", "()V");
		CAudioInputAndroid::startMethod=env->GetMethodID(cls, "start", "()Z");
		CAudioInputAndroid::stopMethod=env->GetMethodID(cls, "stop", "()V");

		cls=env->FindClass("org/telegram/messenger/voip/AudioTrackJNI");
		CAudioOutputAndroid::jniClass=(jclass) env->NewGlobalRef(cls);
		CAudioOutputAndroid::initMethod=env->GetMethodID(cls, "init", "(IIII)V");
		CAudioOutputAndroid::releaseMethod=env->GetMethodID(cls, "release", "()V");
		CAudioOutputAndroid::startMethod=env->GetMethodID(cls, "start", "()V");
		CAudioOutputAndroid::stopMethod=env->GetMethodID(cls, "stop", "()V");
	}

	setStateMethod=env->GetMethodID(env->GetObjectClass(thiz), "handleStateChange", "(I)V");

	impl_data_android_t* impl=(impl_data_android_t*) malloc(sizeof(impl_data_android_t));
	impl->javaObject=env->NewGlobalRef(thiz);
	CVoIPController* cntrlr=new CVoIPController();
	cntrlr->implData=impl;
	cntrlr->SetStateCallback(updateConnectionState);
	return (jlong)(intptr_t)cntrlr;
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_VoIPController_nativeStart(JNIEnv* env, jobject thiz, jlong inst){
	((CVoIPController*)(intptr_t)inst)->Start();
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_VoIPController_nativeConnect(JNIEnv* env, jobject thiz, jlong inst){
	((CVoIPController*)(intptr_t)inst)->Connect();
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_VoIPController_nativeSetEncryptionKey(JNIEnv* env, jobject thiz, jlong inst, jbyteArray key, jboolean isOutgoing){
	jbyte* akey=env->GetByteArrayElements(key, NULL);
	((CVoIPController*)(intptr_t)inst)->SetEncryptionKey((char *) akey, isOutgoing);
	env->ReleaseByteArrayElements(key, akey, JNI_ABORT);
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_VoIPController_nativeSetRemoteEndpoints(JNIEnv* env, jobject thiz, jlong inst, jobjectArray endpoints, jboolean allowP2p){
	size_t len=(size_t) env->GetArrayLength(endpoints);
	voip_endpoint_t* eps=(voip_endpoint_t *) malloc(sizeof(voip_endpoint_t)*len);
	/*public String ip;
		public String ipv6;
		public int port;
		public byte[] peer_tag;*/
	jclass epClass=env->GetObjectClass(env->GetObjectArrayElement(endpoints, 0));
	jfieldID ipFld=env->GetFieldID(epClass, "ip", "Ljava/lang/String;");
	jfieldID ipv6Fld=env->GetFieldID(epClass, "ipv6", "Ljava/lang/String;");
	jfieldID portFld=env->GetFieldID(epClass, "port", "I");
	jfieldID peerTagFld=env->GetFieldID(epClass, "peer_tag", "[B");
	jfieldID idFld=env->GetFieldID(epClass, "id", "J");
	int i;
	for(i=0;i<len;i++){
		jobject endpoint=env->GetObjectArrayElement(endpoints, i);
		jstring ip=(jstring) env->GetObjectField(endpoint, ipFld);
		jstring ipv6=(jstring) env->GetObjectField(endpoint, ipv6Fld);
		jint port=env->GetIntField(endpoint, portFld);
		jlong id=env->GetLongField(endpoint, idFld);
		jbyteArray peerTag=(jbyteArray) env->GetObjectField(endpoint, peerTagFld);
		eps[i].id=id;
		eps[i].port=(uint32_t) port;
		const char* ipChars=env->GetStringUTFChars(ip, NULL);
		inet_aton(ipChars, &eps[i].address);
		env->ReleaseStringUTFChars(ip, ipChars);
		if(ipv6 && env->GetStringLength(ipv6)){
			const char* ipv6Chars=env->GetStringUTFChars(ipv6, NULL);
			inet_pton(AF_INET6, ipv6Chars, &eps[i].address6);
			env->ReleaseStringUTFChars(ipv6, ipv6Chars);
		}
		if(peerTag && env->GetArrayLength(peerTag)){
			jbyte* peerTagBytes=env->GetByteArrayElements(peerTag, NULL);
			memcpy(eps[i].peerTag, peerTagBytes, 16);
			env->ReleaseByteArrayElements(peerTag, peerTagBytes, JNI_ABORT);
		}
		eps[i].type=EP_TYPE_UDP_RELAY;
	}
	((CVoIPController*)(intptr_t)inst)->SetRemoteEndpoints(eps, len, allowP2p);
	free(eps);
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_VoIPController_nativeSetNativeBufferSize(JNIEnv* env, jclass thiz, jint size){
	CAudioOutputOpenSLES::nativeBufferSize=size;
	CAudioInputOpenSLES::nativeBufferSize=size;
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_VoIPController_nativeRelease(JNIEnv* env, jobject thiz, jlong inst){
	//env->DeleteGlobalRef(CAudioInputAndroid::jniClass);

	CVoIPController* ctlr=((CVoIPController*)(intptr_t)inst);
	impl_data_android_t* impl=(impl_data_android_t*)ctlr->implData;
	delete ctlr;
	env->DeleteGlobalRef(impl->javaObject);
	((impl_data_android_t*)ctlr->implData)->javaObject=NULL;
	free(impl);
}


extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_AudioRecordJNI_nativeCallback(JNIEnv* env, jobject thiz, jobject buffer){
	if(!audioRecordInstanceFld)
		audioRecordInstanceFld=env->GetFieldID(env->GetObjectClass(thiz), "nativeInst", "J");

	jlong inst=env->GetLongField(thiz, audioRecordInstanceFld);
	CAudioInputAndroid* in=(CAudioInputAndroid*)(intptr_t)inst;
	in->HandleCallback(env, buffer);
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_AudioTrackJNI_nativeCallback(JNIEnv* env, jobject thiz, jbyteArray buffer){
	if(!audioTrackInstanceFld)
		audioTrackInstanceFld=env->GetFieldID(env->GetObjectClass(thiz), "nativeInst", "J");

	jlong inst=env->GetLongField(thiz, audioTrackInstanceFld);
	CAudioOutputAndroid* in=(CAudioOutputAndroid*)(intptr_t)inst;
	in->HandleCallback(env, buffer);
}

extern "C" JNIEXPORT jstring Java_org_telegram_messenger_voip_VoIPController_nativeGetDebugString(JNIEnv* env, jobject thiz, jlong inst){
	char buf[10240];
	((CVoIPController*)(intptr_t)inst)->GetDebugString(buf, 10240);
	return env->NewStringUTF(buf);
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_VoIPController_nativeSetNetworkType(JNIEnv* env, jobject thiz, jlong inst, jint type){
	((CVoIPController*)(intptr_t)inst)->SetNetworkType(type);
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_VoIPController_nativeSetMicMute(JNIEnv* env, jobject thiz, jlong inst, jboolean mute){
	((CVoIPController*)(intptr_t)inst)->SetMicMute(mute);
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_VoIPController_nativeSetConfig(JNIEnv* env, jobject thiz, jlong inst, jdouble recvTimeout, jdouble initTimeout, jint dataSavingMode, jboolean enableAEC, jboolean enableNS, jboolean enableAGC, jstring logFilePath){
	voip_config_t cfg;
	cfg.init_timeout=initTimeout;
	cfg.recv_timeout=recvTimeout;
	cfg.data_saving=dataSavingMode;
	cfg.enableAEC=enableAEC;
	cfg.enableNS=enableNS;
	cfg.enableAGC=enableAGC;
	if(logFilePath){
		char* path=(char *) env->GetStringUTFChars(logFilePath, NULL);
		strncpy(cfg.logFilePath, path, sizeof(cfg.logFilePath));
		cfg.logFilePath[sizeof(cfg.logFilePath)-1]=0;
		env->ReleaseStringUTFChars(logFilePath, path);
	}else{
		memset(cfg.logFilePath, 0, sizeof(cfg.logFilePath));
	}
	((CVoIPController*)(intptr_t)inst)->SetConfig(&cfg);
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_VoIPController_nativeDebugCtl(JNIEnv* env, jobject thiz, jlong inst, jint request, jint param){
	((CVoIPController*)(intptr_t)inst)->DebugCtl(request, param);
}

extern "C" JNIEXPORT jstring Java_org_telegram_messenger_voip_VoIPController_nativeGetVersion(JNIEnv* env, jclass clasz){
	return env->NewStringUTF(CVoIPController::GetVersion());
}

extern "C" JNIEXPORT jlong Java_org_telegram_messenger_voip_VoIPController_nativeGetPreferredRelayID(JNIEnv* env, jclass clasz, jlong inst){
	return ((CVoIPController*)(intptr_t)inst)->GetPreferredRelayID();
}

extern "C" JNIEXPORT jint Java_org_telegram_messenger_voip_VoIPController_nativeGetLastError(JNIEnv* env, jclass clasz, jlong inst){
	return ((CVoIPController*)(intptr_t)inst)->GetLastError();
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_VoIPController_nativeGetStats(JNIEnv* env, jclass clasz, jlong inst, jobject stats){
	voip_stats_t _stats;
	((CVoIPController*)(intptr_t)inst)->GetStats(&_stats);
	jclass cls=env->GetObjectClass(stats);
	env->SetLongField(stats, env->GetFieldID(cls, "bytesSentWifi", "J"), _stats.bytesSentWifi);
	env->SetLongField(stats, env->GetFieldID(cls, "bytesSentMobile", "J"), _stats.bytesSentMobile);
	env->SetLongField(stats, env->GetFieldID(cls, "bytesRecvdWifi", "J"), _stats.bytesRecvdWifi);
	env->SetLongField(stats, env->GetFieldID(cls, "bytesRecvdMobile", "J"), _stats.bytesRecvdMobile);
}

extern "C" JNIEXPORT void Java_org_telegram_messenger_voip_VoIPServerConfig_nativeSetConfig(JNIEnv* env, jclass clasz, jobjectArray keys, jobjectArray values){
	std::map<std::string, std::string> config;
	int len=env->GetArrayLength(keys);
	int i;
	for(i=0;i<len;i++){
		jstring jkey=(jstring)env->GetObjectArrayElement(keys, i);
		jstring jval=(jstring)env->GetObjectArrayElement(values, i);
		if(jkey==NULL|| jval==NULL)
			continue;
		const char* ckey=env->GetStringUTFChars(jkey, NULL);
		const char* cval=env->GetStringUTFChars(jval, NULL);
		std::string key(ckey);
		std::string val(cval);
		env->ReleaseStringUTFChars(jkey, ckey);
		env->ReleaseStringUTFChars(jval, cval);
		config[key]=val;
	}
	CVoIPServerConfig::GetSharedInstance()->Update(config);
}

extern "C" JNIEXPORT jstring Java_org_telegram_messenger_voip_VoIPController_nativeGetDebugLog(JNIEnv* env, jobject thiz, jlong inst){
	CVoIPController* ctlr=((CVoIPController*)(intptr_t)inst);
	std::string log=ctlr->GetDebugLog();
	return env->NewStringUTF(log.c_str());
}