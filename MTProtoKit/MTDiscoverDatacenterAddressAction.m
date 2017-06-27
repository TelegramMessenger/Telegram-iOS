/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTDiscoverDatacenterAddressAction.h"

#import "MTContext.h"
#import "MTSerialization.h"
#import "MTProto.h"
#import "MTDatacenterAddressSet.h"
#import "MTRequestMessageService.h"
#import "MTRequest.h"

@interface MTDiscoverDatacenterAddressAction () <MTContextChangeListener>
{
    NSInteger _datacenterId;
    __weak MTContext *_context;
    
    NSInteger _targetDatacenterId;
    bool _awaitingAddresSetUpdate;
    MTProto *_mtProto;
    MTRequestMessageService *_requestService;
    
    NSMutableSet *_processedDatacenters;
}

@end

@implementation MTDiscoverDatacenterAddressAction

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _processedDatacenters = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self cleanup];
}

- (void)execute:(MTContext *)context datacenterId:(NSInteger)datacenterId
{
    _datacenterId = datacenterId;
    _context = context;
    
    if (_datacenterId != 0 && context != nil)
    {
        __block bool datacenterAddressIsKnown = false;
        __block NSInteger currentDatacenterId = 0;
        
        [context enumerateAddressSetsForDatacenters:^(NSInteger datacenterId, __unused MTDatacenterAddressSet *addressSet, BOOL *stop)
        {
            if (datacenterId == _datacenterId)
            {
                datacenterAddressIsKnown = true;
                if (stop != NULL)
                    *stop = true;
            }
            else if (![_processedDatacenters containsObject:@(datacenterId)])
            {
                currentDatacenterId = datacenterId;
                [_processedDatacenters addObject:@(datacenterId)];
                
                if (stop != NULL)
                    *stop = true;
            }
        }];
        
        if (datacenterAddressIsKnown)
            [self complete];
        else if (currentDatacenterId != 0)
            [self askForAnAddressDatacenterWithId:currentDatacenterId];
        else
            [self fail];
    }
    else
        [self fail];
}

- (void)askForAnAddressDatacenterWithId:(NSInteger)targetDatacenterId
{
    _targetDatacenterId = targetDatacenterId;
    
    MTContext *context = _context;
    
    if (context == nil)
        [self fail];
    else
    {
        if ([context authInfoForDatacenterWithId:_targetDatacenterId] != nil)
        {
            _mtProto = [[MTProto alloc] initWithContext:context datacenterId:_targetDatacenterId usageCalculationInfo:nil];
            _requestService = [[MTRequestMessageService alloc] initWithContext:_context];
            [_mtProto addMessageService:_requestService];
            
            MTRequest *request = [[MTRequest alloc] init];
            
            NSData *getConfigData = nil;
            MTRequestDatacenterAddressListParser responseParser = [_context.serialization requestDatacenterAddressWithData:&getConfigData];
            
            [request setPayload:getConfigData metadata:@"getConfig" responseParser:responseParser];
            
            __weak MTDiscoverDatacenterAddressAction *weakSelf = self;
            [request setCompleted:^(MTDatacenterAddressListData *result, __unused NSTimeInterval completionTimestamp, id error)
            {
                __strong MTDiscoverDatacenterAddressAction *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    if (error == nil)
                        [strongSelf getConfigSuccess:result.addressList[@(strongSelf->_datacenterId)]];
                    else
                        [strongSelf getConfigFailed];
                }
            }];
            
            [_requestService addRequest:request];
        }
        else
            [context authInfoForDatacenterWithIdRequired:_targetDatacenterId isCdn:false];
    }
}

- (void)contextDatacenterAuthInfoUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo *)__unused authInfo
{
    if (_context != context || !_awaitingAddresSetUpdate)
        return;
    
    if (_targetDatacenterId != 0 && _targetDatacenterId == datacenterId)
    {
        _awaitingAddresSetUpdate = false;
        
        [self askForAnAddressDatacenterWithId:datacenterId];
    }
}

- (void)getConfigSuccess:(NSArray *)addressList
{
    if (addressList.count != 0)
    {
        MTContext *context = _context;
        [context updateAddressSetForDatacenterWithId:_datacenterId addressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:addressList] forceUpdateSchemes:false];
        [self complete];
    }
    else
        [self fail];
}

- (void)getConfigFailed
{
    [self cleanup];
    
    [self fail];
}

- (void)cleanup
{
    [_mtProto stop];
    _mtProto = nil;
}

- (void)cancel
{
    [self cleanup];
    [self fail];
}

- (void)complete
{
    id<MTDiscoverDatacenterAddressActionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(discoverDatacenterAddressActionCompleted:)])
        [delegate discoverDatacenterAddressActionCompleted:self];
}

- (void)fail
{
    id<MTDiscoverDatacenterAddressActionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(discoverDatacenterAddressActionCompleted:)])
        [delegate discoverDatacenterAddressActionCompleted:self];
}

@end
