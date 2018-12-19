//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef TGVOIP_NO_DSP
#include "webrtc_dsp/modules/audio_processing/include/audio_processing.h"
#include "webrtc_dsp/api/audio/audio_frame.h"
#endif

#include "EchoCanceller.h"
#include "audio/AudioOutput.h"
#include "audio/AudioInput.h"
#include "logging.h"
#include "VoIPServerConfig.h"
#include <string.h>
#include <stdio.h>

using namespace tgvoip;

EchoCanceller::EchoCanceller(bool enableAEC, bool enableNS, bool enableAGC){
#ifndef TGVOIP_NO_DSP
	this->enableAEC=enableAEC;
	this->enableAGC=enableAGC;
	this->enableNS=enableNS;
	isOn=true;

	webrtc::Config extraConfig;
#ifdef TGVOIP_USE_DESKTOP_DSP
	extraConfig.Set(new webrtc::DelayAgnostic(true));
#endif

	apm=webrtc::AudioProcessingBuilder().Create(extraConfig);

	webrtc::AudioProcessing::Config config;
	config.echo_canceller.enabled = enableAEC;
#ifndef TGVOIP_USE_DESKTOP_DSP
	config.echo_canceller.mobile_mode = true;
#else
	config.echo_canceller.mobile_mode = false;
#endif
	config.high_pass_filter.enabled = enableAEC;
	config.gain_controller2.enabled = enableAGC;
	apm->ApplyConfig(config);
	
	webrtc::NoiseSuppression::Level nsLevel;
#ifdef __APPLE__
	switch(ServerConfig::GetSharedInstance()->GetInt("webrtc_ns_level_vpio", 0)){
#else
	switch(ServerConfig::GetSharedInstance()->GetInt("webrtc_ns_level", 2)){
#endif
		case 0:
			nsLevel=webrtc::NoiseSuppression::Level::kLow;
			break;
		case 1:
			nsLevel=webrtc::NoiseSuppression::Level::kModerate;
			break;
		case 3:
			nsLevel=webrtc::NoiseSuppression::Level::kVeryHigh;
			break;
		case 2:
		default:
			nsLevel=webrtc::NoiseSuppression::Level::kHigh;
			break;
	}
	apm->noise_suppression()->set_level(nsLevel);
	apm->noise_suppression()->Enable(enableNS);
	if(enableAGC){
		apm->gain_control()->set_mode(webrtc::GainControl::Mode::kAdaptiveDigital);
		apm->gain_control()->set_target_level_dbfs(ServerConfig::GetSharedInstance()->GetInt("webrtc_agc_target_level", 9));
		apm->gain_control()->enable_limiter(ServerConfig::GetSharedInstance()->GetBoolean("webrtc_agc_enable_limiter", true));
		apm->gain_control()->set_compression_gain_db(ServerConfig::GetSharedInstance()->GetInt("webrtc_agc_compression_gain", 20));
	}
	apm->voice_detection()->set_likelihood(webrtc::VoiceDetection::Likelihood::kVeryLowLikelihood);

	audioFrame=new webrtc::AudioFrame();
	audioFrame->samples_per_channel_=480;
	audioFrame->sample_rate_hz_=48000;
	audioFrame->num_channels_=1;

	farendQueue=new BlockingQueue<int16_t*>(11);
	farendBufferPool=new BufferPool(960*2, 10);
	running=true;
	bufferFarendThread=new Thread(std::bind(&EchoCanceller::RunBufferFarendThread, this));
	bufferFarendThread->Start();

#else
	this->enableAEC=this->enableAGC=enableAGC=this->enableNS=enableNS=false;
	isOn=true;
#endif
}

EchoCanceller::~EchoCanceller(){
#ifndef TGVOIP_NO_DSP
	delete apm;
	delete audioFrame;
#endif
}

void EchoCanceller::Start(){

}

void EchoCanceller::Stop(){

}


void EchoCanceller::SpeakerOutCallback(unsigned char* data, size_t len){
    if(len!=960*2 || !enableAEC || !isOn)
		return;
#ifndef TGVOIP_NO_DSP
	int16_t* buf=(int16_t*)farendBufferPool->Get();
	if(buf){
		memcpy(buf, data, 960*2);
		farendQueue->Put(buf);
	}
#endif
}

#ifndef TGVOIP_NO_DSP
void EchoCanceller::RunBufferFarendThread(){
	webrtc::AudioFrame frame;
	frame.num_channels_=1;
	frame.sample_rate_hz_=48000;
	frame.samples_per_channel_=480;
	while(running){
		int16_t* samplesIn=farendQueue->GetBlocking();
		if(samplesIn){
			memcpy(frame.mutable_data(), samplesIn, 480*2);
			apm->ProcessReverseStream(&frame);
			memcpy(frame.mutable_data(), samplesIn+480, 480*2);
			apm->ProcessReverseStream(&frame);
			didBufferFarend=true;
			farendBufferPool->Reuse(reinterpret_cast<unsigned char*>(samplesIn));
		}
	}
}
#endif

void EchoCanceller::Enable(bool enabled){
	isOn=enabled;
}

void EchoCanceller::ProcessInput(int16_t* inOut, size_t numSamples, bool& hasVoice){
	if(!isOn || (!enableAEC && !enableAGC && !enableNS)){
		return;
	}
	int delay=audio::AudioInput::GetEstimatedDelay()+audio::AudioOutput::GetEstimatedDelay();
	assert(numSamples==960);

	memcpy(audioFrame->mutable_data(), inOut, 480*2);
	if(enableAEC)
    	apm->set_stream_delay_ms(delay);
	apm->ProcessStream(audioFrame);
	if(enableVAD)
    	hasVoice=apm->voice_detection()->stream_has_voice();
	memcpy(inOut, audioFrame->data(), 480*2);
	memcpy(audioFrame->mutable_data(), inOut+480, 480*2);
	if(enableAEC)
    	apm->set_stream_delay_ms(delay);
	apm->ProcessStream(audioFrame);
	if(enableVAD){
    	hasVoice=hasVoice || apm->voice_detection()->stream_has_voice();
	}
	memcpy(inOut+480, audioFrame->data(), 480*2);
}

void EchoCanceller::SetAECStrength(int strength){
#ifndef TGVOIP_NO_DSP
	/*if(aec){
#ifndef TGVOIP_USE_DESKTOP_DSP
		AecmConfig cfg;
		cfg.cngMode=AecmFalse;
		cfg.echoMode=(int16_t) strength;
		WebRtcAecm_set_config(aec, cfg);
#endif
	}*/
#endif
}

void EchoCanceller::SetVoiceDetectionEnabled(bool enabled){
	enableVAD=enabled;
	apm->voice_detection()->Enable(enabled);
}

AudioEffect::~AudioEffect(){

}

void AudioEffect::SetPassThrough(bool passThrough){
	this->passThrough=passThrough;
}

AutomaticGainControl::AutomaticGainControl(){
#ifndef TGVOIP_NO_DSP
	/*splittingFilter=new webrtc::SplittingFilter(1, 3, 960);
	splittingFilterIn=new webrtc::IFChannelBuffer(960, 1, 1);
	splittingFilterOut=new webrtc::IFChannelBuffer(960, 1, 3);

	agc=WebRtcAgc_Create();
	WebRtcAgcConfig agcConfig;
	agcConfig.compressionGaindB = 9;
	agcConfig.limiterEnable = 1;
	agcConfig.targetLevelDbfs = 3;
	WebRtcAgc_Init(agc, 0, 255, kAgcModeAdaptiveDigital, 48000);
	WebRtcAgc_set_config(agc, agcConfig);
	agcMicLevel=0;*/
#endif
}

AutomaticGainControl::~AutomaticGainControl(){
#ifndef TGVOIP_NO_DSP
	/*delete (webrtc::SplittingFilter*)splittingFilter;
	delete (webrtc::IFChannelBuffer*)splittingFilterIn;
	delete (webrtc::IFChannelBuffer*)splittingFilterOut;
	WebRtcAgc_Free(agc);*/
#endif
}

void AutomaticGainControl::Process(int16_t *inOut, size_t numSamples){
#ifndef TGVOIP_NO_DSP
	/*if(passThrough)
		return;
	if(numSamples!=960){
		LOGW("AutomaticGainControl only works on 960-sample buffers (got %u samples)", (unsigned int)numSamples);
		return;
	}
	//LOGV("processing frame through AGC");

	webrtc::IFChannelBuffer* bufIn=(webrtc::IFChannelBuffer*) splittingFilterIn;
	webrtc::IFChannelBuffer* bufOut=(webrtc::IFChannelBuffer*) splittingFilterOut;

	memcpy(bufIn->ibuf()->bands(0)[0], inOut, 960*2);

	((webrtc::SplittingFilter*)splittingFilter)->Analysis(bufIn, bufOut);

	int i;
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
	memcpy(bufOut->ibuf()->bands(0)[0], _agcOut[0], 320*2);
	memcpy(bufOut->ibuf()->bands(0)[1], _agcOut[1], 320*2);
	memcpy(bufOut->ibuf()->bands(0)[2], _agcOut[2], 320*2);

	((webrtc::SplittingFilter*)splittingFilter)->Synthesis(bufOut, bufIn);

	memcpy(inOut, bufIn->ibuf_const()->bands(0)[0], 960*2);*/
#endif
}

