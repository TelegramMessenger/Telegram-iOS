//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_ECHOCANCELLER_H
#define LIBTGVOIP_ECHOCANCELLER_H

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

/*#if TARGET_OS_IPHONE
#define TGVOIP_NO_AEC
#endif*/

#include "threading.h"
#include "BufferPool.h"
#include "BlockingQueue.h"
#ifndef TGVOIP_NO_AEC
#include "external/include/webrtc/echo_control_mobile.h"
//#include "external/include/webrtc/echo_cancellation.h"
#include "external/include/webrtc/splitting_filter_wrapper.h"
#include "external/include/webrtc/noise_suppression_x.h"
#include "external/include/webrtc/gain_control.h"
#endif

class CEchoCanceller{

public:
	CEchoCanceller(bool enableAEC, bool enableNS, bool enableAGC);
	virtual ~CEchoCanceller();
	virtual void Start();
	virtual void Stop();
	void SpeakerOutCallback(unsigned char* data, size_t len);
	void Enable(bool enabled);
	void ProcessInput(unsigned char* data, unsigned char* out, size_t len);

private:
	bool enableAEC;
	bool enableAGC;
	bool enableNS;
#ifndef TGVOIP_NO_AEC
	static void* StartBufferFarendThread(void* arg);
	void RunBufferFarendThread();
	bool didBufferFarend;
	tgvoip_mutex_t aecMutex;
	void* aec;
	tgvoip_splitting_filter_t* splittingFilter;
	tgvoip_splitting_filter_t* splittingFilterFarend;
	tgvoip_thread_t bufferFarendThread;
	CBlockingQueue* farendQueue;
	CBufferPool* farendBufferPool;
	bool running;
	NsxHandle* ns;
	void* agc;
	int32_t agcMicLevel;
#endif
};


#endif //LIBTGVOIP_ECHOCANCELLER_H
