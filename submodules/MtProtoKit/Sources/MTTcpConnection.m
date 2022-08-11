#import "MTTcpConnection.h"

#import <MtProtoKit/MTLogging.h>
#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTTimer.h>

#import "GCDAsyncSocket.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMac.h>

#import <MtProtoKit/MTInternalId.h>

#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTApiEnvironment.h>
#import <MtProtoKit/MTDatacenterAddress.h>
#import <MtProtoKit/MTTransportScheme.h>

#import "MTAes.h"
#import <MtProtoKit/MTEncryption.h>
#import <MtProtoKit/MTSignal.h>
#import "MTDNS.h"

#import <EncryptionProvider/EncryptionProvider.h>

static id<MTBignum> get_y2(id<MTBignum> x, id<MTBignum> mod, id<MTBignumContext> context) {
    // returns y^2 = x^3 + 486662 * x^2 + x
    id<MTBignum> y = [context clone:x];
    assert(y != NULL);
    id<MTBignum> coef = [context create];
    [context assignWordTo:coef value:486662];
    [context modAddInto:y a:y b:coef mod:mod];
    [context modMulInto:y a:y b:x mod:mod];
    [context assignOneTo:coef];
    [context modAddInto:y a:y b:coef mod:mod];
    [context modMulInto:y a:y b:x mod:mod];
    return y;
}

static id<MTBignum> get_double_x(id<MTBignum> x, id<MTBignum> mod, id<MTBignumContext> context) {
    // returns x_2 =(x^2 - 1)^2/(4*y^2)
    id<MTBignum> denominator = get_y2(x, mod, context);
    assert(denominator != NULL);
    id<MTBignum> coef = [context create];
    [context assignWordTo:coef value:4];
    [context modMulInto:denominator a:denominator b:coef mod:mod];
    
    id<MTBignum> numerator = [context create];
    assert(numerator != NULL);
    [context modMulInto:numerator a:x b:x mod:mod];
    [context assignOneTo:coef];
    [context modSubInto:numerator a:numerator b:coef mod:mod];
    [context modMulInto:numerator a:numerator b:numerator mod:mod];
    
    [context modInverseInto:denominator a:denominator mod:mod];
    [context modMulInto:numerator a:numerator b:denominator mod:mod];
    
    return numerator;
}

static void generate_public_key(unsigned char key[32], id<EncryptionProvider> provider) {
    id<MTBignumContext> context = [provider createBignumContext];
    assert(context != NULL);
    id<MTBignum> mod = [context create];
    [context assignHexTo:mod value:@"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed"];
    id<MTBignum> pow = [context create];
    [context assignHexTo:pow value:@"3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6"];
    
    id<MTBignum> x = [context create];
    while (1) {
        int randomResult = SecRandomCopyBytes(kSecRandomDefault, 32, key);
        assert(randomResult == errSecSuccess);
        
        key[31] &= 127;
        [context assignBinTo:x value:[NSData dataWithBytesNoCopy:key length:32 freeWhenDone:false]];
        
        [context modMulInto:x a:x b:x mod:mod];
        
        id<MTBignum> y = get_y2(x, mod, context);
        
        id<MTBignum> r = [context create];
        [context modExpInto:r a:y b:pow mod:mod];
        if ([context isOne:r]) {
            break;
        }
    }
    
    int i;
    for (i = 0; i < 3; i++) {
        id<MTBignum> x2 = get_double_x(x, mod, context);
        x = x2;
    }
    
    NSData *xBytes = [context getBin:x];
    
    int num_size = (int)[xBytes length];
    assert(num_size <= 32);
    memset(key, '\0', 32 - num_size);
    [xBytes getBytes:key + (32 - num_size) length:[xBytes length]];
    for (i = 0; i < 16; i++) {
        unsigned char t = key[i];
        key[i] = key[31 - i];
        key[31 - i] = t;
    }
}

