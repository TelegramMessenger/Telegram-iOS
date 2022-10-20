#import <MtProtoKit/MTTransport.h>

#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTNetworkAvailability.h>

@interface MTTransport () <MTNetworkAvailabilityDelegate>
{
    MTNetworkAvailability *_networkAvailability;
}

@end

@implementation MTTransport

- (instancetype)initWithDelegate:(id<MTTransportDelegate>)delegate context:(MTContext *)context datacenterId:(NSInteger)datacenterId schemes:(NSArray<MTTransportScheme *> * _Nonnull)schemes proxySettings:(MTSocksProxySettings *)proxySettings usageCalculationInfo:(MTNetworkUsageCalculationInfo *)__unused usageCalculationInfo getLogPrefix:(NSString * _Nullable (^ _Nullable)())getLogPrefix
{
#ifdef DEBUG
    NSAssert(context != nil, @"context should not be nil");
    NSAssert(datacenterId != 0, @"datacenter id should not be 0");
#endif
    
    self = [super init];
    if (self != nil) {
        _delegate = delegate;
        _context = context;
        _datacenterId = datacenterId;
        _proxySettings = proxySettings;
        _getLogPrefix = [getLogPrefix copy];
        
        _networkAvailability = [[MTNetworkAvailability alloc] initWithDelegate:self];
        
        _reportTransportConnectionContextUpdateStates = true;
    }
    return self;
}

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo *)__unused usageCalculationInfo {
}

- (bool)needsParityCorrection
{
    return false;
}

- (void)reset
{
}

- (void)stop
{
}

- (void)updateConnectionState
{
}

- (void)setDelegateNeedsTransaction
{
}

- (void)_processIncomingData:(NSData *)data scheme:(MTTransportScheme *)scheme transactionId:(id)transactionId requestTransactionAfterProcessing:(bool)requestTransactionAfterProcessing decodeResult:(void (^)(id transactionId, bool success))decodeResult
{
    id<MTTransportDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(transportHasIncomingData:scheme:data:transactionId:requestTransactionAfterProcessing:decodeResult:)])
    {
        [delegate transportHasIncomingData:self scheme:scheme data:data transactionId:transactionId requestTransactionAfterProcessing:requestTransactionAfterProcessing decodeResult:decodeResult];
    }
}

- (void)networkAvailabilityChanged:(MTNetworkAvailability *)__unused networkAvailability networkIsAvailable:(bool)networkIsAvailable
{
    [self _networkAvailabilityChanged:networkIsAvailable];
}

- (void)_networkAvailabilityChanged:(bool)networkAvailable
{
    id<MTTransportDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(transportNetworkAvailabilityChanged:isNetworkAvailable:)])
        [delegate transportNetworkAvailabilityChanged:self isNetworkAvailable:networkAvailable];
}

- (void)activeTransactionIds:(void (^)(NSArray *activeTransactionId))completion
{
    if (completion)
        completion(nil);
}

- (void)incomingMessageDecoded:(MTIncomingMessage *)__unused incomingMessage
{
}

- (void)updateSchemes:(NSArray<MTTransportScheme *> * _Nonnull)schemes {
}

@end
