/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTTcpConnection.h"

#import "MTLogging.h"
#import "MTQueue.h"
#import "MTTimer.h"

#import "GCDAsyncSocket.h"
#import <sys/socket.h>

#import "MTInternalId.h"

#import "MTContext.h"
#import "MTApiEnvironment.h"
#import "MTDatacenterAddress.h"

#import "MTAes.h"

MTInternalIdClass(MTTcpConnection)

typedef enum {
    MTTcpReadTagPacketShortLength = 0,
    MTTcpReadTagPacketLongLength = 1,
    MTTcpReadTagPacketBody = 2,
    MTTcpReadTagPacketHead = 3,
    MTTcpReadTagQuickAck = 4
} MTTcpReadTags;

static const NSTimeInterval MTMinTcpResponseTimeout = 12.0;
static const NSUInteger MTTcpProgressCalculationThreshold = 4096;
static const bool useEncryption = true;

struct ctr_state {
    unsigned char ivec[16];  /* ivec[0..7] is the IV, ivec[8..15] is the big-endian counter */
    unsigned int num;
    unsigned char ecount[16];
};

static void init_ctr(struct ctr_state *state, const unsigned char *iv)
{
    state->num = 0;
    memset(state->ecount, 0, 16);
    memcpy(state->ivec, iv, 16);
}

@interface MTTcpConnection () <GCDAsyncSocketDelegate>
{   
    GCDAsyncSocket *_socket;
    bool _closed;
    
    uint8_t _quickAckByte;
    
    MTTimer *_responseTimeoutTimer;
    
    bool _readingPartialData;
    NSData *_packetHead;
    NSUInteger _packetRestLength;
    NSUInteger _packetRestReceivedLength;
    
    bool _delegateImplementsProgressUpdated;
    NSData *_firstPacketControlByte;
    
    bool _addedControlHeader;
    
    MTAesCtr *_outgoingAesCtr;
    MTAesCtr *_incomingAesCtr;
    
    MTNetworkUsageCalculationInfo *_usageCalculationInfo;
}

@property (nonatomic) int64_t packetHeadDecodeToken;
@property (nonatomic, strong) id packetProgressToken;

@end

@implementation MTTcpConnection

+ (MTQueue *)tcpQueue
{
    static MTQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[MTQueue alloc] initWithName:"org.mtproto.tcpQueue"];
    });
    return queue;
}

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address interface:(NSString *)interface usageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo
{
#ifdef DEBUG
    NSAssert(address != nil, @"address should not be nil");
#endif
    
    self = [super init];
    if (self != nil)
    {
        _internalId = [[MTInternalId(MTTcpConnection) alloc] init];
        
/*#ifdef DEBUG
        if (![address isIpv6]) {
            address = [[MTDatacenterAddress alloc] initWithIp:@"127.0.0.1" port:443 preferForMedia:address.preferForMedia restrictToTcp:address.restrictToTcp];
        }
#endif*/
        
        _address = address;
        
        _interface = interface;
        _usageCalculationInfo = usageCalculationInfo;
        
        if (context.apiEnvironment.datacenterAddressOverrides[@(datacenterId)] != nil) {
            _firstPacketControlByte = [context.apiEnvironment tcpPayloadPrefix];
        }
    }
    return self;
}

- (void)dealloc
{
    GCDAsyncSocket *socket = _socket;
    socket.delegate = nil;
    _socket = nil;
    
    MTTimer *responseTimeoutTimer = _responseTimeoutTimer;
    
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        [responseTimeoutTimer invalidate];
        
        [socket disconnect];
    }];
}

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo {
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^{
        _usageCalculationInfo = usageCalculationInfo;
        _socket.usageCalculationInfo = usageCalculationInfo;
    }];
}

- (void)setDelegate:(id<MTTcpConnectionDelegate>)delegate
{
    _delegate = delegate;
    
    _delegateImplementsProgressUpdated = [delegate respondsToSelector:@selector(tcpConnectionProgressUpdated:packetProgressToken:packetLength:progress:)];
}

- (void)start
{
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        if (_socket == nil)
        {
            _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:[[MTTcpConnection tcpQueue] nativeQueue]];
            _socket.usageCalculationInfo = _usageCalculationInfo;
            
            if (MTLogEnabled()) {
                MTLog(@"[MTTcpConnection#%x connecting to %@:%d]", (int)self, _address.ip, (int)_address.port);
            }
            
            NSString *ip = _address.ip;
            
            __autoreleasing NSError *error = nil;
            if (![_socket connectToHost:ip onPort:_address.port viaInterface:_interface withTimeout:12 error:&error] || error != nil)
                [self closeAndNotify];
            else
                [_socket readDataToLength:1 withTimeout:-1 tag:MTTcpReadTagPacketShortLength];
        }
    }];
}

