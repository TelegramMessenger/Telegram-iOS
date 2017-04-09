//
// Created by Grishka on 01.04.17.
//

#include <math.h>
#include "Resampler.h"

using namespace tgvoip::audio;

#define MIN(a, b) (a<b ? a : b)

size_t Resampler::Convert48To44(int16_t *from, int16_t *to, size_t fromLen, size_t toLen){
	size_t outLen=fromLen*147/160;
	if(toLen<outLen)
		outLen=toLen;
	unsigned int offset;
	for(offset=0;offset<outLen;offset++){
		float offsetf=offset*160.0f/147.0f;
		float factor=offsetf-floorf(offsetf);
		to[offset]=(int16_t)((from[(int)floorf(offsetf)]*(1-factor))+(from[(int)ceilf(offsetf)]*(factor)));
	}
	return outLen;
}

size_t Resampler::Convert44To48(int16_t *from, int16_t *to, size_t fromLen, size_t toLen){
	size_t outLen=fromLen*160/147;
	if(toLen<outLen)
		outLen=toLen;
	unsigned int offset;
	for(offset=0;offset<outLen;offset++){
		float offsetf=offset*147.0f/160.0f;
		float factor=offsetf-floorf(offsetf);
		to[offset]=(int16_t)((from[(int)floorf(offsetf)]*(1-factor))+(from[(int)ceilf(offsetf)]*(factor)));
	}
	return outLen;
}


size_t Resampler::Convert(int16_t *from, int16_t *to, size_t fromLen, size_t toLen, int num, int denom){
	size_t outLen=fromLen*num/denom;
	if(toLen<outLen)
		outLen=toLen;
	unsigned int offset;
	for(offset=0;offset<outLen;offset++){
		float offsetf=offset*(float)denom/(float)num;
		float factor=offsetf-floorf(offsetf);
		to[offset]=(int16_t)((from[(int)floorf(offsetf)]*(1-factor))+(from[(int)ceilf(offsetf)]*(factor)));
	}
	return outLen;
}
