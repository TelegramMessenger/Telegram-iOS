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
#include "utils.h"

namespace webrtc{
	class AudioProcessing;
	class AudioFrame;
}

namespace tgvoip{
class EchoCanceller{

public:
	TGVOIP_DISALLOW_COPY_AND_ASSIGN(EchoCanceller);
	EchoCanceller(bool enableAEC, bool enableNS, bool enableAGC);
	virtual ~EchoCanceller();
	virtual void Start();
	virtual void Stop();
	void SpeakerOutCallback(unsigned char* data, size_t len);
	void Enable(bool enabled);
	void ProcessInput(int16_t* inOut, size_t numSamples, bool& hasVoice);
	void SetAECStrength(int strength);
	void SetVoiceDetectionEnabled(bool enabled);

private:
	bool enableAEC;
	bool enableAGC;
	bool enableNS;
	bool enableVAD=false;
	bool isOn;
#ifndef TGVOIP_NO_DSP
	webrtc::AudioProcessing* apm=NULL;
	webrtc::AudioFrame* audioFrame=NULL;
	void RunBufferFarendThread();
	bool didBufferFarend;
	Thread* bufferFarendThread;
	BlockingQueue<int16_t*>* farendQueue;
	BufferPool* farendBufferPool;
	bool running;
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
