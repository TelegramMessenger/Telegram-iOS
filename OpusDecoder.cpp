//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "OpusDecoder.h"
#include "logging.h"
#include <assert.h>

#define PACKET_SIZE (960*2)

COpusDecoder::COpusDecoder(CMediaStreamItf *dst){
	//this->source=source;
	dst->SetCallback(COpusDecoder::Callback, this);
	dec=opus_decoder_create(48000, 1, NULL);
	//test=fopen("/sdcard/test.raw", "wb");
	buffer=(unsigned char *) malloc(4096);
	//lastDecoded=(unsigned char*) malloc(960*2);
	lastDecoded=NULL;
	lastDecodedLen=0;
	outputBufferSize=0;
	packetsNeeded=0;
	lastDecodedOffset=0;
	decodedQueue=new CBlockingQueue(33);
	bufferPool=new CBufferPool(PACKET_SIZE, 32);
	echoCanceller=NULL;
	frameDuration=20;
}

COpusDecoder::~COpusDecoder(){
	opus_decoder_destroy(dec);
	free(buffer);
	delete bufferPool;
	delete decodedQueue;
}


void COpusDecoder::SetEchoCanceller(CEchoCanceller* canceller){
	echoCanceller=canceller;
}

size_t COpusDecoder::Callback(unsigned char *data, size_t len, void *param){
	((COpusDecoder*)param)->HandleCallback(data, len);
	return 0;
}

void COpusDecoder::HandleCallback(unsigned char *data, size_t len){
	if(!running){
		memset(data, 0, len);
		return;
	}
	if(outputBufferSize==0){
		outputBufferSize=len;
		if(len>PACKET_SIZE)
			packetsNeeded=len/PACKET_SIZE;
		else
			packetsNeeded=1;
		packetsNeeded*=2;
		lock_mutex(mutex);
		notify_lock(lock);
		unlock_mutex(mutex);
	}
	assert(outputBufferSize==len && "output buffer size is supposed to be the same throughout callbacks");
	if(len>PACKET_SIZE){
		int count=len/PACKET_SIZE;
		int i;
		for(i=0;i<count;i++){
			lastDecoded=(unsigned char*) decodedQueue->GetBlocking();
			memcpy(data+(i*PACKET_SIZE), lastDecoded, PACKET_SIZE);
			if(echoCanceller)
				echoCanceller->SpeakerOutCallback(data, PACKET_SIZE);
			bufferPool->Reuse(lastDecoded);
		}
		lock_mutex(mutex);
		packetsNeeded+=count;
		if(packetsNeeded>0)
			notify_lock(lock);
		unlock_mutex(mutex);
	}else if(len==PACKET_SIZE){
		lastDecoded=(unsigned char*) decodedQueue->GetBlocking();
		memcpy(data, lastDecoded, PACKET_SIZE);
		bufferPool->Reuse(lastDecoded);
		lock_mutex(mutex);
		packetsNeeded+=1;
		if(packetsNeeded>0)
			notify_lock(lock);
		if(echoCanceller)
			echoCanceller->SpeakerOutCallback(data, PACKET_SIZE);
		unlock_mutex(mutex);
	}else if(len<PACKET_SIZE){
		if(lastDecodedOffset==0){
			lastDecoded=(unsigned char*) decodedQueue->GetBlocking();
		}

		memcpy(data, lastDecoded+lastDecodedOffset, len);
		lastDecodedOffset+=len;

		if(lastDecodedOffset>=PACKET_SIZE){
			if(echoCanceller)
				echoCanceller->SpeakerOutCallback(lastDecoded, PACKET_SIZE);
			lastDecodedOffset=0;
			bufferPool->Reuse(lastDecoded);
			//LOGV("before req packet, qsize=%d", decodedQueue->Size());
			lock_mutex(mutex);
			if(decodedQueue->Size()==0)
				packetsNeeded+=2;
			else
				packetsNeeded+=1;
			if(packetsNeeded>0)
				notify_lock(lock);
			unlock_mutex(mutex);
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


void COpusDecoder::Start(){
	init_lock(lock);
	init_mutex(mutex);
	running=true;
	start_thread(thread, COpusDecoder::StartThread, this);
	set_thread_priority(thread, get_thread_max_priority());
	set_thread_name(thread, "opus_decoder");
}

void COpusDecoder::Stop(){
	if(!running)
		return;
	running=false;
	lock_mutex(mutex);
	notify_lock(lock);
	unlock_mutex(mutex);
	join_thread(thread);
	free_lock(lock);
	free_mutex(mutex);
}


void* COpusDecoder::StartThread(void *param){
	((COpusDecoder*)param)->RunThread();
	return NULL;
}

void COpusDecoder::RunThread(){
	//FILE* test=fopen("/sdcard/test.raw", "w");
	unsigned char nextBuffer[8192];
	unsigned char decodeBuffer[8192];
	int i;
	int packetsPerFrame=frameDuration/20;
	bool first=true;
	LOGI("decoder: packets per frame %d", packetsPerFrame);
	size_t nextLen=0;
	while(running){
		lock_mutex(mutex);
		if(packetsNeeded<=0)
			wait_lock(lock, mutex);
		unlock_mutex(mutex);
		//LOGV("after wait, running=%d", running);
		if(!running){
			//fclose(test);
			//unlock_mutex(mutex);
			LOGI("==== decoder exiting ====");
			return;
		}
		//LOGD("Will get %d packets", packetsNeeded);
		//lastDecodedLen=0;
		memcpy(buffer, nextBuffer, nextLen);
		size_t inLen=nextLen;
		//nextLen=InvokeCallback(nextBuffer, 8192);
		nextLen=jitterBuffer->HandleOutput(nextBuffer, 8192, 0);
		if(first){
			first=false;
			continue;
		}
		//LOGV("Before decode, len=%d", inLen);
		if(!inLen){
			LOGV("Trying to recover late packet");
			inLen=jitterBuffer->HandleOutput(buffer, 8192, -2);
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
		for(i=0;i<packetsPerFrame;i++){
			unsigned char *buf=bufferPool->Get();
			if(buf){
				if(size>0){
					memcpy(buf, decodeBuffer+(PACKET_SIZE*i), PACKET_SIZE);
				}else{
					LOGE("Error decoding, result=%d", size);
					memset(buf, 0, PACKET_SIZE);
				}
				decodedQueue->Put(buf);
			}else{
				LOGW("decoder: no buffers left!");
			}
			lock_mutex(mutex);
			packetsNeeded--;
			unlock_mutex(mutex);
			//LOGD("packets needed: %d", packetsNeeded);
		}
	}
}


void COpusDecoder::SetFrameDuration(uint32_t duration){
	frameDuration=duration;
}


void COpusDecoder::ResetQueue(){
	/*lock_mutex(mutex);
	packetsNeeded=0;
	unlock_mutex(mutex);
	while(decodedQueue->Size()>0){
		bufferPool->Reuse((unsigned char *) decodedQueue->Get());
	}*/
}


void COpusDecoder::SetJitterBuffer(CJitterBuffer* jitterBuffer){
	this->jitterBuffer=jitterBuffer;
}
