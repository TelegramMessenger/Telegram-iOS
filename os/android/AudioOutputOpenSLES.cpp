//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include <sys/time.h>
#include <unistd.h>
#include <assert.h>
#include "AudioOutputOpenSLES.h"
#include "../../logging.h"
#include "../../VoIPController.h"
#include "OpenSLEngineWrapper.h"
#include "AudioInputAndroid.h"

#define CHECK_SL_ERROR(res, msg) if(res!=SL_RESULT_SUCCESS){ LOGE(msg); return; }
#define BUFFER_SIZE 960 // 20 ms

int CAudioOutputOpenSLES::nativeBufferSize;

CAudioOutputOpenSLES::CAudioOutputOpenSLES(){
	SLresult result;
	slEngine=COpenSLEngineWrapper::CreateEngine();

	const SLInterfaceID pOutputMixIDs[] = {};
	const SLboolean pOutputMixRequired[] = {};
	result = (*slEngine)->CreateOutputMix(slEngine, &slOutputMixObj, 0, pOutputMixIDs, pOutputMixRequired);
	CHECK_SL_ERROR(result, "Error creating output mix");

	result = (*slOutputMixObj)->Realize(slOutputMixObj, SL_BOOLEAN_FALSE);
	CHECK_SL_ERROR(result, "Error realizing output mix");

	LOGI("Native buffer size is %u samples", nativeBufferSize);
	/*if(nativeBufferSize<BUFFER_SIZE && BUFFER_SIZE % nativeBufferSize!=0){
		LOGE("20ms is not divisible by native buffer size!!");
		nativeBufferSize=BUFFER_SIZE;
	}else if(nativeBufferSize>BUFFER_SIZE && nativeBufferSize%BUFFER_SIZE!=0){
		LOGE("native buffer size is not multiple of 20ms!!");
		nativeBufferSize+=nativeBufferSize%BUFFER_SIZE;
	}
	LOGI("Adjusted native buffer size is %u", nativeBufferSize);*/

	buffer=(int16_t*)calloc(BUFFER_SIZE, sizeof(int16_t));
	nativeBuffer=(int16_t*)calloc((size_t) nativeBufferSize, sizeof(int16_t));
	slPlayerObj=NULL;
	remainingDataSize=0;
}

CAudioOutputOpenSLES::~CAudioOutputOpenSLES(){
	if(!stopped)
		Stop();
	(*slBufferQueue)->Clear(slBufferQueue);
	LOGV("destroy slPlayerObj");
	(*slPlayerObj)->Destroy(slPlayerObj);
	LOGV("destroy slOutputMixObj");
	(*slOutputMixObj)->Destroy(slOutputMixObj);
	COpenSLEngineWrapper::DestroyEngine();
	free(buffer);
	free(nativeBuffer);
}


void CAudioOutputOpenSLES::SetNativeBufferSize(int size){
	CAudioOutputOpenSLES::nativeBufferSize=size;
}

void CAudioOutputOpenSLES::BufferCallback(SLAndroidSimpleBufferQueueItf bq, void *context){
	((CAudioOutputOpenSLES*)context)->HandleSLCallback();
}

