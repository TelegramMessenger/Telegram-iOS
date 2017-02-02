//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include <sys/time.h>
#include <unistd.h>
#include <assert.h>
#include "AudioOutputAudioUnit.h"
#include "../../logging.h"
#include "AudioUnitIO.h"

#define BUFFER_SIZE 960
const int8_t permutation[33]={0,1,2,3,4,4,5,5,5,5,6,6,6,6,6,7,7,7,7,8,8,8,9,9,9,9,9,9,9,9,9,9,9};

CAudioOutputAudioUnit::CAudioOutputAudioUnit(CAudioUnitIO* io){
	isPlaying=false;
	remainingDataSize=0;
    level=0.0;
	this->io=io;
	io->AttachOutput(this);
}

CAudioOutputAudioUnit::~CAudioOutputAudioUnit(){
	io->DetachOutput();
}

void CAudioOutputAudioUnit::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	io->Configure(sampleRate, bitsPerSample, channels);
}

bool CAudioOutputAudioUnit::IsPhone(){
	return false;
}

void CAudioOutputAudioUnit::EnableLoudspeaker(bool enabled){

}

void CAudioOutputAudioUnit::Start(){
	isPlaying=true;
	io->EnableOutput(true);
}

void CAudioOutputAudioUnit::Stop(){
	isPlaying=false;
	io->EnableOutput(false);
}

bool CAudioOutputAudioUnit::IsPlaying(){
	return isPlaying;
}

float CAudioOutputAudioUnit::GetLevel(){
    return level / 9.0;
}

void CAudioOutputAudioUnit::HandleBufferCallback(AudioBufferList *ioData){
	int i;
    unsigned int k;
    int16_t absVal=0;
	for(i=0;i<ioData->mNumberBuffers;i++){
		AudioBuffer buf=ioData->mBuffers[i];
		if(!isPlaying){
			memset(buf.mData, 0, buf.mDataByteSize);
			return;
		}
		while(remainingDataSize<buf.mDataByteSize){
			assert(remainingDataSize+BUFFER_SIZE*2<10240);
			InvokeCallback(remainingData+remainingDataSize, BUFFER_SIZE*2);
			remainingDataSize+=BUFFER_SIZE*2;
		}
		memcpy(buf.mData, remainingData, buf.mDataByteSize);
		remainingDataSize-=buf.mDataByteSize;
		memmove(remainingData, remainingData+buf.mDataByteSize, remainingDataSize);
        
        unsigned int samples=buf.mDataByteSize/sizeof(int16_t);
        for (k=0;k<samples;k++){
            int16_t absolute=(int16_t)abs(*((int16_t *)buf.mData+k));
            if (absolute>absVal)
                absVal=absolute;
        }
        
        if (absVal>absMax)
            absMax=absVal;
        
        count++;
        if (count>=10) {
            count=0;
            
            short position=absMax/1000;
            if (position==0 && absMax>250) {
                position=1;
            }
            level=permutation[position];
            absMax>>=2;
        }
	}
}

