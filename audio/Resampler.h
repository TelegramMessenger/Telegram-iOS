//
// Created by Grishka on 01.04.17.
//

#ifndef LIBTGVOIP_RESAMPLER_H
#define LIBTGVOIP_RESAMPLER_H

#include <stdlib.h>
#include <stdint.h>

namespace tgvoip{ namespace audio{
	class Resampler{
	public:
		static size_t Convert48To44(int16_t* from, int16_t* to, size_t fromLen, size_t toLen);
		static size_t Convert44To48(int16_t* from, int16_t* to, size_t fromLen, size_t toLen);
		static size_t Convert(int16_t* from, int16_t* to, size_t fromLen, size_t toLen, int num, int denom);
	};
}}

#endif //LIBTGVOIP_RESAMPLER_H
