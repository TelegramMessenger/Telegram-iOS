//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "OpusDecoder.h"
#include "audio/Resampler.h"
#include "logging.h"
#include <assert.h>
#include <algorithm>

#include "VoIPController.h"

#define PACKET_SIZE (960*2)

using namespace tgvoip;

tgvoip::OpusDecoder::OpusDecoder(MediaStreamItf *dst, bool isAsync){
	async=isAsync;
	dst->SetCallback(OpusDecoder::Callback, this);
	if(async){
		decodedQueue=new BlockingQueue<unsigned char*>(33);
		bufferPool=new BufferPool(PACKET_SIZE, 32);
		semaphore=new Semaphore(32, 0);
	}else{
		decodedQueue=NULL;
		bufferPool=NULL;
		semaphore=NULL;
	}
	dec=opus_decoder_create(48000, 1, NULL);
	buffer=(unsigned char *) malloc(8192);
	lastDecoded=NULL;
	outputBufferSize=0;
	echoCanceller=NULL;
	frameDuration=20;
	consecutiveLostPackets=0;
	enableDTX=false;
	silentPacketCount=0;
	levelMeter=NULL;
	nextLen=0;
	running=false;
	remainingDataLen=0;
	processedBuffer=NULL;
}

tgvoip::OpusDecoder::~OpusDecoder(){
	opus_decoder_destroy(dec);
	free(buffer);
	if(bufferPool)
		delete bufferPool;
	if(decodedQueue)
		delete decodedQueue;
	if(semaphore)
		delete semaphore;
}


void tgvoip::OpusDecoder::SetEchoCanceller(EchoCanceller* canceller){
	echoCanceller=canceller;
}

size_t tgvoip::OpusDecoder::Callback(unsigned char *data, size_t len, void *param){
	return ((OpusDecoder*)param)->HandleCallback(data, len);
}

size_t tgvoip::OpusDecoder::HandleCallback(unsigned char *data, size_t len){
	if(async){
		if(!running){
			memset(data, 0, len);
			return 0;
		}
		if(outputBufferSize==0){
			outputBufferSize=len;
			int packetsNeeded;
			if(len>PACKET_SIZE)
				packetsNeeded=len/PACKET_SIZE;
			else
				packetsNeeded=1;
			packetsNeeded*=2;
			semaphore->Release(packetsNeeded);
		}
		assert(outputBufferSize==len && "output buffer size is supposed to be the same throughout callbacks");
		if(len==PACKET_SIZE){
			lastDecoded=(unsigned char *) decodedQueue->GetBlocking();
			if(!lastDecoded)
				return 0;
			memcpy(data, lastDecoded, PACKET_SIZE);
			bufferPool->Reuse(lastDecoded);
			semaphore->Release();
			if(silentPacketCount>0){
				silentPacketCount--;
				if(levelMeter)
					levelMeter->Update(reinterpret_cast<int16_t *>(data), 0);
				return 0;
			}
			if(echoCanceller){
				echoCanceller->SpeakerOutCallback(data, PACKET_SIZE);
			}
		}else{
			LOGE("Opus decoder buffer length != 960 samples");
			abort();
		}
	}else{
		if(remainingDataLen==0 && silentPacketCount==0){
			int duration=DecodeNextFrame();
			remainingDataLen=(size_t) (duration/20*960*2);
		}
		if(silentPacketCount>0 || remainingDataLen==0 || !processedBuffer){
			if(silentPacketCount>0)
				silentPacketCount--;
			memset(data, 0, 960*2);
			if(levelMeter)
				levelMeter->Update(reinterpret_cast<int16_t *>(data), 0);
			return 0;
		}
		memcpy(data, processedBuffer, 960*2);
		remainingDataLen-=960*2;
		if(remainingDataLen>0){
			memmove(processedBuffer, processedBuffer+960*2, remainingDataLen);
		}
	}
	if(levelMeter)
		levelMeter->Update(reinterpret_cast<int16_t *>(data), len/2);
	return len;
}


void tgvoip::OpusDecoder::Start(){
	if(!async)
		return;
	running=true;
	thread=new Thread(new MethodPointer<tgvoip::OpusDecoder>(&tgvoip::OpusDecoder::RunThread, this), NULL);
	thread->SetName("opus_decoder");
	thread->SetMaxPriority();
	thread->Start();
}

