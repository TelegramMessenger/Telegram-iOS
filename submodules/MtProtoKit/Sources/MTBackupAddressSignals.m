#import <MtProtoKit/MTBackupAddressSignals.h>

#import <MtProtoKit/MTSignal.h>
#import <MtProtoKit/MTQueue.h>
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

static NSData *base64_decode(NSString *str) {
    if ([NSData instancesRespondToSelector:@selector(initWithBase64EncodedString:options:)]) {
        NSData *data = [[NSData alloc] initWithBase64EncodedString:str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        return data;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [[NSData alloc] initWithBase64Encoding:[str stringByReplacingOccurrencesOfString:@"[^A-Za-z0-9+/=]" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, [str length])]];
#pragma clang diagnostic pop
    }
}

@implementation MTBackupAddressSignals

+ (bool)checkIpData:(MTBackupDatacenterData *)data timestamp:(int32_t)timestamp source:(NSString *)source {
    if (data.timestamp >= timestamp + 60 * 20 || data.expirationDate <= timestamp - 60 * 20) {
        if (MTLogEnabled()) {
            MTLog(@"[Backup address fetch: backup config from %@ validity interval %d ... %d does not include current %d]", source, data.timestamp, data.expirationDate, timestamp);
        }
        return false;
    } else {
        return true;
    }
}

+ (MTSignal *)fetchBackupIpsResolveGoogle:(bool)isTesting phoneNumber:(NSString *)phoneNumber currentContext:(MTContext *)currentContext addressOverride:(NSString *)addressOverride {
    NSArray *hosts = @[
        @[@"dns.google.com", @""],
        @[@"www.google.com", @"dns.google.com"],
    ];
    
    id<EncryptionProvider> encryptionProvider = currentContext.encryptionProvider;
    
    NSMutableArray *signals = [[NSMutableArray alloc] init];
    for (NSArray *hostAndHostname in hosts) {
        NSString *host = hostAndHostname[0];
        NSString *hostName = hostAndHostname[1];
        NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
        if ([hostName length] != 0) {
            headers[@"Host"] = hostName;
        }
        NSString *apvHost = @"apv3.stel.com";
        if (addressOverride != nil) {
            apvHost = addressOverride;
        }
        MTSignal *signal = [[[MTHttpRequestOperation dataForHttpUrl:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/resolve?name=%@&type=16&random_padding=%@", host, isTesting ? @"tapv3.stel.com" : apvHost, makeRandomPadding()]] headers:headers] mapToSignal:^MTSignal *(MTHttpResponse *response) {
            NSString *dateHeader = response.headers[@"Date"];
            if ([dateHeader isKindOfClass:[NSString class]]) {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
                [formatter setLocale:usLocale];
                [formatter setDateFormat:@"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"];
                NSDate *date = [formatter dateFromString:dateHeader];
                if (date != nil) {
                    double difference = [date timeIntervalSince1970] - [[NSDate date] timeIntervalSince1970];
                    [MTContext setFixedTimeDifference:(int32_t)difference];
                }
            }
            
            NSData *data = response.data;
            
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([dict respondsToSelector:@selector(objectForKey:)]) {
                NSArray *answer = dict[@"Answer"];
                NSMutableArray *strings = [[NSMutableArray alloc] init];
                if ([answer respondsToSelector:@selector(objectAtIndex:)]) {
                    for (NSDictionary *value in answer) {
                        if ([value respondsToSelector:@selector(objectForKey:)]) {
                            NSString *part = value[@"data"];
                            if ([part respondsToSelector:@selector(characterAtIndex:)]) {
                                [strings addObject:part];
                            }
                        }
                    }
                    [strings sortUsingComparator:^NSComparisonResult(NSString *lhs, NSString *rhs) {
                        if (lhs.length > rhs.length) {
                            return NSOrderedAscending;
                        } else {
                            return NSOrderedDescending;
                        }
                    }];
                    
                    NSString *finalString = @"";
                    for (NSString *string in strings) {
                        finalString = [finalString stringByAppendingString:[string stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]]];
                    }
                    
                    NSData *result = base64_decode(finalString);
                    NSMutableData *finalData = [[NSMutableData alloc] initWithData:result];
                    [finalData setLength:256];
                    MTBackupDatacenterData *datacenterData = MTIPDataDecode(encryptionProvider, finalData, phoneNumber);
                    if (datacenterData != nil && [self checkIpData:datacenterData timestamp:(int32_t)[currentContext globalTime] source:@"resolveGoogle"]) {
                        return [MTSignal single:datacenterData];
                    }
                }
            }
            return [MTSignal complete];
        }] catch:^MTSignal *(__unused id error) {
            return [MTSignal complete];
        }];
        if (signals.count != 0) {
            signal = [signal delay:signals.count onQueue:[[MTQueue alloc] init]];
        }
        [signals addObject:signal];
    }
    
    return [[MTSignal mergeSignals:signals] take:1];
}

