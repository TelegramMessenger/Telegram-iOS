//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "EchoCanceller.h"
#include "audio/AudioOutput.h"
#include "logging.h"
#include <string.h>
#include <stdio.h>

#define AEC_FRAME_SIZE 160
#define OFFSET_STEP AEC_FRAME_SIZE*2

//#define CLAMP(x, min, max) (x<max ? (x>min ? x : min) : max)
#define CLAMP(x, min, max) x

/*namespace webrtc{
	void WebRtcAec_enable_delay_agnostic(AecCore* self, int enable);
}*/

CEchoCanceller::CEchoCanceller(bool enableAEC, bool enableNS, bool enableAGC){
	this->enableAEC=enableAEC;
	this->enableAGC=enableAGC;
	this->enableNS=enableNS;

	splittingFilter=tgvoip_splitting_filter_create();
	splittingFilterFarend=tgvoip_splitting_filter_create();

	if(enableAEC){
		init_mutex(aecMutex);
		aec=WebRtcAecm_Create();
		WebRtcAecm_Init(aec, 16000);
		AecmConfig cfg;
		cfg.cngMode=AecmFalse;
		cfg.echoMode=1;
		WebRtcAecm_set_config(aec, cfg);

		farendQueue=new CBlockingQueue(11);
		farendBufferPool=new CBufferPool(960*2, 10);
		running=true;

		start_thread(bufferFarendThread, CEchoCanceller::StartBufferFarendThread, this);
	}

	if(enableNS){
		ns=WebRtcNsx_Create();
		WebRtcNsx_Init(ns, 48000);
		WebRtcNsx_set_policy(ns, 2);
	}

	if(enableAGC){
		agc=WebRtcAgc_Create();
		WebRtcAgcConfig agcConfig;
		agcConfig.compressionGaindB = 9;
		agcConfig.limiterEnable = 1;
		agcConfig.targetLevelDbfs = 3;
		WebRtcAgc_Init(agc, 0, 255, kAgcModeAdaptiveAnalog, 48000);
		WebRtcAgc_set_config(agc, agcConfig);
		agcMicLevel=128;
	}

	/*state=webrtc::WebRtcAec_Create();
	webrtc::WebRtcAec_Init(state, 16000, 16000);
	webrtc::WebRtcAec_enable_delay_agnostic(webrtc::WebRtcAec_aec_core(state), 1);*/
}

CEchoCanceller::~CEchoCanceller(){
	if(enableAEC){
		running=false;
		farendQueue->Put(NULL);
		join_thread(bufferFarendThread);
		delete farendQueue;
		delete farendBufferPool;
		WebRtcAecm_Free(aec);
	}
	if(enableNS){
		WebRtcNsx_Free(ns);
	}
	if(enableAGC){
		WebRtcAgc_Free(agc);
	}
	//webrtc::WebRtcAec_Free(state);
	tgvoip_splitting_filter_free(splittingFilter);
	tgvoip_splitting_filter_free(splittingFilterFarend);
    if (this->enableAEC) {
        free_mutex(aecMutex);
    }
}

void CEchoCanceller::Start(){

}

void CEchoCanceller::Stop(){

}


void CEchoCanceller::SpeakerOutCallback(unsigned char* data, size_t len){
    if(len!=960*2 || !enableAEC)
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
}

void *CEchoCanceller::StartBufferFarendThread(void *arg){
	((CEchoCanceller*)arg)->RunBufferFarendThread();
	return NULL;
}

void CEchoCanceller::RunBufferFarendThread(){
	while(running){
		int16_t* samplesIn=(int16_t *) farendQueue->GetBlocking();
		if(samplesIn){
			int i;
			memcpy(splittingFilterFarend->bufferIn, samplesIn, 960*2);
			farendBufferPool->Reuse((unsigned char *) samplesIn);
			tgvoip_splitting_filter_analyze(splittingFilterFarend);
			lock_mutex(aecMutex);
			//webrtc::WebRtcAec_BufferFarend(state, splittingFilterFarend->bufferOut[0], 160);
			//webrtc::WebRtcAec_BufferFarend(state, &splittingFilterFarend->bufferOut[0][160], 160);
			WebRtcAecm_BufferFarend(aec, splittingFilterFarend->bufferOut[0], 160);
			WebRtcAecm_BufferFarend(aec, splittingFilterFarend->bufferOut[0]+160, 160);
			unlock_mutex(aecMutex);
			didBufferFarend=true;
		}
	}
}

void CEchoCanceller::Enable(bool enabled){
	//isOn=enabled;
}

