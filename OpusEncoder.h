//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_OPUSENCODER_H
#define LIBTGVOIP_OPUSENCODER_H


#include "MediaStreamItf.h"
#include "opus.h"
#include "threading.h"
#include "BlockingQueue.h"
#include "BufferPool.h"
#include "EchoCanceller.h"

#include <stdint.h>

namespace tgvoip{
class OpusEncoder : public MediaStreamItf{
public:
	OpusEncoder(MediaStreamItf* source);
	virtual ~OpusEncoder();
	virtual void Start();
	virtual void Stop();
	void SetBitrate(uint32_t bitrate);
	void SetEchoCanceller(EchoCanceller* aec);
	void SetOutputFrameDuration(uint32_t duration);
	void SetPacketLoss(int percent);
	int GetPacketLoss();
	uint32_t GetBitrate();

private:
	static size_t Callback(unsigned char* data, size_t len, void* param);
	static void* StartThread(void* arg);
	void RunThread();
	void Encode(unsigned char* data, size_t len);
	MediaStreamItf* source;
	::OpusEncoder* enc;
	unsigned char buffer[4096];
	uint32_t requestedBitrate;
	uint32_t currentBitrate;
	tgvoip_thread_t thread;
	BlockingQueue<unsigned char*> queue;
	BufferPool bufferPool;
	EchoCanceller* echoCanceller;
	int complexity;
	bool running;
	uint32_t frameDuration;
	int packetLossPercent;
	uint32_t mediumCorrectionBitrate;
	uint32_t strongCorrectionBitrate;
	double mediumCorrectionMultiplier;
	double strongCorrectionMultiplier;
};
}

#endif //LIBTGVOIP_OPUSENCODER_H
