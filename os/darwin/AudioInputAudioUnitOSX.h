//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_AUDIOINPUTAUDIOUNIT_H
#define LIBTGVOIP_AUDIOINPUTAUDIOUNIT_H

#include <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>
#include "../../audio/AudioInput.h"

class CAudioInputAudioUnit : public CAudioInput{

public:
	CAudioInputAudioUnit();
	virtual ~CAudioInputAudioUnit();
	virtual void Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels);
	virtual void Start();
	virtual void Stop();
	void HandleBufferCallback(AudioBufferList* ioData);

private:
	static OSStatus BufferCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
	unsigned char remainingData[10240];
	size_t remainingDataSize;
	bool isRecording;
	AudioUnit unit;
	AudioBufferList inBufferList;
	int hardwareSampleRate;
};


#endif //LIBTGVOIP_AUDIOINPUTAUDIOUNIT_H
