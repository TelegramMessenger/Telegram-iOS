//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "OpusDecoder.h"
#include "audio/Resampler.h"
#include "logging.h"
#include <assert.h>

#define PACKET_SIZE (960*2)

using namespace tgvoip;

tgvoip::OpusDecoder::OpusDecoder(MediaStreamItf *dst) : semaphore(32, 0){
	//this->source=source;
	dst->SetCallback(OpusDecoder::Callback, this);
	dec=opus_decoder_create(48000, 1, NULL);
	//test=fopen("/sdcard/test.raw", "wb");
	buffer=(unsigned char *) malloc(8192);
	//lastDecoded=(unsigned char*) malloc(960*2);
	lastDecoded=NULL;
	lastDecodedLen=0;
	outputBufferSize=0;
	lastDecodedOffset=0;
	decodedQueue=new BlockingQueue<unsigned char*>(33);
	bufferPool=new BufferPool(PACKET_SIZE, 32);
	echoCanceller=NULL;
	frameDuration=20;
}

tgvoip::OpusDecoder::~OpusDecoder(){
	opus_decoder_destroy(dec);
	free(buffer);
	delete bufferPool;
	delete decodedQueue;
}


void tgvoip::OpusDecoder::SetEchoCanceller(EchoCanceller* canceller){
	echoCanceller=canceller;
}

size_t tgvoip::OpusDecoder::Callback(unsigned char *data, size_t len, void *param){
	((OpusDecoder*)param)->HandleCallback(data, len);
	return 0;
}

void tgvoip::OpusDecoder::HandleCallback(unsigned char *data, size_t len){
	if(!running){
		memset(data, 0, len);
		return;
	}
	if(outputBufferSize==0){
		outputBufferSize=len;
		int packetsNeeded;
		if(len>PACKET_SIZE)
			packetsNeeded=len/PACKET_SIZE;
		else
			packetsNeeded=1;
		packetsNeeded*=2;
		semaphore.Release(packetsNeeded);
	}
	assert(outputBufferSize==len && "output buffer size is supposed to be the same throughout callbacks");
	if(len>PACKET_SIZE){
		int count=len/PACKET_SIZE;
		int i;
		for(i=0;i<count;i++){
			lastDecoded=(unsigned char*) decodedQueue->GetBlocking();
			if(!lastDecoded)
				return;
			memcpy(data+(i*PACKET_SIZE), lastDecoded, PACKET_SIZE);
			if(echoCanceller)
				echoCanceller->SpeakerOutCallback(data, PACKET_SIZE);
			bufferPool->Reuse(lastDecoded);
		}
		semaphore.Release(count);
	}else if(len==PACKET_SIZE){
		lastDecoded=(unsigned char*) decodedQueue->GetBlocking();
		if(!lastDecoded)
			return;
		memcpy(data, lastDecoded, PACKET_SIZE);
		bufferPool->Reuse(lastDecoded);
		semaphore.Release();
		lock_mutex(mutex);
		if(echoCanceller)
			echoCanceller->SpeakerOutCallback(data, PACKET_SIZE);
		unlock_mutex(mutex);
	}else if(len<PACKET_SIZE){
		if(lastDecodedOffset==0){
			lastDecoded=(unsigned char*) decodedQueue->GetBlocking();
		}
		if(!lastDecoded)
			return;

		memcpy(data, lastDecoded+lastDecodedOffset, len);
		lastDecodedOffset+=len;

		if(lastDecodedOffset>=PACKET_SIZE){
			if(echoCanceller)
				echoCanceller->SpeakerOutCallback(lastDecoded, PACKET_SIZE);
			lastDecodedOffset=0;
			bufferPool->Reuse(lastDecoded);
			//LOGV("before req packet, qsize=%d", decodedQueue->Size());
			if(decodedQueue->Size()==0)
				semaphore.Release(2);
			else
				semaphore.Release();
		}
	}
	/*if(lastDecodedLen){
		LOGV("ldl=%d, l=%d", lastDecodedLen, len);
		if(len==PACKET_SIZE){
			memcpy(data, lastDecoded, len);
			packetsNeeded=1;
		}else if(len>PACKET_SIZE){
			memcpy(data, lastDecoded, len);
			//LOGV("ldl=%d, l=%d", lastDecodedLen, len);
			packetsNeeded=len/PACKET_SIZE;
		}else if(len<PACKET_SIZE){
			memcpy(data, lastDecoded+lastDecodedOffset, len);
			lastDecodedOffset+=len;
			if(lastDecodedOffset>=PACKET_SIZE){
				packetsNeeded=1;
				lastDecodedOffset=0;
			}
		}
	}else{
		LOGW("skipping callback");
		if(len>PACKET_SIZE)
			packetsNeeded=len/PACKET_SIZE;
		else
			packetsNeeded=1;
	}*/
	/*if(packetsNeeded>0){
		lock_mutex(mutex);
		notify_lock(lock);
		unlock_mutex(mutex);
	}*/
}