void CEchoCanceller::ProcessInput(unsigned char* data, unsigned char* out, size_t len){
	int i;
	if(!enableAEC && !enableAGC && !enableNS){
		memcpy(out, data, len);
		return;
	}
	int16_t* samplesIn=(int16_t*)data;
	int16_t* samplesOut=(int16_t*)out;
	//int16_t samplesAfterNs[320];
	//float fout[3][320];
	memcpy(splittingFilter->bufferIn, samplesIn, 960*2);

	tgvoip_splitting_filter_analyze(splittingFilter);
	
	if(enableAGC){
		int16_t _agcOut[3][320];
		int16_t* agcIn[3];
		int16_t* agcOut[3];
		for(i=0;i<3;i++){
			agcIn[i]=splittingFilter->bufferOut[i];
			agcOut[i]=_agcOut[i];
		}
		uint8_t saturation;
		WebRtcAgc_AddMic(agc, agcIn, 3, 160);
		WebRtcAgc_Process(agc, (const int16_t *const *) agcIn, 3, 160, agcOut, agcMicLevel, &agcMicLevel, 0, &saturation);
		for(i=0;i<3;i++){
			agcOut[i]+=160;
			agcIn[i]+=160;
		}
		WebRtcAgc_AddMic(agc, agcIn, 3, 160);
		WebRtcAgc_Process(agc, (const int16_t *const *) agcIn, 3, 160, agcOut, agcMicLevel, &agcMicLevel, 0, &saturation);
		//LOGV("AGC mic level %d", agcMicLevel);
		memcpy(splittingFilter->bufferOut[0], _agcOut[0], 960*2);
	}

	if(enableAEC && enableNS){
		int16_t _nsOut[3][320];
		int16_t* nsIn[3];
		int16_t* nsOut[3];
		for(i=0;i<3;i++){
			nsIn[i]=splittingFilter->bufferOut[i];
			nsOut[i]=_nsOut[i];
		}
		WebRtcNsx_Process(ns, (const short *const *) nsIn, 3, nsOut);
		for(i=0;i<3;i++){
			nsOut[i]+=160;
			nsIn[i]+=160;
		}
		WebRtcNsx_Process(ns, (const short *const *) nsIn, 3, nsOut);

		memcpy(splittingFilter->bufferOut[1], _nsOut[1], 320*2*2);

		lock_mutex(aecMutex);
		WebRtcAecm_Process(aec, splittingFilter->bufferOut[0], _nsOut[0], samplesOut, AEC_FRAME_SIZE, (int16_t) CAudioOutput::GetEstimatedDelay());
		WebRtcAecm_Process(aec, splittingFilter->bufferOut[0]+160, _nsOut[0]+160, samplesOut+160, AEC_FRAME_SIZE, (int16_t) CAudioOutput::GetEstimatedDelay());
		unlock_mutex(aecMutex);
		memcpy(splittingFilter->bufferOut[0], samplesOut, 320*2);
	}else if(enableAEC){
		lock_mutex(aecMutex);
		WebRtcAecm_Process(aec, splittingFilter->bufferOut[0], NULL, samplesOut, AEC_FRAME_SIZE, (int16_t) CAudioOutput::GetEstimatedDelay());
		WebRtcAecm_Process(aec, splittingFilter->bufferOut[0]+160, NULL, samplesOut+160, AEC_FRAME_SIZE, (int16_t) CAudioOutput::GetEstimatedDelay());
		unlock_mutex(aecMutex);
		memcpy(splittingFilter->bufferOut[0], samplesOut, 320*2);
	}else if(enableNS){
		int16_t _nsOut[3][320];
		int16_t* nsIn[3];
		int16_t* nsOut[3];
		for(i=0;i<3;i++){
			nsIn[i]=splittingFilter->bufferOut[i];
			nsOut[i]=_nsOut[i];
		}
		WebRtcNsx_Process(ns, (const short *const *) nsIn, 3, nsOut);
		for(i=0;i<3;i++){
			nsOut[i]+=160;
			nsIn[i]+=160;
		}
		WebRtcNsx_Process(ns, (const short *const *) nsIn, 3, nsOut);

		memcpy(splittingFilter->bufferOut[0], _nsOut[0], 960*2);
		//memcpy(splittingFilter->bufferOut[1], _nsOut[1], 320*2);
		//memcpy(splittingFilter->bufferOut[2], _nsOut[2], 320*2);
	}

	//memcpy(splittingFilter->bufferOut[0], fout[0], 320*sizeof(float));
	//memcpy(splittingFilter->bufferOut[1], fout[1], 320*sizeof(float));
	//memcpy(splittingFilter->bufferOut[2], fout[2], 320*sizeof(float));

	tgvoip_splitting_filter_synthesize(splittingFilter);

	memcpy(samplesOut, splittingFilter->bufferIn, 960*2);
}

