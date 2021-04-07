#import "TGForwardedMessageMediaAttachment.h"

@implementation TGForwardedMessageMediaAttachment

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGForwardedMessageMediaAttachmentType;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGForwardedMessageMediaAttachment *attachment = [[TGForwardedMessageMediaAttachment alloc] init];
    
    attachment.forwardSourcePeerId = _forwardSourcePeerId;
    attachment.forwardPeerId = _forwardPeerId;
    attachment.forwardDate = _forwardDate;
    attachment.forwardAuthorUserId = _forwardAuthorUserId;
    attachment.forwardPostId = _forwardPostId;
    attachment.forwardMid = _forwardMid;
    
    return attachment;
}

- (void)serialize:(NSMutableData *)data
{
    int32_t magic = 0x72413fad;
    [data appendBytes:&magic length:4];
    
    int dataLengthPtr = (int)data.length;
    int zero = 0;
    [data appendBytes:&zero length:4];
    
    [data appendBytes:&_forwardPeerId length:8];
    [data appendBytes:&_forwardDate length:4];
    [data appendBytes:&_forwardMid length:4];
    
    [data appendBytes:&_forwardAuthorUserId length:4];
    [data appendBytes:&_forwardPostId length:4];
    
    [data appendBytes:&_forwardSourcePeerId length:8];
    
    NSData *signatureData = [_forwardAuthorSignature dataUsingEncoding:NSUTF8StringEncoding];
    int32_t signatureLength = (int32_t)signatureData.length;
    [data appendBytes:&signatureLength length:4];
    [data appendData:signatureData];
    
    int dataLength = (int)(data.length - dataLengthPtr - 4);
    [data replaceBytesInRange:NSMakeRange(dataLengthPtr, 4) withBytes:&dataLength];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int32_t magic = 0;
    [is read:(uint8_t *)&magic maxLength:4];
    
    int32_t dataLength = 0;
    
    int32_t version = 0;
    
    if (magic == 0x72413faa) {
        version = 2;
        [is read:(uint8_t *)&dataLength maxLength:4];
    } else if (magic == 0x72413fab) {
        version = 3;
        [is read:(uint8_t *)&dataLength maxLength:4];
    } else if (magic == 0x72413fac) {
        version = 4;
        [is read:(uint8_t *)&dataLength maxLength:4];
    } else if (magic == 0x72413fad) {
        version = 5;
        [is read:(uint8_t *)&dataLength maxLength:4];
    } else {
        dataLength = magic;
    }
    
    TGForwardedMessageMediaAttachment *messageAttachment = [[TGForwardedMessageMediaAttachment alloc] init];
    
    if (version >= 2) {
        int64_t forwardPeerId = 0;
        [is read:(uint8_t *)&forwardPeerId maxLength:8];
        messageAttachment.forwardPeerId = forwardPeerId;
    } else {
        int32_t forwardUid = 0;
        [is read:(uint8_t *)&forwardUid maxLength:4];
        messageAttachment.forwardPeerId = forwardUid;
    }
    
    int forwardDate = 0;
    [is read:(uint8_t *)&forwardDate maxLength:4];
    messageAttachment.forwardDate = forwardDate;
    
    int forwardMid = 0;
    [is read:(uint8_t *)&forwardMid maxLength:4];
    messageAttachment.forwardMid = forwardMid;
    
    if (version >= 3) {
        int32_t forwardAuthorUserId = 0;
        [is read:(uint8_t *)&forwardAuthorUserId maxLength:4];
        messageAttachment.forwardAuthorUserId = forwardAuthorUserId;
        
        int32_t forwardPostId = 0;
        [is read:(uint8_t *)&forwardPostId maxLength:4];
        messageAttachment.forwardPostId = forwardPostId;
    }
    
    if (version >= 4) {
        int64_t forwardSourcePeerId = 0;
        [is read:(uint8_t *)&forwardSourcePeerId maxLength:8];
        messageAttachment.forwardSourcePeerId = forwardSourcePeerId;
    }
    
    if (version >= 5) {
        int32_t signatureLength = 0;
        [is read:(uint8_t *)&signatureLength maxLength:4];
        uint8_t *signatureBytes = malloc(signatureLength);
        [is read:signatureBytes maxLength:signatureLength];
        NSString *signature = [[NSString alloc] initWithBytesNoCopy:signatureBytes length:signatureLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        if (signatureLength != 0) {
            messageAttachment.forwardAuthorSignature = signature;
        } else {
            messageAttachment.forwardAuthorSignature = nil;
        }
    }
    
    return messageAttachment;
}

@end
