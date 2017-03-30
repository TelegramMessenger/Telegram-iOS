//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include "BlockingQueue.h"

CBlockingQueue::CBlockingQueue(size_t capacity){
	this->capacity=capacity;
	overflowCallback=NULL;
	init_lock(lock);
	init_mutex(mutex);
}

CBlockingQueue::~CBlockingQueue(){
	lock_mutex(mutex);
	notify_lock(lock);
	unlock_mutex(mutex);
	lock_mutex(mutex);
	unlock_mutex(mutex);
	free_lock(lock);
	free_mutex(mutex);
}

void CBlockingQueue::Put(void *thing){
	lock_mutex(mutex);
	if(queue.empty()){
		notify_lock(lock);
	}
	queue.push_back(thing);
	while(queue.size()>capacity){
		if(overflowCallback){
			overflowCallback(queue.front());
			queue.pop_front();
		}else{
			abort();
		}
	}
	unlock_mutex(mutex);
}

void *CBlockingQueue::GetBlocking(){
	lock_mutex(mutex);
	while(queue.empty()){
		wait_lock(lock, mutex);
	}
	void* r=GetInternal();
	unlock_mutex(mutex);
	return r;
}


void *CBlockingQueue::Get(){
	lock_mutex(mutex);
	void* r=GetInternal();
	unlock_mutex(mutex);
	return r;
}

void *CBlockingQueue::GetInternal(){
	if(queue.size()==0)
		return NULL;
	void* r=queue.front();
	queue.pop_front();
	return r;
}


unsigned int CBlockingQueue::Size(){
	return queue.size();
}


void CBlockingQueue::PrepareDealloc(){
	lock_mutex(mutex);
	notify_lock(lock);
	unlock_mutex(mutex);
}


void CBlockingQueue::SetOverflowCallback(void (*overflowCallback)(void *)){
	this->overflowCallback=overflowCallback;
}