static NSString *makeRandomPadding() {
    char validCharacters[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    int maxIndex = sizeof(validCharacters) - 1;
    
    int minPadding = 13;
    int maxPadding = 128;
    int padding = minPadding + arc4random_uniform(maxPadding - minPadding);
    NSMutableData *result = [[NSMutableData alloc] initWithLength:padding];
    for (NSUInteger i = 0; i < result.length; i++) {
        int index = arc4random_uniform(maxIndex);
        assert(index >= 0 && index < maxIndex);
        ((uint8_t *)(result.mutableBytes))[i] = validCharacters[index];
    }
    NSString *string = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
    return string;
}

+ (MTSignal *)fetchBackupIpsResolveCloudflare:(bool)isTesting phoneNumber:(NSString *)phoneNumber currentContext:(MTContext *)currentContext addressOverride:(NSString *)addressOverride {
    id<EncryptionProvider> encryptionProvider = currentContext.encryptionProvider;
    
    NSArray *hosts = @[
        @[@"mozilla.cloudflare-dns.com", @""],
    ];
    
    NSMutableArray *signals = [[NSMutableArray alloc] init];
    for (NSArray *hostAndHostname in hosts) {
        NSString *host = hostAndHostname[0];
        NSString *hostName = hostAndHostname[1];
        NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
        headers[@"accept"] = @"application/dns-json";
        if ([hostName length] != 0) {
            headers[@"Host"] = hostName;
        }
        NSString *apvHost = @"apv3.stel.com";
        if (addressOverride != nil) {
            apvHost = addressOverride;
        }
        MTSignal *signal = [[[MTHttpRequestOperation dataForHttpUrl:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/dns-query?name=%@&type=16&random_padding=%@", host, isTesting ? @"tapv3.stel.com" : apvHost, makeRandomPadding()]] headers:headers] mapToSignal:^MTSignal *(MTHttpResponse *response) {
            NSString *dateHeader = response.headers[@"Date"];
            if ([dateHeader isKindOfClass:[NSString class]]) {
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
                [formatter setLocale:usLocale];
                [formatter setDateFormat:@"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"];
                NSDate *date = [formatter dateFromString:dateHeader];
                if (date != nil) {
                    double difference = [date timeIntervalSince1970] - [[NSDate date] timeIntervalSince1970];
                    [MTContext setFixedTimeDifference:(int32_t)difference];
                }
            }
            
            NSData *data = response.data;
            
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([dict respondsToSelector:@selector(objectForKey:)]) {
                NSArray *answer = dict[@"Answer"];
                NSMutableArray *strings = [[NSMutableArray alloc] init];
                if ([answer respondsToSelector:@selector(objectAtIndex:)]) {
                    for (NSDictionary *value in answer) {
                        if ([value respondsToSelector:@selector(objectForKey:)]) {
                            NSString *part = value[@"data"];
                            if ([part respondsToSelector:@selector(characterAtIndex:)]) {
                                [strings addObject:part];
                            }
                        }
                    }
                    [strings sortUsingComparator:^NSComparisonResult(NSString *lhs, NSString *rhs) {
                        if (lhs.length > rhs.length) {
                            return NSOrderedAscending;
                        } else {
                            return NSOrderedDescending;
                        }
                    }];
                    
                    NSString *finalString = @"";
                    for (NSString *string in strings) {
                        finalString = [finalString stringByAppendingString:[string stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]]];
                    }
                    
                    NSData *result = base64_decode(finalString);
                    NSMutableData *finalData = [[NSMutableData alloc] initWithData:result];
                    [finalData setLength:256];
                    MTBackupDatacenterData *datacenterData = MTIPDataDecode(encryptionProvider, finalData, phoneNumber);
                    if (datacenterData != nil && [self checkIpData:datacenterData timestamp:(int32_t)[currentContext globalTime] source:@"resolveCloudflare"]) {
                        return [MTSignal single:datacenterData];
                    }
                }
            }
            return [MTSignal complete];
        }] catch:^MTSignal *(__unused id error) {
            return [MTSignal complete];
        }];
        if (signals.count != 0) {
            signal = [signal delay:signals.count onQueue:[[MTQueue alloc] init]];
        }
        [signals addObject:signal];
    }
    
    return [[MTSignal mergeSignals:signals] take:1];
}

