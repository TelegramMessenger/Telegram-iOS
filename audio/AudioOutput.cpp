//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "AudioOutput.h"
#include "../logging.h"
#include <stdlib.h>
#if defined(__ANDROID__)
#include "../os/android/AudioOutputOpenSLES.h"
#include "../os/android/AudioOutputAndroid.h"
#include <sys/system_properties.h>
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#include "../os/darwin/AudioOutputAudioUnit.h"
#if TARGET_OS_OSX
#include "../os/darwin/AudioOutputAudioUnitOSX.h"
#endif
#elif defined(_WIN32)
#ifdef TGVOIP_WINXP_COMPAT
#include "../os/windows/AudioOutputWave.h"
#endif
#include "../os/windows/AudioOutputWASAPI.h"
#elif defined(__linux__)
#include "../os/linux/AudioOutputALSA.h"
#include "../os/linux/AudioOutputPulse.h"
#else
#error "Unsupported operating system"
#endif

using namespace tgvoip;
using namespace tgvoip::audio;

int32_t AudioOutput::estimatedDelay=60;

std::unique_ptr<AudioOutput> AudioOutput::Create(std::string deviceID, void* platformSpecific){
#if defined(__ANDROID__)
	return std::unique_ptr<AudioOutput>(new AudioOutputAndroid());
#elif defined(__APPLE__)
#if TARGET_OS_OSX
	if(kCFCoreFoundationVersionNumber<kCFCoreFoundationVersionNumber10_7)
		return std::unique_ptr<AudioOutput>(new AudioOutputAudioUnitLegacy(deviceID));
#endif
	return std::unique_ptr<AudioOutput>(new AudioOutputAudioUnit(deviceID, reinterpret_cast<AudioUnitIO*>(platformSpecific)));
#elif defined(_WIN32)
#ifdef TGVOIP_WINXP_COMPAT
	if(LOBYTE(LOWORD(GetVersion()))<6)
		return std::unique_ptr<AudioOutput>(new AudioOutputWave(deviceID));
#endif
	return std::unique_ptr<AudioOutput>(new AudioOutputWASAPI(deviceID));
#elif defined(__linux__)
	if(AudioOutputPulse::IsAvailable()){
		AudioOutputPulse* aop=new AudioOutputPulse(deviceID);
		if(!aop->IsInitialized())
			delete aop;
		else
			return std::unique_ptr<AudioOutput>(aop);
		LOGW("out: PulseAudio available but not working; trying ALSA");
	}
	return std::unique_ptr<AudioOutput>(new AudioOutputALSA(deviceID));
#endif
}

AudioOutput::AudioOutput() : currentDevice("default"){
	failed=false;
}

AudioOutput::AudioOutput(std::string deviceID) : currentDevice(deviceID){
	failed=false;
}

AudioOutput::~AudioOutput(){

}


int32_t AudioOutput::GetEstimatedDelay(){
#if defined(__ANDROID__)
	char sdkNum[PROP_VALUE_MAX];
	__system_property_get("ro.build.version.sdk", sdkNum);
	int systemVersion=atoi(sdkNum);
	return systemVersion<21 ? 150 : 50;
#endif
	return estimatedDelay;
}

float AudioOutput::GetLevel(){
	return 0;
}


void AudioOutput::EnumerateDevices(std::vector<AudioOutputDevice>& devs){
#if defined(__APPLE__) && TARGET_OS_OSX
	AudioOutputAudioUnitLegacy::EnumerateDevices(devs);
#elif defined(_WIN32)
#ifdef TGVOIP_WINXP_COMPAT
	if(LOBYTE(LOWORD(GetVersion()))<6){
		AudioOutputWave::EnumerateDevices(devs);
		return;
	}
#endif
	AudioOutputWASAPI::EnumerateDevices(devs);
#elif defined(__linux__) && !defined(__ANDROID__)
	if(!AudioOutputPulse::IsAvailable() || !AudioOutputPulse::EnumerateDevices(devs))
		AudioOutputALSA::EnumerateDevices(devs);
#endif
}


std::string AudioOutput::GetCurrentDevice(){
	return currentDevice;
}

void AudioOutput::SetCurrentDevice(std::string deviceID){
	
}

bool AudioOutput::IsInitialized(){
	return !failed;
}
