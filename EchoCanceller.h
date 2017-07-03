//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_ECHOCANCELLER_H
#define LIBTGVOIP_ECHOCANCELLER_H

#include "threading.h"
#include "BufferPool.h"
#include "BlockingQueue.h"

namespace tgvoip{
class EchoCanceller{

public:
	EchoCanceller(bool enableAEC, bool enableNS, bool enableAGC);
	virtual ~EchoCanceller();
	virtual void Start();
	virtual void Stop();
	void SpeakerOutCallback(unsigned char* data, size_t len);
	void Enable(bool enabled);
	void ProcessInput(unsigned char* data, unsigned char* out, size_t len);

private:
	bool enableAEC;
	bool enableAGC;
	bool enableNS;
#ifndef TGVOIP_NO_DSP
	static void* StartBufferFarendThread(void* arg);
	void RunBufferFarendThread();
	bool didBufferFarend;
	tgvoip_mutex_t aecMutex;
	void* aec;
	void* splittingFilter; // webrtc::SplittingFilter
	void* splittingFilterIn; // webrtc::IFChannelBuffer
	void* splittingFilterOut; // webrtc::IFChannelBuffer
	void* splittingFilterFarend; // webrtc::SplittingFilter
	void* splittingFilterFarendIn; // webrtc::IFChannelBuffer
	void* splittingFilterFarendOut; // webrtc::IFChannelBuffer
	tgvoip_thread_t bufferFarendThread;
	BlockingQueue<int16_t*>* farendQueue;
	BufferPool* farendBufferPool;
	bool running;
	void* ns; // NsxHandle
	void* agc;
	int32_t agcMicLevel;
#endif
};
}

#endif //LIBTGVOIP_ECHOCANCELLER_H
