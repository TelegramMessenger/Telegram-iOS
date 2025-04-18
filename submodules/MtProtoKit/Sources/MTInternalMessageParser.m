#import "MTInternalMessageParser.h"

#import "MTBufferReader.h"

#import "MTResPqMessage.h"
#import "MTRpcResultMessage.h"
#import <MtProtoKit/MTRpcError.h>
#import "MTDropRpcResultMessage.h"
#import "MTServerDhParamsMessage.h"
#import "MTServerDhInnerDataMessage.h"
#import "MTSetClientDhParamsResponseMessage.h"
#import "MTMsgsAckMessage.h"
#import "MTMsgsStateReqMessage.h"
#import "MTMsgsStateInfoMessage.h"
#import "MTMsgDetailedInfoMessage.h"
#import "MTMsgAllInfoMessage.h"
#import "MTMessage.h"
#import "MTMsgResendReqMessage.h"
#import "MTBadMsgNotificationMessage.h"
#import "MTPingMessage.h"
#import "MTPongMessage.h"
#import "MTNewSessionCreatedMessage.h"
#import "MTDestroySessionResponseMessage.h"
#import "MTMsgContainerMessage.h"
#import "MTFutureSaltsMessage.h"

#import <MtProtoKit/MTLogging.h>

#import <zlib.h>

@implementation MTInternalMessageParser

