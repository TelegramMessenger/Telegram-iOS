//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_AUDIOINPUT_H
#define LIBTGVOIP_AUDIOINPUT_H

#include <stdint.h>
#include "../MediaStreamItf.h"

class CAudioInput : public CMediaStreamItf{
public:
	virtual ~CAudioInput();

	virtual void Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels)=0;
	static CAudioInput* Create();
};


#endif //LIBTGVOIP_AUDIOINPUT_H
