//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#ifndef __THREADING_H
#define __THREADING_H

#if defined(_POSIX_THREADS) || defined(_POSIX_VERSION) || defined(__unix__) || defined(__unix) || (defined(__APPLE__) && defined(__MACH__))

#include <pthread.h>
#include <semaphore.h>
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

#ifdef __APPLE__
#include <dispatch/dispatch.h>
namespace tgvoip{
class Semaphore{
public:
	Semaphore(unsigned int maxCount, unsigned int initValue){
		sem = dispatch_semaphore_create(initValue);
	}
	
	~Semaphore(){
#if ! __has_feature(objc_arc)
        dispatch_release(sem);
#endif
	}
	
	void Acquire(){
		dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
	}
	
	void Release(){
		dispatch_semaphore_signal(sem);
	}
	
	void Acquire(int count){
		for(int i=0;i<count;i++)
			Acquire();
	}
	
	void Release(int count){
		for(int i=0;i<count;i++)
			Release();
	}
	
private:
	dispatch_semaphore_t sem;
};
}
#else
namespace tgvoip{
class Semaphore{
public:
	Semaphore(unsigned int maxCount, unsigned int initValue){
		sem_init(&sem, 0, initValue);
	}

	~Semaphore(){
		sem_destroy(&sem);
	}

	void Acquire(){
		sem_wait(&sem);
	}

	void Release(){
		sem_post(&sem);
	}

	void Acquire(int count){
		for(int i=0;i<count;i++)
			Acquire();
	}

	void Release(int count){
		for(int i=0;i<count;i++)
			Release();
	}

private:
	sem_t sem;
};
}
#endif

#elif defined(_WIN32)

#include <Windows.h>
#include <assert.h>
typedef HANDLE tgvoip_thread_t;
typedef CRITICAL_SECTION tgvoip_mutex_t;
typedef HANDLE tgvoip_lock_t; // uncomment for XP compatibility
//typedef CONDITION_VARIABLE tgvoip_lock_t;

#define start_thread(ref, entry, arg) (ref=CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)entry, arg, 0, NULL))
#if !defined(WINAPI_FAMILY) || WINAPI_FAMILY!=WINAPI_FAMILY_PHONE_APP
#define join_thread(thread) {WaitForSingleObject(thread, INFINITE); CloseHandle(thread);}
#else
#define join_thread(thread) {WaitForSingleObjectEx(thread, INFINITE, false); CloseHandle(thread);}
#endif
#define set_thread_name(thread, name) // threads in Windows don't have names
#define set_thread_priority(thread, priority) SetThreadPriority(thread, priority)
#define get_thread_max_priority() THREAD_PRIORITY_HIGHEST
#define get_thread_min_priority() THREAD_PRIORITY_LOWEST
#if !defined(WINAPI_FAMILY) || WINAPI_FAMILY!=WINAPI_FAMILY_PHONE_APP
#define init_mutex(mutex) InitializeCriticalSection(&mutex)
#else
#define init_mutex(mutex) InitializeCriticalSectionEx(&mutex, 0, 0)
#endif
#define free_mutex(mutex) DeleteCriticalSection(&mutex)
#define lock_mutex(mutex) EnterCriticalSection(&mutex)
#define unlock_mutex(mutex) LeaveCriticalSection(&mutex)
#define init_lock(lock) (lock=CreateEvent(NULL, false, false, NULL))
#define free_lock(lock) CloseHandle(lock)
#define wait_lock(lock, mutex) {LeaveCriticalSection(&mutex); WaitForSingleObject(lock, INFINITE); EnterCriticalSection(&mutex);}
#define notify_lock(lock) PulseEvent(lock)
//#define init_lock(lock) InitializeConditionVariable(&lock)
//#define free_lock(lock) // ?
//#define wait_lock(lock, mutex) SleepConditionVariableCS(&lock, &mutex, INFINITE)
//#define notify_lock(lock) WakeAllConditionVariable(&lock)

namespace tgvoip{
class Semaphore{
public:
	Semaphore(unsigned int maxCount, unsigned int initValue){
#if !defined(WINAPI_FAMILY) || WINAPI_FAMILY!=WINAPI_FAMILY_PHONE_APP
		h=CreateSemaphore(NULL, initValue, maxCount, NULL);
#else
		h=CreateSemaphoreEx(NULL, initValue, maxCount, NULL, 0, SEMAPHORE_ALL_ACCESS);
		assert(h);
#endif
	}

	~Semaphore(){
		CloseHandle(h);
	}

	void Acquire(){
#if !defined(WINAPI_FAMILY) || WINAPI_FAMILY!=WINAPI_FAMILY_PHONE_APP
		WaitForSingleObject(h, INFINITE);
#else
		WaitForSingleObjectEx(h, INFINITE, false);
#endif
	}

	void Release(){
		ReleaseSemaphore(h, 1, NULL);
	}

	void Acquire(int count){
		for(int i=0;i<count;i++)
			Acquire();
	}

	void Release(int count){
		ReleaseSemaphore(h, count, NULL);
	}

private:
	HANDLE h;
};
}
#else
#error "No threading implementation for your operating system"
#endif

namespace tgvoip{
class MutexGuard{
public:
    MutexGuard(tgvoip_mutex_t &mutex) : mutex(mutex) {
		lock_mutex(mutex);
	}
	~MutexGuard(){
		unlock_mutex(mutex);
	}
private:
	tgvoip_mutex_t &mutex;
};
}
	
#endif //__THREADING_H
