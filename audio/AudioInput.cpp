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

CAudioInput::CAudioInput(){
	failed=false;
}

CAudioInput *CAudioInput::Create(){
#if defined(__ANDROID__)
	return new CAudioInputAndroid();
#elif defined(__APPLE__)
	return new CAudioInputAudioUnit();
#elif defined(_WIN32)
	return new tgvoip::audio::AudioInputWave();
#elif defined(__linux__)
	return new tgvoip::audio::AudioInputALSA();
#endif
}


CAudioInput::~CAudioInput(){

}

bool CAudioInput::IsInitialized(){
	return !failed;
}
