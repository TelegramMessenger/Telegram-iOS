#import "TGAudioMediaAttachment.h"

@implementation TGAudioMediaAttachment

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGAudioMediaAttachmentType;
    }
    return self;
}

- (void)serialize:(NSMutableData *)data
{
    int dataLengthPtr = (int)data.length;
    int32_t zero = 0;
    [data appendBytes:&zero length:4];
    
    [data appendBytes:&_audioId length:8];
    [data appendBytes:&_accessHash length:8];
    [data appendBytes:&_datacenterId length:4];

    [data appendBytes:&_localAudioId length:8];
    
    [data appendBytes:&_duration length:4];
    [data appendBytes:&_fileSize length:4];
    
    NSData *audioUriData = [_audioUri dataUsingEncoding:NSUTF8StringEncoding];
    int32_t audioUriLength = (int32_t)audioUriData.length;
    [data appendBytes:&audioUriLength length:4];
    if (audioUriLength != 0)
        [data appendData:audioUriData];
    
    int dataLength = (int)(data.length - dataLengthPtr - 4);
    [data replaceBytesInRange:NSMakeRange(dataLengthPtr, 4) withBytes:&dataLength];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int dataLength = 0;
    [is read:(uint8_t *)&dataLength maxLength:4];
    
    TGAudioMediaAttachment *attachment = [[TGAudioMediaAttachment alloc] init];
    
    if (attachment != nil)
    {
        [is read:(uint8_t *)&attachment->_audioId maxLength:8];
        [is read:(uint8_t *)&attachment->_accessHash maxLength:8];
        [is read:(uint8_t *)&attachment->_datacenterId maxLength:4];
        
        [is read:(uint8_t *)&attachment->_localAudioId maxLength:8];

        [is read:(uint8_t *)&attachment->_duration maxLength:4];
        [is read:(uint8_t *)&attachment->_fileSize maxLength:4];
        
        int32_t audioUriLength = 0;
        [is read:(uint8_t *)&audioUriLength maxLength:4];
        if (audioUriLength != 0)
        {
            uint8_t *audioUriBytes = malloc(audioUriLength);
            [is read:audioUriBytes maxLength:audioUriLength];
            attachment.audioUri = [[NSString alloc] initWithBytesNoCopy:audioUriBytes length:audioUriLength encoding:NSUTF8StringEncoding freeWhenDone:true];
        }
    }
    
    return attachment;
}

@end
