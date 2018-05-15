//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "BufferPool.h"
#include "logging.h"
#include <stdlib.h>
#include <assert.h>

using namespace tgvoip;

BufferPool::BufferPool(unsigned int size, unsigned int count){
	assert(count<=64);
	buffers[0]=(unsigned char*) malloc(size*count);
	bufferCount=count;
	unsigned int i;
	for(i=1;i<count;i++){
		buffers[i]=buffers[0]+i*size;
	}
	usedBuffers=0;
	this->size=size;
}

BufferPool::~BufferPool(){
	free(buffers[0]);
}

unsigned char* BufferPool::Get(){
	MutexGuard m(mutex);
	int i;
	for(i=0;i<bufferCount;i++){
		if(!((usedBuffers >> i) & 1)){
			usedBuffers|=(1LL << i);
			return buffers[i];
		}
	}
	return NULL;
}

void BufferPool::Reuse(unsigned char* buffer){
	MutexGuard m(mutex);
	int i;
	for(i=0;i<bufferCount;i++){
		if(buffers[i]==buffer){
			usedBuffers&= ~(1LL << i);
			return;
		}
	}
	LOGE("pointer passed isn't a valid buffer from this pool");
	abort();
}

size_t BufferPool::GetSingleBufferSize(){
	return size;
}

size_t BufferPool::GetBufferCount(){
	return (size_t) bufferCount;
}