/*typedef enum {
    HelloGenerationCommandInvalid = 0,
    HelloGenerationCommandString = 1,
    HelloGenerationCommandZero = 2,
    HelloGenerationCommandRandom = 3,
    HelloGenerationCommandDomain = 4,
    HelloGenerationCommandGrease = 5,
    HelloGenerationCommandKey = 6,
    HelloGenerationCommandPushLengthPosition = 7,
    HelloGenerationCommandPopLengthPosition = 8
} HelloGenerationCommand;

typedef struct {
    int position;
} HelloParseState;

static HelloGenerationCommand parseCommand(NSString *string, HelloParseState *state) {
    if (state->position + 1 >= string.length) {
        return HelloGenerationCommandInvalid;
    }
    unichar c = [string characterAtIndex:state->position];
    state->position += 1;
    
    if (c == 'S') {
        return HelloGenerationCommandString;
    } else if (c == 'Z') {
        return HelloGenerationCommandZero;
    } else if (c == 'R') {
        return HelloGenerationCommandRandom;
    } else if (c == 'D') {
        return HelloGenerationCommandDomain;
    } else if (c == 'G') {
        return HelloGenerationCommandGrease;
    } else if (c == 'K') {
        return HelloGenerationCommandKey;
    } else if (c == '[') {
        return HelloGenerationCommandPushLengthPosition;
    } else if (c == ']') {
        return HelloGenerationCommandPopLengthPosition;
    } else {
        return HelloGenerationCommandInvalid;
    }
}

static bool parseSpace(NSString *string, HelloParseState *state) {
    if (state->position + 1 >= string.length) {
        return false;
    }
    bool hadSpace = false;
    while (true) {
        unichar c = [string characterAtIndex:state->position];
        state->position += 1;
        if (c == ' ') {
            hadSpace = true;
        } else {
            if (hadSpace) {
                return true;
            } else {
                return false;
            }
        }
    }
    return true;
}

static bool parseEndlineOrEnd(NSString *string, HelloParseState *state) {
    if (state->position == string.length) {
        return true;
    } else if (state->position + 1 >= string.length) {
        return false;
    } else {
        unichar c = [string characterAtIndex:state->position];
        state->position += 1;
        return c == '\n';
    }
}

static bool parseHexByte(unichar c, uint8_t *output) {
    if (c >= '0' && c <= '9') {
        *output = (uint8_t)(c - '0');
    } else if (c >= 'a' && c <= 'f') {
        *output = (uint8_t)(c - 'a');
    } else if (c >= 'A' && c <= 'F') {
        *output = (uint8_t)(c - 'A');
    } else {
        return false;
    }
    return true;
}

static NSData *parseHexStringArgument(NSString *string, HelloParseState *state) {
    if (state->position >= string.length) {
        return nil;
    }
    
    NSMutableData *data = [[NSMutableData alloc] init];
    
    while (true) {
        if (state->position == string.length) {
            return data;
        }
        
        unichar c = [string characterAtIndex:state->position];
        state->position += 1;
        if (c == '\\') {
            if (state->position >= string.length) {
                return nil;
            }
            c = [string characterAtIndex:state->position];
            state->position += 1;
            if (c == 'x') {
                if (state->position >= string.length) {
                    return nil;
                }
                unichar d1 = [string characterAtIndex:state->position];
                state->position += 1;
                if (state->position >= string.length) {
                    return nil;
                }
                unichar d0 = [string characterAtIndex:state->position];
                state->position += 1;
                
                uint8_t c1 = 0;
                if (!parseHexByte(d1, &c1)) {
                    return nil;
                }
                uint8_t c0 = 0;
                if (!parseHexByte(d0, &c0)) {
                    return nil;
                }
                uint8_t byteValue = (c1 << 4) | c0;
                [data appendBytes:&byteValue length:1];
            } else {
                return nil;
            }
        } else if (c == '\n') {
            return data;
        } else {
            return nil;
        }
    }
    
    return nil;
}

static bool parseIntArgument(NSString *string, HelloParseState *state, int *output) {
    if (state->position >= string.length) {
        return false;
    }
    int value = 0;
    while (true) {
        if (state->position == string.length) {
            *output = value;
            return true;
        }
        
        unichar c = [string characterAtIndex:state->position];
        state->position += 1;
        
        if (c == '\n') {
            *output = value;
            return true;
        } else if (c >= '0' && c <= '9') {
            value *= 10;
            value += c;
        } else {
            return false;
        }
    }
    return false;
}

static NSData *executeGenerationCode(id<EncryptionProvider> provider, NSData *domain) {
    NSString *code = @"S \"\\x16\\x03\\x01\\x02\\x00\\x01\\x00\\x01\\xfc\\x03\\x03\\n"
    "Z 32"
    "S \"\\x20\"\n"
    "R 32\n"
    "S \"\\x00\\x36\"\n"
    "G 0\n"
    "S \"\\x13\\x01\\x13\\x02\\x13\\x03\\xc0\\x2c\\xc0\\x2b\\xcc\\xa9\\xc0\\x30\\xc0\\x2f\\xcc\\xa8\\xc0\\x24\\xc0\\x23\\xc0\\x0a\\xc0\\x09\\xc0\\x28\\xc0\\x27\\xc0\\x14\\xc0\\x13\\x00\\x9d\\x00\\x9c\\x00\\x3d\\x00\\x3c\\x00\\x35\\x00\\x2f\\xc0\\x08\\xc0\\x12\\x00\\x0a\\x01\\x00\\x01\\x7d\"\n"
    "G 2\n"
    "S \"\\x00\\x00\\x00\\x00\"\n"
    "[\n"
    "[\n"
    "S \"\\x00\"\n"
    "[\n"
    "D\n"
    "]\n"
    "]\n"
    "]\n"
    "S \"\\x00\\x17\\x00\\x00\\xff\\x01\\x00\\x01\\x00\\x00\\x0a\\x00\\x0c\\x00\\x0a\"\n"
    "G 4\n"
    "S \"\\x00\\x1d\\x00\\x17\\x00\\x18\\x00\\x19\\x00\\x0b\\x00\\x02\\x01\\x00\\x00\\x10\\x00\\x0e\\x00\\x0c\\x02\\x68\\x32\\x08\\x68\\x74\\x74\\x70\\x2f\\x31\\x2e\\x31\\x00\\x05\\x00\\x05\\x01\\x00\\x00\\x00\\x00\\x00\\x0d\\x00\\x18\\x00\\x16\\x04\\x03\\x08\\x04\\x04\\x01\\x05\\x03\\x02\\x03\\x08\\x05\\x08\\x05\\x05\\x01\\x08\\x06\\x06\\x01\\x02\\x01\\x00\\x12\\x00\\x00\\x00\\x33\\x00\\x2b\\x00\\x29\"\n"
    "G 4\n"
    "S \"\\x00\\x01\\x00\\x00\\x1d\\x00\\x20\"\n"
    "K\n"
    "S \"\\x00\\x2d\\x00\\x02\\x01\\x01\\x00\\x2b\\x00\\x0b\\x0a\"\n"
    "G 6\n"
    "S \"\\x03\\x04\\x03\\x03\\x03\\x02\\x03\\x01\"\n"
    "G 3\n"
    "S \"\\x00\\x01\\x00\\x00\\x15\"";
    
    int greaseCount = 8;
    NSMutableData *greaseData = [[NSMutableData alloc] initWithLength:greaseCount];
    uint8_t *greaseBytes = (uint8_t *)greaseData.mutableBytes;
    int result;
    result = SecRandomCopyBytes(nil, greaseData.length, greaseData.mutableBytes);
    
    for (int i = 0; i < greaseData.length; i++) {
        uint8_t c = greaseBytes[i];
        c = (c & 0xf0) | 0x0a;
        greaseBytes[i] = c;
    }
    for (int i = 1; i < greaseData.length; i += 2) {
        if (greaseBytes[i] == greaseBytes[i - 1]) {
            greaseBytes[i] &= 0x10;
        }
    }
    
    NSMutableData *resultData = [[NSMutableData alloc] init];
    NSMutableArray<NSNumber *> *lengthStack = [[NSMutableArray alloc] init];
    
    HelloParseState state;
    state.position = 0;
    
    while (true) {
        if (state.position >= code.length) {
            break;
        } else {
            HelloGenerationCommand command = parseCommand(code, &state);
            switch (command) {
                case HelloGenerationCommandString: {
                    if (!parseSpace(code, &state)) {
                        return nil;
                    }
                    NSData *data = parseHexStringArgument(code, &state);
                    if (data == nil) {
                        return nil;
                    }
                    
                    [resultData appendData:data];
                    
                    break;
                }
                case HelloGenerationCommandZero: {
                    if (!parseSpace(code, &state)) {
                        return false;
                    }
                    int zeroLength = 0;
                    if (!parseIntArgument(code, &state, &zeroLength)) {
                        return nil;
                    }
                    
                    NSMutableData *zeroData = [[NSMutableData alloc] initWithLength:zeroLength];
                    [resultData appendData:zeroData];
                    
                    break;
                }
                case HelloGenerationCommandRandom: {
                    if (!parseSpace(code, &state)) {
                        return nil;
                    }
                    int randomLength = 0;
                    if (!parseIntArgument(code, &state, &randomLength)) {
                        return nil;
                    }
                    
                    NSMutableData *randomData = [[NSMutableData alloc] initWithLength:randomLength];
                    int randomResult = SecRandomCopyBytes(kSecRandomDefault, randomLength, randomData.mutableBytes);
                    if (randomResult != errSecSuccess) {
                        return nil;
                    }
                    [resultData appendData:randomData];
                    
                    break;
                }
                case HelloGenerationCommandDomain: {
                    [resultData appendData:domain];
                    if (!parseEndlineOrEnd(code, &state)) {
                        return nil;
                    }
                    break;
                }
                case HelloGenerationCommandGrease: {
                    if (!parseSpace(code, &state)) {
                        return nil;
                    }
                    int greaseIndex = 0;
                    if (!parseIntArgument(code, &state, &greaseIndex)) {
                        return nil;
                    }
                    
                    if (greaseIndex < 0 || greaseIndex >= greaseCount) {
                        return nil;
                    }
                    
                    [resultData appendBytes:&greaseBytes[greaseIndex] length:1];
                    [resultData appendBytes:&greaseBytes[greaseIndex] length:1];
                    
                    break;
                }
                case HelloGenerationCommandKey: {
                    if (!parseEndlineOrEnd(code, &state)) {
                        return nil;
                    }
                    
                    NSMutableData *key = [[NSMutableData alloc] initWithLength:32];
                    generate_public_key(key.mutableBytes, provider);
                    [resultData appendData:key];
                    
                    break;
                }
                case HelloGenerationCommandPushLengthPosition: {
                    if (!parseEndlineOrEnd(code, &state)) {
                        return nil;
                    }
                    
                    [lengthStack addObject:@(resultData.length)];
                    NSMutableData *zeroData = [[NSMutableData alloc] initWithLength:2];
                    [resultData appendData:zeroData];
                    
                    break;
                }
                case HelloGenerationCommandPopLengthPosition: {
                    if (!parseEndlineOrEnd(code, &state)) {
                        return nil;
                    }
                    
                    if (lengthStack.count == 0) {
                        return nil;
                    }
                    
                    int position = [lengthStack[lengthStack.count - 1] intValue];
                    uint16_t calculatedLength = resultData.length - 2 - position;
                    ((uint8_t *)resultData.mutableBytes)[position] = ((uint8_t *)&calculatedLength)[1];
                    ((uint8_t *)resultData.mutableBytes)[position + 1] = ((uint8_t *)&calculatedLength)[0];
                    [lengthStack removeLastObject];
                    
                    break;
                }
                case HelloGenerationCommandInvalid: {
                    return nil;
                }
                default: {
                    return nil;
                }
            }
        }
    }
    
    int paddingLengthPosition = (int)resultData.length;
    [lengthStack addObject:@(resultData.length)];
    NSMutableData *zeroData = [[NSMutableData alloc] initWithLength:2];
    [resultData appendData:zeroData];
    
    while (resultData.length < 517) {
        uint8_t zero = 0;
        [resultData appendBytes:&zero length:1];
    }
    
    uint16_t calculatedLength = resultData.length - 2 - paddingLengthPosition;
    ((uint8_t *)resultData.mutableBytes)[paddingLengthPosition] = ((uint8_t *)&calculatedLength)[1];
    ((uint8_t *)resultData.mutableBytes)[paddingLengthPosition + 1] = ((uint8_t *)&calculatedLength)[0];
    
    return resultData;
}*/

@interface MTTcpConnectionData : NSObject

@property (nonatomic, strong, readonly) NSString *ip;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, readonly) bool isSocks;

@end

@implementation MTTcpConnectionData

- (instancetype)initWithIp:(NSString *)ip port:(int32_t)port isSocks:(bool)isSocks {
    self = [super init];
    if (self != nil) {
        _ip = ip;
        _port = port;
        _isSocks = isSocks;
    }
    return self;
}

@end

MTInternalIdClass(MTTcpConnection)

struct socks5_ident_req
{
    unsigned char Version;
    unsigned char NumberOfMethods;
    unsigned char Methods[256];
};

struct socks5_ident_resp
{
    unsigned char Version;
    unsigned char Method;
};

struct socks5_req
{
    unsigned char Version;
    unsigned char Cmd;
    unsigned char Reserved;
    unsigned char AddrType;
    union {
        struct in_addr IPv4;
        struct in6_addr IPv6;
        struct {
            unsigned char DomainLen;
            char Domain[256];
        };
    } DestAddr;
    unsigned short DestPort;
};

struct socks5_resp
{
    unsigned char Version;
    unsigned char Reply;
    unsigned char Reserved;
    unsigned char AddrType;
    union {
        struct in_addr IPv4;
        struct in6_addr IPv6;
        struct {
            unsigned char DomainLen;
            char Domain[256];
        };
    } BindAddr;
    unsigned short BindPort;
};

