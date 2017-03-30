#ifndef __WEBRTC_SPLITTING_FILTER_WRAPPER
#define __WEBRTC_SPLITTING_FILTER_WRAPPER

#include <stdint.h>

struct tgvoip_splitting_filter_t{
	/*IFCHannelBuffer*/ void* _bufferIn;
	/*IFCHannelBuffer*/ void* _bufferOut;
	/*SplittingFilter*/ void* _splittingFilter;
	int16_t bufferIn[960];
	int16_t bufferOut[3][320];
};

extern "C"{
tgvoip_splitting_filter_t* tgvoip_splitting_filter_create();
void tgvoip_splitting_filter_free(tgvoip_splitting_filter_t* filter);

void tgvoip_splitting_filter_analyze(tgvoip_splitting_filter_t* filter);
void tgvoip_splitting_filter_synthesize(tgvoip_splitting_filter_t* filter);
}

#endif // __WEBRTC_SPLITTING_FILTER_WRAPPER