//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "AudioOutput.h"
#if defined(__ANDROID__)
#include "../os/android/AudioOutputOpenSLES.h"
#include "../os/android/AudioOutputAndroid.h"
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#include "../os/darwin/AudioOutputAudioUnit.h"
#else
#include "../os/darwin/AudioOutputAudioUnitOSX.h"
#endif
#elif defined(_WIN32)
#include "../os/windows/AudioOutputWave.h"
#elif defined(__linux__)
#include "../os/linux/AudioOutputALSA.h"
#else
#error "Unsupported operating system"
#endif

#if defined(__ANDROID__)
int CAudioOutput::systemVersion;
#endif

CAudioOutput *CAudioOutput::Create(){
#if defined(__ANDROID__)
	if(systemVersion<21)
		return new CAudioOutputAndroid();
	return new CAudioOutputOpenSLES();
#elif defined(__APPLE__)
	return new CAudioOutputAudioUnit();
#elif defined(_WIN32)
	return new tgvoip::audio::AudioOutputWave();
#elif defined(__linux__)
	return new tgvoip::audio::AudioOutputALSA();
#endif
}

CAudioOutput::CAudioOutput(){
	failed=false;
}

CAudioOutput::~CAudioOutput(){

}


int32_t CAudioOutput::GetEstimatedDelay(){
#if defined(__ANDROID__)
	return systemVersion<21 ? 150 : 50;
#endif
	return 60;
}

float CAudioOutput::GetLevel(){
	return 0;
}
