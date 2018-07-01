//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_ECHOCANCELLER_H
#define LIBTGVOIP_ECHOCANCELLER_H

#include "threading.h"
#include "Buffers.h"
#include "BlockingQueue.h"
#include "MediaStreamItf.h"

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
	void SetAECStrength(int strength);

private:
	bool enableAEC;
	bool enableAGC;
	bool enableNS;
	bool isOn;
#ifndef TGVOIP_NO_DSP
	void RunBufferFarendThread(void* arg);
	bool didBufferFarend;
	Mutex aecMutex;
	void* aec;
	void* splittingFilter; // webrtc::SplittingFilter
	void* splittingFilterIn; // webrtc::IFChannelBuffer
	void* splittingFilterOut; // webrtc::IFChannelBuffer
	void* splittingFilterFarend; // webrtc::SplittingFilter
	void* splittingFilterFarendIn; // webrtc::IFChannelBuffer
	void* splittingFilterFarendOut; // webrtc::IFChannelBuffer
	Thread* bufferFarendThread;
	BlockingQueue<int16_t*>* farendQueue;
	BufferPool* farendBufferPool;
	bool running;
	void* ns; // NsxHandle
	void* agc;
	int32_t agcMicLevel;
	//int32_t outstandingFarendFrames=0;
#endif
};

	class AudioEffect{
	public:
		virtual ~AudioEffect()=0;
		virtual void Process(int16_t* inOut, size_t numSamples)=0;
		virtual void SetPassThrough(bool passThrough);
	protected:
		bool passThrough;
	};

	class AutomaticGainControl : public AudioEffect{
	public:
		AutomaticGainControl();
		virtual ~AutomaticGainControl();
		virtual void Process(int16_t* inOut, size_t numSamples);

	private:
		void* agc;
		void* splittingFilter;
		void* splittingFilterIn;
		void* splittingFilterOut;
		int32_t agcMicLevel;
	};
};

#endif //LIBTGVOIP_ECHOCANCELLER_H