+ (id)parseMessage:(NSData *)data
{
    MTBufferReader *reader = [[MTBufferReader alloc] initWithData:data];
    
    int32_t signature = 0;
    if ([reader readInt32:&signature])
    {
        switch (signature)
        {
            case (int32_t)0x05162463:
            {
                NSMutableData *nonce = [[NSMutableData alloc] init];
                [nonce setLength:16];
                if (![reader readBytes:nonce.mutableBytes length:16])
                    return nil;

                NSMutableData *serverNonce = [[NSMutableData alloc] init];
                [serverNonce setLength:16];
                if (![reader readBytes:serverNonce.mutableBytes length:16])
                    return nil;
                
                NSData *pq = nil;
                if (![reader readTLBytes:&pq])
                    return nil;

                if (![reader readInt32:NULL])
                    return nil;
                
                int32_t count = 0;
                if (![reader readInt32:&count])
                    return nil;
                
                NSMutableArray *serverPublicKeyFingerprints = [[NSMutableArray alloc] init];
                for (int32_t i = 0; i < count; i++)
                {
                    int64_t fingerprint = 0;
                    if (![reader readInt64:&fingerprint])
                        return nil;
                    [serverPublicKeyFingerprints addObject:@(fingerprint)];
                }
                
                return [[MTResPqMessage alloc] initWithNonce:nonce serverNonce:serverNonce pq:pq serverPublicKeyFingerprints:serverPublicKeyFingerprints];
            }
            case (int32_t)0x79cb045d:
            {
                NSMutableData *nonce = [[NSMutableData alloc] init];
                [nonce setLength:16];
                if (![reader readBytes:nonce.mutableBytes length:16])
                    return nil;
                
                NSMutableData *serverNonce = [[NSMutableData alloc] init];
                [serverNonce setLength:16];
                if (![reader readBytes:serverNonce.mutableBytes length:16])
                    return nil;
                
                NSMutableData *nextNonceHash = [[NSMutableData alloc] init];
                [nextNonceHash setLength:16];
                if (![reader readBytes:nextNonceHash.mutableBytes length:16])
                    return nil;
                
                return [[MTServerDhParamsFailMessage alloc] initWithNonce:nonce serverNonce:serverNonce nextNonceHash:nextNonceHash];
            }
            case (int32_t)0xd0e8075c:
            {
                NSMutableData *nonce = [[NSMutableData alloc] init];
                [nonce setLength:16];
                if (![reader readBytes:nonce.mutableBytes length:16])
                    return nil;
                
                NSMutableData *serverNonce = [[NSMutableData alloc] init];
                [serverNonce setLength:16];
                if (![reader readBytes:serverNonce.mutableBytes length:16])
                    return nil;
                
                NSData *encryptedResponse = nil;
                if (![reader readTLBytes:&encryptedResponse])
                    return nil;
                
                return [[MTServerDhParamsOkMessage alloc] initWithNonce:nonce serverNonce:serverNonce encryptedResponse:encryptedResponse];
            }
            case (int32_t)0xb5890dba:
            {
                NSMutableData *nonce = [[NSMutableData alloc] init];
                [nonce setLength:16];
                if (![reader readBytes:nonce.mutableBytes length:16])
                    return nil;
                
                NSMutableData *serverNonce = [[NSMutableData alloc] init];
                [serverNonce setLength:16];
                if (![reader readBytes:serverNonce.mutableBytes length:16])
                    return nil;
                
                int32_t g = 0;
                if (![reader readInt32:&g])
                    return nil;
                
                NSData *dhPrime = nil;
                if (![reader readTLBytes:&dhPrime])
                    return nil;
                
                NSData *gA = nil;
                if (![reader readTLBytes:&gA])
                    return nil;
                
                int32_t serverTime = 0;
                if (![reader readInt32:&serverTime])
                    return nil;
                
                return [[MTServerDhInnerDataMessage alloc] initWithNonce:nonce serverNonce:serverNonce g:g dhPrime:dhPrime gA:gA serverTime:serverTime];
            }
            case (int32_t)0x3bcbf734:
            {
                NSMutableData *nonce = [[NSMutableData alloc] init];
                [nonce setLength:16];
                if (![reader readBytes:nonce.mutableBytes length:16])
                    return nil;
                
                NSMutableData *serverNonce = [[NSMutableData alloc] init];
                [serverNonce setLength:16];
                if (![reader readBytes:serverNonce.mutableBytes length:16])
                    return nil;
                
                NSMutableData *nextNonceHash1 = [[NSMutableData alloc] init];
                [nextNonceHash1 setLength:16];
                if (![reader readBytes:nextNonceHash1.mutableBytes length:16])
                    return nil;
                
                return [[MTSetClientDhParamsResponseOkMessage alloc] initWithNonce:nonce serverNonce:serverNonce nextNonceHash1:nextNonceHash1];
            }
            case (int32_t)0x46dc1fb9:
            {
                NSMutableData *nonce = [[NSMutableData alloc] init];
                [nonce setLength:16];
                if (![reader readBytes:nonce.mutableBytes length:16])
                    return nil;
                
                NSMutableData *serverNonce = [[NSMutableData alloc] init];
                [serverNonce setLength:16];
                if (![reader readBytes:serverNonce.mutableBytes length:16])
                    return nil;
                
                NSMutableData *nextNonceHash2 = [[NSMutableData alloc] init];
                [nextNonceHash2 setLength:16];
                if (![reader readBytes:nextNonceHash2.mutableBytes length:16])
                    return nil;
                
                return [[MTSetClientDhParamsResponseRetryMessage alloc] initWithNonce:nonce serverNonce:serverNonce nextNonceHash2:nextNonceHash2];
            }
            case (int32_t)0xa69dae02:
            {
                NSMutableData *nonce = [[NSMutableData alloc] init];
                [nonce setLength:16];
                if (![reader readBytes:nonce.mutableBytes length:16])
                    return nil;
                
                NSMutableData *serverNonce = [[NSMutableData alloc] init];
                [serverNonce setLength:16];
                if (![reader readBytes:serverNonce.mutableBytes length:16])
                    return nil;
                
                NSMutableData *nextNonceHash3 = [[NSMutableData alloc] init];
                [nextNonceHash3 setLength:16];
                if (![reader readBytes:nextNonceHash3.mutableBytes length:16])
                    return nil;
                
                return [[MTSetClientDhParamsResponseFailMessage alloc] initWithNonce:nonce serverNonce:serverNonce nextNonceHash3:nextNonceHash3];
            }
            case (int32_t)0xf35c6d01:
            {
                int64_t requestMessageId = 0;
                if (![reader readInt64:&requestMessageId])
                    return nil;
                
                NSData *responseData = [reader readRest];
                
                return [[MTRpcResultMessage alloc] initWithRequestMessageId:requestMessageId data:responseData];
            }
            case (int32_t)0x2144ca19:
            {
                int32_t errorCode = 0;
                if (![reader readInt32:&errorCode])
                    return nil;
                
                NSString *errorDescription = @"";
                if (![reader readTLString:&errorDescription])
                    return nil;
                
                return [[MTRpcError alloc] initWithErrorCode:errorCode errorDescription:errorDescription];
            }
            case (int32_t)0x5e2ad36e:
            {
                return [[MTDropRpcResultUnknownMessage alloc] init];
            }
            case (int32_t)0xcd78e586:
            {
                return [[MTDropRpcResultDroppedRunningMessage alloc] init];
            }
            case (int32_t)0xa43ad8b7:
            {
                int64_t messageId = 0;
                if (![reader readInt64:&messageId])
                    return nil;
                
                int32_t seqNo = 0;
                if (![reader readInt32:&seqNo])
                    return nil;
                
                int32_t size = 0;
                if (![reader readInt32:&size])
                    return nil;
                
                return [[MTDropRpcResultDroppedMessage alloc] initWithMessageId:messageId seqNo:seqNo size:size];
            }
            case (int32_t)0xda69fb52:
            {
                if (![reader readInt32:NULL])
                    return nil;
                
                int32_t count = 0;
                if (![reader readInt32:&count])
                    return nil;
                
                NSMutableArray *messageIds = [[NSMutableArray alloc] init];
                for (int32_t i = 0; i < count; i++)
                {
                    int64_t messageId = 0;
                    if (![reader readInt64:&messageId])
                        return nil;
                    [messageIds addObject:@(messageId)];
                }
                
                return [[MTMsgsStateReqMessage alloc] initWithMessageIds:messageIds];
            }
            case (int32_t)0x04deb57d:
            {
                int64_t requestMessageId = 0;
                if (![reader readInt64:&requestMessageId])
                    return nil;
                
                NSData *info = nil;
                if (![reader readTLBytes:&info])
                    return nil;
                
                return [[MTMsgsStateInfoMessage alloc] initWithRequestMessageId:requestMessageId info:info];
            }
            case (int32_t)0x276d3ec6:
            {
                int64_t requestMessageId = 0;
                if (![reader readInt64:&requestMessageId])
                    return nil;
                
                int64_t responseMessageId = 0;
                if (![reader readInt64:&responseMessageId])
                    return nil;
                
                int32_t responseLength = 0;
                if (![reader readInt32:&responseLength])
                    return nil;
                
                int32_t status = 0;
                if (![reader readInt32:&status])
                    return nil;
                
                return [[MTMsgDetailedResponseInfoMessage alloc] initWithRequestMessageId:requestMessageId responseMessageId:responseMessageId responseLength:responseLength status:status];
            }
            case (int32_t)0x809db6df:
            {
                int64_t responseMessageId = 0;
                if (![reader readInt64:&responseMessageId])
                    return nil;
                
                int32_t responseLength = 0;
                if (![reader readInt32:&responseLength])
                    return nil;
                
                int32_t status = 0;
                if (![reader readInt32:&status])
                    return nil;
                
                return [[MTMsgDetailedInfoMessage alloc] initWithResponseMessageId:responseMessageId responseLength:responseLength status:status];
            }
            case (int32_t)0x8cc0d131:
            {
                if (![reader readInt32:NULL])
                    return nil;
                
                int32_t count = 0;
                if (![reader readInt32:&count])
                    return nil;
                
                NSMutableArray *messageIds = [[NSMutableArray alloc] init];
                for (int32_t i = 0; i < count; i++)
                {
                    int64_t messageId = 0;
                    if (![reader readInt64:&messageId])
                        return nil;
                    [messageIds addObject:@(messageId)];
                }
                
                NSData *info = nil;
                if (![reader readTLBytes:&info])
                    return nil;
                
                return [[MTMsgAllInfoMessage alloc] initWithMessageIds:messageIds info:info];
            }
            case (int32_t)0xe06046b2:
            {
                int32_t messageSignature = 0;
                if (![reader readInt32:&messageSignature] || messageSignature != (int32_t)0x5bb8e511)
                    return nil;
                
                int64_t messageId = 0;
                if (![reader readInt64:&messageId])
                    return nil;
                
                int32_t seqNo = 0;
                if (![reader readInt32:&seqNo])
                    return nil;
                
                int32_t length = 0;
                if (![reader readInt32:&length])
                    return nil;
                
                NSData *data = [reader readRest];
                if (data.length != (NSUInteger)length)
                    return nil;
                
                return [[MTMessage alloc] initWithMessageId:messageId seqNo:seqNo data:data];
            }
            case (int32_t)0x7d861a08:
            {
                int32_t count = 0;
                if (![reader readInt32:&count])
                    return nil;
                
                NSMutableArray *messageIds = [[NSMutableArray alloc] init];
                for (int32_t i = 0; i < count; i++)
                {
                    int64_t messageId = 0;
                    if (![reader readInt64:&messageId])
                        return nil;
                    [messageIds addObject:@(messageId)];
                }
                
                return [[MTMsgResendReqMessage alloc] initWithMessageIds:messageIds];
            }
            case (int32_t)0xa7eff811:
            {
                int64_t badMessageId = 0;
                if (![reader readInt64:&badMessageId])
                    return nil;
                
                int32_t badMessageSeqNo = 0;
                if (![reader readInt32:&badMessageSeqNo])
                    return nil;
                
                int32_t errorCode = 0;
                if (![reader readInt32:&errorCode])
                    return nil;
                
                return [[MTBadMsgNotificationMessage alloc] initWithBadMessageId:badMessageId badMessageSeqNo:badMessageSeqNo errorCode:errorCode];
            }
            case (int32_t)0xedab447b:
            {
                int64_t badMessageId = 0;
                if (![reader readInt64:&badMessageId])
                    return nil;
                
                int32_t badMessageSeqNo = 0;
                if (![reader readInt32:&badMessageSeqNo])
                    return nil;
                
                int32_t errorCode = 0;
                if (![reader readInt32:&errorCode])
                    return nil;
                
                int64_t nextServerSalt = 0;
                if (![reader readInt64:&nextServerSalt])
                    return nil;
                
                return [[MTBadServerSaltNotificationMessage alloc] initWithBadMessageId:badMessageId badMessageSeqNo:badMessageSeqNo errorCode:errorCode nextServerSalt:nextServerSalt];
            }
            case (int32_t)0x62d6b459:
            {
                int32_t vectorSignature = 0;
                if (![reader readInt32:&vectorSignature])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTInternalMessageParser: msgs_ack can't read vectorSignature]");
                    }
                    return nil;
                }
                else if (vectorSignature != (int32_t)0x1cb5c415)
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTInternalMessageParser: msgs_ack invalid vectorSignature]");
                    }
                    return nil;
                }
                
                int32_t count = 0;
                if (![reader readInt32:&count])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTInternalMessageParser: msgs_ack can't read count]");
                    }
                    return nil;
                }
                
                NSMutableArray *messageIds = [[NSMutableArray alloc] init];
                for (int32_t i = 0; i < count; i++)
                {
                    int64_t messageId = 0;
                    if (![reader readInt64:&messageId])
                    {
                        if (MTLogEnabled()) {
                            MTLog(@"[MTInternalMessageParser: msgs_ack can't read messageId]");
                        }
                        return nil;
                    }
                    [messageIds addObject:@(messageId)];
                }
                
                return [[MTMsgsAckMessage alloc] initWithMessageIds:messageIds];
            }
            case (int32_t)0x7abe77ec:
            {
                int64_t pingId = 0;
                if (![reader readInt64:&pingId])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTInternalMessageParser: ping can't read pingId]");
                    }
                    return nil;
                }
                
                return [[MTPingMessage alloc] initWithPingId:pingId];
            }
            case (int32_t)0x347773c5:
            {
                int64_t messageId = 0;
                if (![reader readInt64:&messageId])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTInternalMessageParser: pong can't read messageId]");
                    }
                    return nil;
                }
                
                int64_t pingId = 0;
                if (![reader readInt64:&pingId])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTInternalMessageParser: pong can't read pingId]");
                    }
                    return nil;
                }
                
                return [[MTPongMessage alloc] initWithMessageId:messageId pingId:pingId];
            }
            case (int32_t)0x9ec20908:
            {
                int64_t firstMessageId = 0;
                if (![reader readInt64:&firstMessageId])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTInternalMessageParser: new_session_created can't read firstMessageId]");
                    }
                    return nil;
                }
                
                int64_t uniqueId = 0;
                if (![reader readInt64:&uniqueId])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTInternalMessageParser: new_session_created can't read uniqueId]");
                    }
                    return nil;
                }
                
                int64_t serverSalt = 0;
                if (![reader readInt64:&serverSalt])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTInternalMessageParser: new_session_created can't read serverSalt]");
                    }
                    return nil;
                }
                
                return [[MTNewSessionCreatedMessage alloc] initWithFirstMessageId:firstMessageId uniqueId:uniqueId serverSalt:serverSalt];
            }
            case (int32_t)0xe22045fc:
            {
                int64_t sessionId = 0;
                if (![reader readInt64:&sessionId])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTInternalMessageParser: destroy_session_ok can't read sessionId]");
                    }
                    return nil;
                }
                
                return [[MTDestroySessionResponseOkMessage alloc] initWithSessionId:sessionId];
            }
            case (int32_t)0x62d350c9:
            {
                int64_t sessionId = 0;
                if (![reader readInt64:&sessionId])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTInternalMessageParser: destroy_session_none can't read sessionId]");
                    }
                    return nil;
                }
                
                return [[MTDestroySessionResponseNoneMessage alloc] initWithSessionId:sessionId];
            }
            case (int32_t)0xfb95abcd:
            {
                NSData *responsesData = [reader readRest];
                
                return [[MTDestroySessionMultipleResponseMessage alloc] initWithResponses:responsesData];
            }
            case (int32_t)0x73f1f8dc:
            {
                int32_t count = 0;
                if (![reader readInt32:&count])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTInternalMessageParser: msg_container can't read count]");
                    }
                    return nil;
                }
                
                NSMutableArray *messages = [[NSMutableArray alloc] init];
                
                for (int32_t i = 0; i < count; i++)
                {
                    int64_t messageId = 0;
                    if (![reader readInt64:&messageId])
                    {
                        if (MTLogEnabled()) {
                            MTLog(@"[MTInternalMessageParser: msg_container can't read messageId]");
                        }
                        return nil;
                    }
                    
                    int32_t seqNo = 0;
                    if (![reader readInt32:&seqNo])
                    {
                        if (MTLogEnabled()) {
                            MTLog(@"[MTInternalMessageParser: msg_container can't read seqNo]");
                        }
                        return nil;
                    }
                    
                    int32_t length = 0;
                    if (![reader readInt32:&length])
                    {
                        if (MTLogEnabled()) {
                            MTLog(@"[MTInternalMessageParser: msg_container can't read length]");
                        }
                        return nil;
                    }
                    
                    if (length < 0 || length > 16 * 1024 * 1024)
                    {
                        if (MTLogEnabled()) {
                            MTLog(@"[MTInternalMessageParser: msg_container invalid length %d]", length);
                        }
                        return nil;
                    }
                    
                    NSMutableData *messageData = [[NSMutableData alloc] init];
                    [messageData setLength:(NSUInteger)length];
                    if (![reader readBytes:messageData.mutableBytes length:(NSUInteger)length])
                    {
                        if (MTLogEnabled()) {
                            MTLog(@"[MTInternalMessageParser: msg_container can't read bytes]");
                        }
                        return nil;
                    }
                    
                    [messages addObject:[[MTMessage alloc] initWithMessageId:messageId seqNo:seqNo data:messageData]];
                }
                
                return [[MTMsgContainerMessage alloc] initWithMessages:messages];
            }
            case (int32_t)0xae500895:
            {
                int64_t requestMessageId = 0;
                if (![reader readInt64:&requestMessageId])
                    return nil;
                
                int32_t now = 0;
                if (![reader readInt32:&now])
                    return nil;
                
                int32_t count = 0;
                if (![reader readInt32:&count])
                    return nil;
                
                NSMutableArray *salts = [[NSMutableArray alloc] init];
                
                for (int32_t i = 0; i < count; i++)
                {
                    int32_t validSince = 0;
                    if (![reader readInt32:&validSince])
                        return nil;
                    
                    int32_t validUntil = 0;
                    if (![reader readInt32:&validUntil])
                        return nil;
                    
                    int64_t salt = 0;
                    if (![reader readInt64:&salt])
                        return nil;
                    
                    [salts addObject:[[MTFutureSalt alloc] initWithValidSince:validSince validUntil:validUntil salt:salt]];
                }
                
                return [[MTFutureSaltsMessage alloc] initWithRequestMessageId:requestMessageId now:now salts:salts];
            }
            default:
                break;
        }
    }
    
    return nil;
}

