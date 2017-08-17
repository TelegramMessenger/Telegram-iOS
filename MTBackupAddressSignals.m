#import "MTBackupAddressSignals.h"

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTSignal.h>
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

@implementation MTBackupAddressSignals

+ (MTSignal *)fetchBackupIpsGoogle:(bool)isTesting {
    NSDictionary *headers = @{@"Host": @"dns-telegram.appspot.com"};
    
    return [[MTHttpRequestOperation dataForHttpUrl:[NSURL URLWithString:isTesting ? @"https://google.com/test/" : @"https://google.com/"] headers:headers] mapToSignal:^MTSignal *(NSData *data) {
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        text = [text stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];
        NSData *result = [[NSData alloc] initWithBase64EncodedString:text options:NSDataBase64DecodingIgnoreUnknownCharacters];
        NSMutableData *finalData = [[NSMutableData alloc] initWithData:result];
        [finalData setLength:256];
        MTBackupDatacenterData *datacenterData = MTIPDataDecode(finalData);
        if (datacenterData != nil) {
            return [MTSignal single:datacenterData];
        } else {
            return [MTSignal complete];
        };
    }];
}

+ (MTSignal *)fetchBackupIpsResolveGoogle:(bool)isTesting {
    NSDictionary *headers = @{@"Host": @"dns.google.com"};
    
    return [[MTHttpRequestOperation dataForHttpUrl:[NSURL URLWithString:[NSString stringWithFormat:@"https://google.com/resolve?name=%@&type=16", isTesting ? @"tap.stel.com" : @"ap.stel.com"]] headers:headers] mapToSignal:^MTSignal *(NSData *data) {
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
                
                NSData *result = [[NSData alloc] initWithBase64EncodedString:finalString options:NSDataBase64DecodingIgnoreUnknownCharacters];
                NSMutableData *finalData = [[NSMutableData alloc] initWithData:result];
                [finalData setLength:256];
                MTBackupDatacenterData *datacenterData = MTIPDataDecode(finalData);
                if (datacenterData != nil) {
                    return [MTSignal single:datacenterData];
                }
            }
        }
        return [MTSignal complete];
    }];
}

+ (MTSignal *)fetchBackupIps:(bool)isTestingEnvironment currentContext:(MTContext *)currentContext {
    NSArray *signals = @[[self fetchBackupIpsGoogle:isTestingEnvironment], [self fetchBackupIpsResolveGoogle:isTestingEnvironment]];
    
    return [[[MTSignal mergeSignals:signals] take:1] mapToSignal:^MTSignal *(MTBackupDatacenterData *data) {
        if (data != nil && data.addressList.count != 0) {
            MTApiEnvironment *apiEnvironment = [currentContext.apiEnvironment copy];
            
            NSMutableDictionary *datacenterAddressOverrides = [[NSMutableDictionary alloc] init];
            
            MTBackupDatacenterAddress *address = data.addressList[0];
            datacenterAddressOverrides[@(data.datacenterId)] = [[MTDatacenterAddress alloc] initWithIp:address.ip port:(uint16_t)address.port preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false];
            apiEnvironment.datacenterAddressOverrides = datacenterAddressOverrides;
            
            apiEnvironment.apiId = currentContext.apiEnvironment.apiId;
            apiEnvironment.layer = currentContext.apiEnvironment.layer;
            apiEnvironment = [apiEnvironment withUpdatedLangPackCode:currentContext.apiEnvironment.langPackCode];
            apiEnvironment.disableUpdates = true;
            apiEnvironment.langPack = currentContext.apiEnvironment.langPack;
            
            MTContext *context = [[MTContext alloc] initWithSerialization:currentContext.serialization apiEnvironment:apiEnvironment];
            
            if (data.datacenterId != 0) {
                context.keychain = currentContext.keychain;
            }
            
            MTProto *mtProto = [[MTProto alloc] initWithContext:context datacenterId:data.datacenterId usageCalculationInfo:nil];
            MTRequestMessageService *requestService = [[MTRequestMessageService alloc] initWithContext:context];
            [mtProto addMessageService:requestService];
            
            [mtProto resume];
            
            MTRequest *request = [[MTRequest alloc] init];
            
            NSData *getConfigData = nil;
            MTRequestDatacenterAddressListParser responseParser = [currentContext.serialization requestDatacenterAddressWithData:&getConfigData];
            
            [request setPayload:getConfigData metadata:@"getConfig" responseParser:responseParser];
            
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
                                         MTLog(@"[Backup address fetch (%@): updating datacenter %d address set to %@]", isTestingEnvironment ? @"testing" : @"production", [nDatacenterId intValue], addressSet);
                                     }
                                     
                                     [strongCurrentContext updateAddressSetForDatacenterWithId:[nDatacenterId integerValue] addressSet:addressSet forceUpdateSchemes:true];
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
                }];
            }];
        }
        return [MTSignal complete];
    }];
}

@end