void CAudioOutputOpenSLES::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	assert(slPlayerObj==NULL);
	SLDataLocator_AndroidSimpleBufferQueue locatorBufferQueue =
			{SL_DATALOCATOR_ANDROIDSIMPLEBUFFERQUEUE, 1};
	SLDataFormat_PCM formatPCM = {SL_DATAFORMAT_PCM, channels, sampleRate*1000,
								   SL_PCMSAMPLEFORMAT_FIXED_16, SL_PCMSAMPLEFORMAT_FIXED_16,
								   channels==2 ? (SL_SPEAKER_FRONT_LEFT | SL_SPEAKER_FRONT_RIGHT) : SL_SPEAKER_FRONT_CENTER, SL_BYTEORDER_LITTLEENDIAN};
	SLDataSource audioSrc = {&locatorBufferQueue, &formatPCM};
	SLDataLocator_OutputMix locatorOutMix = {SL_DATALOCATOR_OUTPUTMIX, slOutputMixObj};
	SLDataSink audioSnk = {&locatorOutMix, NULL};

	const SLInterfaceID id[2] = {SL_IID_BUFFERQUEUE, SL_IID_ANDROIDCONFIGURATION};
	const SLboolean req[2] = {SL_BOOLEAN_TRUE, SL_BOOLEAN_TRUE};
	SLresult result = (*slEngine)->CreateAudioPlayer(slEngine, &slPlayerObj, &audioSrc, &audioSnk, 2, id, req);
	CHECK_SL_ERROR(result, "Error creating player");


	SLAndroidConfigurationItf playerConfig;
	result = (*slPlayerObj)->GetInterface(slPlayerObj, SL_IID_ANDROIDCONFIGURATION, &playerConfig);
	SLint32 streamType = SL_ANDROID_STREAM_VOICE;
	result = (*playerConfig)->SetConfiguration(playerConfig, SL_ANDROID_KEY_STREAM_TYPE, &streamType, sizeof(SLint32));


	result=(*slPlayerObj)->Realize(slPlayerObj, SL_BOOLEAN_FALSE);
	CHECK_SL_ERROR(result, "Error realizing player");

	result=(*slPlayerObj)->GetInterface(slPlayerObj, SL_IID_PLAY, &slPlayer);
	CHECK_SL_ERROR(result, "Error getting player interface");

	result=(*slPlayerObj)->GetInterface(slPlayerObj, SL_IID_ANDROIDSIMPLEBUFFERQUEUE, &slBufferQueue);
	CHECK_SL_ERROR(result, "Error getting buffer queue");

	result=(*slBufferQueue)->RegisterCallback(slBufferQueue, CAudioOutputOpenSLES::BufferCallback, this);
	CHECK_SL_ERROR(result, "Error setting buffer queue callback");

	(*slBufferQueue)->Enqueue(slBufferQueue, nativeBuffer, nativeBufferSize*sizeof(int16_t));
}

bool CAudioOutputOpenSLES::IsPhone(){
	return false;
}

void CAudioOutputOpenSLES::EnableLoudspeaker(bool enabled){

}

void CAudioOutputOpenSLES::Start(){
	stopped=false;
	SLresult result=(*slPlayer)->SetPlayState(slPlayer, SL_PLAYSTATE_PLAYING);
	CHECK_SL_ERROR(result, "Error starting player");
}

void CAudioOutputOpenSLES::Stop(){
	stopped=true;
	LOGV("Stopping OpenSL output");
	SLresult result=(*slPlayer)->SetPlayState(slPlayer, SL_PLAYSTATE_PAUSED);
	CHECK_SL_ERROR(result, "Error starting player");
}

void CAudioOutputOpenSLES::HandleSLCallback(){
	/*if(stopped){
		//LOGV("left HandleSLCallback early");
		return;
	}*/
	//LOGV("before InvokeCallback");
	if(!stopped){
		while(remainingDataSize<nativeBufferSize*2){
			assert(remainingDataSize+BUFFER_SIZE*2<10240);
			InvokeCallback(remainingData+remainingDataSize, BUFFER_SIZE*2);
			remainingDataSize+=BUFFER_SIZE*2;
		}
		memcpy(nativeBuffer, remainingData, nativeBufferSize*2);
		remainingDataSize-=nativeBufferSize*2;
		if(remainingDataSize>0)
			memmove(remainingData, remainingData+nativeBufferSize*2, remainingDataSize);
		//InvokeCallback((unsigned char *) nativeBuffer, nativeBufferSize*sizeof(int16_t));
	}else{
		memset(nativeBuffer, 0, nativeBufferSize*2);
	}

	(*slBufferQueue)->Enqueue(slBufferQueue, nativeBuffer, nativeBufferSize*sizeof(int16_t));
	//LOGV("left HandleSLCallback");
}


bool CAudioOutputOpenSLES::IsPlaying(){
	if(slPlayer){
		uint32_t state;
		(*slPlayer)->GetPlayState(slPlayer, &state);
		return state==SL_PLAYSTATE_PLAYING;
	}
	return false;
}


float CAudioOutputOpenSLES::GetLevel(){
	return 0; // we don't use this anyway
}