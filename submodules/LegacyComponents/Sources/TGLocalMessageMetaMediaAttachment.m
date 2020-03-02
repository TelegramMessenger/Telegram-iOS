#import "TGLocalMessageMetaMediaAttachment.h"

#import "TGImageInfo.h"

@implementation TGLocalMessageMetaMediaAttachment

@synthesize imageInfoList = _imageInfoList;
@synthesize imageUrlToDataFile = _imageUrlToDataFile;
@synthesize localMediaId = _localMediaId;

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGLocalMessageMetaMediaAttachmentType;
        
        _imageInfoList = [[NSMutableArray alloc] init];
        _imageUrlToDataFile = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)serialize:(NSMutableData *)data
{
    int dataLengthPtr = (int)data.length;
    int zero = 0;
    [data appendBytes:&zero length:4];
    
    int count = (int)_imageInfoList.count;
    [data appendBytes:&count length:4];
    for (int i = 0; i < count; i++)
    {
        [(TGImageInfo *)[_imageInfoList objectAtIndex:i] serialize:data];
    }
    
    count = (int)_imageUrlToDataFile.count;
    [data appendBytes:&count length:4];
    [_imageUrlToDataFile enumerateKeysAndObjectsUsingBlock:^(NSString *imageUrl, NSString *filePath, __unused BOOL *stop)
    {
        NSData *byteData = [imageUrl dataUsingEncoding:NSUTF8StringEncoding];
        int length = (int)byteData.length;
        [data appendBytes:&length length:4];
        [data appendData:byteData];
        
        byteData = [filePath dataUsingEncoding:NSUTF8StringEncoding];
        length = (int)byteData.length;
        [data appendBytes:&length length:4];
        [data appendData:byteData];
    }];
    
    [data appendBytes:&_localMediaId length:4];
    
    int dataLength = (int)(data.length - dataLengthPtr - 4);
    [data replaceBytesInRange:NSMakeRange(dataLengthPtr, 4) withBytes:&dataLength];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int dataLength = 0;
    [is read:(uint8_t *)&dataLength maxLength:4];
    
    TGLocalMessageMetaMediaAttachment *attachment = [[TGLocalMessageMetaMediaAttachment alloc] init];
    
    int count = 0;
    [is read:(uint8_t *)&count maxLength:4];
    for (int i = 0; i < count; i++)
    {
        TGImageInfo *imageInfo = [TGImageInfo deserialize:is];
        if (imageInfo != nil)
            [attachment.imageInfoList addObject:imageInfo];
    }
    
    count = 0;
    [is read:(uint8_t *)&count maxLength:4];
    for (int i = 0; i < count; i++)
    {
        int length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *bytes = malloc(length);
        [is read:bytes maxLength:length];
        NSString *imageUrl = [[NSString alloc] initWithBytesNoCopy:bytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        
        length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        bytes = malloc(length);
        [is read:bytes maxLength:length];
        NSString *filePath = [[NSString alloc] initWithBytesNoCopy:bytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
        
        if (imageUrl != nil && filePath != nil)
            [attachment.imageUrlToDataFile setObject:filePath forKey:imageUrl];
    }
    
    int mediaId = 0;
    [is read:(uint8_t *)&mediaId maxLength:4];
    attachment.localMediaId = mediaId;
    
    return attachment;
}

@end
