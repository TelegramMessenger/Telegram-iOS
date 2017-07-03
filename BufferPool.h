//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_BUFFERPOOL_H
#define LIBTGVOIP_BUFFERPOOL_H

#include <stdint.h>
#include "threading.h"

namespace tgvoip{
class BufferPool{
public:
	BufferPool(unsigned int size, unsigned int count);
	~BufferPool();
	unsigned char* Get();
	void Reuse(unsigned char* buffer);
	size_t GetSingleBufferSize();
	size_t GetBufferCount();

private:
	uint64_t usedBuffers;
	int bufferCount;
	size_t size;
	unsigned char* buffers[64];
	tgvoip_mutex_t mutex;
};
}

#endif //LIBTGVOIP_BUFFERPOOL_H
