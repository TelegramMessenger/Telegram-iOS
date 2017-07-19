#import "TGReplyMessageMediaAttachment.h"

#import "TGMessage.h"

#import "PSKeyValueDecoder.h"
#import "PSKeyValueEncoder.h"

@implementation TGReplyMessageMediaAttachment

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGReplyMessageMediaAttachmentType;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGReplyMessageMediaAttachment *attachment = [[TGReplyMessageMediaAttachment alloc] init];
    
    attachment->_replyMessageId = _replyMessageId;
    attachment->_replyMessage = [_replyMessage copy];
    
    return attachment;
}

- (void)serialize:(NSMutableData *)data
{
    int dataLengthPtr = (int)data.length;
    int zero = 0;
    [data appendBytes:&zero length:4];
    
    PSKeyValueEncoder *encoder = [[PSKeyValueEncoder alloc] init];
    [encoder encodeObject:_replyMessage forCKey:"replyMessage"];
    [encoder encodeInt32:_replyMessageId forCKey:"replyMessageId"];
    NSData *replyMessageData = [encoder data];
    [data appendData:replyMessageData];
    
    int dataLength = (int)(data.length - dataLengthPtr - 4);
    [data replaceBytesInRange:NSMakeRange(dataLengthPtr, 4) withBytes:&dataLength];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int dataLength = 0;
    [is read:(uint8_t *)&dataLength maxLength:4];
    
    TGReplyMessageMediaAttachment *messageAttachment = [[TGReplyMessageMediaAttachment alloc] init];
    
    uint8_t *replyMessageBytes = malloc(dataLength);
    [is read:replyMessageBytes maxLength:dataLength];
    
    NSData *replyMessageData = [NSData dataWithBytesNoCopy:replyMessageBytes length:dataLength freeWhenDone:true];
    PSKeyValueDecoder *decoder = [[PSKeyValueDecoder alloc] initWithData:replyMessageData];
    TGMessage *replyMessage = (TGMessage *)[decoder decodeObjectForCKey:"replyMessage"];
    int32_t replyMessageId = [decoder decodeInt32ForCKey:"replyMessageId"];
    messageAttachment.replyMessage = replyMessage;
    messageAttachment.replyMessageId = replyMessageId;
    
    return messageAttachment;
}

@end
