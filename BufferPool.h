//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_BUFFERPOOL_H
#define LIBTGVOIP_BUFFERPOOL_H

#include <stdint.h>
#include "threading.h"

class CBufferPool{
public:
	CBufferPool(unsigned int size, unsigned int count);
	~CBufferPool();
	unsigned char* Get();
	void Reuse(unsigned char* buffer);

private:
	uint64_t usedBuffers;
	int bufferCount;
	unsigned char* buffers[64];
	tgvoip_mutex_t mutex;
};


#endif //LIBTGVOIP_BUFFERPOOL_H
