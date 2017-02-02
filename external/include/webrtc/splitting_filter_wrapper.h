#ifndef __WEBRTC_SPLITTING_FILTER_WRAPPER
#define __WEBRTC_SPLITTING_FILTER_WRAPPER

struct splitting_filter_t{
	/*IFCHannelBuffer*/ void* _bufferIn;
	/*IFCHannelBuffer*/ void* _bufferOut;
	/*SplittingFilter*/ void* _splittingFilter;
	float* bufferIn;
	float* bufferOut[3];
};

extern "C"{
splitting_filter_t* tgvoip_splitting_filter_create();
void tgvoip_splitting_filter_free(splitting_filter_t* filter);

void tgvoip_splitting_filter_analyze(splitting_filter_t* filter);
void tgvoip_splitting_filter_synthesize(splitting_filter_t* filter);
}

#endif // __WEBRTC_SPLITTING_FILTER_WRAPPER