+ (MTSignal *)fetchConfigFromAddress:(MTBackupDatacenterAddress *)address currentContext:(MTContext *)currentContext {
    MTApiEnvironment *apiEnvironment = [currentContext.apiEnvironment copy];
    
    apiEnvironment = [apiEnvironment withUpdatedSocksProxySettings:nil];
    
    NSMutableDictionary *datacenterAddressOverrides = [[NSMutableDictionary alloc] init];
    
    datacenterAddressOverrides[@(address.datacenterId)] = [[MTDatacenterAddress alloc] initWithIp:address.ip port:(uint16_t)address.port preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:address.secret];
    apiEnvironment.datacenterAddressOverrides = datacenterAddressOverrides;
    
    apiEnvironment.apiId = currentContext.apiEnvironment.apiId;
    apiEnvironment.layer = currentContext.apiEnvironment.layer;
    apiEnvironment = [apiEnvironment withUpdatedLangPackCode:currentContext.apiEnvironment.langPackCode];
    apiEnvironment.disableUpdates = true;
    apiEnvironment.langPack = currentContext.apiEnvironment.langPack;
    
    MTContext *context = [[MTContext alloc] initWithSerialization:currentContext.serialization encryptionProvider:currentContext.encryptionProvider apiEnvironment:apiEnvironment isTestingEnvironment:currentContext.isTestingEnvironment useTempAuthKeys:false];
    
    if (address.datacenterId != 0) {
        //context.keychain = currentContext.keychain;
    }
    
    MTProto *mtProto = [[MTProto alloc] initWithContext:context datacenterId:address.datacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    mtProto.useTempAuthKeys = true;
    mtProto.allowUnboundEphemeralKeys = true;
    MTRequestMessageService *requestService = [[MTRequestMessageService alloc] initWithContext:context];
    [mtProto addMessageService:requestService];
    
    [mtProto resume];
    
    MTRequest *request = [[MTRequest alloc] init];
    
    NSData *getConfigData = nil;
    MTRequestDatacenterAddressListParser responseParser = [currentContext.serialization requestDatacenterAddressWithData:&getConfigData];
    
    [request setPayload:getConfigData metadata:@"getConfig" shortMetadata:@"getConfig" responseParser:responseParser];
    
    __weak MTContext *weakCurrentContext = currentContext;
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        [request setCompleted:^(MTDatacenterAddressListData *result, __unused NSTimeInterval completionTimestamp, id error)
         {
             if (error == nil) {
                 __strong MTContext *strongCurrentContext = weakCurrentContext;
                 if (strongCurrentContext != nil) {
                     [result.addressList enumerateKeysAndObjectsUsingBlock:^(NSNumber *nDatacenterId, NSArray *list, __unused BOOL *stop) {
                         MTDatacenterAddressSet *addressSet = [[MTDatacenterAddressSet alloc] initWithAddressList:list];
                         
                         MTDatacenterAddressSet *currentAddressSet = [context addressSetForDatacenterWithId:[nDatacenterId integerValue]];
                         
                         if (currentAddressSet == nil || ![addressSet isEqual:currentAddressSet])
                         {
                             if (MTLogEnabled()) {
                                 MTLog(@"[Backup address fetch: updating datacenter %d address set to %@]", [nDatacenterId intValue], addressSet);
                             }
                             
                             [strongCurrentContext updateAddressSetForDatacenterWithId:[nDatacenterId integerValue] addressSet:addressSet forceUpdateSchemes:true];
                             [subscriber putNext:@true];
                             [subscriber putCompletion];
                         }
                     }];
                 }
             } else {
                 [subscriber putCompletion];
             }
         }];
        
        [requestService addRequest:request];
        
        id requestId = request.internalId;
        return [[MTBlockDisposable alloc] initWithBlock:^{
            [requestService removeRequestByInternalId:requestId];
            [mtProto pause];
        }];
    }];
}

+ (MTSignal * _Nonnull)fetchBackupIps:(bool)isTestingEnvironment currentContext:(MTContext * _Nonnull)currentContext additionalSource:(MTSignal * _Nullable)additionalSource phoneNumber:(NSString * _Nullable)phoneNumber {
    NSMutableArray *signals = [[NSMutableArray alloc] init];
    [signals addObject:[self fetchBackupIpsResolveGoogle:isTestingEnvironment phoneNumber:phoneNumber currentContext:currentContext addressOverride:currentContext.apiEnvironment.accessHostOverride]];
    [signals addObject:[self fetchBackupIpsResolveCloudflare:isTestingEnvironment phoneNumber:phoneNumber currentContext:currentContext addressOverride:currentContext.apiEnvironment.accessHostOverride]];
    if (additionalSource != nil) {
        [signals addObject:[additionalSource mapToSignal:^MTSignal *(MTBackupDatacenterData *datacenterData) {
            if (![datacenterData isKindOfClass:[MTBackupDatacenterData class]]) {
                return [MTSignal complete];
            }
            if (datacenterData != nil && [self checkIpData:datacenterData timestamp:(int32_t)[currentContext globalTime] source:@"resolveExternal"]) {
                return [MTSignal single:datacenterData];
            } else {
                return [MTSignal complete];
            }
        }]];
    }
    
    return [[[MTSignal mergeSignals:signals] take:1] mapToSignal:^MTSignal *(MTBackupDatacenterData *data) {
        if (data != nil && data.addressList.count != 0) {
            NSMutableArray *signals = [[NSMutableArray alloc] init];
            NSTimeInterval delay = 0.0;
            for (MTBackupDatacenterAddress *address in data.addressList) {
                MTSignal *signal = [self fetchConfigFromAddress:address currentContext:currentContext];
                if (delay > DBL_EPSILON) {
                    signal = [signal delay:delay onQueue:[[MTQueue alloc] init]];
                }
                [signals addObject:signal];
                delay += 5.0;
            }
            return [[MTSignal mergeSignals:signals] take:1];
        }
        return [MTSignal complete];
    }];
}

@end
