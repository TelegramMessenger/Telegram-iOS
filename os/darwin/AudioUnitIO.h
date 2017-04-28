//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_AUDIOUNITIO_H
#define LIBTGVOIP_AUDIOUNITIO_H

#include <AudioUnit/AudioUnit.h>
#include "../../threading.h"

namespace tgvoip{ namespace audio{
class AudioInputAudioUnit;
class AudioOutputAudioUnit;

class AudioUnitIO{
public:
	AudioUnitIO();
	~AudioUnitIO();
	void Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels);
	void AttachInput(AudioInputAudioUnit* i);
	void AttachOutput(AudioOutputAudioUnit* o);
	void DetachInput();
	void DetachOutput();
	void EnableInput(bool enabled);
	void EnableOutput(bool enabled);
	static AudioUnitIO* Get();
	static void Release();
	static void* StartFakeIOThread(void* arg);
	static void AudioSessionAcquired();
	
private:
	static OSStatus BufferCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
	void BufferCallback(AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 bus, UInt32 numFrames, AudioBufferList* ioData);
	void RunFakeIOThread();
	void Init();
	void ActuallyConfigure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels);
	void ProcessAudioSessionAcquired();
	AudioComponentInstance unit;
	AudioInputAudioUnit* input;
	AudioOutputAudioUnit* output;
	AudioBufferList inBufferList;
	bool configured;
	bool inputEnabled;
	bool outputEnabled;
	bool runFakeIO;
	uint32_t cfgSampleRate;
	uint32_t cfgBitsPerSample;
	uint32_t cfgChannels;
	tgvoip_thread_t fakeIOThread;
	static int refCount;
	static AudioUnitIO* sharedInstance;
	static bool haveAudioSession;
};
}}

#endif /* LIBTGVOIP_AUDIOUNITIO_H */
