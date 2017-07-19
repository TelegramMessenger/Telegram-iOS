#import "TGUnsupportedMediaAttachment.h"

@implementation TGUnsupportedMediaAttachment

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGUnsupportedMediaAttachmentType;
    }
    return self;
}

- (void)serialize:(NSMutableData *)data
{
    uint8_t version = 0;
    [data appendBytes:&version length:1];
    
    int32_t length = (int32_t)_data.length;
    [data appendBytes:&length length:4];
    [data appendData:_data];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    uint8_t version = 0;
    [is read:&version maxLength:1];
    
    int32_t dataLength = 0;
    [is read:(uint8_t *)&dataLength maxLength:4];
    
    uint8_t *dataBytes = malloc(dataLength);
    [is read:dataBytes maxLength:dataLength];
    
    TGUnsupportedMediaAttachment *unsupportedMediaAttachment = [[TGUnsupportedMediaAttachment alloc] init];
    
    unsupportedMediaAttachment.data = [[NSData alloc] initWithBytesNoCopy:dataBytes length:dataLength freeWhenDone:true];
    
    return unsupportedMediaAttachment;
}


@end
