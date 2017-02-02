//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "BufferPool.h"
#include "logging.h"
#include <stdlib.h>
#include <assert.h>

CBufferPool::CBufferPool(unsigned int size, unsigned int count){
	assert(count<=64);
	init_mutex(mutex);
	buffers[0]=(unsigned char*) malloc(size*count);
	bufferCount=count;
	int i;
	for(i=1;i<count;i++){
		buffers[i]=buffers[0]+i*size;
	}
	usedBuffers=0;
}

CBufferPool::~CBufferPool(){
	free_mutex(mutex);
	free(buffers[0]);
}

unsigned char* CBufferPool::Get(){
	lock_mutex(mutex);
	int i;
	for(i=0;i<bufferCount;i++){
		if(!((usedBuffers >> i) & 1)){
			usedBuffers|=(1LL << i);
			unlock_mutex(mutex);
			return buffers[i];
		}
	}
	unlock_mutex(mutex);
	return NULL;
}

void CBufferPool::Reuse(unsigned char* buffer){
	lock_mutex(mutex);
	int i;
	for(i=0;i<bufferCount;i++){
		if(buffers[i]==buffer){
			usedBuffers&= ~(1LL << i);
			unlock_mutex(mutex);
			return;
		}
	}
	LOGE("pointer passed isn't a valid buffer from this pool");
	abort();
}

