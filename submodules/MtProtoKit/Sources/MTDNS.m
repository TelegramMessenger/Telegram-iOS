#import "MTDNS.h"

#import <arpa/inet.h>
#include <netinet/tcp.h>
#import <fcntl.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <netinet/in.h>
#import <net/if.h>

#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTSignal.h>
#import <MtProtoKit/MTBag.h>
#import <MtProtoKit/MTAtomic.h>
#import <MtProtoKit/MTHttpRequestOperation.h>
#import <MtProtoKit/MTEncryption.h>
#import <MtProtoKit/MTRequestMessageService.h>
#import <MtProtoKit/MTRequest.h>
#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTApiEnvironment.h>
#import <MtProtoKit/MTDatacenterAddress.h>
#import <MtProtoKit/MTDatacenterAddressSet.h>
#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTSerialization.h>
#import <MtProtoKit/MTLogging.h>

#import <netinet/in.h>
#import <arpa/inet.h>

@interface MTDNSHostContext : NSObject {
    MTBag *_subscribers;
    id<MTDisposable> _disposable;
}

@end

@implementation MTDNSHostContext

- (instancetype)initWithHost:(NSString *)host disposable:(id<MTDisposable>)disposable {
    self = [super init];
    if (self != nil) {
        _subscribers = [[MTBag alloc] init];
        _disposable = disposable;
    }
    return self;
}

- (void)dealloc {
    [_disposable dispose];
}

- (NSInteger)addSubscriber:(void (^)(NSString *))completion {
    return [_subscribers addItem:[completion copy]];
}

- (void)removeSubscriber:(NSInteger)index {
    [_subscribers removeItem:index];
}

- (bool)isEmpty {
    return [_subscribers isEmpty];
}

- (void)complete:(NSString *)result {
    for (void (^completion)(NSString *) in [_subscribers copyItems]) {
        completion(result);
    }
}

@end

@interface MTDNSContext : NSObject {
    NSMutableDictionary<NSString *, MTDNSHostContext *> *_contexts;
}

@end

@implementation MTDNSContext

+ (MTQueue *)sharedQueue {
    static MTQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[MTQueue alloc] init];
    });
    return queue;
}

+ (MTSignal *)shared {
    return [[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        static MTDNSContext *instance = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            instance = [[MTDNSContext alloc] init];
        });
        [subscriber putNext:instance];
        [subscriber putCompletion];
        return nil;
    }] startOn:[self sharedQueue]];
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _contexts = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id<MTDisposable>)subscribe:(NSString *)host port:(int32_t)port completion:(void (^)(NSString *))completion {
    NSString *key = [NSString stringWithFormat:@"%@:%d", host, port];
    
    MTMetaDisposable *disposable = nil;
    if (_contexts[key] == nil) {
        disposable = [[MTMetaDisposable alloc] init];
        _contexts[key] = [[MTDNSHostContext alloc] initWithHost:host disposable:disposable];
    }
    MTDNSHostContext *context = _contexts[key];
    
    NSInteger index = [context addSubscriber:^(NSString *result) {
        if (completion) {
            completion(result);
        }
    }];
    
    if (disposable != nil) {
        __weak MTDNSContext *weakSelf = self;
        [disposable setDisposable:[[[self performLookup:host port:port] deliverOn:[MTDNSContext sharedQueue]] startWithNext:^(NSString *result) {
            __strong MTDNSContext *strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            if (strongSelf->_contexts[key] != nil) {
                [strongSelf->_contexts[key] complete:result];
                [strongSelf->_contexts removeObjectForKey:key];
            }
        }]];
    }
    
    __weak MTDNSContext *weakSelf = self;
    __weak MTDNSHostContext *weakContext = context;
    return [[MTBlockDisposable alloc] initWithBlock:^{
        [[MTDNSContext sharedQueue] dispatchOnQueue:^{
            __strong MTDNSContext *strongSelf = weakSelf;
            __strong MTDNSHostContext *strongContext = weakContext;
            if (strongSelf == nil || strongContext == nil) {
                return;
            }
            if (strongSelf->_contexts[key] != nil && strongSelf->_contexts[key] == strongContext) {
                [strongSelf->_contexts[key] removeSubscriber:index];
                if ([strongSelf->_contexts[key] isEmpty]) {
                    [strongSelf->_contexts removeObjectForKey:key];
                }
            }
        }];
    }];
}