typedef enum {
    MTTcpReadTagPacketShortLength,
    MTTcpReadTagPacketLongLength,
    MTTcpReadTagPacketFullLength,
    MTTcpReadTagPacketBody,
    MTTcpReadTagPacketHead,
    MTTcpReadTagQuickAck,
    MTTcpReadTagFullQuickAck,
    MTTcpSocksLogin,
    MTTcpSocksRequest,
    MTTcpSocksReceiveBindAddr4,
    MTTcpSocksReceiveBindAddr6,
    MTTcpSocksReceiveBindAddrDomainNameLength,
    MTTcpSocksReceiveBindAddrDomainName,
    MTTcpSocksReceiveBindAddrPort,
    MTTcpSocksReceiveAuthResponse,
    MTTcpSocksReceiveHelloResponse,
    MTTcpSocksReceiveHelloResponse1,
    MTTcpSocksReceiveHelloResponse2,
    MTTcpSocksReceivePassthrough,
    MTTcpSocksReceiveComplexLength,
    MTTcpSocksReceiveComplexPacketPart
} MTTcpReadTags;

static const NSTimeInterval MTMinTcpResponseTimeout = 12.0;
static const NSUInteger MTTcpProgressCalculationThreshold = 4096;

struct ctr_state {
    unsigned char ivec[16];  /* ivec[0..7] is the IV, ivec[8..15] is the big-endian counter */
    unsigned int num;
    unsigned char ecount[16];
};

@interface MTTcpSendData : NSObject

@property (nonatomic, strong, readonly) NSArray<NSData *> *dataSet;
@property (nonatomic, copy, readonly) void (^completion)(bool success);
@property (nonatomic, readonly) bool requestQuickAck;
@property (nonatomic, readonly) bool expectDataInResponse;

@end

@implementation MTTcpSendData

- (instancetype)initWithDataSet:(NSArray *)dataSet completion:(void (^)(bool success))completion requestQuickAck:(bool)requestQuickAck expectDataInResponse:(bool)expectDataInResponse {
    self = [super init];
    if (self != nil) {
        _dataSet = dataSet;
        _completion = [completion copy];
        _requestQuickAck = requestQuickAck;
        _expectDataInResponse = expectDataInResponse;
    }
    return self;
}

@end

@interface MTTcpReceiveData : NSObject

@property (nonatomic, readonly) int tag;
@property (nonatomic, readonly) int length;

@end

@implementation MTTcpReceiveData

- (instancetype)initWithTag:(int)tag length:(int)length {
    self = [super init];
    if (self != nil) {
        _tag = tag;
        _length = length;
    }
    return self;
}

@end

@interface MTTcpConnection () <GCDAsyncSocketDelegate>
{
    id<EncryptionProvider> _encryptionProvider;
    
    GCDAsyncSocket *_socket;
    bool _closed;
    
    bool _useIntermediateFormat;
    
    int32_t _datacenterTag;
    
    uint8_t _quickAckByte;
    
    MTTimer *_responseTimeoutTimer;
    
    bool _readingPartialData;
    NSData *_packetHead;
    NSUInteger _packetRestLength;
    NSUInteger _packetRestReceivedLength;
    
    bool _delegateImplementsProgressUpdated;
    NSData *_firstPacketControlByte;
    
    bool _addedControlHeader;
    bool _addedHelloHeader;
    
    MTAesCtr *_outgoingAesCtr;
    MTAesCtr *_incomingAesCtr;
    
    MTNetworkUsageCalculationInfo *_usageCalculationInfo;
    
    NSString *_socksIp;
    int32_t _socksPort;
    NSString *_socksUsername;
    NSString *_socksPassword;
    
    NSString *_mtpIp;
    int32_t _mtpPort;
    MTProxySecret *_mtpSecret;
    NSData *_helloRandom;
    NSData *_currentHelloResponse;
    
    MTMetaDisposable *_resolveDisposable;
    
