#import "MTDNS.h"

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTSignal.h>
#   import <MTProtoKitDynamic/MTAtomic.h>
#   import <MTProtoKitDynamic/MTHttpRequestOperation.h>
#   import <MTProtoKitDynamic/MTEncryption.h>
#   import <MTProtoKitDynamic/MTRequestMessageService.h>
#   import <MTProtoKitDynamic/MTRequest.h>
#   import <MTProtoKitDynamic/MTContext.h>
#   import <MTProtoKitDynamic/MTApiEnvironment.h>
#   import <MTProtoKitDynamic/MTDatacenterAddress.h>
#   import <MTProtoKitDynamic/MTDatacenterAddressSet.h>
#   import <MTProtoKitDynamic/MTProto.h>
#   import <MTProtoKitDynamic/MTSerialization.h>
#   import <MTProtoKitDynamic/MTLogging.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTSignal.h>
#   import <MTProtoKitMac/MTAtomic.h>
#   import <MTProtoKitMac/MTHttpRequestOperation.h>
#   import <MTProtoKitMac/MTEncryption.h>
#   import <MTProtoKitMac/MTRequestMessageService.h>
#   import <MTProtoKitMac/MTRequest.h>
#   import <MTProtoKitMac/MTContext.h>
#   import <MTProtoKitMac/MTApiEnvironment.h>
#   import <MTProtoKitMac/MTDatacenterAddress.h>
#   import <MTProtoKitMac/MTDatacenterAddressSet.h>
#   import <MTProtoKitMac/MTProto.h>
#   import <MTProtoKitMac/MTSerialization.h>
#   import <MTProtoKitMac/MTLogging.h>
#else
#   import <MTProtoKit/MTSignal.h>
#   import <MTProtoKit/MTAtomic.h>
#   import <MTProtoKit/MTHttpRequestOperation.h>
#   import <MTProtoKit/MTEncryption.h>
#   import <MTProtoKit/MTRequestMessageService.h>
#   import <MTProtoKit/MTRequest.h>
#   import <MTProtoKit/MTContext.h>
#   import <MTProtoKit/MTApiEnvironment.h>
#   import <MTProtoKit/MTDatacenterAddress.h>
#   import <MTProtoKit/MTDatacenterAddressSet.h>
#   import <MTProtoKit/MTProto.h>
#   import <MTProtoKit/MTSerialization.h>
#   import <MTProtoKit/MTLogging.h>
#endif

#import <netinet/in.h>
#import <arpa/inet.h>

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
        
        return [[[MTHttpRequestOperation dataForHttpUrl:[NSURL URLWithString:[NSString stringWithFormat:@"https://google.com/resolve?name=%@", hostname]] headers:headers] mapToSignal:^MTSignal *(NSData *data) {
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

@end
