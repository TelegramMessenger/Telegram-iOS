//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_OPUSDECODER_H
#define LIBTGVOIP_OPUSDECODER_H


#include "MediaStreamItf.h"
#include "opus.h"
#include "threading.h"
#include "BlockingQueue.h"
#include "BufferPool.h"
#include "EchoCanceller.h"
#include "JitterBuffer.h"
#include <stdio.h>
#include <vector>

namespace tgvoip{
class OpusDecoder {
public:
	virtual void Start();

	virtual void Stop();

	OpusDecoder(MediaStreamItf* dst, bool isAsync);
	virtual ~OpusDecoder();
	size_t HandleCallback(unsigned char* data, size_t len);
	void SetEchoCanceller(EchoCanceller* canceller);
	void SetFrameDuration(uint32_t duration);
	void SetJitterBuffer(JitterBuffer* jitterBuffer);
	void SetDTX(bool enable);
	void SetLevelMeter(AudioLevelMeter* levelMeter);
	void AddAudioEffect(AudioEffect* effect);
	void RemoveAudioEffect(AudioEffect* effect);

private:
	static size_t Callback(unsigned char* data, size_t len, void* param);
	void RunThread(void* param);
	int DecodeNextFrame();
	::OpusDecoder* dec;
	BlockingQueue<unsigned char*>* decodedQueue;
	BufferPool* bufferPool;
	unsigned char* buffer;
	unsigned char* lastDecoded;
	unsigned char* processedBuffer;
	size_t outputBufferSize;
	bool running;
    Thread* thread;
	Semaphore* semaphore;
	uint32_t frameDuration;
	EchoCanceller* echoCanceller;
	JitterBuffer* jitterBuffer;
	AudioLevelMeter* levelMeter;
	int consecutiveLostPackets;
	bool enableDTX;
	size_t silentPacketCount;
	std::vector<AudioEffect*> postProcEffects;
	bool async;
	unsigned char nextBuffer[8192];
	unsigned char decodeBuffer[8192];
	bool first;
	size_t nextLen;
	unsigned int packetsPerFrame;
	ssize_t remainingDataLen;
};
}

#endif //LIBTGVOIP_OPUSDECODER_H