- (void)stop
{
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        if (!_closed)
            [self closeAndNotify];
    }];
}

- (void)closeAndNotify
{
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        if (!_closed)
        {
            _closed = true;
            
            [_socket disconnect];
            _socket.delegate = nil;
            _socket = nil;
            
            if (_connectionClosed)
                _connectionClosed();
            id<MTTcpConnectionDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(tcpConnectionClosed:)])
                [delegate tcpConnectionClosed:self];
        }
    }];
}

- (void)sendDatas:(NSArray *)datas completion:(void (^)(bool success))completion requestQuickAck:(bool)requestQuickAck expectDataInResponse:(bool)expectDataInResponse
{
    if (datas.count == 0)
    {
        completion(false);
        
        return;
    }
    
#ifdef DEBUG
    for (NSData *data in datas)
    {
        NSAssert(data.length % 4 == 0, @"data length should be divisible by 4");
    }
#endif
    
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        if (!_closed)
        {
            if (_socket != nil)
            {
                NSUInteger completeDataLength = 0;
                
                for (NSData *data in datas)
                {
                    NSMutableData *packetData = [[NSMutableData alloc] initWithCapacity:data.length + 4];
                    
                    int32_t quarterLength = (int32_t)(data.length / 4);
                    
                    if (quarterLength <= 0x7e)
                    {
                        uint8_t quarterLengthMarker = (uint8_t)quarterLength;
                        if (requestQuickAck)
                            quarterLengthMarker |= 0x80;
                        [packetData appendBytes:&quarterLengthMarker length:1];
                    }
                    else
                    {
                        uint8_t quarterLengthMarker = 0x7f;
                        if (requestQuickAck)
                            quarterLengthMarker |= 0x80;
                        [packetData appendBytes:&quarterLengthMarker length:1];
                        [packetData appendBytes:((uint8_t *)&quarterLength) length:3];
                    }
                    
                    [packetData appendData:data];
                    
                    completeDataLength += packetData.length;
                    
                    if (!_addedControlHeader) {
                        _addedControlHeader = true;
                        uint8_t controlBytes[64];
                        arc4random_buf(controlBytes, 64);
                        
                        if (useEncryption) {
                            int32_t controlVersion = 0xefefefef;
                            memcpy(controlBytes + 56, &controlVersion, 4);
                            
                            uint8_t controlBytesReversed[64];
                            for (int i = 0; i < 64; i++) {
                                controlBytesReversed[i] = controlBytes[64 - 1 - i];
                            }
                            
                            _outgoingAesCtr = [[MTAesCtr alloc] initWithKey:controlBytes + 8 keyLength:32 iv:controlBytes + 8 + 32];
                            _incomingAesCtr = [[MTAesCtr alloc] initWithKey:controlBytesReversed + 8 keyLength:32 iv:controlBytesReversed + 8 + 32];
                            
                            uint8_t encryptedControlBytes[64];
                            [_outgoingAesCtr encryptIn:controlBytes out:encryptedControlBytes len:64];
                            
                            NSMutableData *outData = [[NSMutableData alloc] initWithLength:64 + packetData.length];
                            memcpy(outData.mutableBytes, controlBytes, 56);
                            memcpy(outData.mutableBytes + 56, encryptedControlBytes + 56, 8);
                            
                            [_outgoingAesCtr encryptIn:packetData.bytes out:outData.mutableBytes + 64 len:packetData.length];
                            
                            [_socket writeData:outData withTimeout:-1 tag:0];
                        } else {
                            int32_t *firstByte = (int32_t *)controlBytes;
                            while (*firstByte == 0x44414548 || *firstByte == 0x54534f50 || *firstByte == 0x20544547 || *firstByte == 0x4954504f || *firstByte == 0xeeeeeeee) {
                                arc4random_buf(controlBytes, 4);
                            }
                            
                            while (controlBytes[0] == 0xef) {
                                arc4random_buf(controlBytes, 1);
                            }
                            
                            NSMutableData *controlData = [[NSMutableData alloc] init];
                            [controlData appendBytes:controlBytes length:64];
                            [controlData appendData:packetData];
                            [_socket writeData:controlData withTimeout:-1 tag:0];
                        }
                    } else {
                        if (useEncryption) {
                            NSMutableData *encryptedData = [[NSMutableData alloc] initWithLength:packetData.length];
                            [_outgoingAesCtr encryptIn:packetData.bytes out:encryptedData.mutableBytes len:packetData.length];
                            
                            [_socket writeData:encryptedData withTimeout:-1 tag:0];
                        } else {
                            [_socket writeData:packetData withTimeout:-1 tag:0];
                        }
                    }
                }
                
                if (expectDataInResponse && _responseTimeoutTimer == nil)
                {
                    __weak MTTcpConnection *weakSelf = self;
                    _responseTimeoutTimer = [[MTTimer alloc] initWithTimeout:MTMinTcpResponseTimeout + completeDataLength / (12.0 * 1024) repeat:false completion:^
                    {
                        __strong MTTcpConnection *strongSelf = weakSelf;
                        [strongSelf responseTimeout];
                    } queue:[MTTcpConnection tcpQueue].nativeQueue];
                    [_responseTimeoutTimer start];
                }
                
                if (completion)
                    completion(true);
            }
            else
            {
                if (MTLogEnabled()) {
                    MTLog(@"***** %s: can't send data: connection is not opened", __PRETTY_FUNCTION__);
                }
                
                if (completion)
                    completion(false);
            }
        }
        else
        {
            if (completion)
                completion(false);
        }
    }];
}

