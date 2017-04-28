//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include "AudioUnitIO.h"
#include "AudioInputAudioUnit.h"
#include "../../logging.h"

#define BUFFER_SIZE 960

using namespace tgvoip;
using namespace tgvoip::audio;

AudioInputAudioUnit::AudioInputAudioUnit(){
	remainingDataSize=0;
	isRecording=false;
	this->io=AudioUnitIO::Get();
	io->AttachInput(this);
}

AudioInputAudioUnit::~AudioInputAudioUnit(){
	io->DetachInput();
	AudioUnitIO::Release();
}

void AudioInputAudioUnit::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	io->Configure(sampleRate, bitsPerSample, channels);
}

void AudioInputAudioUnit::Start(){
	isRecording=true;
	io->EnableInput(true);
}

void AudioInputAudioUnit::Stop(){
	isRecording=false;
	io->EnableInput(false);
}

void AudioInputAudioUnit::HandleBufferCallback(AudioBufferList *ioData){
	int i;
	for(i=0;i<ioData->mNumberBuffers;i++){
		AudioBuffer buf=ioData->mBuffers[i];
		assert(remainingDataSize+buf.mDataByteSize<10240);
		memcpy(remainingData+remainingDataSize, buf.mData, buf.mDataByteSize);
		remainingDataSize+=buf.mDataByteSize;
		while(remainingDataSize>=BUFFER_SIZE*2){
			InvokeCallback((unsigned char*)remainingData, BUFFER_SIZE*2);
			remainingDataSize-=BUFFER_SIZE*2;
			if(remainingDataSize>0){
				memmove(remainingData, remainingData+(BUFFER_SIZE*2), remainingDataSize);
			}
		}
	}
}