    bool _readyToSendData;
    NSMutableArray<MTTcpSendData *> *_pendingDataQueue;
    NSMutableData *_receivedDataBuffer;
    MTTcpReceiveData *_pendingReceiveData;
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

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId scheme:(MTTransportScheme *)scheme interface:(NSString *)interface usageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo getLogPrefix:(NSString *(^)())getLogPrefix
{
#ifdef DEBUG
    NSAssert(scheme != nil, @"scheme should not be nil");
#endif
    
    self = [super init];
    if (self != nil)
    {
        _internalId = [[MTInternalId(MTTcpConnection) alloc] init];
        
        _getLogPrefix = [getLogPrefix copy];
        
        _encryptionProvider = context.encryptionProvider;
        
        _scheme = scheme;
        
        _interface = interface;
        _usageCalculationInfo = usageCalculationInfo;
        
        if (context.apiEnvironment.datacenterAddressOverrides[@(datacenterId)] != nil) {
            _firstPacketControlByte = [context.apiEnvironment tcpPayloadPrefix];
        }
        
        if (_scheme.address.secret != nil) {
            _mtpIp = _scheme.address.ip;
            _mtpPort = _scheme.address.port;
            _mtpSecret = [MTProxySecret parseData:_scheme.address.secret];
        }
        if (context.apiEnvironment.socksProxySettings != nil) {
            if (context.apiEnvironment.socksProxySettings.secret != nil) {
                _mtpIp = context.apiEnvironment.socksProxySettings.ip;
                _mtpPort = context.apiEnvironment.socksProxySettings.port;
                _mtpSecret = [MTProxySecret parseData:context.apiEnvironment.socksProxySettings.secret];
            } else {
                _socksIp = context.apiEnvironment.socksProxySettings.ip;
                _socksPort = context.apiEnvironment.socksProxySettings.port;
                _socksUsername = context.apiEnvironment.socksProxySettings.username;
                _socksPassword = context.apiEnvironment.socksProxySettings.password;
            }
        }
        
        if (_mtpSecret != nil) {
            if ([_mtpSecret isKindOfClass:[MTProxySecretType1 class]] || [_mtpSecret isKindOfClass:[MTProxySecretType2 class]]) {
                _useIntermediateFormat = true;
            }
        }
        
        _resolveDisposable = [[MTMetaDisposable alloc] init];
        
        if (context.isTestingEnvironment) {
            if (scheme.address.preferForMedia) {
                _datacenterTag = -(int32_t)(10000 + datacenterId);
            } else {
                _datacenterTag = (int32_t)(10000 + datacenterId);
            }
        } else {
            if (scheme.address.preferForMedia) {
                _datacenterTag = -(int32_t)datacenterId;
            } else {
                _datacenterTag = (int32_t)datacenterId;
            }
        }
        
        _pendingDataQueue = [[NSMutableArray alloc] init];
        _receivedDataBuffer = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)dealloc
{
    GCDAsyncSocket *socket = _socket;
    socket.delegate = nil;
    _socket = nil;
    
    MTTimer *responseTimeoutTimer = _responseTimeoutTimer;
    
    MTMetaDisposable *resolveDisposable = _resolveDisposable;
    
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        [responseTimeoutTimer invalidate];
        
        [socket disconnect];
        [resolveDisposable dispose];
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
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^{
        _delegate = delegate;
        
        _delegateImplementsProgressUpdated = [delegate respondsToSelector:@selector(tcpConnectionProgressUpdated:packetProgressToken:packetLength:progress:)];
    }];
}

- (void)start
{
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        if (_socket == nil)
        {
            _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:[[MTTcpConnection tcpQueue] nativeQueue]];
            _socket.getLogPrefix = _getLogPrefix;
            _socket.usageCalculationInfo = _usageCalculationInfo;
            
            NSString *addressIp = _scheme.address.ip;
            MTSignal *resolveSignal = [MTSignal single:[[MTTcpConnectionData alloc] initWithIp:addressIp port:_scheme.address.port isSocks:false]];
            
            if (_socksIp != nil) {
                bool isHostname = true;
                struct in_addr ip4;
                struct in6_addr ip6;
                if (inet_aton(_socksIp.UTF8String, &ip4) != 0) {
                    isHostname = false;
                } else if (inet_pton(AF_INET6, _socksIp.UTF8String, &ip6) != 0) {
                    isHostname = false;
                }
                
                if (isHostname) {
                    int32_t port = _socksPort;
                    resolveSignal = [[MTDNS resolveHostnameUniversal:_socksIp port:port] map:^id(NSString *resolvedIp) {
                        return [[MTTcpConnectionData alloc] initWithIp:resolvedIp port:port isSocks:true];
                    }];
                } else {
                    resolveSignal = [MTSignal single:[[MTTcpConnectionData alloc] initWithIp:_socksIp port:_socksPort isSocks:true]];
                }
            } else if (_mtpIp != nil) {
                bool isHostname = true;
                struct in_addr ip4;
                struct in6_addr ip6;
                if (inet_aton(_mtpIp.UTF8String, &ip4) != 0) {
                    isHostname = false;
                } else if (inet_pton(AF_INET6, _mtpIp.UTF8String, &ip6) != 0) {
                    isHostname = false;
                }
                
                if (isHostname) {
                    int32_t port = _mtpPort;
                    resolveSignal = [[MTDNS resolveHostnameUniversal:_mtpIp port:port] map:^id(NSString *resolvedIp) {
                        return [[MTTcpConnectionData alloc] initWithIp:resolvedIp port:port isSocks:false];
                    }];
                } else {
                    resolveSignal = [MTSignal single:[[MTTcpConnectionData alloc] initWithIp:_mtpIp port:_mtpPort isSocks:false]];
                }
            }
            
            __weak MTTcpConnection *weakSelf = self;
            [_resolveDisposable setDisposable:[resolveSignal startWithNext:^(MTTcpConnectionData *connectionData) {
                [[MTTcpConnection tcpQueue] dispatchOnQueue:^{
                    __strong MTTcpConnection *strongSelf = weakSelf;
                    if (strongSelf == nil || connectionData == nil) {
                        return;
                    }
                    if (![connectionData.ip respondsToSelector:@selector(characterAtIndex:)]) {
                        return;
                    }
                    
                    if (connectionData.isSocks) {
                        strongSelf->_socksIp = connectionData.ip;
                        strongSelf->_socksPort = connectionData.port;
                    }
                    
                    if (MTLogEnabled()) {
                        if (strongSelf->_socksIp != nil) {
                            if (strongSelf->_socksUsername.length == 0) {
                                MTLog(@"[MTTcpConnection#%" PRIxPTR " connecting to %@:%d via %@:%d]", (intptr_t)strongSelf, strongSelf->_scheme.address.ip, (int)strongSelf->_scheme.address.port, strongSelf->_socksIp, (int)strongSelf->_socksPort);
                            } else {
                                MTLog(@"[MTTcpConnection#%" PRIxPTR " connecting to %@:%d via %@:%d using %@:%@]", (intptr_t)strongSelf, strongSelf->_scheme.address.ip, (int)strongSelf->_scheme.address.port, strongSelf->_socksIp, (int)strongSelf->_socksPort, strongSelf->_socksUsername, strongSelf->_socksPassword);
                            }
                        } else if (strongSelf->_mtpIp != nil) {
                            MTLog(@"[MTTcpConnection#%" PRIxPTR " connecting to %@:%d via mtp://%@:%d:%@]", (intptr_t)strongSelf, strongSelf->_scheme.address.ip, (int)strongSelf->_scheme.address.port, strongSelf->_mtpIp, (int)strongSelf->_mtpPort, strongSelf->_mtpSecret);
                        } else {
                            MTLog(@"[MTTcpConnection#%" PRIxPTR " connecting to %@:%d]", (intptr_t)strongSelf, strongSelf->_scheme.address.ip, (int)strongSelf->_scheme.address.port);
                        }
                    }
                    
                    __autoreleasing NSError *error = nil;
                    if (![strongSelf->_socket connectToHost:connectionData.ip onPort:connectionData.port viaInterface:strongSelf->_interface withTimeout:12 error:&error] || error != nil) {
                        [strongSelf closeAndNotifyWithError:true];
                    } else if (strongSelf->_socksIp == nil) {
                        if (strongSelf->_mtpIp != nil && [strongSelf->_mtpSecret isKindOfClass:[MTProxySecretType2 class]]) {
                            MTProxySecretType2 *secret = (MTProxySecretType2 *)(strongSelf->_mtpSecret);
                            
                            int greaseCount = 8;
                            NSMutableData *greaseData = [[NSMutableData alloc] initWithLength:greaseCount];
                            uint8_t *greaseBytes = (uint8_t *)greaseData.mutableBytes;
                            int result = SecRandomCopyBytes(nil, greaseData.length, greaseData.mutableBytes);
                            if (result != errSecSuccess) {
                                assert(false);
                            }
                            
                            for (int i = 0; i < greaseData.length; i++) {
                                uint8_t c = greaseBytes[i];
                                c = (c & 0xf0) | 0x0a;
                                greaseBytes[i] = c;
                            }
                            for (int i = 1; i < greaseData.length; i += 2) {
                                if (greaseBytes[i] == greaseBytes[i - 1]) {
                                    greaseBytes[i] &= 0x10;
                                }
                            }
                            
                            NSMutableData *helloData = [[NSMutableData alloc] init];
                            
                            uint8_t s1[11] = { 0x16, 0x03, 0x01, 0x02, 0x00, 0x01, 0x00, 0x01, 0xfc, 0x03, 0x03 };
                            [helloData appendBytes:s1 length:11];
                            
                            for (int i = 0; i < 32; i++) {
                                uint8_t zero = 0;
                                [helloData appendBytes:&zero length:1];
                            }
                            
                            uint8_t s2[1] = { 0x20 };
                            [helloData appendBytes:s2 length:1];
                            
                            uint8_t r1[32];
                            result = SecRandomCopyBytes(nil, 32, r1);
                            assert(result == errSecSuccess);
                            [helloData appendBytes:r1 length:32];
                            
                            uint8_t s0[65] = { 0x00, 0x34, 0x13, 0x03, 0x13, 0x01, 0x13, 0x02, 0xc0, 0x2c, 0xc0, 0x2b, 0xc0, 0x24, 0xc0, 0x23, 0xc0, 0x0a, 0xc0, 0x09, 0xcc, 0xa9, 0xc0, 0x30, 0xc0, 0x2f, 0xc0, 0x28, 0xc0, 0x27, 0xc0, 0x14, 0xc0, 0x13, 0xcc, 0xa8, 0x00, 0x9d, 0x00, 0x9c, 0x00, 0x3d, 0x00, 0x3c, 0x00, 0x35, 0x00, 0x2f, 0xc0, 0x08, 0xc0, 0x12, 0x00, 0x0a, 0x01, 0x00, 0x01, 0x7f, 0xff, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00 };
                            [helloData appendBytes:s0 length:65];
                            
                            uint8_t stackZ[2] = { 0x00, 0x00 };
                            
                            int stack1 = (int)helloData.length;
                            [helloData appendBytes:stackZ length:2];
                            
                            int stack2 = (int)helloData.length;
                            [helloData appendBytes:stackZ length:2];
                            
                            uint8_t s5[1] = { 0x00 };
                            [helloData appendBytes:s5 length:1];
                            
                            int stack3 = (int)helloData.length;
                            [helloData appendBytes:stackZ length:2];
                            
                            NSString *d1 = secret.domain;
                            [helloData appendData:[d1 dataUsingEncoding:NSUTF8StringEncoding]];
                            
                            int16_t stack3Value = (int16_t)(helloData.length - stack3 - 2);
                            stack3Value = OSSwapInt16(stack3Value);
                            memcpy(((uint8_t *)helloData.mutableBytes) + stack3, &stack3Value, 2);
                            
                            int16_t stack2Value = (int16_t)(helloData.length - stack2 - 2);
                            stack2Value = OSSwapInt16(stack2Value);
                            memcpy(((uint8_t *)helloData.mutableBytes) + stack2, &stack2Value, 2);
                            
                            int16_t stack1Value = (int16_t)(helloData.length - stack1 - 2);
                            stack1Value = OSSwapInt16(stack1Value);
                            memcpy(((uint8_t *)helloData.mutableBytes) + stack1, &stack1Value, 2);
                            
                            uint8_t s6[117] = { 0x00, 0x17, 0x00, 0x00, 0x00, 0x0d, 0x00, 0x18, 0x00, 0x16, 0x04, 0x03, 0x08, 0x04, 0x04, 0x01, 0x05, 0x03, 0x02, 0x03, 0x08, 0x05, 0x08, 0x05, 0x05, 0x01, 0x08, 0x06, 0x06, 0x01, 0x02, 0x01, 0x00, 0x05, 0x00, 0x05, 0x01, 0x00, 0x00, 0x00, 0x00, 0x33, 0x74, 0x00, 0x00, 0x00, 0x12, 0x00, 0x00, 0x00, 0x10, 0x00, 0x30, 0x00, 0x2e, 0x02, 0x68, 0x32, 0x05, 0x68, 0x32, 0x2d, 0x31, 0x36, 0x05, 0x68, 0x32, 0x2d, 0x31, 0x35, 0x05, 0x68, 0x32, 0x2d, 0x31, 0x34, 0x08, 0x73, 0x70, 0x64, 0x79, 0x2f, 0x33, 0x2e, 0x31, 0x06, 0x73, 0x70, 0x64, 0x79, 0x2f, 0x33, 0x08, 0x68, 0x74, 0x74, 0x70, 0x2f, 0x31, 0x2e, 0x31, 0x00, 0x0b, 0x00, 0x02, 0x01, 0x00, 0x00, 0x33, 0x00, 0x26, 0x00, 0x24, 0x00, 0x1d, 0x00, 0x20 };
                            [helloData appendBytes:s6 length:117];
                            
                            uint8_t r2[32];
                            generate_public_key(r2, strongSelf->_encryptionProvider);
                            
                            [helloData appendBytes:r2 length:32];
                            
                            uint8_t s9[35] = { 0x00, 0x2d, 0x00, 0x02, 0x01, 0x01, 0x00, 0x2b, 0x00, 0x09, 0x08, 0x03, 0x04, 0x03, 0x03, 0x03, 0x02, 0x03, 0x01, 0x00, 0x0a, 0x00, 0x0a, 0x00, 0x08, 0x00, 0x1d, 0x00, 0x17, 0x00, 0x18, 0x00, 0x19, 0x00, 0x15 };
                            [helloData appendBytes:s9 length:35];
                            
                            int stack4 = (int)helloData.length;
                            [helloData appendBytes:stackZ length:2];
                            
                            while (helloData.length < 517) {
                                uint8_t zero = 0;
                                [helloData appendBytes:&zero length:1];
                            }
                            
                            int16_t stack4Value = (int16_t)(helloData.length - stack4 - 2);
                            stack4Value = OSSwapInt16(stack4Value);
                            memcpy(((uint8_t *)helloData.mutableBytes) + stack4, &stack4Value, 2);
                            
                            NSData *effectiveSecret = strongSelf->_mtpSecret.secret;
                            uint8_t cHMAC[CC_SHA256_DIGEST_LENGTH];
                            CCHmac(kCCHmacAlgSHA256, effectiveSecret.bytes, effectiveSecret.length, helloData.bytes, helloData.length, cHMAC);
                            int32_t timestamp = (int32_t)[[NSDate date] timeIntervalSince1970] + [MTContext fixedTimeDifference];
                            uint8_t *timestampValue = (uint8_t *)&timestamp;
                            for (int i = 0; i < 4; i++) {
                                cHMAC[CC_SHA256_DIGEST_LENGTH - 4 + i] ^= timestampValue[i];
                            }
                            _helloRandom = [[NSData alloc] initWithBytes:cHMAC length:32];
                            memcpy(((uint8_t *)helloData.mutableBytes) + 11, cHMAC, 32);
                            
                            [strongSelf->_socket writeData:helloData withTimeout:-1 tag:0];
                            [strongSelf->_socket readDataToLength:5 withTimeout:-1 tag:MTTcpSocksReceiveHelloResponse];
                        } else {
                            strongSelf->_readyToSendData = true;
                            [strongSelf sendDataIfNeeded];
                            if (strongSelf->_useIntermediateFormat) {
                                [strongSelf requestReadDataWithLength:4 tag:MTTcpReadTagPacketFullLength];
                            } else {
                                [strongSelf requestReadDataWithLength:1 tag:MTTcpReadTagPacketShortLength];
                            }
                        }
                    } else {
                        struct socks5_ident_req req;
                        req.Version = 5;
                        req.NumberOfMethods = 1;
                        req.Methods[0] = 0x00;
                        
                        if (strongSelf->_socksUsername != nil) {
                            req.NumberOfMethods += 1;
                            req.Methods[1] = 0x02;
                        }
                        [strongSelf->_socket writeData:[NSData dataWithBytes:&req length:2 + req.NumberOfMethods] withTimeout:-1 tag:0];
                        [strongSelf->_socket readDataToLength:sizeof(struct socks5_ident_resp) withTimeout:-1 tag:MTTcpSocksLogin];
                    }
                }];
            }]];
        }
    }];
}

