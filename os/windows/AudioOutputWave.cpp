//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//


#include <assert.h>
#include "AudioOutputWave.h"
#include "../../logging.h"

#define BUFFER_SIZE 960
#define CHECK_ERROR(res, msg) if(res!=MMSYSERR_NOERROR){wchar_t _buf[1024]; waveOutGetErrorTextW(res, _buf, 1024); LOGE(msg ": %ws (MMRESULT=0x08X)", _buf, res); failed=true;}

using namespace tgvoip::audio;

AudioOutputWave::AudioOutputWave(){
	isPlaying=false;

	for(int i=0;i<4;i++){
		ZeroMemory(&buffers[i], sizeof(WAVEHDR));
		buffers[i].dwBufferLength=960*2;
		buffers[i].lpData=(char*)malloc(960*2);
	}

	ZeroMemory(&format, sizeof(format));
	format.cbSize=0;
	format.wFormatTag=WAVE_FORMAT_PCM;
	format.nSamplesPerSec=48000;
	format.wBitsPerSample=16;
	format.nChannels=1;
	format.nBlockAlign=2;

	MMRESULT res=waveOutOpen(&hWaveOut, WAVE_MAPPER, &format, (DWORD_PTR)AudioOutputWave::WaveOutProc, (DWORD_PTR)this, CALLBACK_FUNCTION);
	CHECK_ERROR(res, "waveOutOpen failed");
}

AudioOutputWave::~AudioOutputWave(){
	for(int i=0;i<4;i++){
		free(buffers[i].lpData);
	}
	waveOutClose(hWaveOut);
}

void AudioOutputWave::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	
}

void AudioOutputWave::Start(){
	isPlaying=true;
	
	for(int i=0;i<4;i++){
		MMRESULT res=waveOutPrepareHeader(hWaveOut, &buffers[i], sizeof(WAVEHDR));
		CHECK_ERROR(res, "waveOutPrepareHeader failed");
		//InvokeCallback((unsigned char*)buffers[i].lpData, buffers[i].dwBufferLength);
		ZeroMemory(buffers[i].lpData, buffers[i].dwBufferLength);
		res=waveOutWrite(hWaveOut, &buffers[i], sizeof(WAVEHDR));
		CHECK_ERROR(res, "waveOutWrite failed");
	}
}

void AudioOutputWave::Stop(){
	isPlaying=false;

	MMRESULT res=waveOutReset(hWaveOut);
	CHECK_ERROR(res, "waveOutReset failed");
	for(int i=0;i<4;i++){
		res=waveOutUnprepareHeader(hWaveOut, &buffers[i], sizeof(WAVEHDR));
		CHECK_ERROR(res, "waveOutUnprepareHeader failed");
	}
}

bool AudioOutputWave::IsPlaying(){
	return isPlaying;
}

void AudioOutputWave::WaveOutProc(HWAVEOUT hwo, UINT uMsg, DWORD_PTR dwInstance, DWORD_PTR dwParam1, DWORD_PTR dwParam2) {
	if(uMsg==WOM_DONE){
		((AudioOutputWave*)dwInstance)->OnBufferDone((WAVEHDR*)dwParam1);
	}
}

void AudioOutputWave::OnBufferDone(WAVEHDR* hdr){
	if(!isPlaying)
		return;

	InvokeCallback((unsigned char*)hdr->lpData, hdr->dwBufferLength);
	hdr->dwFlags&= ~WHDR_DONE;
	MMRESULT res=waveOutWrite(hWaveOut, hdr, sizeof(WAVEHDR));
}
