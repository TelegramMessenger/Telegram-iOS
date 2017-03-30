//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef __THREADING_H
#define __THREADING_H

#if defined(_POSIX_THREADS) || defined(_POSIX_VERSION) || defined(__unix__) || defined(__unix) || (defined(__APPLE__) && defined(__MACH__))

#include <pthread.h>
#include <sched.h>

typedef pthread_t tgvoip_thread_t;
typedef pthread_mutex_t tgvoip_mutex_t;
typedef pthread_cond_t tgvoip_lock_t;

#define start_thread(ref, entry, arg) pthread_create(&ref, NULL, entry, arg)
#define join_thread(thread) pthread_join(thread, NULL)
#ifndef __APPLE__
#define set_thread_name(thread, name) pthread_setname_np(thread, name)
#else
#define set_thread_name(thread, name)
#endif
#define set_thread_priority(thread, priority) {sched_param __param; __param.sched_priority=priority; int __result=pthread_setschedparam(thread, SCHED_RR, &__param); if(__result!=0){LOGE("can't set thread priority: %s", strerror(__result));}};
#define get_thread_max_priority() sched_get_priority_max(SCHED_RR)
#define get_thread_min_priority() sched_get_priority_min(SCHED_RR)
#define init_mutex(mutex) pthread_mutex_init(&mutex, NULL)
#define free_mutex(mutex) pthread_mutex_destroy(&mutex)
#define lock_mutex(mutex) pthread_mutex_lock(&mutex)
#define unlock_mutex(mutex) pthread_mutex_unlock(&mutex)
#define init_lock(lock) pthread_cond_init(&lock, NULL)
#define free_lock(lock) pthread_cond_destroy(&lock)
#define wait_lock(lock, mutex) pthread_cond_wait(&lock, &mutex)
#define notify_lock(lock) pthread_cond_broadcast(&lock)

#else
#error "No threading implementation for your operating system"
#endif

class CMutexGuard{
public:
    CMutexGuard(tgvoip_mutex_t &mutex) : mutex(mutex) {
		lock_mutex(mutex);
	}
	~CMutexGuard(){
		unlock_mutex(mutex);
	}
private:
	tgvoip_mutex_t &mutex;
};

#endif //__THREADING_H