- (void)stop
{
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^
    {
        if (!_closed)
            [self closeAndNotifyWithError:false];
    }];
}

- (void)closeAndNotifyWithError:(bool)error
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
            if ([delegate respondsToSelector:@selector(tcpConnectionClosed:error:)])
                [delegate tcpConnectionClosed:self error:error];
        }
    }];
}

- (void)sendDataIfNeeded {
    while (_pendingDataQueue.count != 0) {
        MTTcpSendData *dataToSend = _pendingDataQueue[0];
        [_pendingDataQueue removeObjectAtIndex:0];
        
        if (!_closed) {
            if (_socket != nil) {
                NSUInteger completeDataLength = 0;
                
                NSMutableData *completeData = [[NSMutableData alloc] init];
                
                for (NSData *data in dataToSend.dataSet) {
                    NSMutableData *packetData = [[NSMutableData alloc] initWithCapacity:data.length + 8];
                    
                    uint8_t padding[16];
                    uint32_t paddingSize = 0;
                    
                    if (_useIntermediateFormat) {
                        int32_t length = (int32_t)data.length;
                        
                        paddingSize = arc4random_uniform(16);
                        if (paddingSize != 0) {
                            arc4random_buf(padding, paddingSize);
                        }
                        length += (int32_t)paddingSize;
                        
                        if (dataToSend.requestQuickAck) {
                            length |= 0x80000000;
                        }
                        [packetData appendBytes:&length length:4];
                    } else {
                        int32_t quarterLength = (int32_t)(data.length / 4);
                        
                        if (quarterLength <= 0x7e) {
                            uint8_t quarterLengthMarker = (uint8_t)quarterLength;
                            if (dataToSend.requestQuickAck) {
                                quarterLengthMarker |= 0x80;
                            }
                            [packetData appendBytes:&quarterLengthMarker length:1];
                        } else {
                            uint8_t quarterLengthMarker = 0x7f;
                            if (dataToSend.requestQuickAck) {
                                quarterLengthMarker |= 0x80;
                            }
                            [packetData appendBytes:&quarterLengthMarker length:1];
                            [packetData appendBytes:((uint8_t *)&quarterLength) length:3];
                        }
                    }
                    
                    [packetData appendData:data];
                    
                    if (paddingSize != 0) {
                        [packetData appendBytes:padding length:paddingSize];
                    }
                    
                    completeDataLength += packetData.length;
                    
                    if (!_addedControlHeader) {
                        _addedControlHeader = true;
                        for (int retryCount = 0; retryCount < 10; retryCount++) {
                            uint8_t controlBytes[64];
                            arc4random_buf(controlBytes, 64);
                            
                            int32_t controlVersion;
                            if (_useIntermediateFormat) {
                                controlVersion = 0xdddddddd;
                            } else {
                                controlVersion = 0xefefefef;
                            }
                            
                            memcpy(controlBytes + 56, &controlVersion, 4);
                            int16_t datacenterTag = (int16_t)_datacenterTag;
                            memcpy(controlBytes + 60, &datacenterTag, 2);
                            
                            uint8_t controlBytesReversed[64];
                            for (int i = 0; i < 64; i++) {
                                controlBytesReversed[i] = controlBytes[64 - 1 - i];
                            }
                            
                            NSData *aesKey = [[NSData alloc] initWithBytes:controlBytes + 8 length:32];
                            NSData *aesIv = [[NSData alloc] initWithBytes:controlBytes + 8 + 32 length:16];
                            
                            NSData *incomingAesKey = [[NSData alloc] initWithBytes:controlBytesReversed + 8 length:32];
                            NSData *incomingAesIv = [[NSData alloc] initWithBytes:controlBytesReversed + 8 + 32 length:16];
                            
                            NSData *effectiveSecret = nil;
                            if (_mtpSecret != nil) {
                                effectiveSecret = _mtpSecret.secret;
                            }
                            if (effectiveSecret.length != 16 && effectiveSecret.length != 17) {
                                effectiveSecret = nil;
                            }
                            
                            if (effectiveSecret) {
                                NSMutableData *aesKeyData = [[NSMutableData alloc] init];
                                [aesKeyData appendData:aesKey];
                                if (effectiveSecret.length == 16) {
                                    [aesKeyData appendData:effectiveSecret];
                                } else if (effectiveSecret.length == 17) {
                                    [aesKeyData appendData:[effectiveSecret subdataWithRange:NSMakeRange(1, effectiveSecret.length - 1)]];
                                }
                                NSData *aesKeyHash = MTSha256(aesKeyData);
                                aesKey = [aesKeyHash subdataWithRange:NSMakeRange(0, 32)];
                                
                                NSMutableData *incomingAesKeyData = [[NSMutableData alloc] init];
                                [incomingAesKeyData appendData:incomingAesKey];
                                if (effectiveSecret.length == 16) {
                                    [incomingAesKeyData appendData:effectiveSecret];
                                } else if (effectiveSecret.length == 17) {
                                    [incomingAesKeyData appendData:[effectiveSecret subdataWithRange:NSMakeRange(1, effectiveSecret.length - 1)]];
                                }
                                NSData *incomingAesKeyHash = MTSha256(incomingAesKeyData);
                                incomingAesKey = [incomingAesKeyHash subdataWithRange:NSMakeRange(0, 32)];
                            }
                            
                            MTAesCtr *outgoingAesCtr = [[MTAesCtr alloc] initWithKey:aesKey.bytes keyLength:32 iv:aesIv.bytes decrypt:false];
                            MTAesCtr *incomingAesCtr = [[MTAesCtr alloc] initWithKey:incomingAesKey.bytes keyLength:32 iv:incomingAesIv.bytes decrypt:false];
                            
                            uint8_t encryptedControlBytes[64];
                            [outgoingAesCtr encryptIn:controlBytes out:encryptedControlBytes len:64];
                            
                            uint32_t intHeader = 0;
                            memcpy(&intHeader, encryptedControlBytes, 4);
                            
                            if (effectiveSecret) {
                                if (retryCount == 9) {
                                    assert(false);
                                } else {
                                    if (intHeader == 0x44414548 ||
                                        intHeader == 0x54534f50 ||
                                        intHeader == 0x20544547 ||
                                        intHeader == 0x4954504f ||
                                        intHeader == 0xdddddddd ||
                                        intHeader == 0xeeeeeeee ||
                                        intHeader == 0x02010316) {
                                        continue;
                                    }
                                }
                            }
                            
                            NSMutableData *outData = [[NSMutableData alloc] initWithLength:64 + packetData.length];
                            memcpy(outData.mutableBytes, controlBytes, 56);
                            memcpy(outData.mutableBytes + 56, encryptedControlBytes + 56, 8);
                            
                            [outgoingAesCtr encryptIn:packetData.bytes out:outData.mutableBytes + 64 len:packetData.length];
                            
                            _incomingAesCtr = incomingAesCtr;
                            _outgoingAesCtr = outgoingAesCtr;
                            [completeData appendData:outData];
                            
                            break;
                        }
                    } else {
                        NSMutableData *encryptedData = [[NSMutableData alloc] initWithLength:packetData.length];
                        [_outgoingAesCtr encryptIn:packetData.bytes out:encryptedData.mutableBytes len:packetData.length];
                        
                        [completeData appendData:encryptedData];
                    }
                    
                    if ([_mtpSecret isKindOfClass:[MTProxySecretType2 class]]) {
                        NSMutableData *partitionedCompleteData = [[NSMutableData alloc] init];
                        if (!_addedHelloHeader) {
                            _addedHelloHeader = true;
                            uint8_t helloHeader[6] = { 0x14, 0x03, 0x03, 0x00, 0x01, 0x01 };
                            [partitionedCompleteData appendData:[[NSData alloc] initWithBytes:helloHeader length:6]];
                        }
                        
                        NSUInteger limit = 2878;
                        NSUInteger offset = 0;
                        while (offset < completeData.length) {
                            NSUInteger partLength = MIN(limit, completeData.length - offset);
                            
                            uint8_t packetHeader[5] = { 0x17, 0x03, 0x03, 0x00, 0x00 };
                            int16_t lengthValue = (int16_t)partLength;
                            lengthValue = OSSwapInt16(lengthValue);
                            memcpy(&packetHeader[3], &lengthValue, 2);
                            
                            [partitionedCompleteData appendData:[[NSData alloc] initWithBytes:packetHeader length:5]];
                            [partitionedCompleteData appendData:[completeData subdataWithRange:NSMakeRange(offset, partLength)]];
                            
                            offset += partLength;
                        }
                        [_socket writeData:partitionedCompleteData withTimeout:-1 tag:0];
                    } else {
                        [_socket writeData:completeData withTimeout:-1 tag:0];
                    }
                }
                
                if (dataToSend.expectDataInResponse && _responseTimeoutTimer == nil) {
                    __weak MTTcpConnection *weakSelf = self;
                    _responseTimeoutTimer = [[MTTimer alloc] initWithTimeout:MTMinTcpResponseTimeout + completeDataLength / (12.0 * 1024) repeat:false completion:^{
                        __strong MTTcpConnection *strongSelf = weakSelf;
                        [strongSelf responseTimeout];
                    } queue:[MTTcpConnection tcpQueue].nativeQueue];
                    [_responseTimeoutTimer start];
                }
                
                if (dataToSend.completion) {
                    dataToSend.completion(true);
                }
            } else {
                if (MTLogEnabled()) {
                    MTLog(@"***** %s: can't send data: connection is not opened", __PRETTY_FUNCTION__);
                }
                
                if (dataToSend.completion) {
                    dataToSend.completion(false);
                }
            }
        } else {
            if (dataToSend.completion) {
                dataToSend.completion(false);
            }
        }
    }
}

