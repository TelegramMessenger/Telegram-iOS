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

namespace tgvoip{
class OpusDecoder {
public:
	virtual void Start();

	virtual void Stop();

	OpusDecoder(MediaStreamItf* dst);
	virtual ~OpusDecoder();
	void HandleCallback(unsigned char* data, size_t len);
	void SetEchoCanceller(EchoCanceller* canceller);
	void SetFrameDuration(uint32_t duration);
	void ResetQueue();
	void SetJitterBuffer(JitterBuffer* jitterBuffer);

private:
	static size_t Callback(unsigned char* data, size_t len, void* param);
	static void* StartThread(void* param);
	void RunThread();
	::OpusDecoder* dec;
	BlockingQueue<unsigned char*>* decodedQueue;
	BufferPool* bufferPool;
	unsigned char* buffer;
	unsigned char* lastDecoded;
	size_t lastDecodedLen, lastDecodedOffset;
	size_t outputBufferSize;
	bool running;
    tgvoip_thread_t thread;
	Semaphore semaphore;
	tgvoip_mutex_t mutex;
	uint32_t frameDuration;
	EchoCanceller* echoCanceller;
	JitterBuffer* jitterBuffer;
};
}

#endif //LIBTGVOIP_OPUSDECODER_H
