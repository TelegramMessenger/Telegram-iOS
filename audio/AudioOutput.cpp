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
#include "../os/darwin/AudioOutputAudioUnit.h"
#include "../os/darwin/AudioUnitIO.h"
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
	return new CAudioOutputAudioUnit(CAudioUnitIO::Get());
#endif
}


CAudioOutput::~CAudioOutput(){
#if defined(__APPLE__)
	CAudioUnitIO::Release();
#endif
}


int32_t CAudioOutput::GetEstimatedDelay(){
#if defined(__ANDROID__)
	return systemVersion<21 ? 150 : 50;
#endif
	return 0;
}