- (void)sendDatas:(NSArray *)datas completion:(void (^)(bool success))completion requestQuickAck:(bool)requestQuickAck expectDataInResponse:(bool)expectDataInResponse
{
    if (datas.count == 0)
    {
        completion(false);
        return;
    }
    
    [[MTTcpConnection tcpQueue] dispatchOnQueue:^{
        [_pendingDataQueue addObject:[[MTTcpSendData alloc] initWithDataSet:datas completion:completion requestQuickAck:requestQuickAck expectDataInResponse:expectDataInResponse]];
        if (_readyToSendData) {
            [self sendDataIfNeeded];
        }
    }];
}

- (void)responseTimeout
{
    [_responseTimeoutTimer invalidate];
    _responseTimeoutTimer = nil;
    
    if (MTLogEnabled()) {
        MTLog(@"[MTTcpConnection#%" PRIxPTR " response timeout]", (intptr_t)self);
    }
    [self closeAndNotifyWithError:true];
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

- (void)requestSocksConnection {
    struct socks5_req req;
    
    req.Version = 5;
    req.Cmd = 1;
    req.Reserved = 0;
    req.AddrType = 1;
    
    struct in_addr ip4;
    inet_aton(_scheme.address.ip.UTF8String, &ip4);
    req.DestAddr.IPv4 = ip4;
    req.DestPort = _scheme.address.port;
    
    NSMutableData *reqData = [[NSMutableData alloc] init];
    [reqData appendBytes:&req length:4];
    
    switch (req.AddrType) {
        case 1: {
            [reqData appendBytes:&req.DestAddr.IPv4 length:sizeof(struct in_addr)];
            break;
        }
        case 3: {
            [reqData appendBytes:&req.DestAddr.DomainLen length:1];
            [reqData appendBytes:&req.DestAddr.Domain length:req.DestAddr.DomainLen];
            break;
        }
        case 4: {
            [reqData appendBytes:&req.DestAddr.IPv6 length:sizeof(struct in6_addr)];
            break;
        }
        default: {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks request address type", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
    }
    
    unsigned short port = htons(req.DestPort);
    [reqData appendBytes:&port length:2];
    
    [_socket writeData:reqData withTimeout:-1 tag:0];
    [_socket readDataToLength:4 withTimeout:-1 tag:MTTcpSocksRequest];
}

- (void)socket:(GCDAsyncSocket *)__unused socket didReadData:(NSData *)rawData withTag:(long)tag
{
    if (_closed)
        return;
    
    if (tag == MTTcpSocksLogin) {
        if (rawData.length != sizeof(struct socks5_ident_resp)) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks5 login response length", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        struct socks5_ident_resp resp;
        [rawData getBytes:&resp length:sizeof(struct socks5_ident_resp)];
        if (resp.Version != 5) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks response version", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        if (resp.Method == 0xFF)
        {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks response method", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        if (resp.Method == 0x02) {
            NSMutableData *reqData = [[NSMutableData alloc] init];
            uint8_t version = 1;
            [reqData appendBytes:&version length:1];
            
            NSData *usernameData = [_socksUsername dataUsingEncoding:NSUTF8StringEncoding];
            NSData *passwordData = [_socksPassword dataUsingEncoding:NSUTF8StringEncoding];
            
            uint8_t usernameLength = (uint8_t)(MIN(usernameData.length, 255));
            [reqData appendBytes:&usernameLength length:1];
            [reqData appendData:usernameData];
            
            uint8_t passwordLength = (uint8_t)(MIN(passwordData.length, 255));
            [reqData appendBytes:&passwordLength length:1];
            [reqData appendData:passwordData];
            
            [_socket writeData:reqData withTimeout:-1 tag:0];
            [_socket readDataToLength:2 withTimeout:-1 tag:MTTcpSocksReceiveAuthResponse];
        } else {
            [self requestSocksConnection];
        }
        
        return;
    } else if (tag == MTTcpSocksRequest) {
        struct socks5_resp resp;
        if (rawData.length != 4) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks5 response length", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        [rawData getBytes:&resp length:4];
        
        if (resp.Reply != 0x00) {
            if (MTLogEnabled()) {
                MTLog(@"***** " PRIxPTR " %s: socks5 connect failed, error 0x%02x", (intptr_t)self, __PRETTY_FUNCTION__, resp.Reply);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        switch (resp.AddrType) {
            case 1: {
                [_socket readDataToLength:sizeof(struct in_addr) withTimeout:-1 tag:MTTcpSocksReceiveBindAddr4];
                break;
            }
            case 3: {
                [_socket readDataToLength:1 withTimeout:-1 tag:MTTcpSocksReceiveBindAddrDomainNameLength];
                break;
            }
            case 4: {
                [_socket readDataToLength:sizeof(struct in6_addr) withTimeout:-1 tag:MTTcpSocksReceiveBindAddr6];
                break;
            }
            default: {
                if (MTLogEnabled()) {
                    MTLog(@"***** %s: socks bound to unknown address type", __PRETTY_FUNCTION__);
                }
                [self closeAndNotifyWithError:true];
                return;
            }
        }
        
        return;
    } else if (tag == MTTcpSocksReceiveBindAddrDomainNameLength) {
        if (rawData.length != 1) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks5 response domain name data length", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        uint8_t length = 0;
        [rawData getBytes:&length length:1];
        
        [_socket readDataToLength:(int)length withTimeout:-1 tag:MTTcpSocksReceiveBindAddrDomainName];
        
        return;
    } else if (tag == MTTcpSocksReceiveBindAddrDomainName || tag == MTTcpSocksReceiveBindAddr4 || tag == MTTcpSocksReceiveBindAddr6) {
        [_socket readDataToLength:2 withTimeout:-1 tag:MTTcpSocksReceiveBindAddrPort];
        
        return;
    } else if (tag == MTTcpSocksReceiveBindAddrPort) {
        if (_connectionOpened)
            _connectionOpened();
        id<MTTcpConnectionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionOpened:)])
            [delegate tcpConnectionOpened:self];
        
        _readyToSendData = true;
        [self sendDataIfNeeded];
        if (_useIntermediateFormat) {
            [self requestReadDataWithLength:4 tag:MTTcpReadTagPacketFullLength];
        } else {
            [self requestReadDataWithLength:1 tag:MTTcpReadTagPacketShortLength];
        }
        
        return;
    } else if (tag == MTTcpSocksReceiveAuthResponse) {
        int8_t version = 0;
        int8_t status = 0;
        [rawData getBytes:&version range:NSMakeRange(0, 1)];
        [rawData getBytes:&status range:NSMakeRange(1, 1)];
        
        if (version != 1 || status != 0) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid socks5 auth response", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        [self requestSocksConnection];
        
        return;
    } else if (tag == MTTcpSocksReceiveHelloResponse) {
        if (rawData.length != 5) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid hello response length", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        NSData *header = [rawData subdataWithRange:NSMakeRange(0, 3)];
        uint8_t expectedHeader[3] = { 0x16, 0x03, 0x03 };
        
        if (![[[NSData alloc] initWithBytes:expectedHeader length:3] isEqualToData:header]) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid hello response header", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        int16_t nextLength = 0;
        [rawData getBytes:&nextLength range:NSMakeRange(3, 2)];
        nextLength = OSSwapInt16(nextLength);
        if (nextLength < 0 || nextLength > 10 * 1024) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid hello response header length marker", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        _currentHelloResponse = [NSData dataWithData:rawData];
        
        [_socket readDataToLength:((int)nextLength) + 9 + 2 withTimeout:-1 tag:MTTcpSocksReceiveHelloResponse1];
        
        return;
    } else if (tag == MTTcpSocksReceiveHelloResponse1) {
        uint8_t expectedResponsePart[9] = { 0x14, 0x03, 0x03, 0x00, 0x01, 0x01, 0x17, 0x03, 0x03 };
        NSData *responsePart = [rawData subdataWithRange:NSMakeRange(rawData.length - 9 - 2, 9)];
        if (![[[NSData alloc] initWithBytes:expectedResponsePart length:9] isEqualToData:responsePart]) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid hello response1 part", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        int16_t nextLength = 0;
        [rawData getBytes:&nextLength range:NSMakeRange(rawData.length - 2, 2)];
        nextLength = OSSwapInt16(nextLength);
        if (nextLength < 0 || nextLength > 10 * 1024) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid hello response header length marker", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        NSMutableData *currentHelloResponse = [[NSMutableData alloc] init];
        [currentHelloResponse appendData:_currentHelloResponse];
        [currentHelloResponse appendData:rawData];
        _currentHelloResponse = currentHelloResponse;
        
        [_socket readDataToLength:((int)nextLength) withTimeout:-1 tag:MTTcpSocksReceiveHelloResponse2];
        return;
    } else if (tag == MTTcpSocksReceiveHelloResponse2) {
        NSMutableData *currentHelloResponse = [[NSMutableData alloc] init];
        [currentHelloResponse appendData:_currentHelloResponse];
        [currentHelloResponse appendData:rawData];
        
        if (currentHelloResponse.length < 11 + 32) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid hello response total length", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        NSData *currentHelloResponseRandom = [currentHelloResponse subdataWithRange:NSMakeRange(11, 32)];
        memset(((uint8_t *)currentHelloResponse.mutableBytes) + 11, 0, 32);
        
        NSMutableData *checkData = [[NSMutableData alloc] init];
        [checkData appendData:_helloRandom];
        [checkData appendData:currentHelloResponse];
        
        NSData *effectiveSecret = _mtpSecret.secret;
        uint8_t cHMAC[CC_SHA256_DIGEST_LENGTH];
        CCHmac(kCCHmacAlgSHA256, effectiveSecret.bytes, effectiveSecret.length, checkData.bytes, checkData.length, cHMAC);
        
        if (![[[NSData alloc] initWithBytes:cHMAC length:CC_SHA256_DIGEST_LENGTH] isEqualToData:currentHelloResponseRandom]) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid hello response random", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        _readyToSendData = true;
        [self sendDataIfNeeded];
        
        if (_useIntermediateFormat) {
            [self requestReadDataWithLength:4 tag:MTTcpReadTagPacketFullLength];
        } else {
            [self requestReadDataWithLength:1 tag:MTTcpReadTagPacketShortLength];
        }
        
        [_socket readDataToLength:5 withTimeout:-1 tag:MTTcpSocksReceiveComplexLength];
        return;
    } else if (tag == MTTcpSocksReceiveComplexLength) {
        if (rawData.length != 5) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid complex header length", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        NSData *header = [rawData subdataWithRange:NSMakeRange(0, 3)];
        uint8_t expectedHeader[3] = { 0x17, 0x03, 0x03 };
        
        if (![[[NSData alloc] initWithBytes:expectedHeader length:3] isEqualToData:header]) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid complex header", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        int16_t nextLength = 0;
        [rawData getBytes:&nextLength range:NSMakeRange(3, 2)];
        nextLength = OSSwapInt16(nextLength);
        if (nextLength < 0) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid complex header length marker", __PRETTY_FUNCTION__);
            }
            [self closeAndNotifyWithError:true];
            return;
        }
        
        [_socket readDataToLength:(int)nextLength withTimeout:-1 tag:MTTcpSocksReceiveComplexPacketPart];
        return;
    } else if (tag == MTTcpSocksReceiveComplexPacketPart) {
        [self addReadData:rawData];
        
        [_socket readDataToLength:5 withTimeout:-1 tag:MTTcpSocksReceiveComplexLength];
        return;
    } else {
        [self addReadData:rawData];
    }
}

