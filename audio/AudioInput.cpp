//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "AudioInput.h"
#include "../logging.h"
#if defined(__ANDROID__)
#include "../os/android/AudioInputAndroid.h"
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#include "../os/darwin/AudioInputAudioUnit.h"
#if TARGET_OS_OSX
#include "../os/darwin/AudioInputAudioUnitOSX.h"
#endif
#elif defined(_WIN32)
#ifdef TGVOIP_WINXP_COMPAT
#include "../os/windows/AudioInputWave.h"
#endif
#include "../os/windows/AudioInputWASAPI.h"
#elif defined(__linux__)
#include "../os/linux/AudioInputALSA.h"
#include "../os/linux/AudioInputPulse.h"
#else
#error "Unsupported operating system"
#endif

using namespace tgvoip;
using namespace tgvoip::audio;

int32_t AudioInput::estimatedDelay=60;

AudioInput::AudioInput() : currentDevice("default"){
	failed=false;
}

AudioInput::AudioInput(std::string deviceID) : currentDevice(deviceID){
	failed=false;
}

AudioInput *AudioInput::Create(std::string deviceID){
#if defined(__ANDROID__)
	return new AudioInputAndroid();
#elif defined(__APPLE__)
#if TARGET_OS_OSX
	if(kCFCoreFoundationVersionNumber<kCFCoreFoundationVersionNumber10_7)
		return new AudioInputAudioUnitLegacy(deviceID);
#endif
	return new AudioInputAudioUnit(deviceID);
#elif defined(_WIN32)
#ifdef TGVOIP_WINXP_COMPAT
	if(LOBYTE(LOWORD(GetVersion()))<6)
		return new AudioInputWave(deviceID);
#endif
	return new AudioInputWASAPI(deviceID);
#elif defined(__linux__)
	if(AudioInputPulse::IsAvailable()){
		AudioInputPulse* aip=new AudioInputPulse(deviceID);
		if(!aip->IsInitialized())
			delete aip;
		else
			return aip;
		LOGW("in: PulseAudio available but not working; trying ALSA");
	}
	return new AudioInputALSA(deviceID);
#endif
}


AudioInput::~AudioInput(){

}

bool AudioInput::IsInitialized(){
	return !failed;
}

void AudioInput::EnumerateDevices(std::vector<AudioInputDevice>& devs){
#if defined(__APPLE__) && TARGET_OS_OSX
	AudioInputAudioUnitLegacy::EnumerateDevices(devs);
#elif defined(_WIN32)
#ifdef TGVOIP_WINXP_COMPAT
	if(LOBYTE(LOWORD(GetVersion()))<6){
		AudioInputWave::EnumerateDevices(devs);
		return;
	}
#endif
	AudioInputWASAPI::EnumerateDevices(devs);
#elif defined(__linux__) && !defined(__ANDROID__)
	if(!AudioInputPulse::IsAvailable() || !AudioInputPulse::EnumerateDevices(devs))
		AudioInputALSA::EnumerateDevices(devs);
#endif
}

std::string AudioInput::GetCurrentDevice(){
	return currentDevice;
}

void AudioInput::SetCurrentDevice(std::string deviceID){
	
}

int32_t AudioInput::GetEstimatedDelay(){
	return estimatedDelay;
}
