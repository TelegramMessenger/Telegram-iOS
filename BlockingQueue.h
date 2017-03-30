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

class CBlockingQueue{
public:
	CBlockingQueue(size_t capacity);
	~CBlockingQueue();
	void Put(void* thing);
	void* GetBlocking();
	void* Get();
	unsigned int Size();
	void PrepareDealloc();
	void SetOverflowCallback(void (*overflowCallback)(void*));

private:
	void* GetInternal();
	list<void*> queue;
	size_t capacity;
	tgvoip_lock_t lock;
	tgvoip_mutex_t mutex;
	void (*overflowCallback)(void*);
};


#endif //LIBTGVOIP_BLOCKINGQUEUE_H