- (void)responseTimeout
{
    [_responseTimeoutTimer invalidate];
    _responseTimeoutTimer = nil;
    
    if (MTLogEnabled()) {
        MTLog(@"[MTTcpConnection#%x response timeout]", (int)self);
    }
    [self stop];
}

- (void)socket:(GCDAsyncSocket *)__unused socket didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)__unused tag
{
    if (_closed)
        return;
    
    [_responseTimeoutTimer resetTimeout:MTMinTcpResponseTimeout];
    
    if (_packetRestLength != 0)
    {
        NSUInteger previousApproximateProgress = _packetRestReceivedLength * 100 / _packetRestLength;
        _packetRestReceivedLength = MIN(_packetRestReceivedLength + partialLength, _packetRestLength);
        NSUInteger currentApproximateProgress = _packetRestReceivedLength * 100 / _packetRestLength;
        
        if (previousApproximateProgress != currentApproximateProgress && _packetProgressToken != nil && _delegateImplementsProgressUpdated)
        {
            id<MTTcpConnectionDelegate> delegate = _delegate;
            [delegate tcpConnectionProgressUpdated:self packetProgressToken:_packetProgressToken packetLength:_packetRestLength progress:currentApproximateProgress / 100.0f];
        }
    }
}

- (void)socket:(GCDAsyncSocket *)__unused socket didReadData:(NSData *)rawData withTag:(long)tag
{
    if (_closed)
        return;
    
    NSData *data = nil;
    if (useEncryption) {
        NSMutableData *decryptedData = [[NSMutableData alloc] initWithLength:rawData.length];
        [_incomingAesCtr encryptIn:rawData.bytes out:decryptedData.mutableBytes len:rawData.length];
        
        data = decryptedData;
    } else {
        data = rawData;
    }
    
    if (tag == MTTcpReadTagPacketShortLength)
    {
#ifdef DEBUG
        NSAssert(data.length == 1, @"data length should be equal to 1");
#endif
        
        uint8_t quarterLengthMarker = 0;
        [data getBytes:&quarterLengthMarker length:1];
        
        if ((quarterLengthMarker & 0x80) == 0x80)
        {
            _quickAckByte = quarterLengthMarker;
            [_socket readDataToLength:3 withTimeout:-1 tag:MTTcpReadTagQuickAck];
        }
        else
        {
            if (quarterLengthMarker >= 0x01 && quarterLengthMarker <= 0x7e)
            {
                NSUInteger packetBodyLength = ((NSUInteger)quarterLengthMarker) * 4;
                if (packetBodyLength >= MTTcpProgressCalculationThreshold)
                {
                    _packetRestLength = packetBodyLength - 128;
                    _packetRestReceivedLength = 0;
                    [_socket readDataToLength:128 withTimeout:-1 tag:MTTcpReadTagPacketHead];
                }
                else
                    [_socket readDataToLength:packetBodyLength withTimeout:-1 tag:MTTcpReadTagPacketBody];
            }
            else if (quarterLengthMarker == 0x7f)
                [_socket readDataToLength:3 withTimeout:-1 tag:MTTcpReadTagPacketLongLength];
            else
            {
                if (MTLogEnabled()) {
                    MTLog(@"***** %s: invalid quarter length marker (%" PRIu8 ")", __PRETTY_FUNCTION__, quarterLengthMarker);
                }
                [self closeAndNotify];
            }
        }
    }
    else if (tag == MTTcpReadTagPacketLongLength)
    {
#ifdef DEBUG
        NSAssert(data.length == 3, @"data length should be equal to 3");
#endif
        
        uint32_t quarterLength = 0;
        [data getBytes:(((uint8_t *)&quarterLength)) length:3];
        
        if (quarterLength <= 0 || quarterLength > (4 * 1024 * 1024) / 4)
        {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid quarter length (%" PRIu32 ")", __PRETTY_FUNCTION__, quarterLength);
            }
            [self closeAndNotify];
        }
        else
        {
            NSUInteger packetBodyLength = quarterLength * 4;
            if (packetBodyLength >= MTTcpProgressCalculationThreshold)
            {
                _packetRestLength = packetBodyLength - 128;
                _packetRestReceivedLength = 0;
                [_socket readDataToLength:128 withTimeout:-1 tag:MTTcpReadTagPacketHead];
            }
            else
                [_socket readDataToLength:packetBodyLength withTimeout:-1 tag:MTTcpReadTagPacketBody];
        }
    }
    else if (tag == MTTcpReadTagPacketHead)
    {
        _packetHead = data;
        
        static int64_t nextToken = 0;
        _packetHeadDecodeToken = nextToken;
        nextToken++;
        
        id<MTTcpConnectionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionDecodePacketProgressToken:data:token:completion:)])
        {
            __weak MTTcpConnection *weakSelf = self;
            [delegate tcpConnectionDecodePacketProgressToken:self data:data token:_packetHeadDecodeToken completion:^(int64_t token, id packetProgressToken)
            {
                __strong MTTcpConnection *strongSelf = weakSelf;
                if (strongSelf != nil && token == strongSelf.packetHeadDecodeToken)
                    strongSelf.packetProgressToken = packetProgressToken;
            }];
        }
        
        [_socket readDataToLength:_packetRestLength withTimeout:-1 tag:MTTcpReadTagPacketBody];
    }
    else if (tag == MTTcpReadTagPacketBody)
    {
        [_responseTimeoutTimer invalidate];
        _responseTimeoutTimer = nil;
        
        _packetHeadDecodeToken = -1;
        _packetProgressToken = nil;
        
        NSData *packetData = data;
        if (_packetHead != nil)
        {
            NSMutableData *combinedData = [[NSMutableData alloc] initWithCapacity:_packetHead.length + data.length];
            [combinedData appendData:_packetHead];
            [combinedData appendData:data];
            packetData = combinedData;
            _packetHead = nil;
        }
        
        if (_connectionReceivedData)
            _connectionReceivedData(packetData);
        id<MTTcpConnectionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionReceivedData:data:)])
            [delegate tcpConnectionReceivedData:self data:packetData];
        
        [_socket readDataToLength:1 withTimeout:-1 tag:MTTcpReadTagPacketShortLength];
    }
    else if (tag == MTTcpReadTagQuickAck)
    {
#ifdef DEBUG
        NSAssert(data.length == 3, @"data length should be equal to 3");
#endif
        
        int32_t ackId = 0;
        ((uint8_t *)&ackId)[0] = _quickAckByte;
        memcpy(((uint8_t *)&ackId) + 1, data.bytes, 3);
        ackId = (int32_t)OSSwapInt32(ackId);
        ackId &= ((int32_t)0xffffffff ^ (int32_t)(1 << 31));
        
        id<MTTcpConnectionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionReceivedQuickAck:quickAck:)])
            [delegate tcpConnectionReceivedQuickAck:self quickAck:ackId];
        
        [_socket readDataToLength:1 withTimeout:-1 tag:MTTcpReadTagPacketShortLength];
    }
}

- (void)socket:(GCDAsyncSocket *)__unused socket didConnectToHost:(NSString *)__unused host port:(uint16_t)__unused port
{
    if (_connectionOpened)
        _connectionOpened();
    id<MTTcpConnectionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(tcpConnectionOpened:)])
        [delegate tcpConnectionOpened:self];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)__unused socket withError:(NSError *)error
{
    if (error != nil) {
        if (MTLogEnabled()) {
            MTLog(@"[MTTcpConnection#%x disconnected from %@ (%@)]", (int)self, _address.ip, error);
        }
    }
    else {
        if (MTLogEnabled()) {
            MTLog(@"[MTTcpConnection#%x disconnected from %@]", (int)self, _address.ip);
        }
    }
    
    [self closeAndNotify];
}

@end
