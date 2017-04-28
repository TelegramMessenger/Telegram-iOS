//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_AUDIOOUTPUTWAVE_H
#define LIBTGVOIP_AUDIOOUTPUTWAVE_H

#include <windows.h>
#include <string>
#include <vector>
#include "../../audio/AudioOutput.h"

namespace tgvoip{
namespace audio{

class AudioOutputWave : public AudioOutput{
public:
	AudioOutputWave(std::string deviceID);
	virtual ~AudioOutputWave();
	virtual void Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels);
	virtual void Start();
	virtual void Stop();
	virtual bool IsPlaying();
	virtual void SetCurrentDevice(std::string deviceID);
	static void EnumerateDevices(std::vector<AudioOutputDevice>& devs);

private:
	HWAVEOUT hWaveOut;
	WAVEFORMATEX format;
	WAVEHDR buffers[4];
	static void CALLBACK WaveOutProc(HWAVEOUT hwo, UINT uMsg, DWORD_PTR dwInstance, DWORD_PTR dwParam1, DWORD_PTR dwParam2);
	void OnBufferDone(WAVEHDR* hdr);
	bool isPlaying;
};

}
}

#endif //LIBTGVOIP_AUDIOOUTPUTWAVE_H
