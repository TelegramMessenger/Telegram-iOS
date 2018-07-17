//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//


#include "AudioIO.h"
#include "../logging.h"

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#if defined(__ANDROID__)
#include "../os/android/AudioInputAndroid.h"
#include "../os/android/AudioOutputAndroid.h"
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#include "../os/darwin/AudioUnitIO.h"
#if TARGET_OS_OSX
#include "../os/darwin/AudioInputAudioUnitOSX.h"
#include "../os/darwin/AudioOutputAudioUnitOSX.h"
#endif
#elif defined(_WIN32)
#ifdef TGVOIP_WINXP_COMPAT
#include "../os/windows/AudioInputWave.h"
#include "../os/windows/AudioOutputWave.h"
#endif
#include "../os/windows/AudioInputWASAPI.h"
#include "../os/windows/AudioOutputWASAPI.h"
#elif defined(__linux__) || defined(__FreeBSD_kernel__) || defined(__gnu_hurd__)
#ifndef WITHOUT_ALSA
#include "../os/linux/AudioInputALSA.h"
#include "../os/linux/AudioOutputALSA.h"
#endif
#ifndef WITHOUT_PULSE
#include "../os/linux/AudioPulse.h"
#endif
#else
#error "Unsupported operating system"
#endif

using namespace tgvoip;
using namespace tgvoip::audio;
using namespace std;

shared_ptr<AudioIO> AudioIO::Create(){
	std::string inputDevice="default", outputDevice="default";
#if defined(__ANDROID__)
	return std::make_shared<ContextlessAudioIO<AudioInputAndroid, AudioOutputAndroid>>();
#elif defined(__APPLE__)
#if TARGET_OS_OSX
	if(kCFCoreFoundationVersionNumber<kCFCoreFoundationVersionNumber10_7)
		return std::make_shared<ContextlessAudioIO<AudioInputAudioUnitLegacy, AudioOutputAudioUnitLegacy>>(inputDevice, outputDevice);

#endif
	return std::make_shared<AudioUnitIO>();
#elif defined(_WIN32)
#ifdef TGVOIP_WINXP_COMPAT
	if(LOBYTE(LOWORD(GetVersion()))<6)
		return std::make_shared<ContextlessAudioIO<AudioInputWave, AudioOutputWave>>(inputDevice, outputDevice);
#endif
	return std::make_shared<ContextlessAudioIO<AudioInputWASAPI, AudioOutputWASAPI>>(inputDevice, outputDevice);
#elif defined(__linux__)
#ifndef WITHOUT_ALSA
#ifndef WITHOUT_PULSE
	if(AudioPulse::Load()){
		std::shared_ptr<AudioIO> io=std::make_shared<AudioPulse>(inputDevice, outputDevice);
		if(!io->Failed() && io->GetInput()->IsInitialized() && io->GetOutput()->IsInitialized())
			return io;
		LOGW("PulseAudio available but not working; trying ALSA");
	}
#endif
	return std::make_shared<ContextlessAudioIO<AudioInputALSA, AudioOutputALSA>>(inputDevice, outputDevice);
#else
	return std::make_shared<AudioPulse>(inputDevice, outputDevice);
#endif
#endif
}

bool AudioIO::Failed(){
	return failed;
}

std::string AudioIO::GetErrorDescription(){
	return error;
}