- (MTSignal *)performLookup:(NSString *)host port:(int32_t)port {
    MTSignal *lookupOnce = [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        MTMetaDisposable *disposable = [[MTMetaDisposable alloc] init];
        [[MTQueue concurrentDefaultQueue] dispatchOnQueue:^{
            struct addrinfo hints, *res, *res0;
            
            memset(&hints, 0, sizeof(hints));
            hints.ai_family   = PF_UNSPEC;
            hints.ai_socktype = SOCK_STREAM;
            hints.ai_protocol = IPPROTO_TCP;
            
            NSString *portStr = [NSString stringWithFormat:@"%d", port];
            if (MTLogEnabled()) {
                MTLog(@"[MTDNS lookup %@:%@]", host, portStr);
            }
            int gai_error = getaddrinfo([host UTF8String], [portStr UTF8String], &hints, &res0);
            
            NSString *address4 = nil;
            NSString *address6 = nil;
            
            if (gai_error == 0) {
                for(res = res0; res; res = res->ai_next) {
                    if ((address4 == nil) && (res->ai_family == AF_INET)) {
                        struct sockaddr_in *addr_in = (struct sockaddr_in *)res->ai_addr;
                        char *s = malloc(INET_ADDRSTRLEN);
                        inet_ntop(AF_INET, &(addr_in->sin_addr), s, INET_ADDRSTRLEN);
                        address4 = [NSString stringWithUTF8String:s];
                        free(s);
                    } else if ((address6 == nil) && (res->ai_family == AF_INET6)) {
                        struct sockaddr_in6 *addr_in6 = (struct sockaddr_in6 *)res->ai_addr;
                        char *s = malloc(INET6_ADDRSTRLEN);
                        inet_ntop(AF_INET6, &(addr_in6->sin6_addr), s, INET6_ADDRSTRLEN);
                        address6 = [NSString stringWithUTF8String:s];
                        free(s);
                    }
                }
                freeaddrinfo(res0);
            }
            
            if (address4 != nil) {
                if (MTLogEnabled()) {
                    MTLog(@"[MTDNS lookup %@:%@ success ipv4]", host, portStr);
                }
                [subscriber putNext:address4];
                [subscriber putCompletion];
            } else if (address6 != nil) {
                if (MTLogEnabled()) {
                    MTLog(@"[MTDNS lookup %@:%@ success ipv6]", host, portStr);
                }
                [subscriber putNext:address6];
                [subscriber putCompletion];
            } else {
                if (MTLogEnabled()) {
                    MTLog(@"[MTDNS lookup %@:%@ error %d]", host, portStr, gai_error);
                }
                [subscriber putError:nil];
            }
        }];
        return disposable;
    }];
    return [[[lookupOnce catch:^MTSignal *(__unused id error) {
        return [[MTSignal complete] delay:2.0 onQueue:[MTDNSContext sharedQueue]];
    }] restart] take:1];
}

@end

@interface MTDNSCachedHostname : NSObject

@property (nonatomic, strong) NSString *ip;
@property (nonatomic) NSTimeInterval timestamp;

@end

@implementation MTDNSCachedHostname

- (instancetype)initWithIp:(NSString *)ip timestamp:(NSTimeInterval)timestamp {
    self = [super init];
    if (self != nil) {
        _ip = ip;
        _timestamp = timestamp;
    }
    return self;
}

@end

@implementation MTDNS

+ (MTAtomic *)hostnameCache {
    static MTAtomic *result = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        result = [[MTAtomic alloc] initWithValue:[[NSMutableDictionary alloc] init]];
    });
    return result;
}

+ (NSString *)cachedIp:(NSString *)hostname {
    return [[self hostnameCache] with:^id (NSMutableDictionary *dict) {
        MTDNSCachedHostname *result = dict[hostname];
        if (result != nil && result.timestamp > CFAbsoluteTimeGetCurrent() - 10.0 * 60.0) {
            return result.ip;
        }
        return nil;
    }];
}

+ (void)cacheIp:(NSString *)hostname ip:(NSString *)ip {
    [[self hostnameCache] with:^id (NSMutableDictionary *dict) {
        dict[hostname] = [[MTDNSCachedHostname alloc] initWithIp:ip timestamp:CFAbsoluteTimeGetCurrent()];
        return nil;
    }];
}

+ (MTSignal *)resolveHostname:(NSString *)hostname {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        NSString *cached = [self cachedIp:hostname];
        if (cached != nil) {
            [subscriber putNext:cached];
            [subscriber putCompletion];
            return nil;
        }
        NSDictionary *headers = @{@"Host": @"dns.google.com"};
        
        return [[[MTHttpRequestOperation dataForHttpUrl:[NSURL URLWithString:[NSString stringWithFormat:@"https://google.com/resolve?name=%@", hostname]] headers:headers] mapToSignal:^MTSignal *(MTHttpResponse *response) {
            NSData *data = response.data;
            
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([dict respondsToSelector:@selector(objectForKey:)]) {
                NSArray *answer = dict[@"Answer"];
                if ([answer respondsToSelector:@selector(objectAtIndex:)]) {
                    for (NSDictionary *item in answer) {
                        if ([item respondsToSelector:@selector(objectForKey:)]) {
                            NSString *itemData = item[@"data"];
                            if ([itemData respondsToSelector:@selector(characterAtIndex:)]) {
                                bool isIp = true;
                                struct in_addr ip4;
                                struct in6_addr ip6;
                                if (inet_aton(itemData.UTF8String, &ip4) == 0) {
                                    if (inet_pton(AF_INET6, itemData.UTF8String, &ip6) == 0) {
                                        isIp = false;
                                    }
                                }
                                if (isIp) {
                                    [self cacheIp:hostname ip:itemData];
                                    return [MTSignal single:itemData];
                                }
                            }
                        }
                    }
                }
            }
            [subscriber putNext:hostname];
            [subscriber putCompletion];
            return nil;
        }] startWithNext:^(id next) {
            [subscriber putNext:next];
            [subscriber putCompletion];
        } error:^(id error) {
            [subscriber putNext:hostname];
            [subscriber putCompletion];
        } completed:nil];
    }];
}

+ (MTSignal *)resolveHostnameNative:(NSString *)hostname port:(int32_t)port {
    return [[MTDNSContext shared] mapToSignal:^MTSignal *(MTDNSContext *context) {
        return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
            return [context subscribe:hostname port:port completion:^(NSString *result) {
                [subscriber putNext:result];
                [subscriber putCompletion];
            }];
        }];
    }];
}

+ (MTSignal *)resolveHostnameUniversal:(NSString *)hostname port:(int32_t)port {
    return [[self resolveHostname:hostname] timeout:10.0 onQueue:[MTQueue concurrentDefaultQueue] orSignal:[self resolveHostnameNative:hostname port:port]];
}

@end