void tgvoip::OpusDecoder::Stop(){
	if(!running || !async)
		return;
	running=false;
	semaphore->Release();
	thread->Join();
	delete thread;
}

void tgvoip::OpusDecoder::RunThread(void* param){
	int i;
	LOGI("decoder: packets per frame %d", packetsPerFrame);
	while(running){
		int playbackDuration=DecodeNextFrame();
		for(i=0;i<playbackDuration/20;i++){
			semaphore->Acquire();
			if(!running){
				LOGI("==== decoder exiting ====");
				return;
			}
			unsigned char *buf=bufferPool->Get();
			if(buf){
				if(remainingDataLen>0){
					for(std::vector<AudioEffect*>::iterator effect=postProcEffects.begin();effect!=postProcEffects.end();++effect){
						(*effect)->Process(reinterpret_cast<int16_t*>(processedBuffer+(PACKET_SIZE*i)), 960);
					}
					memcpy(buf, processedBuffer+(PACKET_SIZE*i), PACKET_SIZE);
				}else{
					//LOGE("Error decoding, result=%d", size);
					memset(buf, 0, PACKET_SIZE);
				}
				decodedQueue->Put(buf);
			}else{
				LOGW("decoder: no buffers left!");
			}
		}
	}
}

int tgvoip::OpusDecoder::DecodeNextFrame(){
	/*memcpy(buffer, nextBuffer, nextLen);
	size_t inLen=nextLen;
	int playbackDuration=0;
	nextLen=jitterBuffer->HandleOutput(nextBuffer, 8192, 0, &playbackDuration);
	if(first){
		first=false;
		return 0;
	}
	if(!inLen){
		LOGV("Trying to recover late packet");
		inLen=jitterBuffer->HandleOutput(buffer, 8192, -2, &playbackDuration);
		if(inLen)
		LOGV("Decoding late packet");
	}*/
	int playbackDuration=0;
	size_t len=jitterBuffer->HandleOutput(buffer, 8192, 0, true, &playbackDuration);
	bool fec=false;
	if(!len){
		fec=true;
		len=jitterBuffer->HandleOutput(buffer, 8192, 0, false, &playbackDuration);
		if(len)
			LOGV("Trying FEC...");
	}
	int size;
	if(len){
		size=opus_decode(dec, buffer, len, (opus_int16 *) decodeBuffer, packetsPerFrame*960, fec ? 1 : 0);
		consecutiveLostPackets=0;
	}else{ // do packet loss concealment
		consecutiveLostPackets++;
		if(consecutiveLostPackets>2 && enableDTX){
			silentPacketCount+=packetsPerFrame;
			size=packetsPerFrame*960;
		}else{
			size=opus_decode(dec, NULL, 0, (opus_int16 *) decodeBuffer, packetsPerFrame*960, 0);
			//LOGV("PLC");
		}
	}
	if(size<0)
		LOGW("decoder: opus_decode error %d", size);
	remainingDataLen=size;
	if(playbackDuration==80){
		processedBuffer=buffer;
		audio::Resampler::Rescale60To80((int16_t*) decodeBuffer, (int16_t*) processedBuffer);
	}else if(playbackDuration==40){
		processedBuffer=buffer;
		audio::Resampler::Rescale60To40((int16_t*) decodeBuffer, (int16_t*) processedBuffer);
	}else{
		processedBuffer=decodeBuffer;
	}
	return playbackDuration;
}


void tgvoip::OpusDecoder::SetFrameDuration(uint32_t duration){
	frameDuration=duration;
	packetsPerFrame=frameDuration/20;
}


void tgvoip::OpusDecoder::SetJitterBuffer(JitterBuffer* jitterBuffer){
	this->jitterBuffer=jitterBuffer;
}

void tgvoip::OpusDecoder::SetDTX(bool enable){
	enableDTX=enable;
}

void tgvoip::OpusDecoder::SetLevelMeter(AudioLevelMeter *levelMeter){
	this->levelMeter=levelMeter;
}

void tgvoip::OpusDecoder::AddAudioEffect(AudioEffect *effect){
	postProcEffects.push_back(effect);
}

void tgvoip::OpusDecoder::RemoveAudioEffect(AudioEffect *effect){
	std::vector<AudioEffect*>::iterator i=std::find(postProcEffects.begin(), postProcEffects.end(), effect);
	if(i!=postProcEffects.end())
		postProcEffects.erase(i);
}
