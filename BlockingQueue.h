//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef LIBTGVOIP_BLOCKINGQUEUE_H
#define LIBTGVOIP_BLOCKINGQUEUE_H

#include <stdlib.h>
#include <list>
#include "threading.h"

using namespace std;

namespace tgvoip{

template<typename T>
class BlockingQueue{
public:
	BlockingQueue(size_t capacity) : semaphore(capacity, 0){
		this->capacity=capacity;
		overflowCallback=NULL;
		init_mutex(mutex);
	};

	~BlockingQueue(){
		semaphore.Release();
		free_mutex(mutex);
	}

	void Put(T thing){
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

	T GetBlocking(){
		semaphore.Acquire();
		MutexGuard sync(mutex);
		T r=GetInternal();
		return r;
	}

	T Get(){
		MutexGuard sync(mutex);
		if(queue.size()>0)
			semaphore.Acquire();
		T r=GetInternal();
		return r;
	}

	unsigned int Size(){
		return queue.size();
	}

	void PrepareDealloc(){

	}

	void SetOverflowCallback(void (*overflowCallback)(T)){
		this->overflowCallback=overflowCallback;
	}

private:
	T GetInternal(){
		//if(queue.size()==0)
		//	return NULL;
		T r=queue.front();
		queue.pop_front();
		return r;
	}

	list<T> queue;
	size_t capacity;
	//tgvoip_lock_t lock;
	Semaphore semaphore;
	tgvoip_mutex_t mutex;
	void (*overflowCallback)(T);
};
}

#endif //LIBTGVOIP_BLOCKINGQUEUE_H
