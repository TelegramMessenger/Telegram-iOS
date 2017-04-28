//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_AUDIOINPUTAUDIOUNIT_H
#define LIBTGVOIP_AUDIOINPUTAUDIOUNIT_H

#include <AudioUnit/AudioUnit.h>
#include "../../audio/AudioInput.h"

namespace tgvoip{ namespace audio{
class AudioUnitIO;

class AudioInputAudioUnit : public AudioInput{

public:
	AudioInputAudioUnit();
	virtual ~AudioInputAudioUnit();
	virtual void Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels);
	virtual void Start();
	virtual void Stop();
	void HandleBufferCallback(AudioBufferList* ioData);

private:
	unsigned char remainingData[10240];
	size_t remainingDataSize;
	bool isRecording;
	AudioUnitIO* io;
};
}}

#endif //LIBTGVOIP_AUDIOINPUTAUDIOUNIT_H
