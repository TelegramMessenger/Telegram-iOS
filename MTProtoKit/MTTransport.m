/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTTransport.h>

#import <MTProtoKit/MTNetworkAvailability.h>

@interface MTTransport () <MTNetworkAvailabilityDelegate>
{
    MTNetworkAvailability *_networkAvailability;
}

@end

@implementation MTTransport

- (instancetype)initWithDelegate:(id<MTTransportDelegate>)delegate context:(MTContext *)context datacenterId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address
{
#ifdef DEBUG
    NSAssert(context != nil, @"context should not be nil");
    NSAssert(datacenterId != 0, @"datacenter id should not be 0");
#endif
    
    self = [super init];
    if (self != nil)
    {
        _delegate = delegate;
        _context = context;
        _datacenterId = datacenterId;
        
        _networkAvailability = [[MTNetworkAvailability alloc] initWithDelegate:self];
        
        _reportTransportConnectionContextUpdateStates = true;
    }
    return self;
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

- (void)_processIncomingData:(NSData *)data transactionId:(id)transactionId requestTransactionAfterProcessing:(bool)requestTransactionAfterProcessing decodeResult:(void (^)(id transactionId, bool success))decodeResult
{
    id<MTTransportDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(transportHasIncomingData:data:transactionId:requestTransactionAfterProcessing:decodeResult:)])
    {
        [delegate transportHasIncomingData:self data:data transactionId:transactionId requestTransactionAfterProcessing:requestTransactionAfterProcessing decodeResult:decodeResult];
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

@end