- (void)requestReadDataWithLength:(int)length tag:(int)tag {
    assert(length > 0);
    assert(_pendingReceiveData == nil);
    _pendingReceiveData = [[MTTcpReceiveData alloc] initWithTag:tag length:length];
    if (![_mtpSecret isKindOfClass:[MTProxySecretType2 class]]) {
        [_socket readDataToLength:length withTimeout:-1 tag:MTTcpSocksReceivePassthrough];
    }
    if (_receivedDataBuffer.length >= _pendingReceiveData.length) {
        NSData *rawData = [_receivedDataBuffer subdataWithRange:NSMakeRange(0, _pendingReceiveData.length)];
        [_receivedDataBuffer replaceBytesInRange:NSMakeRange(0, _pendingReceiveData.length) withBytes:nil length:0];
        int tag = _pendingReceiveData.tag;
        _pendingReceiveData = nil;
        [self processReceivedData:rawData tag:tag];
    }
}

- (void)addReadData:(NSData *)data {
    if (_pendingReceiveData != nil && _pendingReceiveData.length == data.length) {
        int tag = _pendingReceiveData.tag;
        _pendingReceiveData = nil;
        [self processReceivedData:data tag:tag];
    } else {
        [_receivedDataBuffer appendData:data];
        if (_pendingReceiveData != nil) {
            if (_receivedDataBuffer.length >= _pendingReceiveData.length) {
                NSData *rawData = [_receivedDataBuffer subdataWithRange:NSMakeRange(0, _pendingReceiveData.length)];
                [_receivedDataBuffer replaceBytesInRange:NSMakeRange(0, _pendingReceiveData.length) withBytes:nil length:0];
                int tag = _pendingReceiveData.tag;
                _pendingReceiveData = nil;
                [self processReceivedData:rawData tag:tag];
            }
        }
    }
}