+ (NSData *)readBytes:(NSData *)data skippingLength:(NSUInteger)skipLength
{
    NSUInteger offset = skipLength;
    
    uint8_t tmp = 0;
    [data getBytes:&tmp range:NSMakeRange(offset, 1)];
    offset += 1;
    
    int32_t length = tmp;
    if (length == 254)
    {
        length = 0;
        [data getBytes:((uint8_t *)&length) + 1 range:NSMakeRange(offset, 3)];
        offset += 3;
        length >>= 8;
    }
    
    return [data subdataWithRange:NSMakeRange(offset, length)];
}

+ (NSData *)decompressGZip:(NSData *)data
{
    const int kMemoryChunkSize = 1024;
    
    NSUInteger length = [data length];
    int windowBits = 15 + 32; //Default + gzip header instead of zlib header
    int retCode;
    unsigned char output[kMemoryChunkSize];
    uInt gotBack;
    NSMutableData *result;
    z_stream stream;
    
    if ((length == 0) || (length > UINT_MAX)) //FIXME: Support 64 bit inputs
        return nil;
    
    bzero(&stream, sizeof(z_stream));
    stream.avail_in = (uInt)length;
    stream.next_in = (unsigned char*)[data bytes];
    
    retCode = inflateInit2(&stream, windowBits);
    if(retCode != Z_OK)
    {
        NSLog(@"%s: inflateInit2() failed with error %i", __PRETTY_FUNCTION__, retCode);
        return nil;
    }
    
    result = [NSMutableData dataWithCapacity:(length * 4)];
    do
    {
        stream.avail_out = kMemoryChunkSize;
        stream.next_out = output;
        retCode = inflate(&stream, Z_NO_FLUSH);
        if ((retCode != Z_OK) && (retCode != Z_STREAM_END))
        {
            NSLog(@"%s: inflate() failed with error %i", __PRETTY_FUNCTION__, retCode);
            inflateEnd(&stream);
            return nil;
        }
        gotBack = kMemoryChunkSize - stream.avail_out;
        if (gotBack > 0)
            [result appendBytes:output length:gotBack];
    } while( retCode == Z_OK);
    inflateEnd(&stream);
    
    return (retCode == Z_STREAM_END ? result : nil);
}

+ (NSData *)unwrapMessage:(NSData *)data
{
    if (data.length < 4)
        return data;
    
    int32_t signature = 0;
    [data getBytes:&signature length:4];
    
    if (signature == (int32_t)0x3072cfa1)
    {
        NSData *packedData = [self readBytes:data skippingLength:4];
        if (packedData != nil)
        {
            NSData *unpackedData = [self decompressGZip:packedData];
            return unpackedData;
        }
    }
    
    return data;
}

@end
