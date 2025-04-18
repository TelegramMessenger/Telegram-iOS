#import "TGContactMediaAttachment.h"

@implementation TGContactMediaAttachment

@synthesize uid = _uid;
@synthesize firstName = _firstName;
@synthesize lastName = _lastName;
@synthesize phoneNumber = _phoneNumber;

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGContactMediaAttachmentType;
    }
    return self;
}

- (void)serialize:(NSMutableData *)data
{
    int dataLengthPtr = (int)data.length;
    int zero = 0;
    [data appendBytes:&zero length:4];
    
    [data appendBytes:&_uid length:4];
    
    NSData *firstNameData = [_firstName dataUsingEncoding:NSUTF8StringEncoding];
    int length = (int)firstNameData.length;
    [data appendBytes:&length length:4];
    [data appendData:firstNameData];
    
    NSData *lastNameData = [_lastName dataUsingEncoding:NSUTF8StringEncoding];
    length = (int)lastNameData.length;
    [data appendBytes:&length length:4];
    [data appendData:lastNameData];
    
    NSData *phoneData = [_phoneNumber dataUsingEncoding:NSUTF8StringEncoding];
    length = (int)phoneData.length;
    [data appendBytes:&length length:4];
    [data appendData:phoneData];
    
    NSData *vcardData = [_vcard dataUsingEncoding:NSUTF8StringEncoding];
    length = (int)vcardData.length;
    [data appendBytes:&length length:4];
    [data appendData:vcardData];
    
    int dataLength = (int)data.length - dataLengthPtr - 4;
    [data replaceBytesInRange:NSMakeRange(dataLengthPtr, 4) withBytes:&dataLength];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int dataLength = 0;
    int read = 0;
    [is read:(uint8_t *)&dataLength maxLength:4];
    
    TGContactMediaAttachment *contactAttachment = [[TGContactMediaAttachment alloc] init];
    
    int uid = 0;
    [is read:(uint8_t *)&uid maxLength:4];
    read += 4;
    contactAttachment.uid = uid;
    
    int length = 0;
    [is read:(uint8_t *)&length maxLength:4];
    uint8_t *firstNameBytes = malloc(length);
    [is read:firstNameBytes maxLength:length];
    read += length + 4;
    contactAttachment.firstName = [[NSString alloc] initWithBytesNoCopy:firstNameBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
    
    length = 0;
    [is read:(uint8_t *)&length maxLength:4];
    uint8_t *lastNameBytes = malloc(length);
    [is read:lastNameBytes maxLength:length];
    read += length + 4;
    contactAttachment.lastName = [[NSString alloc] initWithBytesNoCopy:lastNameBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
    
    length = 0;
    [is read:(uint8_t *)&length maxLength:4];
    uint8_t *phoneBytes = malloc(length);
    [is read:phoneBytes maxLength:length];
    read += length + 4;
    contactAttachment.phoneNumber = [[NSString alloc] initWithBytesNoCopy:phoneBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
    
    if (read < dataLength)
    {
        length = 0;
        [is read:(uint8_t *)&length maxLength:4];
        uint8_t *vcardBytes = malloc(length);
        [is read:vcardBytes maxLength:length];
        read += length;
        contactAttachment.vcard = [[NSString alloc] initWithBytesNoCopy:vcardBytes length:length encoding:NSUTF8StringEncoding freeWhenDone:true];
    }
    
    return contactAttachment;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        self.type = TGContactMediaAttachmentType;
        _uid = [aDecoder decodeInt32ForKey:@"uid"];
        _firstName = [aDecoder decodeObjectForKey:@"firstName"];
        _lastName = [aDecoder decodeObjectForKey:@"lastName"];
        _phoneNumber = [aDecoder decodeObjectForKey:@"phoneNumber"];
        _vcard = [aDecoder decodeObjectForKey:@"vcard"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt32:_uid forKey:@"uid"];
    [aCoder encodeObject:_firstName forKey:@"firstName"];
    [aCoder encodeObject:_lastName forKey:@"lastName"];
    [aCoder encodeObject:_phoneNumber forKey:@"phoneNumber"];
    [aCoder encodeObject:_vcard forKey:@"vcard"];
}

@end
