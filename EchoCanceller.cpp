//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "EchoCanceller.h"
#include "audio/AudioOutput.h"
#include "logging.h"
#include <string.h>

#define AEC_FRAME_SIZE 160
#define OFFSET_STEP AEC_FRAME_SIZE*2

//#define CLAMP(x, min, max) (x<max ? (x>min ? x : min) : max)
#define CLAMP(x, min, max) x

/*namespace webrtc{
	void WebRtcAec_enable_delay_agnostic(AecCore* self, int enable);
}*/

CEchoCanceller::CEchoCanceller(){
#ifndef TGVOIP_NO_AEC
	init_mutex(mutex);
	state=WebRtcAecm_Create();
	WebRtcAecm_Init(state, 16000);
	AecmConfig cfg;
	cfg.cngMode=AecmFalse;
	cfg.echoMode=1;
	WebRtcAecm_set_config(state, cfg);

	//ns=WebRtcNsx_Create();
	//WebRtcNsx_Init(ns, 16000);

	/*state=webrtc::WebRtcAec_Create();
	webrtc::WebRtcAec_Init(state, 16000, 16000);
	webrtc::WebRtcAec_enable_delay_agnostic(webrtc::WebRtcAec_aec_core(state), 1);*/
	splittingFilter=tgvoip_splitting_filter_create();
	splittingFilterFarend=tgvoip_splitting_filter_create();

	farendQueue=new CBlockingQueue(10);
	farendBufferPool=new CBufferPool(960*2, 10);
	running=true;

	start_thread(bufferFarendThread, CEchoCanceller::StartBufferFarendThread, this);

	isOn=true;
#endif
}

CEchoCanceller::~CEchoCanceller(){
#ifndef TGVOIP_NO_AEC
	running=false;
	farendQueue->Put(NULL);
	join_thread(bufferFarendThread);
	delete farendQueue;
	delete farendBufferPool;
	WebRtcAecm_Free(state);
	//WebRtcNsx_Free(ns);
	//webrtc::WebRtcAec_Free(state);
	tgvoip_splitting_filter_free(splittingFilter);
	tgvoip_splitting_filter_free(splittingFilterFarend);
	free_mutex(mutex);
#endif
}

void CEchoCanceller::Start(){

}

void CEchoCanceller::Stop(){

}


void CEchoCanceller::SpeakerOutCallback(unsigned char* data, size_t len){
#ifndef TGVOIP_NO_AEC
    if(len!=960*2 || !isOn)
		return;
	/*size_t offset=0;
	while(offset<len){
		WebRtcAecm_BufferFarend(state, (int16_t*)(data+offset), AEC_FRAME_SIZE);
		offset+=OFFSET_STEP;
	}*/
	unsigned char* buf=farendBufferPool->Get();
	if(buf){
		memcpy(buf, data, 960*2);
		farendQueue->Put(buf);
	}
#endif
}

#ifndef TGVOIP_NO_AEC
void *CEchoCanceller::StartBufferFarendThread(void *arg){
	((CEchoCanceller*)arg)->RunBufferFarendThread();
	return NULL;
}

void CEchoCanceller::RunBufferFarendThread(){
	while(running){
		int16_t* samplesIn=(int16_t *) farendQueue->GetBlocking();
		if(samplesIn){
			int i;
			for(i=0;i<960;i++){
				splittingFilterFarend->bufferIn[i]=samplesIn[i]/(float)32767;
			}
			farendBufferPool->Reuse((unsigned char *) samplesIn);
			tgvoip_splitting_filter_analyze(splittingFilterFarend);
			//webrtc::WebRtcAec_BufferFarend(state, splittingFilterFarend->bufferOut[0], 160);
			//webrtc::WebRtcAec_BufferFarend(state, &splittingFilterFarend->bufferOut[0][160], 160);
			int16_t farend[320];
			for(i=0;i<320;i++){
				farend[i]=(int16_t) (CLAMP(splittingFilterFarend->bufferOut[0][i], -1, 1)*32767);
			}
			lock_mutex(mutex);
			WebRtcAecm_BufferFarend(state, farend, 160);
			WebRtcAecm_BufferFarend(state, farend+160, 160);
			unlock_mutex(mutex);
			didBufferFarend=true;
		}
	}
}
#endif

void CEchoCanceller::Enable(bool enabled){
	isOn=enabled;
}

void CEchoCanceller::ProcessInput(unsigned char* data, unsigned char* out, size_t len){
#ifndef TGVOIP_NO_AEC
	int i;
	if(!isOn){
		memcpy(out, data, len);
		return;
	}
	int16_t* samplesIn=(int16_t*)data;
	int16_t* samplesOut=(int16_t*)out;
	//int16_t samplesAfterNs[320];
	//float fout[3][320];
	for(i=0;i<960;i++){
		splittingFilter->bufferIn[i]=samplesIn[i]/(float)32767;
	}

	tgvoip_splitting_filter_analyze(splittingFilter);

	for(i=0;i<320;i++){
		samplesIn[i]=(int16_t) (CLAMP(splittingFilter->bufferOut[0][i], -1, 1)*32767);
	}
	lock_mutex(mutex);
	/*float* aecIn[3];
	float* aecOut[3];
	aecIn[0]=splittingFilter->bufferOut[0];
	aecIn[1]=splittingFilter->bufferOut[1];
	aecIn[2]=splittingFilter->bufferOut[2];
	aecOut[0]=fout[0];
	aecOut[1]=fout[1];
	aecOut[2]=fout[2];
	webrtc::WebRtcAec_Process(state, (const float *const *) aecIn, 1, (float *const *) aecOut, 160, 0, 0);
	aecIn[0]+=160;
	aecIn[1]+=160;
	aecIn[2]+=160;
	aecOut[0]+=160;
	aecOut[1]+=160;
	aecOut[2]+=160;
	webrtc::WebRtcAec_Process(state, (const float *const *) aecIn, 1, (float *const *) aecOut, 160, 0, 0);*/
	//int16_t* nsIn=samplesIn;
	//int16_t* nsOut=samplesAfterNs;
	//WebRtcNsx_Process(ns, (const short *const *) &nsIn, 1, (short *const *) &nsOut);
	//nsIn+=160;
	//nsOut+=160;
	//WebRtcNsx_Process(ns, (const short *const *) &nsIn, 1, (short *const *) &nsOut);
	WebRtcAecm_Process(state, samplesIn, NULL, samplesOut, AEC_FRAME_SIZE, (int16_t) CAudioOutput::GetEstimatedDelay());
	WebRtcAecm_Process(state, samplesIn+160, NULL, samplesOut+160, AEC_FRAME_SIZE, (int16_t) CAudioOutput::GetEstimatedDelay());
	unlock_mutex(mutex);
	for(i=0;i<320;i++){
		splittingFilter->bufferOut[0][i]=samplesOut[i]/(float)32767;
	}

	//memcpy(splittingFilter->bufferOut[0], fout[0], 320*sizeof(float));
	//memcpy(splittingFilter->bufferOut[1], fout[1], 320*sizeof(float));
	//memcpy(splittingFilter->bufferOut[2], fout[2], 320*sizeof(float));

	tgvoip_splitting_filter_synthesize(splittingFilter);

	for(i=0;i<960;i++){
		samplesOut[i]=(int16_t) (CLAMP(splittingFilter->bufferIn[i], -1, 1)*32767);
	}
#else
	memcpy(out, data, len);
#endif
}