void tgvoip::OpusDecoder::Start(){
	init_mutex(mutex);
	running=true;
	start_thread(thread, OpusDecoder::StartThread, this);
	set_thread_priority(thread, get_thread_max_priority());
	set_thread_name(thread, "opus_decoder");
}

void tgvoip::OpusDecoder::Stop(){
	if(!running)
		return;
	running=false;
	semaphore.Release();
	join_thread(thread);
	free_mutex(mutex);
}


void* tgvoip::OpusDecoder::StartThread(void *param){
	((tgvoip::OpusDecoder*)param)->RunThread();
	return NULL;
}

void tgvoip::OpusDecoder::RunThread(){
	unsigned char nextBuffer[8192];
	unsigned char decodeBuffer[8192];
	int i;
	int packetsPerFrame=frameDuration/20;
	bool first=true;
	LOGI("decoder: packets per frame %d", packetsPerFrame);
	size_t nextLen=0;
	while(running){
		//LOGV("after wait, running=%d", running);
		//LOGD("Will get %d packets", packetsNeeded);
		//lastDecodedLen=0;
		memcpy(buffer, nextBuffer, nextLen);
		size_t inLen=nextLen;
		//nextLen=InvokeCallback(nextBuffer, 8192);
		int playbackDuration=0;
		nextLen=jitterBuffer->HandleOutput(nextBuffer, 8192, 0, &playbackDuration);
		if(first){
			first=false;
			continue;
		}
		//LOGV("Before decode, len=%d", inLen);
		if(!inLen){
			LOGV("Trying to recover late packet");
			inLen=jitterBuffer->HandleOutput(buffer, 8192, -2, &playbackDuration);
			if(inLen)
				LOGV("Decoding late packet");
		}
		int size;
		if(inLen || nextLen)
			size=opus_decode(dec, inLen ? buffer : nextBuffer, inLen ? inLen : nextLen, (opus_int16*) decodeBuffer, packetsPerFrame*960, inLen ? 0 : 1);
		else{ // do packet loss concealment
			size=opus_decode(dec, NULL, 0, (opus_int16 *) decodeBuffer, packetsPerFrame*960, 0);
			LOGV("PLC");
		}
		if(size<0)
			LOGW("decoder: opus_decode error %d", size);
		//LOGV("After decode, size=%d", size);
		//LOGD("playbackDuration=%d", playbackDuration);
		unsigned char* processedBuffer;
		if(playbackDuration==80){
			processedBuffer=buffer;
			audio::Resampler::Rescale60To80((int16_t*) decodeBuffer, (int16_t*) processedBuffer);
		}else if(playbackDuration==40){
			processedBuffer=buffer;
			audio::Resampler::Rescale60To40((int16_t*) decodeBuffer, (int16_t*) processedBuffer);
		}else{
			processedBuffer=decodeBuffer;
		}
		for(i=0;i</*packetsPerFrame*/ playbackDuration/20;i++){
			semaphore.Acquire();
			if(!running){
				LOGI("==== decoder exiting ====");
				return;
			}
			unsigned char *buf=bufferPool->Get();
			if(buf){
				if(size>0){
					memcpy(buf, processedBuffer+(PACKET_SIZE*i), PACKET_SIZE);
				}else{
					LOGE("Error decoding, result=%d", size);
					memset(buf, 0, PACKET_SIZE);
				}
				decodedQueue->Put(buf);
			}else{
				LOGW("decoder: no buffers left!");
			}
			//LOGD("packets needed: %d", packetsNeeded);
		}
	}
}


void tgvoip::OpusDecoder::SetFrameDuration(uint32_t duration){
	frameDuration=duration;
}


void tgvoip::OpusDecoder::ResetQueue(){
	/*lock_mutex(mutex);
	packetsNeeded=0;
	unlock_mutex(mutex);
	while(decodedQueue->Size()>0){
		bufferPool->Reuse((unsigned char *) decodedQueue->Get());
	}*/
}


void tgvoip::OpusDecoder::SetJitterBuffer(JitterBuffer* jitterBuffer){
	this->jitterBuffer=jitterBuffer;
}