- (void)processReceivedData:(NSData *)rawData tag:(int)tag {
    NSMutableData *decryptedData = [[NSMutableData alloc] initWithLength:rawData.length];
    [_incomingAesCtr encryptIn:rawData.bytes out:decryptedData.mutableBytes len:rawData.length];
    
    NSData *data = decryptedData;
    
    if (tag == MTTcpReadTagPacketShortLength) {
#ifdef DEBUG
        NSAssert(data.length == 1, @"data length should be equal to 1");
#endif
        
        uint8_t quarterLengthMarker = 0;
        [data getBytes:&quarterLengthMarker length:1];
        
        if ((quarterLengthMarker & 0x80) == 0x80) {
            _quickAckByte = quarterLengthMarker;
            [self requestReadDataWithLength:3 tag:MTTcpReadTagQuickAck];
        } else {
            if (quarterLengthMarker >= 0x01 && quarterLengthMarker <= 0x7e) {
                NSUInteger packetBodyLength = ((NSUInteger)quarterLengthMarker) * 4;
                if (packetBodyLength >= MTTcpProgressCalculationThreshold) {
                    _packetRestLength = packetBodyLength - 128;
                    _packetRestReceivedLength = 0;
                    [self requestReadDataWithLength:128 tag:MTTcpReadTagPacketHead];
                } else {
                    [self requestReadDataWithLength:(int)packetBodyLength tag:MTTcpReadTagPacketBody];
                }
            } else if (quarterLengthMarker == 0x7f) {
                [self requestReadDataWithLength:3 tag:MTTcpReadTagPacketLongLength];
            } else {
                if (MTLogEnabled()) {
                    MTLog(@"***** %s: invalid quarter length marker (%" PRIu8 ")", __PRETTY_FUNCTION__, quarterLengthMarker);
                }
                [self closeAndNotifyWithError:true];
            }
        }
    } else if (tag == MTTcpReadTagPacketLongLength) {
#ifdef DEBUG
        NSAssert(data.length == 3, @"data length should be equal to 3");
#endif
        
        uint32_t quarterLength = 0;
        [data getBytes:(((uint8_t *)&quarterLength)) length:3];
        
        if (quarterLength <= 0 || quarterLength > (4 * 1024 * 1024) / 4) {
            if (MTLogEnabled()) {
                MTLog(@"***** %s: invalid quarter length (%" PRIu32 ")", __PRETTY_FUNCTION__, quarterLength);
            }
            [self closeAndNotifyWithError:true];
        } else {
            NSUInteger packetBodyLength = quarterLength * 4;
            if (packetBodyLength >= MTTcpProgressCalculationThreshold) {
                _packetRestLength = packetBodyLength - 128;
                _packetRestReceivedLength = 0;
                [self requestReadDataWithLength:128 tag:MTTcpReadTagPacketHead];
            } else {
                [self requestReadDataWithLength:(int)packetBodyLength tag:MTTcpReadTagPacketBody];
            }
        }
    } else if (tag == MTTcpReadTagPacketFullLength) {
#ifdef DEBUG
        NSAssert(data.length == 4, @"data length should be equal to 4");
#endif
        
        int32_t length = 0;
        [data getBytes:&length length:4];
        
        if ((length & 0x80000000) == 0x80000000) {
            int32_t ackId = length;
            ackId &= ((uint32_t)0xffffffff ^ (uint32_t)(((uint32_t)1) << 31));
            ackId = (int32_t)OSSwapInt32(ackId);
            
            id<MTTcpConnectionDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(tcpConnectionReceivedQuickAck:quickAck:)])
                [delegate tcpConnectionReceivedQuickAck:self quickAck:ackId];
            
            if (_useIntermediateFormat) {
                [self requestReadDataWithLength:4 tag:MTTcpReadTagPacketFullLength];
            } else {
                [self requestReadDataWithLength:1 tag:MTTcpReadTagPacketShortLength];
            }
        } else {
            if (length > 16 * 1024 * 1024) {
                if (MTLogEnabled()) {
                    MTLog(@"[MTTcpConnection#%" PRIxPTR " received invalid length %d]", (intptr_t)self, length);
                }
                [self closeAndNotifyWithError:true];
            } else {
                NSUInteger packetBodyLength = (NSUInteger)length;
                
                if (packetBodyLength >= MTTcpProgressCalculationThreshold) {
                    _packetRestLength = packetBodyLength - 128;
                    _packetRestReceivedLength = 0;
                    [self requestReadDataWithLength:128 tag:MTTcpReadTagPacketHead];
                } else {
                    [self requestReadDataWithLength:(int)packetBodyLength tag:MTTcpReadTagPacketBody];
                }
            }
        }
    } else if (tag == MTTcpReadTagPacketHead) {
        _packetHead = data;
        
        static int64_t nextToken = 0;
        _packetHeadDecodeToken = nextToken;
        nextToken++;
        
        id<MTTcpConnectionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionDecodePacketProgressToken:data:token:completion:)]) {
            __weak MTTcpConnection *weakSelf = self;
            [delegate tcpConnectionDecodePacketProgressToken:self data:data token:_packetHeadDecodeToken completion:^(int64_t token, id packetProgressToken) {
                [[MTTcpConnection tcpQueue] dispatchOnQueue:^{
                    __strong MTTcpConnection *strongSelf = weakSelf;
                    if (strongSelf != nil && token == strongSelf.packetHeadDecodeToken)
                        strongSelf.packetProgressToken = packetProgressToken;
                }];
            }];
        }
        
        [self requestReadDataWithLength:(int)_packetRestLength tag:MTTcpReadTagPacketBody];
    } else if (tag == MTTcpReadTagPacketBody) {
        [_responseTimeoutTimer invalidate];
        _responseTimeoutTimer = nil;
        
        _packetHeadDecodeToken = -1;
        _packetProgressToken = nil;
        
        NSData *packetData = data;
        if (_packetHead != nil) {
            NSMutableData *combinedData = [[NSMutableData alloc] initWithCapacity:_packetHead.length + data.length];
            [combinedData appendData:_packetHead];
            [combinedData appendData:data];
            packetData = combinedData;
            _packetHead = nil;
        }
        
        if (packetData.length % 4 != 0) {
            int32_t realLength = ((int32_t)packetData.length) & (~3);
            packetData = [packetData subdataWithRange:NSMakeRange(0, (NSUInteger)realLength)];
        }
        
        bool ignorePacket = false;
        if (packetData.length >= 4) {
            int32_t header = 0;
            [packetData getBytes:&header length:4];
            if (header == 0xffffffff) {
                if (packetData.length >= 8) {
                    int32_t ackId = 0;
                    [packetData getBytes:&ackId range:NSMakeRange(4, 4)];
                    ackId &= ((uint32_t)0xffffffff ^ (uint32_t)(((uint32_t)1) << 31));
                    ackId = (int32_t)OSSwapInt32(ackId);
                    
                    id<MTTcpConnectionDelegate> delegate = _delegate;
                    if ([delegate respondsToSelector:@selector(tcpConnectionReceivedQuickAck:quickAck:)]) {
                        [delegate tcpConnectionReceivedQuickAck:self quickAck:ackId];
                    }
                    
                    ignorePacket = true;
                }
            } else if (header == 0 && packetData.length < 16) {
                if (MTLogEnabled()) {
                    MTLog(@"[MTTcpConnection#%" PRIxPTR " received nop packet]", (intptr_t)self);
                }
                ignorePacket = true;
            }
        }
        
        if (!ignorePacket) {
            if (_connectionReceivedData)
                _connectionReceivedData(packetData);
            id<MTTcpConnectionDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(tcpConnectionReceivedData:data:)])
                [delegate tcpConnectionReceivedData:self data:packetData];
        }
        
        if (_useIntermediateFormat) {
            [self requestReadDataWithLength:4 tag:MTTcpReadTagPacketFullLength];
        } else {
            [self requestReadDataWithLength:1 tag:MTTcpReadTagPacketShortLength];
        }
    } else if (tag == MTTcpReadTagQuickAck) {
#ifdef DEBUG
        NSAssert(data.length == 3, @"data length should be equal to 3");
#endif
        
        int32_t ackId = 0;
        ((uint8_t *)&ackId)[0] = _quickAckByte;
        memcpy(((uint8_t *)&ackId) + 1, data.bytes, 3);
        ackId = (int32_t)OSSwapInt32(ackId);
        ackId &= ((uint32_t)0xffffffff ^ (uint32_t)(((uint32_t)1) << 31));
        
        id<MTTcpConnectionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionReceivedQuickAck:quickAck:)])
            [delegate tcpConnectionReceivedQuickAck:self quickAck:ackId];
        
        if (_useIntermediateFormat) {
            [self requestReadDataWithLength:4 tag:MTTcpReadTagPacketFullLength];
        } else {
            [self requestReadDataWithLength:1 tag:MTTcpReadTagPacketShortLength];
        }
    }
}
             
- (void)socket:(GCDAsyncSocket *)__unused socket didConnectToHost:(NSString *)__unused host port:(uint16_t)__unused port
{
    if (_socksIp != nil) {
        
    } else {
        if (_connectionOpened)
            _connectionOpened();
        id<MTTcpConnectionDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(tcpConnectionOpened:)])
            [delegate tcpConnectionOpened:self];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)__unused socket withError:(NSError *)error
{
    if (error != nil) {
        if (MTLogEnabled()) {
            MTLog(@"[MTTcpConnection#%" PRIxPTR " disconnected from %@ (%@)]", (intptr_t)self, _scheme.address.ip, error);
        }
    }
    else {
        if (MTLogEnabled()) {
            MTLog(@"[MTTcpConnection#%" PRIxPTR " disconnected from %@]", (intptr_t)self, _scheme.address.ip);
        }
    }
    
    [self closeAndNotifyWithError:error != nil];
}

@end
