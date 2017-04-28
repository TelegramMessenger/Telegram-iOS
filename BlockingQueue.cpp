//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "BlockingQueue.h"

using namespace tgvoip;

BlockingQueue::BlockingQueue(size_t capacity) : semaphore(capacity, 0){
	this->capacity=capacity;
	overflowCallback=NULL;
	init_mutex(mutex);
}

BlockingQueue::~BlockingQueue(){
	semaphore.Release();
	free_mutex(mutex);
}

void BlockingQueue::Put(void *thing){
	MutexGuard sync(mutex);
	queue.push_back(thing);
	bool didOverflow=false;
	while(queue.size()>capacity){
		didOverflow=true;
		if(overflowCallback){
			overflowCallback(queue.front());
			queue.pop_front();
		}else{
			abort();
		}
	}
	if(!didOverflow)
		semaphore.Release();
}

void *BlockingQueue::GetBlocking(){
	semaphore.Acquire();
	MutexGuard sync(mutex);
	void* r=GetInternal();
	return r;
}


void *BlockingQueue::Get(){
	MutexGuard sync(mutex);
	if(queue.size()>0)
		semaphore.Acquire();
	void* r=GetInternal();
	return r;
}

void *BlockingQueue::GetInternal(){
	if(queue.size()==0)
		return NULL;
	void* r=queue.front();
	queue.pop_front();
	return r;
}


unsigned int BlockingQueue::Size(){
	return queue.size();
}


void BlockingQueue::PrepareDealloc(){

}


void BlockingQueue::SetOverflowCallback(void (*overflowCallback)(void *)){
	this->overflowCallback=overflowCallback;
}
