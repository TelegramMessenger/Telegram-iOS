/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Basic demonstration of how to use the SystemConfiguration Reachablity APIs.
 */

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <sys/socket.h>
#import <netinet/in.h>

#import <CoreFoundation/CoreFoundation.h>

#import <LegacyReachability/LegacyReachability.h>

#import <pthread.h>
#import <os/lock.h>
#import <libkern/OSAtomic.h>

#pragma mark IPv6 Support
//Reachability fully support IPv6.  For full details, see ReadMe.md.


NSString *kReachabilityChangedNotification = @"kNetworkReachabilityChangedNotification";


#pragma mark - Supporting functions

#define kShouldPrintReachabilityFlags 0

static void PrintReachabilityFlags(SCNetworkReachabilityFlags flags, const char* comment)
{
#if kShouldPrintReachabilityFlags

    NSLog(@"Reachability Flag Status: %c%c %c%c%c%c%c%c%c %s\n",
#if TARGET_OS_IPHONE
          (flags & kSCNetworkReachabilityFlagsIsWWAN) ? 'W' : '-'
#else
          '-'
#endif
          ,
          (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',

          (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
          (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
          (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
          (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-',
          comment
          );
#endif
}

@interface ReachabilityAtomic : NSObject
{
    pthread_mutex_t _lock;
    pthread_mutexattr_t _attr;
    id _value;
}

@end

@implementation ReachabilityAtomic

- (instancetype)initWithValue:(id)value {
    self = [super init];
    if (self != nil) {
        pthread_mutex_init(&_lock, NULL);
        _value = value;
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
}

- (id)swap:(id)newValue {
    id previousValue = nil;
    pthread_mutex_lock(&_lock);
    previousValue = _value;
    _value = newValue;
    pthread_mutex_unlock(&_lock);
    return previousValue;
}

- (id)value {
    id previousValue = nil;
    pthread_mutex_lock(&_lock);
    previousValue = _value;
    pthread_mutex_unlock(&_lock);
    
    return previousValue;
}

- (id)modify:(id (^)(id))f {
    id newValue = nil;
    pthread_mutex_lock(&_lock);
    newValue = f(_value);
    _value = newValue;
    pthread_mutex_unlock(&_lock);
    return newValue;
}

- (id)with:(id (^)(id))f {
    id result = nil;
    pthread_mutex_lock(&_lock);
    result = f(_value);
    pthread_mutex_unlock(&_lock);
    return result;
}

@end

static int32_t nextKey = 1;
static ReachabilityAtomic *contexts() {
    static ReachabilityAtomic *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ReachabilityAtomic alloc] initWithValue:@{}];
    });
    return instance;
}

static void withContext(int32_t key, void (^f)(LegacyReachability *)) {
    LegacyReachability *reachability = [contexts() with:^id(NSDictionary *dict) {
        return dict[@(key)];
    }];
    f(reachability);
}

static int32_t addContext(LegacyReachability *context) {
    int32_t key = OSAtomicIncrement32(&nextKey);
    [contexts() modify:^id(NSMutableDictionary *dict) {
        NSMutableDictionary *updatedDict = [[NSMutableDictionary alloc] initWithDictionary:dict];
        updatedDict[@(key)] = context;
        return updatedDict;
    }];
    return key;
}

static void removeContext(int32_t key) {
    [contexts() modify:^id(NSMutableDictionary *dict) {
        NSMutableDictionary *updatedDict = [[NSMutableDictionary alloc] initWithDictionary:dict];
        [updatedDict removeObjectForKey:@(key)];
        return updatedDict;
    }];
}

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
#pragma unused (target, flags)
	//NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
	//NSCAssert([(__bridge NSObject*) info isKindOfClass: [LegacyReachability class]], @"info was wrong class in ReachabilityCallback");

    int32_t key = (int32_t)((intptr_t)info);
    withContext(key, ^(LegacyReachability *context) {
        if ([context isKindOfClass:[LegacyReachability class]] && context.reachabilityChanged != nil)
            context.reachabilityChanged(context.currentReachabilityStatus);
    });
}


#pragma mark - LegacyReachability implementation

@implementation LegacyReachability
{
    int32_t _key;
	SCNetworkReachabilityRef _reachabilityRef;
}

+ (instancetype)reachabilityWithHostName:(NSString *)hostName
{
    LegacyReachability* returnValue = NULL;
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
	if (reachability != NULL)
	{
		returnValue= [[self alloc] init];
		if (returnValue != NULL)
		{
			returnValue->_reachabilityRef = reachability;
		}
        else {
            CFRelease(reachability);
        }
	}
    if (returnValue) {
        returnValue->_key = addContext(returnValue);
    }
	return returnValue;
}


+ (instancetype)reachabilityWithAddress:(const struct sockaddr *)hostAddress
{
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, hostAddress);

    LegacyReachability* returnValue = NULL;

	if (reachability != NULL)
	{
		returnValue = [[self alloc] init];
		if (returnValue != NULL)
		{
			returnValue->_reachabilityRef = reachability;
		}
        else {
            CFRelease(reachability);
        }
	}
    if (returnValue) {
        returnValue->_key = addContext(returnValue);
    }
	return returnValue;
}


+ (instancetype)reachabilityForInternetConnection
{
	struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;
    
    return [self reachabilityWithAddress: (const struct sockaddr *) &zeroAddress];
}

#pragma mark reachabilityForLocalWiFi
//reachabilityForLocalWiFi has been removed from the sample.  See ReadMe.md for more information.
//+ (instancetype)reachabilityForLocalWiFi



#pragma mark - Start and stop notifier

- (BOOL)startNotifier
{
	BOOL returnValue = NO;
	SCNetworkReachabilityContext context = {0, (void *)((intptr_t)_key), NULL, NULL, NULL};

	if (SCNetworkReachabilitySetCallback(_reachabilityRef, ReachabilityCallback, &context))
	{
		if (SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
		{
			returnValue = YES;
		}
	}
    
	return returnValue;
}


- (void)stopNotifier
{
	if (_reachabilityRef != NULL)
	{
		SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	}
}


- (void)dealloc
{
    removeContext(_key);
	[self stopNotifier];
	if (_reachabilityRef != NULL)
	{
		CFRelease(_reachabilityRef);
	}
}


#pragma mark - Network Flag Handling

- (NetworkStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
	PrintReachabilityFlags(flags, "networkStatusForFlags");
	if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
	{
		// The target host is not reachable.
		return NotReachable;
	}

    NetworkStatus returnValue = NotReachable;

	if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
	{
		/*
         If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
         */
		returnValue = ReachableViaWiFi;
	}

	if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
        (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
	{
        /*
         ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
         */

        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
        {
            /*
             ... and no [user] intervention is needed...
             */
            returnValue = ReachableViaWiFi;
        }
    }

#if TARGET_OS_IPHONE
	if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
	{
		/*
         ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
         */
		returnValue = ReachableViaWWAN;
	}
#endif
    
	return returnValue;
}


- (BOOL)connectionRequired
{
	NSAssert(_reachabilityRef != NULL, @"connectionRequired called with NULL reachabilityRef");
	SCNetworkReachabilityFlags flags;

	if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags))
	{
		return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
	}

    return NO;
}


- (NetworkStatus)currentReachabilityStatus
{
	NSAssert(_reachabilityRef != NULL, @"currentNetworkStatus called with NULL SCNetworkReachabilityRef");
	NetworkStatus returnValue = NotReachable;
	SCNetworkReachabilityFlags flags;
    
	if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags))
	{
        returnValue = [self networkStatusForFlags:flags];
	}
    
	return returnValue;
}


@end
