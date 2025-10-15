

#import <Foundation/Foundation.h>

#import <pthread.h>

#define TG_SYNCHRONIZED_DEFINE(lock) pthread_mutex_t _TG_SYNCHRONIZED_##lock
#define TG_SYNCHRONIZED_INIT(lock) pthread_mutex_init(&_TG_SYNCHRONIZED_##lock, NULL)
#define TG_SYNCHRONIZED_BEGIN(lock) pthread_mutex_lock(&_TG_SYNCHRONIZED_##lock);
#define TG_SYNCHRONIZED_END(lock) pthread_mutex_unlock(&_TG_SYNCHRONIZED_##lock);

@interface NSObject (TGLock)

- (void)tgLockObject;
- (void)tgUnlockObject;

@end
