//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "AudioInput.h"
#if defined(__ANDROID__)
#include "../os/android/AudioInputAndroid.h"
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#include "../os/darwin/AudioInputAudioUnit.h"
#else
#include "../os/darwin/AudioInputAudioUnitOSX.h"
#endif
#elif defined(_WIN32)
#include "../os/windows/AudioInputWave.h"
#elif defined(__linux__)
#include "../os/linux/AudioInputALSA.h"
#else
#error "Unsupported operating system"
#endif

using namespace tgvoip;
using namespace tgvoip::audio;

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
	return new AudioInputAudioUnit(deviceID);
#else
	return new AudioInputAudioUnit();
#endif
#elif defined(_WIN32)
	return new AudioInputWave(deviceID);
#elif defined(__linux__)
	return new AudioInputALSA();
#endif
}


AudioInput::~AudioInput(){

}

bool AudioInput::IsInitialized(){
	return !failed;
}

void AudioInput::EnumerateDevices(std::vector<AudioInputDevice>& devs){
#if defined(__APPLE__) && TARGET_OS_OSX
	AudioInputAudioUnit::EnumerateDevices(devs);
#elif defined(_WIN32)
	AudioInputWave::EnumerateDevices(devs);
#elif defined(__linux__) && !defined(__ANDROID__)
	return new AudioInputALSA();
#endif
}

std::string AudioInput::GetCurrentDevice(){
	return currentDevice;
}

void AudioInput::SetCurrentDevice(std::string deviceID){
	
}
