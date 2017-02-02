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

class COpusDecoder {
public:
	virtual void Start();

	virtual void Stop();

	COpusDecoder(CMediaStreamItf* dst);
	virtual ~COpusDecoder();
	void HandleCallback(unsigned char* data, size_t len);
	void SetEchoCanceller(CEchoCanceller* canceller);
	void SetFrameDuration(uint32_t duration);
	void ResetQueue();
	void SetJitterBuffer(CJitterBuffer* jitterBuffer);

private:
	static size_t Callback(unsigned char* data, size_t len, void* param);
	static void* StartThread(void* param);
	void RunThread();
	OpusDecoder* dec;
	CBlockingQueue* decodedQueue;
	CBufferPool* bufferPool;
	unsigned char* buffer;
	unsigned char* lastDecoded;
	size_t lastDecodedLen, lastDecodedOffset;
	int packetsNeeded;
	size_t outputBufferSize;
	bool running;
    tgvoip_thread_t thread;
	tgvoip_lock_t lock;
	tgvoip_mutex_t mutex;
	uint32_t frameDuration;
	CEchoCanceller* echoCanceller;
	CJitterBuffer* jitterBuffer;
};


#endif //LIBTGVOIP_OPUSDECODER_H
