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

#ifndef TGVOIP_NO_AEC
#include "webrtc/modules/audio_processing/aecm/echo_control_mobile.h"
//#include "external/include/webrtc/echo_cancellation.h"
#include "webrtc/modules/audio_processing/splitting_filter.h"
#include "webrtc/common_audio/channel_buffer.h"
#include "webrtc/modules/audio_processing/ns/noise_suppression_x.h"
#include "webrtc/modules/audio_processing/agc/legacy/gain_control.h"
#endif

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
	
#ifndef TGVOIP_NO_DSP

	splittingFilter=new webrtc::SplittingFilter(1, 3, 960);
	splittingFilterFarend=new webrtc::SplittingFilter(1, 3, 960);
	
	splittingFilterIn=new webrtc::IFChannelBuffer(960, 1, 1);
	splittingFilterFarendIn=new webrtc::IFChannelBuffer(960, 1, 1);
	splittingFilterOut=new webrtc::IFChannelBuffer(960, 1, 3);
	splittingFilterFarendOut=new webrtc::IFChannelBuffer(960, 1, 3);

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
		WebRtcNsx_Init((NsxHandle*)ns, 48000);
		WebRtcNsx_set_policy((NsxHandle*)ns, 2);
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
#endif
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
		WebRtcNsx_Free((NsxHandle*)ns);
	}
	if(enableAGC){
		WebRtcAgc_Free(agc);
	}
	//webrtc::WebRtcAec_Free(state);
	
	delete (webrtc::SplittingFilter*)splittingFilter;
	delete (webrtc::SplittingFilter*)splittingFilterFarend;
	
	delete (webrtc::IFChannelBuffer*)splittingFilterIn;
	delete (webrtc::IFChannelBuffer*)splittingFilterOut;
	delete (webrtc::IFChannelBuffer*)splittingFilterFarendIn;
	delete (webrtc::IFChannelBuffer*)splittingFilterFarendOut;
	
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
			webrtc::IFChannelBuffer* bufIn=(webrtc::IFChannelBuffer*) splittingFilterFarendIn;
			webrtc::IFChannelBuffer* bufOut=(webrtc::IFChannelBuffer*) splittingFilterFarendOut;
			memcpy(bufIn->ibuf()->bands(0)[0], samplesIn, 960*2);
			farendBufferPool->Reuse((unsigned char *) samplesIn);
			((webrtc::SplittingFilter*)splittingFilterFarend)->Analysis(bufIn, bufOut);
			lock_mutex(aecMutex);
			//webrtc::WebRtcAec_BufferFarend(state, splittingFilterFarend->bufferOut[0], 160);
			//webrtc::WebRtcAec_BufferFarend(state, &splittingFilterFarend->bufferOut[0][160], 160);
			WebRtcAecm_BufferFarend(aec, bufOut->ibuf_const()->bands(0)[0], 160);
			WebRtcAecm_BufferFarend(aec, bufOut->ibuf_const()->bands(0)[0]+160, 160);
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
	
	webrtc::IFChannelBuffer* bufIn=(webrtc::IFChannelBuffer*) splittingFilterFarendIn;
	webrtc::IFChannelBuffer* bufOut=(webrtc::IFChannelBuffer*) splittingFilterFarendOut;
	
	memcpy(bufIn->ibuf()->bands(0)[0], samplesIn, 960*2);

	((webrtc::SplittingFilter*)splittingFilter)->Analysis(bufIn, bufOut);
	
	if(enableAGC){
		int16_t _agcOut[3][320];
		int16_t* agcIn[3];
		int16_t* agcOut[3];
		for(i=0;i<3;i++){
			agcIn[i]=(int16_t*)bufOut->ibuf_const()->bands(0)[i];
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
		memcpy(bufOut->ibuf()->bands(0)[0], _agcOut[0], 320*2);
		memcpy(bufOut->ibuf()->bands(0)[1], _agcOut[1], 320*2);
		memcpy(bufOut->ibuf()->bands(0)[2], _agcOut[2], 320*2);
	}

	if(enableAEC && enableNS){
		int16_t _nsOut[3][320];
		int16_t* nsIn[3];
		int16_t* nsOut[3];
		for(i=0;i<3;i++){
			nsIn[i]=(int16_t*)bufOut->ibuf_const()->bands(0)[i];
			nsOut[i]=_nsOut[i];
		}
		WebRtcNsx_Process((NsxHandle*)ns, (const short *const *) nsIn, 3, nsOut);
		for(i=0;i<3;i++){
			nsOut[i]+=160;
			nsIn[i]+=160;
		}
		WebRtcNsx_Process((NsxHandle*)ns, (const short *const *) nsIn, 3, nsOut);

		memcpy(bufOut->ibuf()->bands(0)[1], _nsOut[1], 320*2*2);

		lock_mutex(aecMutex);
		WebRtcAecm_Process(aec, bufOut->ibuf()->bands(0)[0], _nsOut[0], samplesOut, AEC_FRAME_SIZE, (int16_t) CAudioOutput::GetEstimatedDelay());
		WebRtcAecm_Process(aec, bufOut->ibuf()->bands(0)[0]+160, _nsOut[0]+160, samplesOut+160, AEC_FRAME_SIZE, (int16_t) CAudioOutput::GetEstimatedDelay());
		unlock_mutex(aecMutex);
		memcpy(bufOut->ibuf()->bands(0)[0], samplesOut, 320*2);
	}else if(enableAEC){
		lock_mutex(aecMutex);
		WebRtcAecm_Process(aec, bufOut->ibuf()->bands(0)[0], NULL, samplesOut, AEC_FRAME_SIZE, (int16_t) CAudioOutput::GetEstimatedDelay());
		WebRtcAecm_Process(aec, bufOut->ibuf()->bands(0)[0]+160, NULL, samplesOut+160, AEC_FRAME_SIZE, (int16_t) CAudioOutput::GetEstimatedDelay());
		unlock_mutex(aecMutex);
		memcpy(bufOut->ibuf()->bands(0)[0], samplesOut, 320*2);
	}else if(enableNS){
		int16_t _nsOut[3][320];
		int16_t* nsIn[3];
		int16_t* nsOut[3];
		for(i=0;i<3;i++){
			nsIn[i]=(int16_t*)bufOut->ibuf_const()->bands(0)[i];
			nsOut[i]=_nsOut[i];
		}
		WebRtcNsx_Process((NsxHandle*)ns, (const short *const *) nsIn, 3, nsOut);
		for(i=0;i<3;i++){
			nsOut[i]+=160;
			nsIn[i]+=160;
		}
		WebRtcNsx_Process((NsxHandle*)ns, (const short *const *) nsIn, 3, nsOut);

		memcpy(bufOut->ibuf()->bands(0)[0], _nsOut[0], 320*2);
		memcpy(bufOut->ibuf()->bands(0)[1], _nsOut[1], 320*2);
		memcpy(bufOut->ibuf()->bands(0)[2], _nsOut[2], 320*2);
	}

	((webrtc::SplittingFilter*)splittingFilter)->Synthesis(bufOut, bufIn);
	
	memcpy(samplesOut, bufIn->ibuf()->bands(0)[0], 960*2);
}

